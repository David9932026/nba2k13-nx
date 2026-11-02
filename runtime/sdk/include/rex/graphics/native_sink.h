/**
 ******************************************************************************
 * ReXGlue runtime - native renderer command sink                          *
 ******************************************************************************
 *
 * @modified    Cola, 2026 - 2K13 native renderer, phase 1.
 *
 * PATCH(cola): the Xenos emulation path costs ~260 µs per GPU operation here
 * (measured: 659 draws + 876 transfers + 19 resolves per frame, 2 fps). The
 * NFS MW port hit the same wall and replaced the emulation with a renderer that
 * reads the game's own PM4 ring and issues Vulkan directly - 1.5-1.8 µs per
 * draw, which is what makes 30 fps possible on this console.
 *
 * This file is the seam between the two. Nothing here draws anything: it is the
 * point where every command the game asks the GPU to do is captured, once, with
 * everything a renderer needs to reproduce it, and handed to the owner of the
 * sink at the end of each frame. Phase 1 uses it to prove that the capture is
 * complete (what it records must add up to what the ring says) and to learn the
 * pipeline set. Phase 2 will use exactly these records to record Vulkan work.
 *
 * Two rules keep it cheap enough to leave compiled in:
 *  - one predictable branch when inactive (Activo()), and nothing else;
 *  - no allocation, ever - the slots are static, sized from the worst frame
 *    this game has produced (973 draws, 19 resolves, 986 transfer calls).
 */

#pragma once

#include <cstdint>

namespace rex::graphics {

class RegisterFile;

namespace native_sink {

// A frame of basketball is nowhere near this; the ceiling is here so a runaway
// frame cannot walk off the end of the slot. Overflow is counted, not hidden.
// Transfers get a much bigger ceiling than draws on purpose: this game runs ~876
// render-target ownership transfer batches per frame (the EDRAM tile dance), and
// that number being that high is itself the argument for a renderer that does
// not emulate EDRAM at all.
inline constexpr uint32_t kMaxDibujos = 1024;
inline constexpr uint32_t kMaxResolves = 96;
inline constexpr uint32_t kMaxTransferencias = 1024;
inline constexpr uint32_t kNumPaquetes = 0x80;
inline constexpr uint32_t kIndiceInvalido = 0xFFFFFFFFu;

// Where a transfer comes from - kept apart because they cost wildly different
// amounts and a renderer has to handle them differently.
enum class TipoTransferencia : uint8_t {
  kSubida = 0,    // guest memory -> texture (new texture data)
  kRetorno = 1,   // render target / texture -> guest memory (readback)
  kCopia = 2,     // render target -> render target (the resolve tail)
  kOtro = 3,
};

// One draw, as the game asked for it.
struct Dibujo {
  // Identity of the two shaders. ucode_data_hash is what the emulation already
  // keys its pipeline cache on, and this game re-uploads microcode constantly
  // (314 IM_LOAD per frame for 659 draws) - the hash, not the packet, is the
  // identity.
  uint64_t hash_vs;
  uint64_t hash_ps;
  // Everything else that decides which host pipeline is needed: render target
  // formats and base, blend/depth/mode control, colour mask, cull and clip,
  // primitive topology, index format. Two draws with the same clave can be
  // recorded with no pipeline change at all - that is the whole point of it.
  uint64_t clave;

  // Index buffer, guest side. With origen == kAutoIndex both are zero.
  uint32_t indice_base;
  uint32_t indice_bytes;
  uint32_t cuenta;  // VGT_DRAW_INITIATOR::num_indices

  uint16_t pitch;  // RB_SURFACE_INFO::surface_pitch, identifies the pass
  uint16_t scissor_x0, scissor_y0, scissor_x1, scissor_y1;

