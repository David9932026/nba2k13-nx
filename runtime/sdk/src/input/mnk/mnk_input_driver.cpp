/**
 * @file        input/mnk/mnk_input_driver.cpp
 * @brief       Keyboard/mouse input driver implementation.
 *
 * @copyright   Copyright (c) 2026 Tom Clay <tomc@tctechstuff.com>
 *              All rights reserved.
 *
 * @license     BSD 3-Clause License
 *              See LICENSE file in the project root for full license text.
 */
#include <rex/input/mnk/mnk_input_driver.h>

#include <rex/cvar.h>
#include <rex/input/input.h>
#include <rex/logging.h>
#include <rex/ui/keybinds.h>
#include <rex/ui/virtual_key.h>
#include <rex/ui/window.h>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>
#include <cstring>
#include <string_view>
#include <filesystem>
#include <mutex>

REXCVAR_DEFINE_BOOL(mnk_mode, false, "Input", "Enable keyboard/mouse controller emulation");
REXCVAR_DEFINE_BOOL(mnk_mouse, false, "Input",
                    "Use the mouse for the right stick. Off means the right stick comes "
                    "from the keybind_rstick_* keys only");
REXCVAR_DEFINE_DOUBLE(mnk_sensitivity, 1.0, "Input", "Mouse sensitivity for right stick")
    .range(0.01, 10.0);

// PATCH(cola): 脚本输入。文件里每行 `起始ms 结束ms 按钮名`，按时间轴合成手柄状态。
// 用于无手柄、且窗口抢不到前台焦点时自动推进游戏（无焦点时窗口收不到按键事件）。
REXCVAR_DEFINE_STRING(mnk_script, "", "Input",
                      "Path to a scripted pad timeline (lines: start_ms end_ms BUTTON)");

REXCVAR_DEFINE_STRING(keybind_a, "Semicolon,Space", "Input/Keybinds/Controller", "A button");
REXCVAR_DEFINE_STRING(keybind_b, "Quote,Backspace", "Input/Keybinds/Controller", "B button");
REXCVAR_DEFINE_STRING(keybind_x, "L", "Input/Keybinds/Controller", "X button");
REXCVAR_DEFINE_STRING(keybind_y, "P", "Input/Keybinds/Controller", "Y button");
REXCVAR_DEFINE_STRING(keybind_left_trigger, "Q,I", "Input/Keybinds/Controller", "Left trigger");
REXCVAR_DEFINE_STRING(keybind_right_trigger, "E,O", "Input/Keybinds/Controller", "Right trigger");
REXCVAR_DEFINE_STRING(keybind_left_shoulder, "1", "Input/Keybinds/Controller", "Left shoulder");
REXCVAR_DEFINE_STRING(keybind_right_shoulder, "3", "Input/Keybinds/Controller", "Right shoulder");
REXCVAR_DEFINE_STRING(keybind_lstick_up, "W", "Input/Keybinds/Controller", "Left stick up");
REXCVAR_DEFINE_STRING(keybind_lstick_down, "S", "Input/Keybinds/Controller", "Left stick down");
REXCVAR_DEFINE_STRING(keybind_lstick_left, "A", "Input/Keybinds/Controller", "Left stick left");
REXCVAR_DEFINE_STRING(keybind_lstick_right, "D", "Input/Keybinds/Controller", "Left stick right");
REXCVAR_DEFINE_STRING(keybind_lstick_press, "F", "Input/Keybinds/Controller", "Left stick press");
REXCVAR_DEFINE_STRING(keybind_rstick_up, "Up", "Input/Keybinds/Controller", "Right stick up");
REXCVAR_DEFINE_STRING(keybind_rstick_down, "Down", "Input/Keybinds/Controller", "Right stick down");
REXCVAR_DEFINE_STRING(keybind_rstick_left, "Left", "Input/Keybinds/Controller", "Right stick left");
REXCVAR_DEFINE_STRING(keybind_rstick_right, "Right", "Input/Keybinds/Controller",
                      "Right stick right");
