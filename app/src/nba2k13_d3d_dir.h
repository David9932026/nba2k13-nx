// 2K13 - native renderer: everything that is specific to *this* game's copy of
// the Direct3D library, in one place.
//
// The native renderer itself is ported from nfsmw-nx (Need for Speed Most
// Wanted). Between that game and this one, the D3D library is the same code but
// a much later XDK build: every function moved, the device grew, the shader
// object was redesigned and two packet formats changed. All of that knowledge
// lives here rather than being sprinkled through the ported files, so when
// something turns out to be wrong there is one table to correct and one place
// to look.
//
// Every value below was derived by instruction-level comparison of the two
// games' recompiled code, not guessed; the evidence (which function, which
// constant, what proved it) is in D3D函数对照-2K13.md at the project root.
// Confidence is noted where it is not "established".
//
// Naming: 2K13 = this game, NFS = the reference port.

#pragma once

#include <cstdint>

namespace nba2k13::d3d {

// ---------------------------------------------------------------------------
// Guest addresses of the D3D library functions the native renderer hooks.
//
// These are PowerPC guest addresses, the same space as the generated function
// names (sub_82CAB690). A hook is installed by pointing at the recompiled
// function, so the value is only used to build the symbol name.
// ---------------------------------------------------------------------------

// Creates a pixel shader object from a container. Called by the game with the
// original container; the native renderer uses it to learn which shader is
// which, because pixel shader microcode reaches the ring unmodified.
inline constexpr uint32_t kDirCrearPixelShader = 0x82CAB690;
// Same for a vertex shader. Needed separately because D3D rewrites the fetches
// of a vertex shader before it reaches the ring, so its identity has to come
// from the object, not from the microcode.
inline constexpr uint32_t kDirCrearVertexShader = 0x82CAB878;

// SetPixelShader / SetVertexShader. Store the bound object at the device
// offsets below and bump the shader version counters.
inline constexpr uint32_t kDirFijarPixelShader = 0x82CAAEA0;
inline constexpr uint32_t kDirFijarVertexShader = 0x82CAB0A8;

// Get(Current)(Vertex|Pixel)Shader: read the bound object, AddRef, write it to
// the out parameter. Used to identify what a draw is about to use.
inline constexpr uint32_t kDirObtenerPixelShader = 0x82CAB278;
inline constexpr uint32_t kDirObtenerVertexShader = 0x82CAB060;

// Shader object construction: memset 872 bytes and set up the per-slot 416-byte
// descriptor blocks. NFS equivalent is 8259C300.
inline constexpr uint32_t kDirIniciarShader = 0x82CAB780;

// Shader constant / register patch pass: fixes up the microcode fields that
// depend on the device state (constant window base, etc.) right before upload.
// NFS 825A3A40 -> this. High confidence: instruction-for-instruction the same
// shape, differing only in register allocation and field offsets.
inline constexpr uint32_t kDirParcheShader = 0x82CC1560;

// Writes a shader's microcode into the command ring (the upload packet) and
// records the uploaded state. NFS 825A3B70 -> this. **The packet gained two
// dwords** - see kPaqueteSubidaShader below.
inline constexpr uint32_t kDirSubirShaderAnillo = 0x82CC16B0;

// Vertex declaration -> fetch descriptor construction, sorting and write-back.
// NFS 825A3350 -> this. Includes the in-body entry at +0x358 (NFS 825A36A8).
inline constexpr uint32_t kDirConstruirDescriptores = 0x82CC0DB0;

// Vertex declaration dirty check + cache rebuild; calls the function above.
inline constexpr uint32_t kDirDeclaracionSucia = 0x82CC18B8;

// FlushState for shaders: the only function in the whole game that reads
// +13072 (VS), +13068 (PS) and +12240 (declaration) together, and the only
// caller of the two upload functions above.
inline constexpr uint32_t kDirVolcarEstadoShaders = 0x82CC19F8;

// Constant block upload (PM4 0xC0022F00 + address + (index<<2) + count).
// NFS equivalent was never located; this one was found here.
inline constexpr uint32_t kDirSubirConstantes = 0x82CC1808;

// Ring space wait: spins on the read pointer the GPU publishes. Also the two
// helpers it inlines around the spin.
inline constexpr uint32_t kDirEsperarAnillo = 0x82CADC38;
inline constexpr uint32_t kDirEsperaPreparar = 0x82CA2AB8;
inline constexpr uint32_t kDirEsperaLiberar = 0x82CA2AE8;
// "Has the fence in the ring completed" rotation, called by the spin above.
inline constexpr uint32_t kDirComprobarFence = 0x82CA2BB0;

// Builds the submit + fence event write block.
inline constexpr uint32_t kDirEnviarFence = 0x82CAE588;

// NOTE(cola): NFS also hooked 82597930 (a standalone 0xC0025801 event write) to
// count vblanks. This game has no 0xC0025801 anywhere - only 0xC0025800 - so
// that hook has no counterpart. Vblank/vsync must be anchored on the swap
// submit block (kDirEnviarFence) or on the 0x0BADF00D cluster instead.
inline constexpr uint32_t kDirEventWriteVblank = 0;

// NOTE(cola): the reference port also hooks occlusion queries
// (8258FBA8/8258F810/8258EA28/8258F998). This game does not use them at all:
// the 0xFFFFFEED query marker appears zero times in its code, the two query
// PM4 packets have no function in common, and the device has no query list
// field. That whole subsystem is simply not ported - see §4.1 of the report.

// ---------------------------------------------------------------------------
// D3D device field offsets.
//
// Layout changed significantly between the two XDK builds; in particular the
// dirty-flag bits moved to a different byte AND a different bit position, so
// copying the reference port's bit numbers would either make the shader upload
// never happen or happen every frame.
// ---------------------------------------------------------------------------

// Ring write pointer (u32).
inline constexpr uint32_t kDispEscrituraAnillo = 48;
// Ring control block; [0] = GPU read pointer, [4] = last submitted value.
inline constexpr uint32_t kDispControlAnillo = 11024;  // 0x2B10
// Ring write offset.
inline constexpr uint32_t kDispOffsetAnillo = 11036;  // 0x2B1C

// Dirty-flag bytes.
inline constexpr uint32_t kDispSucio0 = 11069;
inline constexpr uint32_t kDispSucio1 = 11070;  // bit 7 = "vertex shader uploaded"
inline constexpr uint32_t kDispSucio2 = 11071;

// Bit in kDispSucio1 meaning "the vertex shader has been uploaded".
// NFS had this as bit 0 of its byte; here it is bit 7. This is the single most
// dangerous constant in the file - wrong, and the shader either never uploads
// or uploads every frame.
inline constexpr uint8_t kBitShaderSubido = 7;

// 64-bit generation stamps, and the copies of them used to decide whether an
// upload is needed.
inline constexpr uint32_t kDispSelloA = 12904;
inline constexpr uint32_t kDispSelloB = 12912;
inline constexpr uint32_t kDispSelloCacheA = 12264;
inline constexpr uint32_t kDispSelloCacheB = 12272;

// Current vertex declaration object (this game keeps it in its own field).
inline constexpr uint32_t kDispDeclaracionActual = 12240;  // 0x2FD0

// Currently bound shaders.
inline constexpr uint32_t kDispPixelShader = 13068;   // 0x330C
inline constexpr uint32_t kDispVertexShader = 13072;  // 0x3310

// Device idle / lost flags, saved ring position, submit sequence latch.
inline constexpr uint32_t kDispInactivo = 13600;
inline constexpr uint32_t kDispAnilloGuardadoA = 13608;
inline constexpr uint32_t kDispAnilloGuardadoB = 13612;
inline constexpr uint32_t kDispSecuenciaEnvio = 15324;

// Per-slot descriptor blocks: 416 bytes each, starting at device+68.
inline constexpr uint32_t kDispoDescriptores = 68;
inline constexpr uint32_t kTamDescriptores = 416;
// Offset table: device+896 + 8*index holds the 32-bit offset of a sub-structure.
inline constexpr uint32_t kDispTablaOffsets = 896;
// The declaration / shader sub-structure starts here; it is itself 872 bytes and
// is the base the shader object's microcode pointer is relative to.
inline constexpr uint32_t kDispSubestructura = 872;

// ---------------------------------------------------------------------------
// Shader object layout.
//
// The object is 872 bytes here versus 592 there, and the microcode pointer is
// no longer a plain pointer: it is an offset relative to the sub-structure
// above. Getting this wrong means reading the wrong bytes as microcode, which
// shows up as a garbled or black image rather than as a crash.
// ---------------------------------------------------------------------------

inline constexpr uint32_t kTamShader = 872;
// u32 offset of the microcode relative to [device + kDispSubestructura].
inline constexpr uint32_t kDispShaderMicrocodigo = 32;
// u32 dword count of the microcode, relative to the sub-structure.
inline constexpr uint32_t kDispShaderMicrocodigoDwords = 876;
// Vertex declaration: element count, then the array (12 bytes per element).
inline constexpr uint32_t kDispShaderElementosCuenta = 24;
inline constexpr uint32_t kDispShaderElementos = 52;
inline constexpr uint32_t kTamElementoDeclaracion = 12;
// 32-bit flags; bit 12 (0x1000) = compiled.
inline constexpr uint32_t kDispShaderFlags = 20;
// Header length used by the patch pass, in dwords: [24] + [28] + 9 (NFS used +10).
inline constexpr uint32_t kDispShaderCabeceraA = 24;
inline constexpr uint32_t kDispShaderCabeceraB = 28;
inline constexpr uint32_t kCabeceraExtraDwords = 9;

// ---------------------------------------------------------------------------
// Command ring packet formats.
// ---------------------------------------------------------------------------

// Shader microcode upload. This game emits TWO Type-0 packets back to back,
// where the reference port emits one:
//
//   NFS : 0xC0002B00 | count<<16, 0, n
//   2K13: 0xC0003B00 | count<<16, 0x100, 0xC0002B00 | count<<16, 0, n
//
// So the upload costs two more dwords, and the ring space request is n+5
// instead of n+3. Sizing the request with the smaller number corrupts the ring.
inline constexpr uint32_t kPaqueteSubidaShaderA = 0x3B00;  // first packet, type bits set
inline constexpr uint32_t kPaqueteSubidaShaderB = 0x2B00;  // second packet
inline constexpr uint32_t kDwordsExtraSubida = 2;
inline constexpr uint32_t kDwordsReservaSubida = 5;  // n + 5

// Event write. Only 0x800 is emitted by this game; the 0x801 variant the
// reference port hooks does not exist here.
inline constexpr uint32_t kPaqueteEventWrite = 0x5800;

// Constant block upload: address, then (index << 2), then count.
inline constexpr uint32_t kPaqueteConstantes = 0x2F00;

// State invalidation, usually paired with 0x0BADF00D.
inline constexpr uint32_t kPaqueteInvalidar = 0x1000;
inline constexpr uint32_t kMarcaInvalidar = 0x77777777;

// ---------------------------------------------------------------------------
// Converting a guest GPU address to a command-ring offset.
//
// Unchanged between the two games - copied verbatim because it is load-bearing
// and easy to get subtly wrong.
// ---------------------------------------------------------------------------

inline uint32_t DireccionGpuAOffsetAnillo(uint32_t direccion) {
  const uint32_t campo = (direccion >> 8) & 0xFFF;
  const uint32_t bajo = direccion & 0x1FFFFFFF;
  const uint32_t alto = ((campo + 512) & 0x1000) + bajo;
  return alto - 0x40000000u;
}

}  // namespace nba2k13::d3d
