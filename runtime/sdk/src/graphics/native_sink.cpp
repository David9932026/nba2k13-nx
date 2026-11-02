/**
 ******************************************************************************
 * ReXGlue runtime - native renderer command sink                          *
 ******************************************************************************
 *
 * @modified    Cola, 2026 - 2K13 native renderer, phase 1.
 *
 * Two slots, one frame each. The command processor thread fills the current
 * slot and, at Swap, hands it to the callback and moves to the other one. There
 * is no second thread here on purpose: on Horizon, std::thread::detach throws
 * std::system_error and terminates the process (we lost two runs to exactly
 * that in rex::cvar::WatchConfig), and phase 1's consumer is a few hundred
 * microseconds of counting. When phase 2 needs a real recording thread it will
 * be a rex::system::XHostThread like every other GPU thread in this runtime.
 */

#include <rex/graphics/native_sink.h>

#include <atomic>
#include <cstring>

#include <rex/assert.h>
#include <rex/graphics/register_file.h>

namespace rex::graphics::native_sink {

namespace {

// FNV-1a, 64 bit. Cheap enough to run over a few dozen words per draw, and
// stable across runs and platforms, which matters because phase 2 will want to
// persist the pipeline set between sessions.
inline uint64_t Fnv(uint64_t hash, uint64_t value) {
  const uint8_t* bytes = reinterpret_cast<const uint8_t*>(&value);
  for (uint32_t i = 0; i < 8; ++i) {
    hash ^= bytes[i];
    hash *= 0x100000001B3ull;
  }
  return hash;
}

inline constexpr uint64_t kFnvOffset = 0xCBF29CE484222325ull;

Fotograma g_slots[2] = {};
uint32_t g_slot_actual = 0;
uint64_t g_fotogramas = 0;
// Deliberately not std::atomic: every tap runs on the command processor thread
// except Activar/SetCallback, which are called from the app's setup before the
// GPU threads exist.
bool g_activo = false;
Callback g_callback = nullptr;
// PATCH(cola): front buffer of the last swap packet. Written and read by the
// same thread; atomic only so a stray read from elsewhere is not UB.
std::atomic<uint32_t> g_front_buffer{0};

Fotograma& Actual() { return g_slots[g_slot_actual]; }

void Vaciar(Fotograma& fotograma) {
  // Only zero what is not rewritten unconditionally: the draw/resolve/transfer
  // arrays can be 90 KB each, and clearing them every frame for nothing showed
  // up in the frame budget on the console.
  fotograma.numero = 0;
  fotograma.tick_inicio = 0;
  std::memset(fotograma.paquetes, 0, sizeof(fotograma.paquetes));
  fotograma.dibujos_n = 0;
  fotograma.dibujos_fallidos = 0;
  fotograma.dibujos_omitidos = 0;
  fotograma.dibujos_perdidos = 0;
  fotograma.resolves_n = 0;
  fotograma.resolves_perdidos = 0;
  fotograma.transferencias_n = 0;
  fotograma.transferencias_perdidas = 0;
  fotograma.swaps = 0;
  fotograma.ancho_destino = 0;
  fotograma.alto_destino = 0;
}

}  // namespace

bool Activo() { return g_activo; }

void Activar(bool activo) {
  g_activo = activo;
  if (activo) {
    g_slot_actual = 0;
    g_fotogramas = 0;
    Vaciar(g_slots[0]);
    Vaciar(g_slots[1]);
  }
}

void SetCallback(Callback callback) { g_callback = callback; }

void Reiniciar() {
  Vaciar(g_slots[0]);
  Vaciar(g_slots[1]);
}

void EmitPaquete(uint32_t opcode) {
  if (!g_activo) {
    return;
  }
  if (opcode < kNumPaquetes) {
    ++Actual().paquetes[opcode];
  }
}

uint32_t EmitDibujo(const Dibujo& dibujo) {
  if (!g_activo) {
    return kIndiceInvalido;
  }
  Fotograma& fotograma = Actual();
  if (fotograma.dibujos_n >= kMaxDibujos) {
    ++fotograma.dibujos_perdidos;
    return kIndiceInvalido;
  }
  const uint32_t indice = fotograma.dibujos_n++;
  fotograma.dibujos[indice] = dibujo;
  return indice;
}

void MarcarDibujo(uint32_t indice, bool ejecutado) {
  if (!g_activo || indice == kIndiceInvalido || !ejecutado) {
    if (g_activo && indice != kIndiceInvalido) {
      ++Actual().dibujos_fallidos;
    }
    return;
  }
}

void EmitDibujoOmitido() {
  if (!g_activo) {
    return;
  }
  ++Actual().dibujos_omitidos;
}

void EmitResolve(const Resolve& resolve) {
  if (!g_activo) {
    return;
  }
  Fotograma& fotograma = Actual();
  if (fotograma.resolves_n >= kMaxResolves) {
    ++fotograma.resolves_perdidos;
    return;
  }
  fotograma.resolves[fotograma.resolves_n++] = resolve;
}

void EmitTransferencia(const Transferencia& transferencia) {
  if (!g_activo) {
    return;
  }
  Fotograma& fotograma = Actual();
  if (fotograma.transferencias_n >= kMaxTransferencias) {
    ++fotograma.transferencias_perdidas;
    return;
  }
  fotograma.transferencias[fotograma.transferencias_n++] = transferencia;
}

void EmitSwap(uint32_t ancho, uint32_t alto) {
  if (!g_activo) {
    return;
  }
  Fotograma& fotograma = Actual();
  ++fotograma.swaps;
  fotograma.ancho_destino = ancho;
  fotograma.alto_destino = alto;
  fotograma.numero = g_fotogramas++;

  // Hand it over while it is still complete, then start the other slot.
  if (g_callback) {
    g_callback(fotograma);
  }
  g_slot_actual ^= 1u;
  Vaciar(Actual());
}

// PATCH(cola): outside Activo() on purpose - see the header.
void AnotarFrontBuffer(uint32_t direccion) {
  g_front_buffer.store(direccion, std::memory_order_relaxed);
}

uint32_t UltimoFrontBuffer() {
  return g_front_buffer.load(std::memory_order_relaxed);
}

uint64_t ClavePipeline(const RegisterFile& regs, uint64_t hash_vs, uint64_t hash_ps,                       uint8_t primitiva, uint8_t formato_indice) {
  // The set of state that forces a different host pipeline. Anything not here
  // (constant values, viewport size, texture contents) is per-draw data, not
  // pipeline identity - putting it here would shatter the cache for nothing.
  uint64_t hash = kFnvOffset;
  hash = Fnv(hash, hash_vs);
  hash = Fnv(hash, hash_ps);
  hash = Fnv(hash, primitiva);
  hash = Fnv(hash, formato_indice);

  const reg::RB_SURFACE_INFO surface_info = regs.Get<reg::RB_SURFACE_INFO>();
  hash = Fnv(hash, surface_info.value);

  const reg::RB_MODECONTROL mode_control = regs.Get<reg::RB_MODECONTROL>();
  hash = Fnv(hash, mode_control.value);

  const reg::RB_COLOR_MASK color_mask = regs.Get<reg::RB_COLOR_MASK>();
  hash = Fnv(hash, color_mask.value);

  const reg::RB_DEPTHCONTROL depth_control = regs.Get<reg::RB_DEPTHCONTROL>();
  hash = Fnv(hash, depth_control.value);

  const reg::PA_SU_SC_MODE_CNTL sc_mode = regs.Get<reg::PA_SU_SC_MODE_CNTL>();
  hash = Fnv(hash, sc_mode.value);

  const reg::PA_CL_CLIP_CNTL clip_cntl = regs.Get<reg::PA_CL_CLIP_CNTL>();
  hash = Fnv(hash, clip_cntl.value);

  // All four render targets and their blend state: this game uses multiple
  // render targets (the log shows 68 render targets per frame).
  for (uint32_t i = 0; i < 4; ++i) {
    const uint32_t color_info = regs.values[reg::RB_COLOR_INFO::rt_register_indices[i]];
    hash = Fnv(hash, color_info);
    const reg::RB_BLENDCONTROL blend_control =
        regs.Get<reg::RB_BLENDCONTROL>(reg::RB_BLENDCONTROL::rt_register_indices[i]);
    hash = Fnv(hash, blend_control.value);
  }

  const reg::RB_DEPTH_INFO depth_info = regs.Get<reg::RB_DEPTH_INFO>();
  hash = Fnv(hash, depth_info.value);

  return hash;
}

uint64_t FotogramasCompletados() { return g_fotogramas; }

}  // namespace rex::graphics::native_sink
