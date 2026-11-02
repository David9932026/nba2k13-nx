/**
 ******************************************************************************
 * ReXGlue runtime - shader library collector                              *
 ******************************************************************************
 *
 * @modified    Cola, 2026 - 2K13 native renderer, step N2a.
 *
 * See shader_lib.h for why this exists. Short version: the native renderer
 * needs, for every shader the game uses, the microcode and the SPIR-V, and the
 * emulation path already has both. This writes them to a file during a normal
 * run.
 *
 * File format - append only, little endian, no seeking, no shutdown hook:
 *
 *   header   "C13SLIB" (7 bytes) + u8 version (1)          once
 *   record   'S' + u8 type + u8 pad[2] + u32 body_bytes    one per distinct shader
 *            body: u64 ucode_hash, u32 ucode_dwords, u32 spirv_bytes,
 *                  u32 tex_count, u32 smp_count, u32 used_texture_mask,
 *                  u32[ucode_dwords], u8[spirv_bytes],
 *                  u8[tex_count]  (fetch_constant | dimension << 5 | signed << 7)
 *                  u16[smp_count] (fetch_constant | mag << 5 | min << 7 |
 *                                  mip << 9 | aniso << 11)
 *   record   'P' + u8 pad[3] + u32 body_bytes              one per distinct pair
 *            body: u64 vs_hash, u64 ps_hash
 *
 * A reader that only wants the shaders can skip anything it does not know by
 * using body_bytes. If the process dies mid-record the last one is truncated;
 * a reader must stop there and keep what came before.
 */

#include <rex/graphics/shader_lib.h>

#include <rex/platform.h>

#include <atomic>
#include <cstdio>
#include <cstring>
#include <string>

#include <rex/graphics/pipeline/shader/shader.h>
#include <rex/graphics/pipeline/shader/spirv.h>

#if REX_PLATFORM_SWITCH
// Defined in switch_crash_hooks.c; returns a directory with a trailing slash.
extern "C" const char* RexSwitchLogDir(void);
#endif