REXCVAR_DEFINE_STRING(keybind_rstick_press, "K", "Input/Keybinds/Controller", "Right stick press");
REXCVAR_DEFINE_STRING(keybind_dpad_up, "Shift+Up", "Input/Keybinds/Controller", "D-pad up");
REXCVAR_DEFINE_STRING(keybind_dpad_down, "Shift+Down", "Input/Keybinds/Controller", "D-pad down");
REXCVAR_DEFINE_STRING(keybind_dpad_left, "Shift+Left", "Input/Keybinds/Controller", "D-pad left");
REXCVAR_DEFINE_STRING(keybind_dpad_right, "Shift+Right", "Input/Keybinds/Controller",
                      "D-pad right");
REXCVAR_DEFINE_STRING(keybind_back, "Z,Tab", "Input/Keybinds/Controller", "Back button");
REXCVAR_DEFINE_STRING(keybind_start, "X,Return", "Input/Keybinds/Controller", "Start button");
REXCVAR_DEFINE_STRING(keybind_guide, "", "Input/Keybinds/Controller", "Guide button");

namespace rex::input::mnk {

namespace {

// A single device, so its handle is a constant.
constexpr rex::input::DeviceId kMnkDevice = static_cast<rex::input::DeviceId>(0x4D4E4B00);

// Bind values are a comma-separated list of alternatives, each optionally
// carrying modifier prefixes: "Q,I" or "Shift+W". Modifier matching is exact,
// so "Up" stays silent while Shift is held and "Shift+Up" stays silent without
// it. That is what lets the D-pad share the arrow keys. A consequence is
// that binding a bare modifier name ("Shift") can never fire, since holding it
// makes the live mask non-zero while the bind wants zero.
constexpr uint8_t kModShift = 1u << 0;
constexpr uint8_t kModCtrl = 1u << 1;
constexpr uint8_t kModAlt = 1u << 2;

uint8_t LiveModifiers(const bool (&key_down)[256]) {
  uint8_t mods = 0;
  if (key_down[static_cast<uint16_t>(rex::ui::VirtualKey::kShift)])
    mods |= kModShift;
  if (key_down[static_cast<uint16_t>(rex::ui::VirtualKey::kControl)])
    mods |= kModCtrl;
  if (key_down[static_cast<uint16_t>(rex::ui::VirtualKey::kMenu)])
    mods |= kModAlt;
  return mods;
}

// Strips leading modifier prefixes off 'token', advancing it to the bare key
// name and returning the mask they require.
uint8_t TakeModifiers(std::string_view& token) {
  uint8_t mods = 0;
  for (;;) {
    size_t plus = token.find('+');
    if (plus == std::string_view::npos || plus == 0) {
      break;
    }
    std::string_view head = token.substr(0, plus);
    uint8_t bit = 0;
    if (head == "Shift") {
      bit = kModShift;
    } else if (head == "Ctrl" || head == "Control") {
      bit = kModCtrl;
    } else if (head == "Alt") {
      bit = kModAlt;
    } else {
      break;
    }
    mods |= bit;
    token.remove_prefix(plus + 1);
  }
  return mods;
}

std::string_view TrimSpaces(std::string_view s) {
  while (!s.empty() && s.front() == ' ') {
    s.remove_prefix(1);
  }
  while (!s.empty() && s.back() == ' ') {
    s.remove_suffix(1);
  }
  return s;
}

bool TokenPressed(const bool (&key_down)[256], std::string_view token, uint8_t live_mods) {
  uint8_t want = TakeModifiers(token);
  if (want != live_mods) {
    return false;
  }
  rex::ui::VirtualKey vk = rex::ui::ParseVirtualKey(token);
  if (vk == rex::ui::VirtualKey::kNone) {
    return false;
  }
  uint16_t idx = static_cast<uint16_t>(vk);
  return idx < 256 && key_down[idx];
}

std::atomic<bool> mouse_look_active{true};

// PATCH(cola): ---- 脚本输入时间轴 ----
struct ScriptEvent {
  uint32_t start_ms;
  uint32_t end_ms;
  std::string button;
};

std::vector<ScriptEvent>& ScriptEvents() {
  static std::vector<ScriptEvent> events;
  return events;
}

// PATCH(cola): the game polls input from more than one guest thread, and the timeline can be
// replaced from a background reload, so every access goes through this lock.
std::mutex& ScriptMutex() {
  static std::mutex m;
  return m;
}

bool& ScriptLoaded() {
  static bool loaded = false;
  return loaded;
}

std::chrono::steady_clock::time_point& ScriptStart() {
  static std::chrono::steady_clock::time_point start = std::chrono::steady_clock::now();
  return start;
}

void ParseScriptFile(const std::string& path) {
  FILE* f = std::fopen(path.c_str(), "rb");
  if (!f) {
    REXLOG_ERROR("[mnk-script] cannot open {}", path);
    return;
  }
  std::vector<ScriptEvent> parsed;
  char line[256];
  while (std::fgets(line, sizeof(line), f)) {
    std::string_view sv(line);
    if (sv.find('#') != std::string_view::npos) {
      sv = sv.substr(0, sv.find('#'));
    }
    unsigned start = 0, end = 0;
    char name[64] = {};
    if (std::sscanf(std::string(sv).c_str(), "%u %u %63s", &start, &end, name) == 3) {
      parsed.push_back({start, end, std::string(name)});
    }
  }
  std::fclose(f);
  size_t count = parsed.size();
  {
    std::lock_guard<std::mutex> lock(ScriptMutex());
    ScriptEvents().swap(parsed);
  }
  REXLOG_INFO("[mnk-script] loaded {} event(s) from {}", count, path);
}

// PATCH(cola): hot reload. The script file can be rewritten while the game runs, so
// menus can be driven interactively instead of guessing a whole timeline up front.
// Event times stay relative to process start, so a rewrite just replaces the timeline.
void LoadScriptIfNeeded() {
  static std::string path;
  static std::chrono::steady_clock::time_point last_check{};
  static uint64_t last_stamp = 0;
  const auto now = std::chrono::steady_clock::now();
  if (!ScriptLoaded()) {
    ScriptLoaded() = true;
    ScriptStart() = now;
    path = REXCVAR_GET(mnk_script);
    if (path.empty()) {
      return;
    }
    ParseScriptFile(path);
    last_check = now;
  }
  if (path.empty()) {
    return;
  }
  if (now - last_check < std::chrono::milliseconds(400)) {
    return;
  }
  last_check = now;
  std::error_code ec;
  const auto write_time = std::filesystem::last_write_time(path, ec);
  if (ec) {
    return;
  }
  const auto size = std::filesystem::file_size(path, ec);
  if (ec) {
    return;
  }
  const uint64_t stamp = uint64_t(write_time.time_since_epoch().count()) ^ (uint64_t(size) << 40);
  if (stamp == last_stamp) {
    return;
  }
  last_stamp = stamp;
  ParseScriptFile(path);
}

uint32_t ScriptNowMs() {
  auto delta = std::chrono::steady_clock::now() - ScriptStart();
  return static_cast<uint32_t>(
      std::chrono::duration_cast<std::chrono::milliseconds>(delta).count());
}

}  // namespace

void SetMouseLookActive(bool active) {
  mouse_look_active.store(active, std::memory_order_relaxed);
}

bool IsMouseLookActive() {
  return mouse_look_active.load(std::memory_order_relaxed);
}

using rex::ui::VirtualKey;

MnkInputDriver::MnkInputDriver(rex::ui::Window* window, size_t window_z_order)
    : InputDriver(window, window_z_order) {}

MnkInputDriver::~MnkInputDriver() {
  // Detach handled by OnClosing; if window outlives the driver, clean up here.
  DetachFromWindow();
}

X_STATUS MnkInputDriver::Setup() {
  return X_STATUS_SUCCESS;
}

void MnkInputDriver::OnWindowAvailable(rex::ui::Window* window) {
  if (window) {
    {
      std::lock_guard lock(state_mutex_);
      attached_window_ = window;
    }
    window->AddInputListener(this, window_z_order());
    window->AddListener(this);
  }
}

void MnkInputDriver::OnClosing(rex::ui::UIEvent&) {
  DetachFromWindow();
}

void MnkInputDriver::DetachFromWindow() {
  rex::ui::Window* window = attached_window_;
  if (!window) {
    return;
  }
  window->app_context().CallInUIThreadSynchronous([this, window] {
    // Detach first so nothing new is queued, then run out what already was.
    {
      std::lock_guard lock(state_mutex_);
      attached_window_ = nullptr;
    }
    if (mouse_capture_update_queued_.load(std::memory_order_relaxed)) {
      window->app_context().ExecutePendingFunctionsFromUIThread();
    }
    ReleaseMouseCaptureFromUIThread(window);
    window->RemoveInputListener(this);
    window->RemoveListener(this);
  });
}

bool MnkInputDriver::IsEnabled() const {
  return REXCVAR_GET(mnk_mode);
}

static bool IsBindPressed(const bool (&key_down)[256], const std::string& cvar_val) {
  const uint8_t live_mods = LiveModifiers(key_down);
  std::string_view rest(cvar_val);
  while (!rest.empty()) {
    size_t comma = rest.find(',');
    std::string_view token = rest.substr(0, comma);
    if (comma == std::string_view::npos) {
      rest = std::string_view();
    } else {
      rest.remove_prefix(comma + 1);
    }
    token = TrimSpaces(token);
    if (!token.empty() && TokenPressed(key_down, token, live_mods)) {
      return true;
    }
  }
  return false;
}

void MnkInputDriver::EnumerateDevices(std::vector<DeviceInfo>& out) {
  // Disabled means no device at all, so it never occupies a guest user slot.
  if (!IsEnabled()) {
    return;
  }
  DeviceInfo info;
  info.id = kMnkDevice;
  info.name = "Keyboard and Mouse";
  info.synthetic = true;
  out.push_back(info);
}

X_RESULT MnkInputDriver::GetDeviceCapabilities(DeviceId id, uint32_t flags,
                                               X_INPUT_CAPABILITIES* out_caps) {
  if (!IsEnabled() || id != kMnkDevice) {
    return X_ERROR_DEVICE_NOT_CONNECTED;
  }
  if (out_caps) {
    std::memset(out_caps, 0, sizeof(*out_caps));
    out_caps->type = 0x01;
    out_caps->sub_type = 0x01;
    out_caps->flags = 0;
    out_caps->gamepad.buttons = 0xFFFF;
    out_caps->gamepad.left_trigger = 0xFF;
    out_caps->gamepad.right_trigger = 0xFF;
    out_caps->gamepad.thumb_lx = static_cast<int16_t>(0x7FFF);
    out_caps->gamepad.thumb_ly = static_cast<int16_t>(0x7FFF);
    out_caps->gamepad.thumb_rx = static_cast<int16_t>(0x7FFF);
    out_caps->gamepad.thumb_ry = static_cast<int16_t>(0x7FFF);
    out_caps->vibration.left_motor_speed = 0xFFFF;
    out_caps->vibration.right_motor_speed = 0xFFFF;
  }
  return X_ERROR_SUCCESS;
}

X_RESULT MnkInputDriver::GetDeviceState(DeviceId id, X_INPUT_STATE* out_state) {
  if (!IsEnabled() || id != kMnkDevice) {
    return X_ERROR_DEVICE_NOT_CONNECTED;
  }

  // Mouse look is opt in. Without this gate, keyboard input alone would hide
  // and lock the cursor, breaking the ImGui overlays.
  QueueMouseCaptureUpdate(IsEnabled() && REXCVAR_GET(mnk_mouse) && IsMouseLookActive() &&
                          has_focus_ && is_active());

  // PATCH(cola): 脚本输入不需要窗口焦点（后台进程抢前台必定失败）。
  LoadScriptIfNeeded();
  bool scripted = false;
  {
    std::lock_guard<std::mutex> lock(ScriptMutex());
    scripted = !ScriptEvents().empty();
  }

  if (!scripted && (!is_active() || !has_focus_)) {
    if (out_state) {
      std::memset(out_state, 0, sizeof(*out_state));
      out_state->packet_number = packet_number_;
    }
    return X_ERROR_SUCCESS;
  }

  std::lock_guard lock(state_mutex_);

  uint16_t buttons = 0;
  if (IsBindPressed(key_down_, REXCVAR_GET(keybind_a)))
    buttons |= X_INPUT_GAMEPAD_A;
  if (IsBindPressed(key_down_, REXCVAR_GET(keybind_b)))
    buttons |= X_INPUT_GAMEPAD_B;
  if (IsBindPressed(key_down_, REXCVAR_GET(keybind_x)))
    buttons |= X_INPUT_GAMEPAD_X;
  if (IsBindPressed(key_down_, REXCVAR_GET(keybind_y)))
    buttons |= X_INPUT_GAMEPAD_Y;
  if (IsBindPressed(key_down_, REXCVAR_GET(keybind_left_shoulder)))
    buttons |= X_INPUT_GAMEPAD_LEFT_SHOULDER;
  if (IsBindPressed(key_down_, REXCVAR_GET(keybind_right_shoulder)))
    buttons |= X_INPUT_GAMEPAD_RIGHT_SHOULDER;
  if (IsBindPressed(key_down_, REXCVAR_GET(keybind_lstick_press)))
    buttons |= X_INPUT_GAMEPAD_LEFT_THUMB;
  if (IsBindPressed(key_down_, REXCVAR_GET(keybind_rstick_press)))
    buttons |= X_INPUT_GAMEPAD_RIGHT_THUMB;
  if (IsBindPressed(key_down_, REXCVAR_GET(keybind_back)))
    buttons |= X_INPUT_GAMEPAD_BACK;
  if (IsBindPressed(key_down_, REXCVAR_GET(keybind_start)))
    buttons |= X_INPUT_GAMEPAD_START;
  if (IsBindPressed(key_down_, REXCVAR_GET(keybind_guide)))
    buttons |= X_INPUT_GAMEPAD_GUIDE;
  if (IsBindPressed(key_down_, REXCVAR_GET(keybind_dpad_up)))
    buttons |= X_INPUT_GAMEPAD_DPAD_UP;
  if (IsBindPressed(key_down_, REXCVAR_GET(keybind_dpad_down)))
    buttons |= X_INPUT_GAMEPAD_DPAD_DOWN;
  if (IsBindPressed(key_down_, REXCVAR_GET(keybind_dpad_left)))
    buttons |= X_INPUT_GAMEPAD_DPAD_LEFT;
  if (IsBindPressed(key_down_, REXCVAR_GET(keybind_dpad_right)))
    buttons |= X_INPUT_GAMEPAD_DPAD_RIGHT;

  uint8_t lt = IsBindPressed(key_down_, REXCVAR_GET(keybind_left_trigger)) ? 0xFF : 0;
  uint8_t rt = IsBindPressed(key_down_, REXCVAR_GET(keybind_right_trigger)) ? 0xFF : 0;

  int32_t lx = 0;
  int32_t ly = 0;
  if (IsBindPressed(key_down_, REXCVAR_GET(keybind_lstick_left)))
    lx -= INT16_MAX;
  if (IsBindPressed(key_down_, REXCVAR_GET(keybind_lstick_right)))
    lx += INT16_MAX;
  if (IsBindPressed(key_down_, REXCVAR_GET(keybind_lstick_up)))
    ly += INT16_MAX;
  if (IsBindPressed(key_down_, REXCVAR_GET(keybind_lstick_down)))
    ly -= INT16_MAX;

  int32_t rx = 0;
  int32_t ry = 0;
  if (IsBindPressed(key_down_, REXCVAR_GET(keybind_rstick_left)))
    rx -= INT16_MAX;
  if (IsBindPressed(key_down_, REXCVAR_GET(keybind_rstick_right)))
    rx += INT16_MAX;
  if (IsBindPressed(key_down_, REXCVAR_GET(keybind_rstick_up)))
    ry += INT16_MAX;
  if (IsBindPressed(key_down_, REXCVAR_GET(keybind_rstick_down)))
    ry -= INT16_MAX;

  if (REXCVAR_GET(mnk_mouse) && IsMouseLookActive()) {
    double sensitivity = REXCVAR_GET(mnk_sensitivity);
    constexpr double kBaseScale = 200.0;
    rx += static_cast<int32_t>(double(mouse_dx_) * sensitivity * kBaseScale);
    ry += static_cast<int32_t>(double(-mouse_dy_) * sensitivity * kBaseScale);
  }
  // Drained unconditionally: deltas keep accumulating in OnMouseMove while the
  // mouse is off, and toggling it on would otherwise dump the whole backlog
  // into one frame as a camera snap.
  mouse_dx_ = 0.0f;
  mouse_dy_ = 0.0f;

  // PATCH(cola): 叠加脚本输入（不需要窗口焦点）。
  if (scripted) {
    const uint32_t now_ms = ScriptNowMs();
    static std::atomic<uint16_t> last_logged{0xFFFF};
    uint16_t script_buttons = 0;
    std::lock_guard<std::mutex> lock(ScriptMutex());
    for (const auto& ev : ScriptEvents()) {
      if (now_ms < ev.start_ms || now_ms >= ev.end_ms) {
        continue;
      }
      const std::string& b = ev.button;
      if (b == "A")
        script_buttons |= X_INPUT_GAMEPAD_A;
      else if (b == "B")
        script_buttons |= X_INPUT_GAMEPAD_B;
      else if (b == "X")
        script_buttons |= X_INPUT_GAMEPAD_X;
      else if (b == "Y")
        script_buttons |= X_INPUT_GAMEPAD_Y;
      else if (b == "LB")
        script_buttons |= X_INPUT_GAMEPAD_LEFT_SHOULDER;
      else if (b == "RB")
        script_buttons |= X_INPUT_GAMEPAD_RIGHT_SHOULDER;
      else if (b == "LS")
        script_buttons |= X_INPUT_GAMEPAD_LEFT_THUMB;
      else if (b == "RS")
        script_buttons |= X_INPUT_GAMEPAD_RIGHT_THUMB;
      else if (b == "BACK")
        script_buttons |= X_INPUT_GAMEPAD_BACK;
      else if (b == "START")
        script_buttons |= X_INPUT_GAMEPAD_START;
      else if (b == "DU")
        script_buttons |= X_INPUT_GAMEPAD_DPAD_UP;
      else if (b == "DD")
        script_buttons |= X_INPUT_GAMEPAD_DPAD_DOWN;
      else if (b == "DL")
        script_buttons |= X_INPUT_GAMEPAD_DPAD_LEFT;
      else if (b == "DR")
        script_buttons |= X_INPUT_GAMEPAD_DPAD_RIGHT;
      else if (b == "LT")
        lt = 0xFF;
      else if (b == "RT")
        rt = 0xFF;
      else if (b == "LUP")
        ly += INT16_MAX;
      else if (b == "LDOWN")
        ly -= INT16_MAX;
      else if (b == "LLEFT")
        lx -= INT16_MAX;
      else if (b == "LRIGHT")
        lx += INT16_MAX;
      else if (b == "RUP")
        ry += INT16_MAX;
      else if (b == "RDOWN")
        ry -= INT16_MAX;
      else if (b == "RLEFT")
        rx -= INT16_MAX;
      else if (b == "RRIGHT")
        rx += INT16_MAX;
    }
    buttons |= script_buttons;
    if (script_buttons != last_logged.load()) {
      last_logged = script_buttons;
      REXLOG_INFO("[mnk-script] t={}ms buttons=0x{:04X}", now_ms, script_buttons);
    }
  }

  auto clamp16 = [](int32_t v) -> int16_t {
    return static_cast<int16_t>(std::clamp(v, (int32_t)INT16_MIN, (int32_t)INT16_MAX));
  };

  packet_number_++;

  {  // PATCH(cola): final state the game sees, logged on change (real keys + script).
    static uint64_t ultimo = ~0ull;
    const uint64_t ahora = uint64_t(buttons) | (uint64_t(lt) << 16) | (uint64_t(rt) << 24) |
                           (uint64_t(uint16_t(clamp16(lx))) << 32) | (uint64_t(uint16_t(clamp16(ly))) << 48);
    if (ahora != ultimo) {
      ultimo = ahora;
      REXLOG_INFO("[mnk-final] buttons=0x{:04X} lt={} rt={} lx={} ly={} rx={} ry={} teclas={}", buttons, lt, rt,
                  clamp16(lx), clamp16(ly), clamp16(rx), clamp16(ry),
                  std::count(std::begin(key_down_), std::end(key_down_), true));
    }
  }

  if (out_state) {
    out_state->packet_number = packet_number_;
    out_state->gamepad.buttons = buttons;
    out_state->gamepad.left_trigger = lt;
    out_state->gamepad.right_trigger = rt;
    out_state->gamepad.thumb_lx = clamp16(lx);
    out_state->gamepad.thumb_ly = clamp16(ly);
    out_state->gamepad.thumb_rx = clamp16(rx);
    out_state->gamepad.thumb_ry = clamp16(ry);
  }
  return X_ERROR_SUCCESS;
}

X_RESULT MnkInputDriver::SetDeviceVibration(DeviceId id, X_INPUT_VIBRATION* vibration) {
  if (!IsEnabled() || id != kMnkDevice) {
    return X_ERROR_DEVICE_NOT_CONNECTED;
  }
  return X_ERROR_SUCCESS;
}

X_RESULT MnkInputDriver::GetDeviceKeystroke(DeviceId id, uint32_t flags,
                                            X_INPUT_KEYSTROKE* out_keystroke) {
  if (!IsEnabled() || id != kMnkDevice) {
    return X_ERROR_DEVICE_NOT_CONNECTED;
  }
  std::lock_guard lock(state_mutex_);
  if (keystroke_queue_.empty()) {
    return X_ERROR_EMPTY;
  }
  if (out_keystroke) {
    *out_keystroke = keystroke_queue_.front();
  }
  keystroke_queue_.pop();
  return X_ERROR_SUCCESS;
}

void MnkInputDriver::EnqueueKeystroke(uint16_t vk_pad, bool down) {
  X_INPUT_KEYSTROKE ks = {};
  ks.virtual_key = vk_pad;
  ks.unicode = 0;
  ks.flags = down ? X_INPUT_KEYSTROKE_KEYDOWN : X_INPUT_KEYSTROKE_KEYUP;
  // InputSystem stamps the guest user this device is assigned to.
  ks.user_index = 0;
  ks.hid_code = 0;
  keystroke_queue_.push(ks);
}

void MnkInputDriver::QueueMouseCaptureUpdate(bool should_capture) {
  mouse_capture_requested_.store(should_capture, std::memory_order_relaxed);
  bool already_queued = false;
  if (!mouse_capture_update_queued_.compare_exchange_strong(already_queued, true)) {
    return;
  }
  std::lock_guard lock(state_mutex_);
  if (!attached_window_) {
    mouse_capture_update_queued_.store(false, std::memory_order_relaxed);
    return;
  }
  // Deferred, not CallInUIThread: running inline would re-enter state_mutex_.
  attached_window_->app_context().CallInUIThreadDeferred([this] {
    mouse_capture_update_queued_.store(false, std::memory_order_relaxed);
    ApplyMouseCaptureFromUIThread();
  });
}

void MnkInputDriver::ApplyMouseCaptureFromUIThread() {
  rex::ui::Window* window = attached_window_;
  if (!window) {
    return;
  }
  bool should_capture = mouse_capture_requested_.load(std::memory_order_relaxed);
  if (should_capture == mouse_captured_) {
    return;
  }
  if (!should_capture) {
    ReleaseMouseCaptureFromUIThread(window);
    return;
  }
  mouse_captured_ = true;
  precapture_cursor_visibility_ = window->GetCursorVisibility();
  window->SetCursorVisibility(rex::ui::Window::CursorVisibility::kHidden);
  window->CaptureMouse();
  relative_mouse_mode_ = window->SetRelativeMouseMode(true);
  if (!relative_mouse_mode_) {
    REXLOG_WARN("Pointer lock unavailable, mouse look falls back to recentering the cursor");
  }
  // Reset deltas to avoid a spike on capture start
  std::lock_guard lock(state_mutex_);
  mouse_dx_ = 0.0f;
  mouse_dy_ = 0.0f;
}

void MnkInputDriver::ReleaseMouseCaptureFromUIThread(rex::ui::Window* window) {
  if (!mouse_captured_) {
    return;
  }
  mouse_captured_ = false;
  window->SetCursorVisibility(precapture_cursor_visibility_);
  window->SetRelativeMouseMode(false);
  relative_mouse_mode_ = false;
  window->ReleaseMouse();
}

void MnkInputDriver::RecenterCursorFromUIThread(int32_t x, int32_t y) {
  rex::ui::Window* window = attached_window_;
  if (!window) {
    return;
  }
  int32_t width = int32_t(window->GetActualPhysicalWidth());
  int32_t height = int32_t(window->GetActualPhysicalHeight());
  if (width <= 0 || height <= 0) {
    return;
  }
  // Only once the pointer has drifted well off the middle, to keep warps rare.
  if (std::abs(x - width / 2) < width / 4 && std::abs(y - height / 2) < height / 4) {
    return;
  }
  int32_t center_x = 0;
  int32_t center_y = 0;
  if (window->WarpMouseToCenter(center_x, center_y)) {
    prev_mouse_x_ = center_x;
    prev_mouse_y_ = center_y;
  }
}

void MnkInputDriver::SetKeyState(uint16_t vk, bool down) {
  if (vk < 256) {
    key_down_[vk] = down;
  }
}

void MnkInputDriver::OnKeyDown(rex::ui::KeyEvent& e) {
  if (!IsEnabled() || !has_focus_)
    return;
  std::lock_guard lock(state_mutex_);
  uint16_t vk = static_cast<uint16_t>(e.virtual_key());
  SetKeyState(vk, true);
}

void MnkInputDriver::OnKeyUp(rex::ui::KeyEvent& e) {
  if (!IsEnabled())
    return;
  std::lock_guard lock(state_mutex_);
  uint16_t vk = static_cast<uint16_t>(e.virtual_key());
  SetKeyState(vk, false);
}

void MnkInputDriver::OnMouseDown(rex::ui::MouseEvent& e) {
  if (!IsEnabled() || !has_focus_)
    return;
  std::lock_guard lock(state_mutex_);
  switch (e.button()) {
    case rex::ui::MouseEvent::Button::kLeft:
      SetKeyState(static_cast<uint16_t>(VirtualKey::kLButton), true);
      break;
    case rex::ui::MouseEvent::Button::kRight:
      SetKeyState(static_cast<uint16_t>(VirtualKey::kRButton), true);
      break;
    case rex::ui::MouseEvent::Button::kMiddle:
      SetKeyState(static_cast<uint16_t>(VirtualKey::kMButton), true);
      break;
    default:
      break;
  }
}

void MnkInputDriver::OnMouseUp(rex::ui::MouseEvent& e) {
  if (!IsEnabled())
    return;
  std::lock_guard lock(state_mutex_);
  switch (e.button()) {
    case rex::ui::MouseEvent::Button::kLeft:
      SetKeyState(static_cast<uint16_t>(VirtualKey::kLButton), false);
      break;
    case rex::ui::MouseEvent::Button::kRight:
      SetKeyState(static_cast<uint16_t>(VirtualKey::kRButton), false);
      break;
    case rex::ui::MouseEvent::Button::kMiddle:
      SetKeyState(static_cast<uint16_t>(VirtualKey::kMButton), false);
      break;
    default:
      break;
  }
}

void MnkInputDriver::OnMouseMove(rex::ui::MouseEvent& e) {
  if (!IsEnabled() || !has_focus_)
    return;
  int32_t x = e.x();
  int32_t y = e.y();
  {
    std::lock_guard lock(state_mutex_);
    if (relative_mouse_mode_) {
      // The pointer is locked, so the absolute position no longer moves.
      mouse_dx_ += e.dx();
      mouse_dy_ += e.dy();
    } else {
      mouse_dx_ += float(x - prev_mouse_x_);
      mouse_dy_ += float(y - prev_mouse_y_);
    }
  }
  prev_mouse_x_ = x;
  prev_mouse_y_ = y;
  // Without a pointer lock the cursor still has to be kept off the edges.
  if (mouse_captured_ && !relative_mouse_mode_) {
    RecenterCursorFromUIThread(x, y);
  }
}

void MnkInputDriver::OnLostFocus(rex::ui::UISetupEvent&) {
  has_focus_ = false;
  // Withdraw the request too, or an update queued before the focus loss grabs
  // the cursor straight back.
  mouse_capture_requested_.store(false, std::memory_order_relaxed);
  {
    std::lock_guard lock(state_mutex_);
    std::memset(key_down_, 0, sizeof(key_down_));
    mouse_dx_ = 0.0f;
    mouse_dy_ = 0.0f;
  }
  if (attached_window_) {
    ReleaseMouseCaptureFromUIThread(attached_window_);
  }
}

void MnkInputDriver::OnGotFocus(rex::ui::UISetupEvent&) {
  has_focus_ = true;
}

}  // namespace rex::input::mnk
