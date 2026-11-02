<div align="center">

# NBA 2K13 for Nintendo Switch

**An unofficial native port of the Xbox 360 game, recompiled for the Switch with a Vulkan renderer.**
**Playable — but not finished. Looking for someone to take it over.**

[![Platform](https://img.shields.io/badge/Switch-homebrew-e60012?style=for-the-badge&logo=nintendoswitch&logoColor=white)](#install)
[![Status](https://img.shields.io/badge/Status-needs_a_maintainer-ff7a1a?style=for-the-badge)](#-looking-for-a-maintainer)
[![Renderer](https://img.shields.io/badge/Renderer-native_Vulkan_(NVK)-1f6feb?style=for-the-badge)](#how-it-works)
[![License](https://img.shields.io/badge/License-GPL--3.0-555?style=for-the-badge)](LICENSE)

**[Looking for a maintainer](#-looking-for-a-maintainer)** · **[Status](#status)** · **[Install](#install)** ·
**[Settings](#settings)** · **[How it works](#how-it-works)** · **[Docs](#documentation)** · **[Build](#building)** ·
**[Credits](#credits)**

</div>

> [!IMPORTANT]
> **No game files are included.** You need your own copy of *NBA 2K13* for Xbox 360 (Title ID `545408A2`,
> `default.xex` of 8,122,368 bytes). This repository contains no assets, no recompiled code and no shader library —
> they are all derived from the game and you have to generate them from your own disc.

---

## 👋 Looking for a maintainer

**This port runs. It boots, it reaches the menus, it plays full games at roughly 30 FPS in handheld mode.
It is not finished, and I am handing it off.**

I got it as far as I could on my own, and the remaining problems are the kind that need somebody with more time
(or better eyes on the renderer) than I have. If you know your way around PM4 command buffers, EDRAM tile resolves
or Vulkan render targets, this is a project with a very short runway to "genuinely good".

### What is already done

| | |
|---|---|
| **Static recompilation** | 59,585 functions translated from `default.xex`, plus the holes the generator missed. |
| **Native renderer** | The Xenos path is bypassed: the game's command ring is read and the same frame is drawn with Vulkan on NVK. |
| **Shader library** | 7,380 shaders translated and packed. This needed support for the game's own 2008-era shader container (`0x102A1100`), which the upstream ports do not have. |
| **It is playable** | Menus, options, practice, full games, pre-game movies, replays, HUD, scoreboard, audio, local 2-player with split Joy-Con. |
| **49 patches, all documented** | Every one has its symptom, root cause and evidence written down — including the five I got wrong and rolled back. → [docs/03](docs/03-修复账本.md) |

### What is left (in the order I would attack it)

| # | Problem | Where I got to |
|---|---|---|
| 1 | **Court floor renders as black holes in some arenas** | Reproduced on PC too, so it is the renderer, not the console. Ruled out: sub-resolve sampling, resolve cropping, mipmaps, the depth-reading lighting pass, shadow-map scale. The hardwood is missing while the painted key stays, and court lines stop dead at the black edge — so it is the floor's own draw, not something drawn on top. Next step: bisect which draw it is with the PS-omit switch and a pixel statistic, not with your eyes. |
| 2 | **Box-score headshots are fragmented** | The options-menu variant is fixed. The stats page one is not. The texture falls inside somebody else's resolve with a format that a resolve can never produce (DXT/DXN family), so the renderer reads CPU-written bytes as pixels. Next step: log the real format and address, then decode that block on the CPU. |
| 3 | **Pre-game music video still shows two overlapping images** | Fixed one path (a fallback was presenting a scene intermediate instead of the swap buffer); the log shows it firing hundreds of times, and the double image is still there. So there is a *second* path. The residual seam looks like a half-resolution buffer (640×360) blown up into one quadrant. |
| 4 | **Some menu text is clipped** (`THUNDER` → `UNDER`) | Almost certainly the crop applied to textures whose declared size is smaller than their resolve. Needs the `C18` log read on the font atlas. |
| 5 | **Menu audio stutters slightly** and **the match drops to ~20 FPS in places** | Priorities were raised; the remaining work is measuring, not guessing. |

### What makes it easy to pick up

- **A device test loop that works.** Fixed-input scripts drive the game to the same screens; the renderer can dump any
  render target to PNG; the analysis scripts decode them and produce numbers. → [docs/07](docs/07-测试与取证方法.md)
- **A debug panel in-game** (L3+R3+Right on Switch) that toggles every patch at runtime, so you can A/B a fix
  without rebuilding.
- **Honest history of dead ends.** Five patches were rolled back after being proven wrong, and they are still in the
  ledger with the reason. That will save you days. → [docs/03 §F](docs/03-修复账本.md)
- **The one big trap is documented**: an apparent "new build made it worse" that turned out to be my own memory
  optimisation. Read §D of the ledger before touching the physical memory allocator.

If you want to take it over: open an issue, or just fork it. I will hand over the repo or review PRs, whichever you
prefer.

---

## Status

| | |
|---|---|
| 🎮 **Playable** | Full games start and finish. Handheld ~30 FPS most of the time. |
| 🏀 **Local 2-player** | Split Joy-Con works. |
| 🎬 **Movies and replays** | Play, with a cosmetic double-image issue still present. |
| 🖥️ **Menus and HUD** | Correct, scoreboard and watermark included. |
| 🎨 **Faces** | Options menu fixed. Box-score headshots still broken. |
| 🏟️ **Court floor** | Broken in some arenas (black patches). |
| 🔊 **Audio** | Works; slight stutter in menus. |
| ⚡ **Frame rate** | ~30 handheld, dips to ~20 in some match scenes. 60 FPS is not reachable on this hardware — that was measured, not assumed. |

---

## Install

There is no browser installer for this one (unlike the ports it is based on). Manual steps:

1. Generate the pieces from your own disc — the recompiled code and the shader library
   ([docs/05](docs/05-资源清单.md), [docs/06](docs/06-构建指南.md)). The shader library is ~260 MB.
2. Build the NRO, or take a release build.
3. Put this on the SD card:

   ```
   sdmc:/switch/nba2k13/
   ├── nba2k13.nro
   ├── nba2k13.toml            settings
   ├── NBA2K13_shaders.nfsp    the game's shaders, made from your disc
   ├── subpasos.txt
   └── game_root/              the files of your disc
   ```

4. Launch it in **title takeover** mode: hold **R** while starting any installed game, then pick `nba2k13` in the
   Homebrew Menu. Applet (album) mode does not give it enough memory.

---

## Settings

`nba2k13.toml` next to the NRO, read at startup. **String values need quotes**, numbers do not.

| Setting | Default | What it does |
|---|---|---|
| `NBA2K13_renderizador` | `"nativo"` | Native renderer. Anything else falls back to the emulated Xenos path (slow, useful as a baseline). |
| `nba2k13_nativo_sombras_escala` | `70` | Shadow maps are drawn at 70% and upscaled. `100` = as on the 360. |
| `nba2k13_nativo_tope_resueltas` | `96` | Cap on cached resolved textures (memory). |
| `nba2k13_nativo_presenta_cinematica` | `true` | Present the movie double-buffer. Required for pre-game videos and replays. |
| `nba2k13_nativo_mipmaps` | `true` | Generate mip chains for resolved textures. |
| `rex_fisico_sin_relleno_64mb` | `false` | **Leave it false.** Turning it on frees 16 MB and corrupts the game's heap. |
| `nba2k13_nativo_perro_congelado` | `false` | Ring-stall watchdog. The self-heal drops legitimate half packets; keep it off. |
| `input_xbox_layout` | `true` | Face buttons by position (Xbox style). `false` = by letter (Nintendo style). |
| `captura_cada_s` / `volcar_*_ancho` | `0` | Screenshot and probe dumps. **Keep at 0** — each one synchronises the whole pipeline. |

### Debug panel

Press **L3 + R3 + D-pad Right** in game (PC: **F4**). Up = performance overlay, Down = log window, Left = achievements.
Every patch in this repository can be toggled live from the **Nativo** category.

> [!CAUTION]
> **Do not press "Save to config".** It rewrites `nba2k13.toml` immediately with the current runtime values.

The combination is not `L+R+Right` because `L+R+D-pad` is a play-call button in this game. It reads the hardware
directly, so it does not depend on the face-button layout.

---

## How it works

```
 default.xex (PowerPC) ──ReXGlue──► C++ ──devkitA64──► nba2k13.nro
                                                          │
 game's GPU command ring (PM4) ──native renderer──► Vulkan (NVK) ──► Switch GPU
 shader containers on your disc ──XenosRecomp + DXC──► SPIR-V ──► NBA2K13_shaders.nfsp
```

- **Static recompilation.** [ReXGlue](https://github.com/rexglue/rexglue-sdk) translates the game's PowerPC code into
  C++ ahead of time and gives it an Xbox 360 around it: files, memory, threads, audio, controllers.
- **Native renderer.** Emulating the Xenos GPU costs ~80 µs of CPU per draw; at ~900 draws per frame that is a
  12 FPS ceiling, and the measurements confirm it. So the renderer from
  [nfsmw-nx](https://github.com/StevensND/nfsmw-nx) reads the command ring and draws the same frame with Vulkan —
  1.5–1.8 µs per draw. 2K13 adds its own handling of EDRAM resolves, texture identity/aliasing and the movie buffer.
- **No EDRAM emulation.** Render targets become ordinary Vulkan images, a resolve becomes a copy into a texture, and
  where the game would clear the target next time the two images are simply swapped.
- **Its own shader format.** The game uses the 2008 shader container (`0x102A1100`), not the 2005 one the upstream
  ports handle: different header size, different microcode offsets, and vertex-shader fetch constants that D3D has
  already rewritten. Matching them needed a position-based rule rather than an exact hash.
- **49 targeted patches on top**, each tied to a specific visual symptom, most of them about one theme: the game
  reuses guest memory as a render target, then as a texture, then as a different render target, and every identity
  change is a chance to sample the wrong bytes.

The full story — including the routes that were tried and abandoned, and why 60 FPS is not on the table — is in
[docs/01-研究总览.md](docs/01-研究总览.md) and [docs/02-技术架构.md](docs/02-技术架构.md).

---

## Documentation

For whoever takes this over, and for anyone porting another Xbox 360 game. **Read
[docs/04-当前卡点.md](docs/04-当前卡点.md) first** — it is the list of what is broken, what has already been ruled
out, and how to attack each one.

| Document | What it is |
|---|---|
| [04 · Open issues](docs/04-当前卡点.md) | The 5 remaining problems, with the ruled-out list and the next step for each |
| [03 · Patch ledger](docs/03-修复账本.md) | C1–C49: symptom, root cause, fix, status, evidence. Includes the rolled-back ones |
| [02 · Architecture](docs/02-技术架构.md) | PM4 ring, native renderer, resolve/aliasing model, memory ledger, threading |
| [01 · Research overview](docs/01-研究总览.md) | Why this route, and every route that was rejected with the numbers behind it |
| [05 · Assets & dependencies](docs/05-资源清单.md) | What you must supply yourself, and what to read before starting |
| [06 · Building](docs/06-构建指南.md) | Environment, PC and Switch builds, flashing rules, every setting |
| [07 · Testing & evidence](docs/07-测试与取证方法.md) | Pixel statistics, seam detection, symbolisation, and three cases where the obvious conclusion was wrong |
| [docs/notas](docs/notas) | Raw dated notes from the work, unedited — dead ends included |

`runtime/docs/` holds the upstream nfsmw-nx documentation (native renderer, shader translation, platform notes,
performance history). That is the best primer on the whole approach.

---

## Building

devkitA64 and libnx from [devkitPro](https://devkitpro.org), MSYS2 (ucrt64) on the host, CMake + Ninja, a Vulkan
driver built from [mesa-switch](https://github.com/danfromtico/mesa-switch) for NVK, and your own copy of the game for
the code generator.

```bash
bash scripts/pc/pcb.sh            # PC build (win-vk), the fast loop
bash scripts/switch/build-sw.sh   # Switch build
```

Nothing derived from the game — its files, the generated C++, the shader library, the built NRO — is committed.
See [docs/06-构建指南.md](docs/06-构建指南.md) for the whole chain, and
[docs/05-资源清单.md](docs/05-资源清单.md) for the sizes to check your own dump against.

---

## Credits

- **2K Sports / Visual Concepts** for *NBA 2K13*. Buy the games.
- **[StevensND](https://github.com/StevensND/nfsmw-nx)** for NFSMW-NX and its native renderer — this port is a
  derivative of it and would not exist otherwise.
- **[jvankooo](https://github.com/jvankooo/sf4-nx)** for sf4-nx, whose documentation set the standard this repository
  tries to follow.
- **[Tom Clay and ReXGlue](https://github.com/rexglue/rexglue-sdk)** for the static recompilation framework, built on
  the work of the **[Xenia](https://github.com/xenia-project/xenia)** team.
- **[hedge-dev](https://github.com/hedge-dev/XenosRecomp)** for XenosRecomp.
- **[danfromtico](https://github.com/danfromtico/mesa-switch)** for mesa-switch (NVK on Horizon).
- **[devkitPro](https://devkitpro.org)** and **[switchbrew](https://github.com/switchbrew/libnx)** for the toolchain
  and libnx.

See [NOTICE.md](NOTICE.md) for licences.

## Legal

Non-commercial fan project, not affiliated with or endorsed by 2K, Take-Two, Microsoft or Nintendo. *NBA 2K13* and
all related artwork are copyrights of their owners. No game code or assets are distributed here: the port only runs
with files from a disc you own. Running homebrew requires custom firmware, which violates Nintendo's ToS and can get
a console banned — your call.

Source is GPL-3.0, inherited from NFSMW-NX. The SDK changes follow the SDK's licence, the shader translator and Mesa
changes their own (see [NOTICE.md](NOTICE.md)).

---

## 中文说明

Xbox 360 版《NBA 2K13》的 Switch 原生移植：静态重编译 + 原生 Vulkan 渲染器。**能玩，但没做完。**

- **已经能玩**：菜单、选项、训练、整场比赛、赛前 MV、回放、HUD、记分牌、音频、拆 Joy-Con 本地双人；
  掌机模式大部分时间 30 帧。
- **还差的**：部分场馆地板发黑、技术统计页头像碎片、赛前 MV 仍有重影、个别菜单文字被裁、菜单音频轻微卡顿、
  比赛有段落掉到 20 帧。详见 [docs/04-当前卡点.md](docs/04-当前卡点.md)。
- **我在找接手的人**：49 个补丁的来龙去脉、每个未解项的取证方法、被证伪后回退的路线都已经写在
  [docs/](docs/README.md) 里，接手不用从零开始。想接手就开 issue 或者直接 fork。
- **不含任何游戏文件**，你需要自己有一份正版 360 版游戏（`545408A2`，`default.xex` 8,122,368 字节）。