namespace rex::graphics::shader_lib {
namespace {

constexpr char kMagia[8] = {'C', '1', '3', 'S', 'L', 'I', 'B', 1};
constexpr const char* kNombreBin = "shaders_2k13.nflib";
constexpr const char* kNombreTxt = "shaders_2k13.txt";

// Everything here is touched from the pipeline creation thread. Pipeline
// creation can happen on more than one thread, so the write path is guarded by
// a spin lock: no OS primitives (std::mutex on Horizon pulls in more than it is
// worth here, and std::thread is forbidden in this codebase anyway).
std::atomic_flag g_cerrojo = ATOMIC_FLAG_INIT;
std::atomic<bool> g_activo{false};
std::atomic<bool> g_arrancado{false};

FILE* g_bin = nullptr;
FILE* g_txt = nullptr;

// Open-addressed set of the hashes already written, so a shader seen through
// many pipelines is stored once. Static, no allocation.
uint64_t g_hashes[kMaxShaders * 2];
uint32_t g_shaders = 0;
uint32_t g_pares = 0;
uint32_t g_desbordes = 0;

// Pair set, keyed by the combination of the two hashes.
struct Par {
  uint64_t vs = 0;
  uint64_t ps = 0;
  bool usado = false;
};
Par g_pares_vistos[kMaxPares * 2];

class Cerrojo {
 public:
  Cerrojo() {
    while (g_cerrojo.test_and_set(std::memory_order_acquire)) {
    }
  }
  ~Cerrojo() { g_cerrojo.clear(std::memory_order_release); }
};

uint64_t Mezclar(uint64_t a, uint64_t b) {
  uint64_t x = a ^ (b + 0x9E3779B97F4A7C15ull + (a << 6) + (a >> 2));
  x ^= x >> 33;
  x *= 0xFF51AFD7ED558CCDull;
  x ^= x >> 33;
  return x;
}

bool YaVisto(uint64_t hash) {
  const uint32_t capacidad = kMaxShaders * 2;
  uint32_t i = uint32_t(hash) & (capacidad - 1);
  for (uint32_t pasos = 0; pasos < capacidad; ++pasos) {
    const uint64_t v = g_hashes[i];
    if (v == hash) {
      return true;
    }
    if (v == 0) {
      g_hashes[i] = hash;
      return false;
    }
    i = (i + 1) & (capacidad - 1);
  }
  return true;  // table full - treat as seen rather than overwrite
}

bool YaVistoPar(uint64_t vs, uint64_t ps) {
  const uint32_t capacidad = kMaxPares * 2;
  const uint64_t clave = Mezclar(vs, ps);
  uint32_t i = uint32_t(clave) & (capacidad - 1);
  for (uint32_t pasos = 0; pasos < capacidad; ++pasos) {
    Par& p = g_pares_vistos[i];
    if (!p.usado) {
      p.usado = true;
      p.vs = vs;
      p.ps = ps;
      return false;
    }
    if (p.vs == vs && p.ps == ps) {
      return true;
    }
    i = (i + 1) & (capacidad - 1);
  }
  return true;
}

void Escribir(FILE* f, const void* datos, size_t tam) {
  if (f && tam) {
    std::fwrite(datos, 1, tam, f);
  }
}

// One shader. Writes the record and, in the text file, a readable line.
void EscribirShader(const Shader::Translation& traduccion, const char* cual) {
  const Shader& shader = traduccion.shader();
  const uint64_t hash = shader.ucode_data_hash();
  if (YaVisto(hash)) {
    return;
  }
  if (g_shaders >= kMaxShaders) {
    ++g_desbordes;
    return;
  }

  const auto& ucode = shader.ucode_data();
  const auto& spirv = traduccion.translated_binary();

  // Bindings the translator worked out. A native draw path needs the same list
  // to build descriptor sets, so it is stored rather than recomputed. The cast
  // is to SpirvShader, not to VulkanShader, so this file has no Vulkan
  // dependency - and it is only ever called from the Vulkan pipeline cache, so
  // the object really is one.
  const auto* spirv_shader = static_cast<const SpirvShader*>(&shader);
  const auto& texturas = spirv_shader->GetTextureBindingsAfterTranslation();
  const auto& samplers = spirv_shader->GetSamplerBindingsAfterTranslation();
  const uint32_t usadas = spirv_shader->GetUsedTextureMaskAfterTranslation();

  const uint32_t tex_count = uint32_t(texturas.size());
  const uint32_t smp_count = uint32_t(samplers.size());
  const uint32_t cuerpo = uint32_t(8 + 4 + 4 + 4 + 4 + 4 + ucode.size() * 4 + spirv.size() +
                                   tex_count + smp_count * 2);

  char cabecera[8];
  cabecera[0] = 'S';
  cabecera[1] = char(uint8_t(shader.type()));
  cabecera[2] = 0;
  cabecera[3] = 0;
  std::memcpy(cabecera + 4, &cuerpo, 4);
  Escribir(g_bin, cabecera, sizeof(cabecera));

  Escribir(g_bin, &hash, 8);
  const uint32_t dwords = uint32_t(ucode.size());
  const uint32_t spirv_bytes = uint32_t(spirv.size());
  Escribir(g_bin, &dwords, 4);
  Escribir(g_bin, &spirv_bytes, 4);
  Escribir(g_bin, &tex_count, 4);
  Escribir(g_bin, &smp_count, 4);
  Escribir(g_bin, &usadas, 4);
  Escribir(g_bin, ucode.data(), ucode.size() * 4);
  Escribir(g_bin, spirv.data(), spirv.size());
  for (const auto& t : texturas) {
    // The enums are bit-fields of enum type; they need the explicit cast before
    // any arithmetic.
    const uint32_t dim = uint32_t(t.dimension);
    const uint32_t sgn = uint32_t(t.is_signed);
    const uint8_t b = uint8_t((t.fetch_constant & 0x1F) | ((dim & 0x3) << 5) | ((sgn & 0x1) << 7));
    Escribir(g_bin, &b, 1);
  }
  for (const auto& s : samplers) {
    const uint32_t mag = uint32_t(s.mag_filter);
    const uint32_t mn = uint32_t(s.min_filter);
    const uint32_t mip = uint32_t(s.mip_filter);
    const uint32_t ani = uint32_t(s.aniso_filter);
    const uint16_t b = uint16_t((s.fetch_constant & 0x1F) | ((mag & 0x3) << 5) | ((mn & 0x3) << 7) |
                                ((mip & 0x3) << 9) | ((ani & 0x7) << 11));
    Escribir(g_bin, &b, 2);
  }

  ++g_shaders;
  if (g_txt) {
    std::fprintf(g_txt, "[SLIB] shader %s #%u hash=%016llX ucode=%u dwords spirv=%u B tex=%u smp=%u mask=%08X\n",
                 cual, g_shaders, (unsigned long long)hash, dwords, spirv_bytes, tex_count,
                 smp_count, usadas);
    std::fflush(g_txt);
  }
  if (g_bin) {
    std::fflush(g_bin);
  }
}

void EscribirPar(uint64_t vs, uint64_t ps) {
  if (YaVistoPar(vs, ps)) {
    return;
  }
  ++g_pares;
  const uint32_t cuerpo = 16;
  char cabecera[8];
  cabecera[0] = 'P';
  cabecera[1] = 0;
  cabecera[2] = 0;
  cabecera[3] = 0;
  std::memcpy(cabecera + 4, &cuerpo, 4);
  Escribir(g_bin, cabecera, sizeof(cabecera));
  Escribir(g_bin, &vs, 8);
  Escribir(g_bin, &ps, 8);
  if (g_txt) {
    std::fprintf(g_txt, "[SLIB] par #%u vs=%016llX ps=%016llX\n", g_pares, (unsigned long long)vs,
                 (unsigned long long)ps);
    std::fflush(g_txt);
  }
  if (g_bin) {
    std::fflush(g_bin);
  }
}

bool LeerInterruptor() {
#if REX_PLATFORM_SWITCH
  const char* ruta = "/switch/nba2k13/shaderlib.txt";
#else
  const char* ruta = "shaderlib.txt";
#endif
  FILE* f = std::fopen(ruta, "rb");
  if (!f) {
    return false;
  }
  char buf[16] = {};
  const size_t n = std::fread(buf, 1, sizeof(buf) - 1, f);
  std::fclose(f);
  if (n == 0) {
    return false;
  }
  int v = 0;
  if (std::sscanf(buf, "%d", &v) != 1) {
    return false;
  }
  return v != 0;
}

std::string Directorio() {
#if REX_PLATFORM_SWITCH
  return std::string(RexSwitchLogDir());
#else
  return std::string("logs/");
#endif
}

}  // namespace

void Iniciar() {
  bool esperado = false;
  if (!g_arrancado.compare_exchange_strong(esperado, true)) {
    return;
  }
  if (!LeerInterruptor()) {
    return;
  }
  const std::string dir = Directorio();
  const std::string ruta_bin = dir + kNombreBin;
  const std::string ruta_txt = dir + kNombreTxt;
  // Fresh file every run: a second run would otherwise append a duplicate set.
  g_bin = std::fopen(ruta_bin.c_str(), "wb");
  g_txt = std::fopen(ruta_txt.c_str(), "wb");
  if (!g_bin) {
    // Nothing to collect into - stay off rather than burn time per shader.
    if (g_txt) {
      std::fprintf(g_txt, "[SLIB] no se pudo abrir %s\n", ruta_bin.c_str());
      std::fclose(g_txt);
      g_txt = nullptr;
    }
    return;
  }
  Escribir(g_bin, kMagia, sizeof(kMagia));
  std::fflush(g_bin);
  if (g_txt) {
    std::fprintf(g_txt, "[SLIB] coleccion activa -> %s\n", ruta_bin.c_str());
    std::fflush(g_txt);
  }
  g_activo.store(true, std::memory_order_release);
}

bool Activo() {
  // Lazy: the first pipeline creation opens the files. After that this is a
  // single atomic load, which is all the per-shader cost should be.
  if (!g_arrancado.load(std::memory_order_acquire)) {
    Iniciar();
  }
  return g_activo.load(std::memory_order_acquire);
}

void RegistrarPipeline(const Shader::Translation& vertex_shader, const Shader::Translation* pixel_shader) {
  if (!g_activo.load(std::memory_order_acquire)) {
    return;
  }
  // Only translated shaders have SPIR-V; a failed one would land in the file
  // with an empty binary and poison the library.
  if (!vertex_shader.is_translated() || !vertex_shader.is_valid()) {
    return;
  }
  if (pixel_shader && (!pixel_shader->is_translated() || !pixel_shader->is_valid())) {
    return;
  }
  Cerrojo guardia;
  EscribirShader(vertex_shader, "VS");
  if (pixel_shader) {
    EscribirShader(*pixel_shader, "PS");
  }
  const uint64_t vs = vertex_shader.shader().ucode_data_hash();
  const uint64_t ps = pixel_shader ? pixel_shader->shader().ucode_data_hash() : 0;
  EscribirPar(vs, ps);
}

uint32_t NumShaders() {
  return g_shaders;
}

uint32_t NumPares() {
  return g_pares;
}

}  // namespace rex::graphics::shader_lib
