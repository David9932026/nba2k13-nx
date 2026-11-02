// PATCH(cola) N4g: substep cap for sub_82292FD8 (the in-game per-frame solver).
//
// The generated sub_82292FD8 computes n = ceil(rate * dt) substeps (vrfip128 v49) and then runs
// sub_822917F8 / sub_82291A70 / sub_82291EF0 / sub_82292830 n times. On the Switch, inside a game
// that loop is ~89% of the main guest thread (rex_perfil.log, 2026-10-31 02:00, 8 fps). The step
// size is derived from the same v49 (1/max(n,1)), so capping n here keeps the integrated time
// equal to dt: fewer, larger substeps instead of a slower simulation.
//
// Cap: subpasos.txt (Switch: /switch/nba2k13/subpasos.txt), an integer; 0 = no cap. Without the
// file the Switch default is kSubpasosDefecto and the PC default is 0. Stats go to stderr every
// 10 s as [SUBPASOS].

#include <rex/platform.h>

#include <atomic>
#include <chrono>
#include <cstdio>
#include <cstdlib>

#include <cstdarg>

namespace {
void Log(const char* fmt, ...) {
  va_list a;
  va_start(a, fmt);
  std::vfprintf(stderr, fmt, a);
  va_end(a);
#if !REX_PLATFORM_SWITCH
  if (std::FILE* f = std::fopen("subpasos.log", "ab")) {
    va_start(a, fmt);
    std::vfprintf(f, fmt, a);
    va_end(a);
    std::fclose(f);
  }
#endif
}
#if REX_PLATFORM_SWITCH
constexpr const char* kArchivo = "/switch/nba2k13/subpasos.txt";
constexpr int kSubpasosDefecto = 3;
#else
constexpr const char* kArchivo = "subpasos.txt";
constexpr int kSubpasosDefecto = 0;
#endif

// N4i: maximum size of one capped substep, as a multiple of the game's own step (1/rate).
// Capping n alone made each step up to 3.5x the original and the cloth overshot (jerseys
// swinging far too much). Above this factor the simulated time is cut instead: the cloth
// lags a little behind but stays stable. Second number in subpasos.txt; 0 = no limit.
float g_factor_max = 1.25f;  // 1.5 still let the shorts swing a little (Switch 2026-11-01 17:39)

int LeerTope() {
  int tope = kSubpasosDefecto;
  if (std::FILE* f = std::fopen(kArchivo, "rb")) {
    char buf[64] = {};
    const size_t n = std::fread(buf, 1, sizeof(buf) - 1, f);
    std::fclose(f);
    buf[n] = 0;
    char* fin = nullptr;
    tope = int(std::strtol(buf, &fin, 10));
    if (tope < 0) tope = 0;
    if (fin && *fin) {
      char* fin2 = nullptr;
      const float fm = std::strtof(fin, &fin2);
      if (fin2 != fin && fm >= 0.0f) g_factor_max = fm;
    }
  }
  Log("[SUBPASOS] tope=%d factor_max=%.2f (%s)\n", tope, g_factor_max, kArchivo);
  return tope;
}

struct Estado {
  int tope = -1;
  uint64_t llamadas = 0, recortadas = 0;
  double suma = 0, suma_tras = 0;
  float max = 0, ultimo_rate = 0, ultimo_dt = 0;
  std::chrono::steady_clock::time_point ultimo{};
};
Estado g;
}  // namespace

// n: the 4 lanes of v49 (ceil(rate*dt)). rate: lane 0 of v54, dt: lane 0 of v53.
extern "C" void ColaSubpasos(float* n, float rate, float dt, float* dt_v, float* dt_a,
                             float* dt_b) {
  if (g.tope < 0) {
    g.tope = LeerTope();
    g.ultimo = std::chrono::steady_clock::now();
  }
  ++g.llamadas;
  g.suma += n[0];
  if (n[0] > g.max) g.max = n[0];
  g.ultimo_rate = rate;
  g.ultimo_dt = dt;
  if (g.tope > 0) {
    bool recorte = false;
    for (int i = 0; i < 4; ++i) {
      if (n[i] > float(g.tope)) {
        const float original = n[i];
        n[i] = float(g.tope);
        recorte = true;
        // step = dt / n. Keep it <= factor_max * (dt / original) by scaling dt.
        if (g_factor_max > 0.0f && original > 0.0f) {
          const float paso = original / n[i];  // step growth caused by the cap
          if (paso > g_factor_max) {
            const float f = g_factor_max / paso;
            if (dt_v) dt_v[i] *= f;
            if (dt_a) dt_a[i] *= f;
            if (dt_b) dt_b[i] *= f;
          }
        }
      }
    }
    g.recortadas += recorte ? 1 : 0;
  }
  g.suma_tras += n[0];
  const auto ahora = std::chrono::steady_clock::now();
  if (ahora - g.ultimo >= std::chrono::seconds(10)) {
    Log("[SUBPASOS] %llu llamadas, n medio %.2f -> %.2f, max %.0f, recortadas %llu | "
                 "rate %.1f dt %.4f | tope %d\n",
                 (unsigned long long)g.llamadas, g.llamadas ? g.suma / g.llamadas : 0.0,
                 g.llamadas ? g.suma_tras / g.llamadas : 0.0, g.max,
                 (unsigned long long)g.recortadas, g.ultimo_rate, g.ultimo_dt, g.tope);
    g.llamadas = g.recortadas = 0;
    g.suma = g.suma_tras = 0;
    g.max = 0;
    g.ultimo = ahora;
  }
}
