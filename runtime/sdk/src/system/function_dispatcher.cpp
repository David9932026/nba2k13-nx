/**
 * @file        system/function_dispatcher.cpp
 * @brief       Guest function dispatch coordinator for recompiled code
 *
 * @copyright   Copyright (c) 2026 Tom Clay <tomc@tctechstuff.com>
 *              All rights reserved.
 *
 * @license     BSD 3-Clause License
 *              See LICENSE file in the project root for full license text.
 *
 * @remarks     Derived from Xenia's runtime::Processor (Ben Vanik, 2020).
 *              Stripped of emulation-era dead code and renamed to reflect its
 *              role as a function dispatch table rather than a CPU emulator.
 */

#include <atomic>
#include <cstdio>
#include <cstring>
#include <string>
#include <rex/assert.h>
#include <rex/cvar.h>
#if REX_PLATFORM_WIN32
#include <windows.h>
#endif
#include <rex/dbg.h>
#include <rex/logging.h>
#include <rex/perf/counter.h>
#include <rex/memory.h>
#include <rex/ppc/context.h>
#include <rex/runtime.h>
#include <rex/system/function_dispatcher.h>
#include <rex/system/thread_state.h>

namespace rex::runtime {

// PATCH(cola): switch for the neighbour retry in ResolveIndirectFunction.
REXCVAR_DEFINE_BOOL(indirect_neighbour_retry, true, "CPU",
                    "Retry an indirect call target on its aligned neighbours");

namespace {

FunctionDispatcher* GetBoundFunctionDispatcher() {
  Runtime* runtime = Runtime::instance();
  return runtime ? runtime->function_dispatcher() : nullptr;
}

}  // namespace

// PATCH(cola): 探测阶段结束后已恢复原有致命行为。
// 探测版的写法（记日志、清 r3~r6 继续跑）能一次撊出多个未登记地址，
// 但它会掩盖真实的未实现函数，只适合在追地址时临时用。
static void InvalidFunctionTrap(PPCContext& ctx, uint8_t* base) {
  // PATCH(cola): dump what the target address actually holds before dying. The
  // title keeps pointers into the 0x84200000-0x84300000 image data region in its
  // objects, so seeing the bytes there decides whether this is a runtime-built
  // thunk that we never wrote or a genuinely corrupt pointer.
  {
    const uint32_t target = ctx.last_indirect_target;
    // PATCH(cola): log the registers unconditionally - the interesting targets now live
    // outside the image window (0xA0-0xB0 physical RAM), so gating this on the image range
    // threw away the only useful information.
    REXLOG_ERROR(
        "InvalidFunctionTrap ctx lr=0x{:08X} ctr=0x{:08X} r3=0x{:08X} r4=0x{:08X} r5=0x{:08X} "
        "r11=0x{:08X} r30=0x{:08X} r31=0x{:08X} r1=0x{:08X}",
        uint32_t(ctx.lr), ctx.ctr.u32, ctx.r3.u32, ctx.r4.u32, ctx.r5.u32, ctx.r11.u32,
        ctx.r30.u32, ctx.r31.u32, ctx.r1.u32);
    // PATCH(cola): when the caller loaded the target out of an object, dump that object too.
    {
      const uint32_t obj = ctx.r3.u32;
      Runtime* rt = Runtime::instance();
      memory::Memory* mem = rt ? rt->memory() : nullptr;
      if (mem && obj >= 0x80000000u && obj < 0x90000000u) {
        std::string objline;
        for (uint32_t i = 0; i < 1600; i += 4) {
          uint32_t word = 0;
          std::memcpy(&word, base + obj - 0x80000000u + i, 4);
          if (i % 16 == 0) {
            objline += fmt::format("\n  obj+0x{:04X}:", i);
          }
          objline += fmt::format(" {:08X}", __builtin_bswap32(word));
        }
        REXLOG_ERROR("InvalidFunctionTrap objdump@0x{:08X}:{}", obj, objline);
      }
      // PATCH(cola): if the bogus target is a physical address, show what it actually points at.
      if (mem && target >= 0xA0000000u && target < 0xC0000000u) {
        const uint32_t page = target & ~uint32_t(0xFF);
        uint8_t* phys = mem->TranslatePhysical(page);
        std::string physline = phys ? std::string() : std::string(" <unmapped>");
        if (phys) {
          for (uint32_t row = 0; row < 0x100; row += 16) {
            physline += fmt::format("\n  phys@0x{:08X}:", page + row);
            for (uint32_t i = 0; i < 16; i += 4) {
              uint32_t word = 0;
              std::memcpy(&word, phys + row + i, 4);
              physline += fmt::format(" {:08X}", __builtin_bswap32(word));
            }
          }
        }
        REXLOG_ERROR("InvalidFunctionTrap physdump@0x{:08X}:{}", page, physline);
      }
    }
    if (base && target >= 0x80000000u && target < 0x90000000u) {
      const uint32_t window_base = target & ~uint32_t(0xFF);
      std::string hex;
      for (uint32_t row = 0; row < 0x100; row += 16) {
        hex += fmt::format("\n  @0x{:08X}:", window_base + row);
        for (uint32_t i = 0; i < 16; i += 4) {
          uint32_t word = 0;
          std::memcpy(&word, base + window_base - 0x80000000u + row + i, 4);
          hex += fmt::format(" {:08X}", __builtin_bswap32(word));
        }
      }
      REXLOG_ERROR("InvalidFunctionTrap window @0x{:08X}:{}", window_base, hex);
      // PATCH(cola): the object the slot belongs to, so the vtable pointer can be checked too.
      const uint32_t obj = ctx.r3.u32;
      if (obj >= 0x82000000u && obj < 0x90000000u) {
        std::string objline;
        for (uint32_t i = 0; i < 32; i += 4) {
          uint32_t word = 0;
          std::memcpy(&word, base + obj - 0x80000000u + i, 4);
          objline += fmt::format(" {:08X}", __builtin_bswap32(word));
        }
        REXLOG_ERROR("InvalidFunctionTrap obj@0x{:08X}:{}", obj, objline);
      }
      REXLOG_ERROR(
          "InvalidFunctionTrap ctx lr=0x{:08X} ctr=0x{:08X} r3=0x{:08X} r11=0x{:08X} r30=0x{:08X} "
          "r31=0x{:08X}",
          uint32_t(ctx.lr), ctx.ctr.u32, ctx.r3.u32, ctx.r11.u32, ctx.r30.u32, ctx.r31.u32);
    }
  }
#if REX_PLATFORM_WIN32
  {
    void* frames[28] = {};
    uintptr_t module_base = reinterpret_cast<uintptr_t>(GetModuleHandleW(nullptr));
    USHORT frame_count = RtlCaptureStackBackTrace(0, 28, frames, nullptr);
    std::string rvas;
    for (USHORT i = 0; i < frame_count; ++i) {
      char piece[32];
      std::snprintf(piece, sizeof(piece), " 0x%08llX",
                    static_cast<unsigned long long>(reinterpret_cast<uintptr_t>(frames[i]) -
                                                    module_base));
      rvas += piece;
    }
    REXLOG_ERROR("InvalidFunctionTrap target=0x{:08X} RVACALL{}", ctx.last_indirect_target, rvas);
  }
#endif
  // PATCH(cola): REX_TRAP_CONTINUE=1 turns the trap into a log so one run can collect many
  // missing entries instead of one per rebuild. Only for hole discovery - the guest state is
  // garbage after this point, so nothing after it is meaningful.
  {
    static const bool s_continue = [] {
      const char* v = std::getenv("REX_TRAP_CONTINUE");
      return v && *v && *v != '0';
    }();
    if (s_continue) {
      REXLOG_ERROR("[UNREGISTERED] 0x{:08X}", ctx.last_indirect_target);
      ctx.r3.u64 = 0;
      ctx.r4.u64 = 0;
      ctx.r5.u64 = 0;
      ctx.r6.u64 = 0;
      return;
    }
  }
  // PATCH(cola): a null target is a call through an interface slot the title left
  // empty (2K13 dispatches UI events through object+40 with a null gate). Dying here
  // stops the title mid-flow for a callback it never installed; treat it as a no-op
  // returning 0 and keep the interesting traps fatal.
  if (ctx.last_indirect_target == 0) {
    static std::atomic<uint32_t> s_null_calls{0};
    const uint32_t n = s_null_calls.fetch_add(1) + 1;
    if (n <= 32) {
      REXLOG_WARN("[NULLCALL] #{} lr=0x{:08X} r3=0x{:08X} r4=0x{:08X} r5=0x{:08X}", n,
                  uint32_t(ctx.lr), ctx.r3.u32, ctx.r4.u32, ctx.r5.u32);
    }
    ctx.r3.u64 = 0;
    return;
  }
  REX_FATAL("Call to invalid or unregistered function at guest address 0x{:08X}",
            ctx.last_indirect_target);
}

PPCFunc* ResolveIndirectFunction(uint32_t guest_address) {
  FunctionDispatcher* dispatcher = GetBoundFunctionDispatcher();
  if (!dispatcher) {
    return &InvalidFunctionTrap;
  }

  if (PPCFunc* func = dispatcher->GetFunction(guest_address)) {
    return func;
  }

  // PATCH(cola): the title sometimes stores a function pointer one to three
  // bytes away from the real entry (the low bits carry a flag). Looking up that
  // exact value misses the registered slot and lands on a neighbour's slot,
  // whose contents get called. Retry on the enclosing 4-byte aligned word and
  // its upper neighbours; the window is deliberately tiny so a genuinely
  // missing function still fails loudly.
  const uint32_t aligned = guest_address & ~uint32_t(3);
  // PATCH(cola): switch so the neighbour retry can be turned off from the command line.
  // Calling a wrong neighbouring function is silent; a wrong neighbour that never faults
  // looks exactly like a hang, so this needs an A/B.
  for (uint32_t delta = 0; REXCVAR_GET(indirect_neighbour_retry) && delta <= 4; ++delta) {
    const uint32_t candidate = aligned + delta;
    if (PPCFunc* func = dispatcher->GetFunction(candidate)) {
      REXLOG_WARN("ResolveIndirectFunction: 0x{:08X} not registered, using neighbour 0x{:08X}",
                  guest_address, candidate);
      return func;
    }
  }

  return &InvalidFunctionTrap;
}

PPCFunc* ValidateIndirectFunc(PPCFunc* fn) {
  if (!fn) {
    return nullptr;
  }
#if REX_PLATFORM_WIN32
  struct HostImageRange {
    uintptr_t base = 0;
    uintptr_t end = 0;
    HostImageRange() {
      auto image_base = reinterpret_cast<uintptr_t>(GetModuleHandleW(nullptr));
      if (!image_base) {
        return;
      }
      base = image_base;
      end = image_base + 0x1000;
      auto* dos = reinterpret_cast<IMAGE_DOS_HEADER*>(image_base);
      if (dos->e_magic == IMAGE_DOS_SIGNATURE) {
        auto* nt = reinterpret_cast<IMAGE_NT_HEADERS*>(image_base + dos->e_lfanew);
        if (nt->Signature == IMAGE_NT_SIGNATURE) {
          end = image_base + nt->OptionalHeader.SizeOfImage;
        }
      }
    }
  };
  static const HostImageRange kHostImage;
  if (!kHostImage.base) {
    return fn;
  }
  const auto address = reinterpret_cast<uintptr_t>(fn);
  if (address < kHostImage.base || address >= kHostImage.end) {
    return nullptr;
  }
#endif
  return fn;
}

FunctionDispatcher::FunctionDispatcher(rex::memory::Memory* memory, ExportResolver* export_resolver)
    : memory_(memory), export_resolver_(export_resolver) {}

FunctionDispatcher::~FunctionDispatcher() = default;

bool FunctionDispatcher::Execute(ThreadState* thread_state, uint32_t address) {
  SCOPE_profile_cpu_f("cpu");
  PROFILE_FUNCTION_DISPATCHED();

  PPCFunc* fn = GetFunction(address);
  if (!fn) {
    REXCPU_ERROR("Execute({:08X}): function not in function table", address);
    return false;
  }

  auto* ctx = thread_state->context();
  auto* previous_thread_state = ThreadState::Get();

  // Rebind the active guest thread for cross-module callbacks.
  ThreadState::Bind(thread_state);

  // Pad out stack a bit, as some games seem to overwrite the caller by about 16 to 32b.
  ctx->r1.u64 -= 64 + 112;

  uint64_t previous_lr = ctx->lr;
  ctx->lr = 0xBCBCBCBC;

  fn(*ctx, memory_->virtual_membase());

  ctx->lr = previous_lr;
  ctx->r1.u64 += 64 + 112;
  ThreadState::Bind(previous_thread_state);

  return true;
}

uint64_t FunctionDispatcher::Execute(ThreadState* thread_state, uint32_t address, uint64_t args[],
                                     size_t arg_count) {
  SCOPE_profile_cpu_f("cpu");

  auto* ctx = thread_state->context();

  if (arg_count > 0)
    ctx->r3.u64 = args[0];
  if (arg_count > 1)
    ctx->r4.u64 = args[1];
  if (arg_count > 2)
    ctx->r5.u64 = args[2];
  if (arg_count > 3)
    ctx->r6.u64 = args[3];
  if (arg_count > 4)
    ctx->r7.u64 = args[4];
  if (arg_count > 5)
    ctx->r8.u64 = args[5];
  if (arg_count > 6)
    ctx->r9.u64 = args[6];
  if (arg_count > 7)
    ctx->r10.u64 = args[7];

  // FIXME: stack-arg path assumes 32-bit values; 64-bit and float args are wrong.
  if (arg_count > 8) {
    auto stack_arg_base =
        memory_->TranslateVirtual(static_cast<uint32_t>(ctx->r1.u64) + 0x54 - (64 + 112));
    for (size_t i = 8; i < arg_count; i++) {
      memory::store_and_swap<uint32_t>(stack_arg_base + ((i - 8) * 8),
                                       static_cast<uint32_t>(args[i]));
    }
  }

  if (!Execute(thread_state, address)) {
    return 0xDEADBABE;
  }
  return ctx->r3.u64;
}

uint64_t FunctionDispatcher::ExecuteTrap(ThreadState* thread_state, uint32_t address,
                                         uint64_t args[], size_t arg_count) {
  auto* ctx = thread_state->context();
  PPCContext saved = *ctx;

  uint64_t result = Execute(thread_state, address, args, arg_count);

  *ctx = saved;
  ctx->fpscr.restoreGuestBits(saved.fpscr.csr);
  return result;
}

uint64_t FunctionDispatcher::ExecuteInterrupt(ThreadState* thread_state, uint32_t address,
                                              uint64_t args[], size_t arg_count) {
  SCOPE_profile_cpu_f("cpu");
  PROFILE_INTERRUPT_DISPATCHED();

  // Hold the global lock during interrupt dispatch.
  auto global_lock = global_critical_region_.Acquire();

  auto* ctx = thread_state->context();
  assert_true(arg_count <= 5);

  if (arg_count > 0)
    ctx->r3.u64 = args[0];
  if (arg_count > 1)
    ctx->r4.u64 = args[1];
  if (arg_count > 2)
    ctx->r5.u64 = args[2];
  if (arg_count > 3)
    ctx->r6.u64 = args[3];
  if (arg_count > 4)
    ctx->r7.u64 = args[4];

  // TLS ptr must be zero during interrupts. Some games check this and early-exit
  // routines when under interrupts.
  auto pcr_address = memory_->TranslateVirtual(static_cast<uint32_t>(ctx->r13.u64));
  uint32_t old_tls_ptr = memory::load_and_swap<uint32_t>(pcr_address);
  memory::store_and_swap<uint32_t>(pcr_address, 0);

  if (!Execute(thread_state, address)) {
    return 0xDEADBABE;
  }

  // Restore TLS ptr.
  memory::store_and_swap<uint32_t>(pcr_address, old_tls_ptr);

  return ctx->r3.u64;
}

// rexglue function table management

bool FunctionDispatcher::InitializeFunctionTable(uint32_t code_base, uint32_t code_size,
                                                 uint32_t image_base, uint32_t image_size,
                                                 bool is_entrypoint) {
  std::lock_guard<std::recursive_mutex> lock(dispatch_mutex_);

  if (is_entrypoint && entrypoint_code_base_ != 0) {
    REXLOG_ERROR("InitializeFunctionTable: entrypoint already registered at {:08X}",
                 entrypoint_code_base_);
    return false;
  }

  uint32_t new_table_end = image_base + image_size + (code_size + kThunkReserveSize) * 2;
  uint32_t new_code_end = code_base + code_size + kThunkReserveSize;
  for (const auto& existing : module_tables_) {
    uint32_t existing_table_end =
        existing.image_base + existing.image_size + (existing.code_size + kThunkReserveSize) * 2;
    uint32_t existing_code_end = existing.code_base + existing.code_size + kThunkReserveSize;
    if (image_base < existing_table_end && new_table_end > existing.image_base) {
      REXLOG_ERROR("Module image range [{:08X}, {:08X}) overlaps existing [{:08X}, {:08X})",
                   image_base, new_table_end, existing.image_base, existing_table_end);
      return false;
    }
    if (code_base < existing_code_end && new_code_end > existing.code_base) {
      REXLOG_ERROR("Module code range [{:08X}, {:08X}) overlaps existing [{:08X}, {:08X})",
                   code_base, new_code_end, existing.code_base, existing_code_end);
      return false;
    }
  }

  if (!memory_->InitializeFunctionTable(code_base, code_size, image_base, image_size)) {
    REXLOG_ERROR("Failed to initialize guest memory function table");
    return false;
  }

  module_tables_.push_back({
      .code_base = code_base,
      .code_size = code_size,
      .image_base = image_base,
      .image_size = image_size,
      .next_thunk_address = code_base + code_size,
      .thunk_limit = code_base + code_size + kThunkReserveSize,
  });

  if (is_entrypoint) {
    entrypoint_code_base_ = code_base;
  }

  REXLOG_INFO("Function table initialized for module: code={:08X}-{:08X}, image={:08X}-{:08X}",
              code_base, code_base + code_size, image_base, image_base + image_size);
  return true;
}

FunctionDispatcher::ModuleTableInfo* FunctionDispatcher::FindModuleByAddress(
    uint32_t guest_address) {
  for (auto& mod : module_tables_) {
    if (guest_address >= mod.code_base && guest_address < mod.thunk_limit) {
      return &mod;
    }
  }
  return nullptr;
}

uint32_t FunctionDispatcher::FindCallerModuleBase(uint32_t guest_address) {
  std::lock_guard<std::recursive_mutex> lock(dispatch_mutex_);
  if (auto* mod = FindModuleByAddress(guest_address)) {
    return mod->code_base;
  }
  return 0;
}

bool FunctionDispatcher::SetFunction(uint32_t guest_address, ::PPCFunc* func) {
  std::lock_guard<std::recursive_mutex> lock(dispatch_mutex_);
  assert_true(!module_tables_.empty());

  if (!FindModuleByAddress(guest_address)) {
    REXLOG_ERROR("SetFunction: address {:08X} outside all registered module ranges", guest_address);
    return false;
  }

  function_table_[guest_address] = func;

  if (!memory_->SetFunction(guest_address, func)) {
    REXLOG_ERROR("SetFunction: dispatcher / Memory module-table state out of sync at {:08X}",
                 guest_address);
    function_table_.erase(guest_address);
    return false;
  }

  if (recording_) {
    recording_addresses_.push_back(guest_address);
  }
  return true;
}

::PPCFunc* FunctionDispatcher::GetFunction(uint32_t guest_address) {
  std::lock_guard<std::recursive_mutex> lock(dispatch_mutex_);
  auto it = function_table_.find(guest_address);
  if (it != function_table_.end()) {
    return it->second;
  }
  return nullptr;
}

uint32_t FunctionDispatcher::AllocateThunk(::PPCFunc* func, uint32_t caller_address) {
  std::lock_guard<std::recursive_mutex> lock(dispatch_mutex_);
  auto* mod = FindModuleByAddress(caller_address);
  if (!mod) {
    if (caller_address != 0) {
      REXLOG_ERROR("AllocateThunk: caller_address {:08X} not in any registered module",
                   caller_address);
      return 0;
    }
    if (entrypoint_code_base_ == 0) {
      REXLOG_ERROR("AllocateThunk: caller_address=0 but no entrypoint registered");
      return 0;
    }
    mod = FindModuleByAddress(entrypoint_code_base_);
    if (!mod) {
      REXLOG_ERROR("AllocateThunk: entrypoint code_base {:08X} not in module_tables_",
                   entrypoint_code_base_);
      return 0;
    }
  }

  if (mod->next_thunk_address >= mod->thunk_limit) {
    REXLOG_ERROR("Thunk address space exhausted for module at {:08X}", mod->code_base);
    return 0;
  }
  uint32_t addr = mod->next_thunk_address;
  mod->next_thunk_address += 4;
  if (!SetFunction(addr, func)) {
    mod->next_thunk_address -= 4;
    return 0;
  }
  return addr;
}

void FunctionDispatcher::RegisterModule(const std::string& module_id, uint32_t code_base,
                                        RegisterFn register_func) {
  std::lock_guard<std::recursive_mutex> lock(dispatch_mutex_);
  if (recording_) {
    REX_FATAL("RegisterModule called while already recording (re-entrancy)");
    return;
  }

  if (module_addresses_.find(module_id) != module_addresses_.end()) {
    REXLOG_WARN("RegisterModule: '{}' is already registered; cleaning up prior batch", module_id);
    UnregisterModule(module_id);
  }

  REXLOG_INFO("Registering module: {} (code_base={:08X})", module_id, code_base);

  recording_addresses_.clear();
  recording_ = true;

  struct RecordingGuard {
    FunctionDispatcher* self;
    ~RecordingGuard() {
      self->recording_ = false;
      self->recording_addresses_.clear();
    }
  } guard{this};

  register_func(this);

  ModuleRegistration reg;
  reg.code_base = code_base;
  reg.addresses = std::move(recording_addresses_);

  size_t count = reg.addresses.size();
  module_addresses_[module_id] = std::move(reg);

  REXLOG_INFO("Module '{}' registered {} functions", module_id, count);
}

std::optional<std::pair<uint32_t, uint32_t>> FunctionDispatcher::UnregisterModule(
    const std::string& module_id) {
  std::lock_guard<std::recursive_mutex> lock(dispatch_mutex_);
  auto it = module_addresses_.find(module_id);
  if (it == module_addresses_.end()) {
    REXLOG_WARN("UnregisterModule: module '{}' not found", module_id);
    return std::nullopt;
  }

  REXLOG_INFO("Unregistering module: {} ({} functions)", module_id, it->second.addresses.size());

  auto table_it = std::find_if(module_tables_.begin(), module_tables_.end(),
                               [code_base = it->second.code_base](const ModuleTableInfo& mti) {
                                 return mti.code_base == code_base;
                               });

  for (uint32_t addr : it->second.addresses) {
    function_table_.erase(addr);
    memory_->SetFunction(addr, nullptr);
  }

  std::optional<std::pair<uint32_t, uint32_t>> cleared_range;
  if (table_it != module_tables_.end()) {
    uint32_t pool_start = table_it->code_base + table_it->code_size;
    uint32_t pool_end = table_it->next_thunk_address;
    for (uint32_t addr = pool_start; addr < pool_end; addr += 4) {
      function_table_.erase(addr);
      memory_->SetFunction(addr, nullptr);
    }
    cleared_range = std::make_pair(pool_start, pool_end);

    if (table_it->code_base == entrypoint_code_base_) {
      entrypoint_code_base_ = 0;
    }
    memory_->DestroyFunctionTable(table_it->code_base);
    module_tables_.erase(table_it);
  }

  module_addresses_.erase(it);

  return cleared_range;
}

}  // namespace rex::runtime
