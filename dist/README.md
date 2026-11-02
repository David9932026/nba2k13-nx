# `dist/` — ready-to-use pieces

Two kinds of file live here: the **launcher NSP** and the **SD-card config files**. Everything that contains
recompiled game code is *not* here — see the bottom of this page for why and what to do instead.

## `012a13c0de5f1000.nsp` — launcher (329,944 bytes)

A homebrew forwarder, built with hacbrewpack. It installs to the Switch home menu and boots
`sdmc:/switch/nba2k13/nba2k13.nro`. It contains no game code of any kind — it is a title that launches another title.

- Title ID: `012A13C0DE5F1000` (placeholder range, does not collide with retail titles)
- Install with DBI / Awoo / Tinfoil, then launch from the home menu
- If you rename or move the `.nro`, repack the NSP — the path is baked in

## `sdcard/` — config files

Copy this folder's contents to `sdmc:/switch/nba2k13/` next to `nba2k13.nro`.

| File | What it does |
|---|---|
| `nba2k13.toml` | **The real config.** Renderer selection, and every on/off patch from the ledger. The in-game panel (`L3+R3+D-pad Right`) writes here when you press *Save to config*. |
| `subpasos.txt` | Guest-thread sub-step count. `3 1.0` is the value that keeps the jersey animation correct without starving the CPU. |
| `nativo.txt` | `1` = use the native renderer. |
| `draw_skip.txt`, `rt_path.txt`, `vp_div.txt`, `video_mode.txt` | Debug overrides from the early black-screen hunt. `0` / default everywhere; leave them alone unless a doc tells you otherwise. |

Two settings in `nba2k13.toml` worth knowing about before you touch anything:

- `rex_fisico_sin_relleno_64mb = false` — **do not set this to `true`**. It reclaims 16 MB of alignment padding and
  the game then writes past its block; the pre-game video freezes at shader load every time.
- `nba2k13_nativo_perro_congelado = false` — the ring-stall watchdog. Useful to diagnose a hang, harmful as a
  permanent setting: it can throw away a legitimate half packet.

## Not included: `nba2k13.nro` and `NBA2K13_shaders.nfsp`

Both are derivative works — the `.nro` embeds 59,585 recompiled functions of NBA 2K13, the `.nfsp` embeds the game's
7,380 translated shaders. Neither can be redistributed here.

Sizes, for reference:

| File | Size | Note |
|---|---|---|
| `nba2k13.nro` | 83,892,421 B | fits under GitHub's 100 MB per-file limit, but is recompiled game code |
| `NBA2K13_shaders.nfsp` | 259,964,744 B | **exceeds the 100 MB per-file limit** — repository upload is impossible |

Both are produced from your own copy of the game by following [`docs/06-构建指南.md`](../docs/06-构建指南.md):

1. Recompile `default.xex` → sources (the code generator walks all 59,585 functions)
2. Translate the 7,380 shaders and pack them into `NBA2K13_shaders.nfsp`
3. Build the Switch target with `switch-build/build-sw.sh` → `nba2k13.nro`

Expect the shader packing step to be the long one: it runs DXC over the whole library.
