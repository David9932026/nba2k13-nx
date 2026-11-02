# 发帖文案（英文）

用于 GBAtemp / Reddit / Discord。标题按论坛习惯写，正文可以直接贴。

---

## 标题备选

- `[WIP] NBA 2K13 (Xbox 360) native Switch port — playable at ~30 FPS, looking for someone to take it over`
- `NBA 2K13 on Switch, recompiled — it plays, but I need a maintainer to finish it`

---

## 正文

**NBA 2K13 — Xbox 360 → Nintendo Switch, native port (not an emulator)**

I've been chipping at this for a while and it now runs properly: static recompilation of `default.xex` with ReXGlue,
plus a native Vulkan renderer on NVK, ported from the renderer in NFSMW-NX. Full games, local 2-player with split
Joy-Con, roughly 30 FPS in handheld.

**It is not finished, and I'm putting it up for adoption.** The remaining bugs are renderer bugs, not "porting" bugs,
and they need more time than I have. Everything I know is written down, so whoever picks it up doesn't start from zero.

### What works

- Boots, menus, options, practice, **full games start and finish**
- **~30 FPS handheld**, mostly stable
- Pre-game movies, replays, close-ups
- HUD, scoreboard, the 2K13 watermark
- Audio (XMA decoded on the console)
- **Local 2-player with split Joy-Con**
- Roughly 900 draws per frame handled by the native renderer at 1.5–1.8 µs per draw

### What's broken

| Problem | State of the investigation |
|---|---|
| **Court floor turns into black patches in some arenas** | Reproduced on PC too, so it's the renderer. Already ruled out: sub-resolve sampling, resolve cropping, mipmaps, the depth-reading lighting pass, shadow-map scale. The hardwood disappears while the painted key stays, and court lines stop dead at the black edge — so it's the floor's own draw. Next step: bisect with the PS-omit switch + a pixel statistic. |
| **Box-score headshots are fragmented** | Options-menu variant is fixed. The stats-page one samples a texture that sits inside someone else's resolve in a compressed format a resolve can never produce, so the renderer reads CPU-written bytes as pixels. Needs a proper CPU-side decode of that block. |
| **Pre-game music video shows two overlapping images** | One cause found and fixed (a fallback was presenting a scene intermediate instead of the swap buffer); the log confirms the fix fires, yet the double image remains → there's a second path. The residual seam looks like a 640×360 buffer blown up into one quadrant. |
| **Some menu text clipped** (`THUNDER` → `UNDER`) | Almost certainly the crop applied to textures whose declared size is smaller than their resolve. Needs the C18 log read on the font atlas. |
| **Menu audio stutters slightly** | Priorities raised; needs measurement, not guessing. |
| **Match drops to ~20 FPS in places** | CPU 100% / GPU 99.7% at the same time; needs a proper profile section. |

60 FPS is **not** on the table — that's measured, not assumed. Emulating the Xenos GPU costs ~80 µs of CPU per draw,
which caps this game at ~12 FPS no matter how the knobs are turned.

### What the next person gets

- **49 documented patches.** Each one has its symptom, root cause, evidence and status. Including the **five that were
  wrong and got rolled back** — with the reason — so you don't repeat them.
- **A test loop that actually works**: scripted inputs drive the game to the same screens, the renderer dumps any
  render target to PNG, and analysis scripts turn those into numbers. No "looks fine to me".
- **An in-game debug panel** (L3+R3+Right) that toggles every patch at runtime — A/B a fix without rebuilding.
- **One big trap, documented**: I once "optimised" the physical memory allocator to save 16 MB, which corrupted the
  game's heap and froze the pre-game video every single time. The ledger explains how it was found (comparing the log
  of a working build against a broken one, one line of `[PHYSPAD]` apart).

Repo: `<link>`

If you want it: open an issue or fork it. I'll hand over the repo or review PRs, whichever you prefer.

### The technical bit, briefly

- **ReXGlue** translates the game's PowerPC to C++, and gives it an Xbox 360 around it (files, memory, threads, audio).
- **No Xenos emulation.** The renderer reads the game's PM4 command ring and draws the same frame with Vulkan. Render
  targets are ordinary images, a resolve is a copy, and where the game clears next frame the two images are swapped
  instead.
- **The game uses the 2008 shader container** (`0x102A1100`), which the upstream ports don't handle: different header
  size, different microcode offsets, and vertex-shader fetch constants that D3D has already rewritten — matching them
  needed a position rule instead of an exact hash. 7,380 shaders in the library.
- **Most of the remaining bugs share one theme**: the game reuses guest memory as a render target, then as a texture,
  then as another render target, and every identity change is a chance to sample the wrong bytes.

### Credits

ReXGlue (Tom Clay, on Xenia's work), NFSMW-NX (StevensND) for the native renderer this is built on, sf4-nx (jvankooo)
for the documentation standard, XenosRecomp (hedge-dev), mesa-switch (danfromtico), devkitPro/libnx.

No game files are included or will ever be. You need your own disc.
