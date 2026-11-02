/**
 ******************************************************************************
 * ReXGlue runtime - shader library collector                              *
 ******************************************************************************
 *
 * @modified    Cola, 2026 - 2K13 native renderer, step N2a.
 *
 * PATCH(cola): why this exists.
 *
 * The NFS MW native renderer does not translate shaders while running. It reads
 * them from a file next to the executable (nfsmw_shaders.nfsp) that holds, for
 * every shader the game uses, the microcode plus the SPIR-V translation made
 * offline by XenosRecomp. The reason is that the PM4 ring only carries
 * microcode: given the microcode that arrives there, the renderer has to answer
 * "which shader is this, and what did we decide to compile it to".
 *
 * 2K13 needs its own copy of that file. Both pieces already pass through the
 * emulation path in a working state - the Xenos plugin receives the microcode
 * and produces SPIR-V for it (that is where the "Creating graphics pipeline
 * state with VS ..." lines come from) - so the library does not have to be
 * built offline with an external tool. This collector writes it out from a
 * normal emulation run: start the game, sit in the menu, and every shader the
 * game creates lands in the file.
 *
 * What is stored per shader, and why each field is needed:
 *  - ucode hash and microcode: the key. The ring gives microcode, and the hash
 *    is how it will be looked up.
 *  - SPIR-V: the compiled form, so a native renderer never has to translate.
 *  - texture / sampler bindings: which fetch constants are textures and how
 *    they are filtered. The emulation derives this during translation and a
 *    native draw path needs exactly the same list to build descriptor sets.
 *  - used texture mask: cheap summary of the same.
 *
 * The file is append-only and written as records the moment each shader
 * appears, so it survives a crash and needs no shutdown hook.
 *
 * NOTE(cola): the vertex shader microcode that reaches the ring is *not* the
 * microcode the game compiled - D3D rewrites its fetches (reorders them,
 * changes swizzles, nulls outputs the pixel shader does not read). So a VS
 * lookup by raw microcode hash will miss. The hash stored here is the hash of
 * the microcode as the D3D object holds it, which is what the game's shader
 * constructors see; the native renderer has to hook those constructors to get
 * the identity of a VS, exactly as NFS MW does. Pixel shaders arrive in the
 * ring unmodified and match directly.
 */

#pragma once

#include <cstdint>

#include <rex/graphics/pipeline/shader/shader.h>

namespace rex::graphics {

namespace shader_lib {

// Ceilings. This game creates 145 pipelines over 80 shader pairs; the ceilings
// are here so a runaway cannot walk off the end of a static array. Overflow is
// counted and reported, never hidden.
inline constexpr uint32_t kMaxShaders = 512;
inline constexpr uint32_t kMaxPares = 1024;

// Reads the switch file once and opens the output files. Cheap and safe to call
// more than once; does nothing if the switch file is absent or zero.
//
// Switch: sdmc:/switch/nba2k13/shaderlib.txt
// PC:     shaderlib.txt next to the working directory
void Iniciar();

// Whether collection is on. One predictable branch when off.
bool Activo();

// Registers one graphics pipeline: the vertex and (optional) pixel shader that
// went into it. Called from the pipeline cache after both have been translated,
// so their SPIR-V exists. Records each shader once (by hash) and the pair
// every time it is new. Can be called from any thread.
void RegistrarPipeline(const Shader::Translation& vertex_shader,
                       const Shader::Translation* pixel_shader);

// Number of distinct shaders and pairs recorded so far.
uint32_t NumShaders();
uint32_t NumPares();

}  // namespace shader_lib
}  // namespace rex::graphics
