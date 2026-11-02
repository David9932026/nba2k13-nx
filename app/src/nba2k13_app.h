// nba2k13 - ReXGlue Recompiled Project
//
// Customize your app by overriding virtual hooks from rex::ReXApp.

#pragma once

#include <cstdio>
#include <rex/cvar.h>
#include <rex/rex_app.h>

// PATCH(cola): native renderer phase 1 - see src/nba2k13_nativo.cpp. Started from OnPostSetup because
// the sink is not internally synchronised: it has to be wired up before the GPU threads exist.
#include "nba2k13_nativo.h"

// PATCH(cola): N2b - el renderizador nativo portado de nfsmw-nx. Con
// NBA2K13_renderizador = "nativo" el juego usa este sistema grafico en vez del
// plugin de emulacion Xenos (ver OnPreSetup).
#include "nativo/nba2k13_nativo_sistema.h"
#include "nativo/nba2k13_nativo_captura.h"

// PATCH(cola): defined in sdk/src/ui/vulkan/vulkan_presenter.cpp; see OnPostSetup below.
REXCVAR_DECLARE(bool, present_esperar_adquisicion_en_cpu);

#if REX_PLATFORM_SWITCH
extern "C" void RexSwitchApmPedirGpuMhz(int mhz);
extern "C" void RexSwitchApmPermitirRam1600(int permitir);
extern "C" void RexSwitchApmAplicar(void);
extern "C" int RexSwitchSysclkForzarCpu(unsigned mhz);
// PATCH(cola): CPU MHz asked from sys-clk; /switch/nba2k13/cpu_mhz.txt overrides (0 = do not touch).
inline unsigned Nba2k13CpuMhz() {
  unsigned mhz = 1785;  // Nintendo's own boost-mode CPU clock
  if (FILE* f = std::fopen("/switch/nba2k13/cpu_mhz.txt", "r")) {
    unsigned v = 0;
    if (std::fscanf(f, "%u", &v) == 1) mhz = v;
    std::fclose(f);
  }
  return mhz;
}
#endif

class Nba2k13App : public rex::ReXApp {
 public:
  using rex::ReXApp::ReXApp;

  static std::unique_ptr<rex::ui::WindowedApp> Create(
      rex::ui::WindowedAppContext& ctx) {
    return std::unique_ptr<Nba2k13App>(new Nba2k13App(ctx, "nba2k13",
        PPCImageConfig));
  }

  // PATCH(cola): N2b. Si el cvar NBA2K13_renderizador pide "nativo", el juego no
  // carga la emulacion Xenos: el anillo PM4 lo lee nuestro procesador de comandos.
  void OnPreSetup(rex::RuntimeConfig& config) override {
    // PATCH(cola): N4 build tag, so a device log tells which NRO actually ran.
    std::fprintf(stderr, "[cola] build N4p sembrar_gen, renderizador=%s\n",
                 nba2k13::nat::Activo() ? "nativo" : "xenos");
    if (nba2k13::nat::Activo()) {
      config.graphics = nba2k13::nat::CrearSistemaGrafico();
    }
  }

  // Override virtual hooks for customization:
  // void OnPostInitLogging() override {}
  // void OnPreSetup(rex::RuntimeConfig& config) override {}
  // void OnLoadXexImage(std::string& xex_image) override {}
  // void OnPostLoadXexImage() override {}
  // PATCH(cola): ask apm for the profile commercial games use (GPU 460.8 + EMC 1331.2) so no manual overclock is needed.
  void OnPostSetup() override {
#if REX_PLATFORM_SWITCH
    RexSwitchApmPedirGpuMhz(460);
    RexSwitchApmPermitirRam1600(0);
    RexSwitchApmAplicar();
    RexSwitchSysclkForzarCpu(Nba2k13CpuMhz());
    /*
     * PATCH(cola): tried and reverted - the swapchain acquire on the CPU did not help.
     *
     * The NFS MW port documents this (present_esperar_adquisicion_en_cpu) as the fix for the GPU channel
     * stalling inside the acquire semaphore, and our log has exactly that symptom - nvkmd reporting
     * "channel 2 hit native submission pressure" hundreds of times. Measured on 2026-10-30 with it on:
     * the flag took effect ("adquisicion esperada en la CPU = SI"), the pressure events did not go away
     * (939 against 870 before), frame rate was identical, and it cost 43.87 ms of CPU wait per frame
     * because it also disables the image prefetch (0 of 600 frames got the image in advance). So the
     * stall is not where the semaphore is waited for; it is the amount of work behind it. Left off.
     */
    // REXCVAR_SET(present_esperar_adquisicion_en_cpu, true);
#endif
    // Reads /switch/nba2k13/nativo.txt; inert if the file is missing or starts with '0'.
    nba2k13::nativo::Iniciar();
    // PATCH(cola): PNG captures of the presented image (NBA2K13_captura_cada_s, off by default).
    nba2k13::captura::Arrancar([this]() -> rex::ui::Presenter* {
      const auto* rt = runtime();
      const auto* grafico = rt ? rt->graphics_system() : nullptr;
      return grafico ? grafico->presenter() : nullptr;
    });
  }
  // void OnCreateDialogs(rex::ui::ImGuiDrawer* drawer) override {}
  // std::unique_ptr<rex::ui::ImGuiDialog> CreateAchievementsOverlay() override;
  // std::unique_ptr<rex::ui::AchievementNotificationDialog>
  // CreateAchievementNotificationDialog() override;
  void OnShutdown() override { nba2k13::captura::Parar(); }
  // PATCH(cola): on Switch the game files live next to the NRO.
  void OnConfigurePaths(rex::PathConfig& paths) override {
#if REX_PLATFORM_SWITCH
    if (paths.game_data_root.empty()) {
      paths.game_data_root = "/switch/nba2k13/game_root/00007000/C096DB2DDEE83F64054B";
    }
    if (paths.user_data_root.empty() || paths.user_data_root.string().find("sdmc:") == std::string::npos) {
      paths.user_data_root = "/switch/nba2k13/user";
    }
#else
    (void)paths;
#endif
  }
};
