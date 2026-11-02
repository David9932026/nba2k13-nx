// nba2k13 - native renderer, phase 1: the sink owner. See nba2k13_nativo.h for why this exists.

#include "nba2k13_nativo.h"

// REX_PLATFORM_SWITCH lives in rex/platform.h. Without this the guard below is false and the whole
// file compiles down to the empty stub: it links fine and silently does nothing, which is exactly
// what a missing `#include` looks like in a codebase that gates everything on a header macro.
#include <rex/platform.h>

#if REX_PLATFORM_SWITCH

#include <cstdio>
#include <cstring>
#include <string>

#include <rex/chrono/clock.h>
#include <rex/graphics/native_sink.h>

extern "C" const char* RexSwitchLogDir(void);

namespace nba2k13::nativo {
namespace {

using rex::graphics::native_sink::Dibujo;
using rex::graphics::native_sink::Fotograma;

// The whole point of the phase is to learn these two sets. 512 is far above what this game has shown
// (72 distinct shader pairs in a long menu session) and small enough to stay in cache.
constexpr uint32_t kMaxClaves = 512;
constexpr uint32_t kMaxPares = 512;
// Enough of a frame to eyeball the command sequence without flooding the SD card.
constexpr uint32_t kMuestrasSecuencia = 48;

FILE* g_registro = nullptr;
bool g_activo = false;
bool g_secuencia_volcada = false;

// Distinct pipeline keys, open-addressed with linear probing. No allocation: these live in BSS.
uint64_t g_claves[kMaxClaves];
uint32_t g_claves_n = 0;
uint32_t g_claves_saturadas = 0;
uint64_t g_pares[kMaxPares];
uint32_t g_pares_n = 0;
uint32_t g_pares_saturados = 0;

// Aggregates of the window being written, one line per second.
uint64_t g_ventana_inicio_tick = 0;
uint32_t g_ventana_fotogramas = 0;
uint64_t g_ventana_dibujos = 0;
uint64_t g_ventana_fallidos = 0;
uint64_t g_ventana_omitidos = 0;
uint64_t g_ventana_perdidos = 0;
uint64_t g_ventana_paquetes_dibujo = 0;
uint64_t g_ventana_resolves = 0;
uint64_t g_ventana_copias = 0;
uint64_t g_ventana_subidas = 0;
uint64_t g_ventana_bytes = 0;
uint64_t g_ventana_descartes = 0;
uint64_t g_ventana_ancho_max = 0;

inline uint64_t Mezclar(uint64_t x) {
  x ^= x >> 33;
  x *= 0xFF51AFD7ED558CCDull;
  x ^= x >> 33;
  x *= 0xC4CEB9FE1A85EC53ull;
  x ^= x >> 33;
  return x;
}

// Returns true if the key was not known yet.
bool AnadirClave(uint64_t clave) {
  if (!clave) {
    return false;
  }
  uint32_t slot = uint32_t(Mezclar(clave)) & (kMaxClaves - 1);
  for (uint32_t i = 0; i < kMaxClaves; ++i) {
    const uint64_t actual = g_claves[slot];
    if (actual == clave) {
      return false;
    }
    if (!actual) {
      g_claves[slot] = clave;
      ++g_claves_n;
      return true;
    }
    slot = (slot + 1) & (kMaxClaves - 1);
  }
  ++g_claves_saturadas;
  return false;
}

bool AnadirPar(uint64_t par) {
  if (!par) {
    return false;
  }
  uint32_t slot = uint32_t(Mezclar(par)) & (kMaxPares - 1);
  for (uint32_t i = 0; i < kMaxPares; ++i) {
    const uint64_t actual = g_pares[slot];
    if (actual == par) {
      return false;
    }
    if (!actual) {
      g_pares[slot] = par;
      ++g_pares_n;
      return true;
    }
    slot = (slot + 1) & (kMaxPares - 1);
  }
  ++g_pares_saturados;
  return false;
}

const char* Primitiva(uint8_t prim) {
  switch (prim) {
    case 0:
      return "punto";
    case 1:
      return "linea";
    case 2:
      return "lista";
    case 3:
      return "franja";
    case 4:
      return "abanico";
    case 5:
      return "tri-lista";
    case 6:
      return "tri-franja";
    case 7:
      return "tri-abanico";
    case 8:
      return "rect-lista";
    case 9:
      return "rect-franja";
    case 10:
      return "rect-abanico";
    case 11:
      return "quad-lista";
    case 12:
      return "quad-franja";
    case 13:
      return "quad-abanico";
    default:
      return "?";
  }
}

void VolcarSecuencia(const Fotograma& fotograma) {
  g_secuencia_volcada = true;
  std::fprintf(g_registro, "[NATIVO] secuencia f=%llu (%u dibujos, %u resolves, %u transferencias)\n",
               static_cast<unsigned long long>(fotograma.numero), fotograma.dibujos_n,
               fotograma.resolves_n, fotograma.transferencias_n);
  const uint32_t n = fotograma.dibujos_n < kMuestrasSecuencia ? fotograma.dibujos_n
                                                             : kMuestrasSecuencia;
  for (uint32_t i = 0; i < n; ++i) {
    const Dibujo& d = fotograma.dibujos[i];
    std::fprintf(g_registro,
                 "[NATIVO]   #%-4u %-11s cuenta=%-6u pitch=%-5u canal=%u scissor=%u,%u..%u,%u "
                 "base=0x%08X vs=%016llX ps=%016llX clave=%016llX\n",
                 i, Primitiva(d.primitiva), d.cuenta, d.pitch, d.canal, d.scissor_x0, d.scissor_y0,
                 d.scissor_x1, d.scissor_y1, d.indice_base,
                 static_cast<unsigned long long>(d.hash_vs),
                 static_cast<unsigned long long>(d.hash_ps),
                 static_cast<unsigned long long>(d.clave));
  }
  if (fotograma.dibujos_n > kMuestrasSecuencia) {
    std::fprintf(g_registro, "[NATIVO]   ... %u mas\n", fotograma.dibujos_n - kMuestrasSecuencia);
  }
  std::fflush(g_registro);
}

void CerrarVentana(uint64_t ahora_tick, uint64_t frecuencia) {
  const double segundos =
      frecuencia ? double(ahora_tick - g_ventana_inicio_tick) / double(frecuencia) : 1.0;
  g_ventana_inicio_tick = ahora_tick;
  const bool con_datos = g_ventana_fotogramas != 0;
  if (!g_registro) {
    return;
  }
  if (con_datos) {
    const double f = double(g_ventana_fotogramas);
    std::fprintf(
        g_registro,
        "[NATIVO] %.1f s, %u f | dibujos/f=%.1f (anillo %.1f) fallidos/f=%.1f omitidos/f=%.1f "
        "perdidos/f=%.1f | resolves/f=%.1f copias/f=%.1f subidas/f=%.1f (%.2f MB/f) | "
        "pipelines=%u pares=%u | descartes=%llu ancho=%llu\n",
        segundos, g_ventana_fotogramas, double(g_ventana_dibujos) / f,
        double(g_ventana_paquetes_dibujo) / f, double(g_ventana_fallidos) / f,
        double(g_ventana_omitidos) / f, double(g_ventana_perdidos) / f,
        double(g_ventana_resolves) / f, double(g_ventana_copias) / f,
        double(g_ventana_subidas) / f,
        f ? double(g_ventana_bytes) / f / (1024.0 * 1024.0) : 0.0, g_claves_n, g_pares_n,
        static_cast<unsigned long long>(g_ventana_descartes),
        static_cast<unsigned long long>(g_ventana_ancho_max));
    if (g_claves_saturadas || g_pares_saturados) {
      std::fprintf(g_registro, "[NATIVO] tablas saturadas: claves %u pares %u\n", g_claves_saturadas,
                   g_pares_saturados);
    }
    std::fflush(g_registro);
  }
  g_ventana_fotogramas = 0;
  g_ventana_dibujos = 0;
  g_ventana_fallidos = 0;
  g_ventana_omitidos = 0;
  g_ventana_perdidos = 0;
  g_ventana_paquetes_dibujo = 0;
  g_ventana_resolves = 0;
  g_ventana_copias = 0;
  g_ventana_subidas = 0;
  g_ventana_bytes = 0;
  g_ventana_descartes = 0;
  g_ventana_ancho_max = 0;
}

void AlFotograma(const Fotograma& fotograma) {
  if (!g_activo || !g_registro) {
    return;
  }

  // 1. Completeness: every draw packet in the ring has to end up in exactly one of these three
  // buckets. A non-zero gap means the capture is missing draws a renderer would have to draw.
  // Opcodes from xenos.h: DRAW_INDX 0x22, DRAW_INDX_2 0x36, and the two tiled variants 0x34/0x35.
  const uint32_t paquetes_dibujo = fotograma.paquetes[0x22] + fotograma.paquetes[0x36] +
                                   fotograma.paquetes[0x34] + fotograma.paquetes[0x35];
  // dibujos_n already contains the ones the backend refused (they are emitted before IssueDraw and
  // only flagged afterwards), so the failed count must not be added again here.
  const uint32_t contados = fotograma.dibujos_n + fotograma.dibujos_omitidos +
                            fotograma.dibujos_perdidos;
  if (paquetes_dibujo > contados) {
    g_ventana_descartes += paquetes_dibujo - contados;
  }

  g_ventana_fotogramas++;
  g_ventana_dibujos += fotograma.dibujos_n;
  g_ventana_fallidos += fotograma.dibujos_fallidos;
  g_ventana_omitidos += fotograma.dibujos_omitidos;
  g_ventana_perdidos += fotograma.dibujos_perdidos;
  g_ventana_paquetes_dibujo += paquetes_dibujo;
  g_ventana_resolves += fotograma.resolves_n;
  for (uint32_t i = 0; i < fotograma.transferencias_n; ++i) {
    const auto& t = fotograma.transferencias[i];
    if (t.tipo == uint8_t(rex::graphics::native_sink::TipoTransferencia::kSubida)) {
      ++g_ventana_subidas;
      g_ventana_bytes += t.bytes;
    } else {
      ++g_ventana_copias;
    }
  }
  if (fotograma.ancho_destino > g_ventana_ancho_max) {
    g_ventana_ancho_max = fotograma.ancho_destino;
  }

  // 2. Pipeline set: what phase 3 precompiles. Dumped as it grows, so the log carries the full table
  // without a separate pass.
  for (uint32_t i = 0; i < fotograma.dibujos_n; ++i) {
    const Dibujo& d = fotograma.dibujos[i];
    if (d.hash_vs || d.hash_ps) {
      const uint64_t par = Mezclar(d.hash_vs) ^ (Mezclar(d.hash_ps) * 0x9E3779B97F4A7C15ull);
      if (AnadirPar(par)) {
        std::fprintf(g_registro, "[NATIVO] par nuevo #%u vs=%016llX ps=%016llX\n", g_pares_n,
                     static_cast<unsigned long long>(d.hash_vs),
                     static_cast<unsigned long long>(d.hash_ps));
      }
    }
    if (AnadirClave(d.clave)) {
      std::fprintf(g_registro, "[NATIVO] pipeline nueva #%u clave=%016llX\n", g_claves_n,
                   static_cast<unsigned long long>(d.clave));
    }
  }

  // 3. One frame's worth of command sequence, once, so the order can be read by eye.
  if (!g_secuencia_volcada && fotograma.dibujos_n >= 100) {
    VolcarSecuencia(fotograma);
  }

  const uint64_t ahora = rex::chrono::Clock::QueryHostTickCount();
  const uint64_t frecuencia = rex::chrono::Clock::QueryHostTickFrequency();
  if (!g_ventana_inicio_tick) {
    g_ventana_inicio_tick = ahora;
    return;
  }
  if (frecuencia && (ahora - g_ventana_inicio_tick) >= frecuencia) {
    CerrarVentana(ahora, frecuencia);
  }
}

bool LeerInterruptor(const char* ruta, char* buffer, size_t tamano) {
  FILE* f = std::fopen(ruta, "rb");
  if (!f) {
    return false;
  }
  const size_t leidos = std::fread(buffer, 1, tamano - 1, f);
  std::fclose(f);
  buffer[leidos] = '\0';
  return true;
}

}  // namespace

void Iniciar() {
  char valor[16] = {};
  const bool hay_interruptor = LeerInterruptor("/switch/nba2k13/nativo.txt", valor, sizeof(valor));
  if (hay_interruptor && valor[0] == '0') {
    return;
  }
  if (!hay_interruptor) {
    // Not even the file: stay off. This has to be turned on deliberately, because phase 1 spends
    // frame time to prove things and the emulation path is already at the edge.
    return;
  }

  const std::string ruta = std::string(RexSwitchLogDir()) + "nativo.log";
  g_registro = std::fopen(ruta.c_str(), "w");
  if (!g_registro) {
    return;
  }
  std::fprintf(g_registro,
               "[NATIVO] fase 1 v2 - captura de comandos GPU. Interruptor: %s (leyendo '%s')\n",
                hay_interruptor ? "nativo.txt" : "ausente", valor);
  std::fflush(g_registro);

  std::memset(g_claves, 0, sizeof(g_claves));
  std::memset(g_pares, 0, sizeof(g_pares));
  g_claves_n = g_pares_n = 0;
  g_claves_saturadas = g_pares_saturados = 0;
  g_secuencia_volcada = false;
  g_ventana_inicio_tick = 0;

  rex::graphics::native_sink::SetCallback(&AlFotograma);
  rex::graphics::native_sink::Activar(true);
  g_activo = true;
}

void Detener() {
  if (!g_activo) {
    return;
  }
  g_activo = false;
  rex::graphics::native_sink::Activar(false);
  rex::graphics::native_sink::SetCallback(nullptr);
  if (g_registro) {
    std::fprintf(g_registro, "[NATIVO] fin: pipelines=%u pares=%u fotogramas=%llu\n", g_claves_n,
                 g_pares_n,
                 static_cast<unsigned long long>(
                     rex::graphics::native_sink::FotogramasCompletados()));
    std::fclose(g_registro);
    g_registro = nullptr;
  }
}

}  // namespace nba2k13::nativo

#else  // !REX_PLATFORM_SWITCH

namespace nba2k13::nativo {
void Iniciar() {}
void Detener() {}
}  // namespace nba2k13::nativo

#endif
