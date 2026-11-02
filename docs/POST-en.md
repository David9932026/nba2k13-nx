# Post draft (English)

For GBAtemp / Reddit / Discord. Replace the `[...]` placeholders before posting.

---

## Title options

- `[WIP] NBA 2K13 (Xbox 360) native Switch port — plays full games at ~30 FPS, looking for someone to take over the renderer work`
- `NBA 2K13 recompiled for Switch: the port is done, the renderer needs an owner`

---

## Body

Hi all.

I've built a **native Nintendo Switch port of *NBA 2K13* (Xbox 360)** — not an emulator: the game's PowerPC code is
statically recompiled to C++ with ReXGlue, and instead of emulating the Xenos GPU, the renderer reads the game's PM4
command ring and draws the same frame with Vulkan on NVK. The renderer itself is a port of the one in NFSMW-NX.

**The porting work is done. It boots, it plays full games, roughly 30 FPS in handheld.** What's left are a handful of
specific rendering bugs I can't get past on my own, so I'm looking for someone to take over — the whole project or just
one of the items below.

---

### Where it stands

**Done and working:**

- Platform layer: native Switch build (devkitAArch64 + libnx), Vulkan through NVK, its own shader library
- **59,585 functions** recompiled from `default.xex`, plus the holes the code generator missed
- **7,380 shaders** translated and packed — this game uses the 2008 shader container (`0x102A1100`), which the existing
  ports don't handle: different header size, different microcode offsets, and vertex fetch constants D3D has already
  rewritten. Matching them needed a position rule instead of an exact hash
- Assets unpacked (16.02 GiB), shader containers scanned and paired
- Input: mapped, Sony layout by default, **local 2-player with split Joy-Con**
- Menus, options, practice, **full games**, pre-game movies, replays, HUD, scoreboard, watermark — all correct
- Audio: XMA decoded on the console
- Framerate: **~30 FPS handheld**, most of the time
- Debug: in-game panel that toggles every patch at runtime, plus a device test loop (scripted inputs → PNG dumps →
  pixel statistics)

**What's left — this is what needs a new owner:**

1. **Court floor renders as black holes in some arenas.** Reproduced on PC as well, so it is the renderer, not the
   console. Ruled out: sub-resolve sampling, resolve cropping, mipmaps, the depth-reading lighting pass, shadow-map
   scale. The hardwood vanishes while the painted key stays, and court lines stop dead at the black edge — so it's the
   floor's own draw. Next step: bisect with the PS-omit switch plus a pixel statistic.

2. **Box-score headshots are fragmented.** The options-menu variant is fixed. On the stats page the texture sits inside
   somebody else's resolve in a compressed format a resolve can never produce (DXT/DXN family), so CPU-written bytes
   are being read as pixels. Needs a correct CPU-side decode for that block.

3. **Pre-game music video still shows two overlapping images.** One cause found and fixed (a fallback was presenting a
   scene intermediate instead of the swap buffer); the log confirms the fix fires, the double image remains — so there
   is a second path. The residual seam looks like a 640×360 buffer blown up into one quadrant.

4. **Some menu text is clipped** (`THUNDER` → `UNDER`). Almost certainly the crop applied to textures whose declared
   size is smaller than their resolve, hitting the font atlas.

5. **Memory is tight.** The guest physical heap is only 512 MB; it currently survives on an LRU cap for resolved
   targets (96) and a 16 MB alignment pad. Don't touch the pad — I tried, it corrupts the game's heap. There is room
   for real optimisation, but it needs care.

6. **The match drops to ~20 FPS in places**, CPU 100% and GPU 99.7% at the same time; needs a proper profile section
   to tell which one is the wall.

7. **Menu audio stutters slightly.** Thread priorities are already raised; the rest needs measuring.

> 60 FPS is not on the table. Emulating Xenos costs ~80 µs of CPU per draw — ~900 draws is a 12 FPS ceiling. Measured,
> not assumed. The native renderer costs 1.5–1.8 µs per draw, which is why 30 is reachable at all.

---

### What I'm looking for

Pick any one of these, you don't have to take the whole thing:

- **Renderer work** — render targets, resolves, texture identity/aliasing, Xenos texture formats, lighting and
  post-processing. **This is the important one; every remaining bug lives here.**
- **Performance** — GPU/CPU load analysis, draw merging, hot-spot hunting
- **Memory and resources** — guest heap policy, texture cache and streaming
- **Platform and input** — Switch-side compatibility, input consistency
- **Device testing** — *I can do this part for you*, you don't need the hardware

### Skills that would help

- Switch / embedded performance optimisation experience, or
- Solid grasp of Vulkan render targets, formats and resolves (**most valuable**), or
- Prior work on Xbox 360 / Xenia / recompilation projects — PM4 packets, EDRAM tiling
- Comfortable in a large C++ codebase, building on Windows + MSYS2
- Able to reach conclusions from logs and pixel data rather than from "looks fine to me"
- Real hardware for testing is a bonus, **not required**

### What I can offer

- **The full repository**: the app project plus the patched runtime SDK
- **A complete ledger of 49 patches** — symptom, root cause, fix, evidence and status for each, *including the five I
  got wrong and rolled back, with the reason*. You won't repeat my dead ends
- **Seven technical documents**: research overview (with the numbers behind every rejected route), architecture, patch
  ledger, open issues, asset manifest, build guide, testing & evidence methodology
- **Test hardware**: I have the console here and can run whatever you need, pull logs, dump targets, send back data
- Working tools: scripted inputs, render-target PNG dumps, pixel statistics, seam detection, crash symbolisation
- Arrangement: `[write what applies: unpaid / small budget for specific fixes / long-term collaboration / transfer of
  repository ownership]`. Remote is fine; part-time or milestone-based also fine.

### Contact

- GitHub: `[fill]`
- Email: `[fill]`
- Discord: `[fill]`

### Links

- Repository: `[fill]`
- Start here: `docs/README.md`, then `docs/04-当前卡点.md` (open issues, what's ruled out, next step for each)
- Patch ledger: `docs/03-修复账本.md`
- Screenshots / logs: `[worth adding a few — match gameplay, the black floor, the fragmented headshot]`

---

**On game files:** the repository contains no game assets, no recompiled code, no shader library and no binaries —
they're all derivative works. Whoever takes this on needs their own copy of the Xbox 360 disc
(`545408A2`, `default.xex` of 8,122,368 bytes) and generates the intermediates from it. That part can't be worked
around.

Thanks — happy to answer anything.