  uint8_t primitiva;       // xenos::PrimitiveType
  uint8_t formato_indice;  // xenos::IndexFormat
  uint8_t swap_indice;     // xenos::Endian of the index data
  uint8_t major_mode;      // xenos::MajorMode
  uint8_t origen;          // xenos::SourceSelect
  uint8_t canal;           // 0 = colour target, 1 = depth only, 2 = both
  uint8_t reservado[2];
};

struct Resolve {
  uint32_t destino_base;   // guest address the resolve writes to
  uint32_t destino_bytes;  // extent that may be written
  uint16_t ancho, alto;
  uint8_t formato;   // xenos::ColorFormat of the destination
  uint8_t copiado;   // 0 = only cleared, 1 = colour copied, 2 = depth copied
  uint8_t limpiado;  // RB_COPY_CONTROL clear bits
  uint8_t reservado;
};

struct Transferencia {
  uint32_t base;
  uint32_t bytes;
  uint16_t ancho, alto;
  uint8_t tipo;  // TipoTransferencia
  uint8_t reservado[3];
};

// One frame, as the game asked for it.
struct Fotograma {
  uint64_t numero;
  uint64_t tick_inicio;

  // Packets seen in the ring this frame, by PM4 opcode. The sum of the draw
  // opcodes is the ground truth for "did we capture every draw".
  uint32_t paquetes[kNumPaquetes];

  uint32_t dibujos_n;
  uint32_t dibujos_fallidos;   // backend refused them (IssueDraw false)
  uint32_t dibujos_omitidos;   // still in the ring, never reached IssueDraw
  uint32_t dibujos_perdidos;   // over kMaxDibujos
  Dibujo dibujos[kMaxDibujos];

  uint32_t resolves_n;
  uint32_t resolves_perdidos;
  Resolve resolves[kMaxResolves];

  uint32_t transferencias_n;
  uint32_t transferencias_perdidas;
  Transferencia transferencias[kMaxTransferencias];

  uint32_t swaps;
  uint32_t ancho_destino, alto_destino;
};

// False most of the time, and the only thing the hot paths test.
bool Activo();
void Activar(bool activo);

// Called from the command processor thread when a frame is complete, before the
// slot is reused. Must not throw and must not block for long - it is the frame
// the game is waiting on.
using Callback = void (*)(const Fotograma& fotograma);
void SetCallback(Callback callback);

// --- taps -----------------------------------------------------------------
// Every one of these is a no-op unless Activo().

// Ring packet, by opcode. Called for every type 3 packet.
void EmitPaquete(uint32_t opcode);

// A draw the game asked for. Returns the slot to hand back to MarcarDibujo, or
// kIndiceInvalido if this frame's list is full.
uint32_t EmitDibujo(const Dibujo& dibujo);
void MarcarDibujo(uint32_t indice, bool ejecutado);

void EmitResolve(const Resolve& resolve);
void EmitTransferencia(const Transferencia& transferencia);

// End of frame. Finalises the current frame and hands it to the callback.
void EmitSwap(uint32_t ancho, uint32_t alto);

// PATCH(cola): the front buffer the game named in its swap packet, on its own
// and outside Activo(): it is not capture data, it is the only authoritative
// answer to "which image is on screen" and the native renderer needs it on
// every swap whether the sink is collecting or not. 2K13's fetch constant 0
// does NOT hold it (it reads back as an unrelated pointer), so this is the only
// source.
void AnotarFrontBuffer(uint32_t direccion);
uint32_t UltimoFrontBuffer();

// A draw packet that was consumed but dropped before the backend saw it
// (conditional draw killed by a visibility query, unsupported source).
void EmitDibujoOmitido();

// --- helpers --------------------------------------------------------------

// Builds Dibujo::clave from the register state a draw inherits. Exposed so the
// phase 2 renderer can reuse the exact same definition - if the two ever
// disagree, the pipeline cache silently doubles.
uint64_t ClavePipeline(const RegisterFile& regs, uint64_t hash_vs, uint64_t hash_ps,
                       uint8_t primitiva, uint8_t formato_indice);

// Frames completed since Activar(true).
uint64_t FotogramasCompletados();

// Drops the accumulated per-frame numbers without touching configuration.
void Reiniciar();

}  // namespace native_sink
}  // namespace rex::graphics
