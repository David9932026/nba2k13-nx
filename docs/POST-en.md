# Post draft (English · detailed)

For GBAtemp / Reddit / Discord. Replace the `[...]` placeholders before posting.

---

## Title options

- `[WIP] NBA 2K13 (Xbox 360) native Switch port — plays full games at ~30 FPS, needs someone to take over the renderer`
- `NBA 2K13 recompiled for Switch: the port works, the picture is 90% there, looking for a maintainer`

---

## Body

Hi all.

**A native Nintendo Switch port of *NBA 2K13* (Xbox 360) — not an emulator.**

The game's PowerPC code is statically recompiled to C++ with ReXGlue and built natively; the GPU side doesn't emulate
Xenos at all — the renderer reads the game's PM4 command ring and draws the same frame with Vulkan on NVK. The
renderer is a port of the one in NFSMW-NX.

**It plays.** Full games start and finish, ~30 FPS in handheld, local 2-player with split Joy-Con.

**It isn't finished.** What's left is all renderer work — the kind that needs frame-by-frame comparison, not
porting grunt work — and I can't push it further alone. Everything I know is written down, so whoever picks it up
doesn't start from zero.

---

## At a glance

| | |
|---|---|
| 🎮 Playable | Yes, full games |
| ⚡ Framerate | ~30 handheld, dips to ~20 in some match scenes |
| 🏀 Local 2P | Split Joy-Con, works |
| 🎬 Pre-game movie / replays | Play, but still a double-image issue |
| 🖥️ Menus / HUD / scoreboard / watermark | Correct |
| 🎨 Headshots | Options menu fixed, **box-score page still fragmented** |
| 🏟️ Court floor | **Black patches in some arenas** |
| 🔊 Audio | Works, slight menu stutter |

---

## What's already done (with the numbers)

**Platform and code**

- Native Switch build: devkitAArch64 + libnx; Vulkan through NVK (`libvulkan.a` from mesa-switch)
- `default.xex` (8,122,368 bytes, Title ID `545408A2`) recompiled into **59,585 functions / 435 files**
- Hot functions the code generator missed were scanned for and added — one missed entry point was causing a crash
  in the 2nd/3rd quarter of every game

**Shaders**

- **7,380 shaders** translated and packed (library is 259,964,744 bytes)
- This game uses the **2008 shader container** (signature `0x102A1100`), which the existing ports don't implement:
  36-byte header instead of 24, microcode at `virtualSize + physicalOffset`, VS element table at `cab+36`
- The hard part was pairing: pixel shaders hash exactly, but **no vertex shader matched** — D3D rewrites the fetch
  constants (one word goes from `0x00000688` to `0x402034C1`). What worked was a position rule: every difference falls
  inside the three words of the fetch instruction the container declares
- One hard wall along the way: past **256** shader registers the driver returns `DEVICE_LOST`, so the whole library was
  rebuilt once for that

**Graphics and system** — 44 verified fixes, each with a symptom and a judgement criterion. A few representative ones:

- Shadow edges shimmering: resolved textures weren't reporting their `1/size`, so every PCF tap landed on the same texel
- Slow memory leak: the resolve cache only grew. Now an LRU with a cap of 96
- Whole-console freezes: the 512 MB guest heap ran out → log flood + nv IPC storm → every thread stuck in
  `binderCreate+0x18`. There's now a memory ledger every 60 s
- CPU at 100% with no frames advancing: not a lack of compute, a futex spinning. Replaced with targeted wakeups
- "The previous player standing behind the current one" in headshot frames: the clear box cleared depth but not colour
- Scoreboard and watermark disappearing mid-game: the presenter was picking an intermediate image that downstream
  passes were still sampling
- In-game debug panel: **L3 + R3 + D-pad Right** toggles every patch at runtime, so a fix can be A/B'd without a
  rebuild (`L+R+D-pad` is a play-call button in this game, hence the combination)

---

## What's left — this is why I need someone

### 1. Court floor renders as black patches in some arenas 🔴 not localised

**Symptom**: in certain arenas the hardwood is a large irregular pure-black patch. **The painted key is still there**,
and court lines stop dead at the black edge. That last detail matters: nothing is drawn on top — the floor's own draw
is wrong.

**Already ruled out** (all A/B'd on PC, judged by a black-pixel statistic, not by eye):

| Turned off | Result |
|---|---|
| Sub-region sampling when a texture falls inside a resolve | unchanged |
| "Crop to the top-left when the declared size is smaller than the resolve" | unchanged |
| Mipmaps | unchanged, and **worse** (frames with large black areas 10 → 25) |
| The one lighting pass that reads the full scene depth (`n982`) | unchanged |
| Shadow-map scale (70% on Switch) | 70 vs 100, **no difference** |

**Evidence**:

- **Reproduces on PC too** (Pistons vs Warriors, Oracle Arena), so it's the renderer, not the console
- `n982` samples only `05822000` (1280×720 depth) in all 79 logged occurrences — it is **not** the floor
- Arena textures are sampled out of 1024×1024 resolves (`0F5D0000`, `0FB21000`, `10072000`, `105AD000`), including
  **DXT1 / DXT5 / DXN compressed formats** and format 59 — **a resolve can never produce those**

**How to attack it** (written so you can just follow it):

1. Bisect with `nba2k13_nativo_diag_omitir_ps` (skip a pixel shader by fingerprint), one demo run each time
2. Judge by counting frames whose black-pixel ratio is ≥15% — **not by eye, and not with a vision model**
3. Whichever skip makes the hardwood vanish entirely identifies the floor's draw
4. Then look at what it samples: base address, declared format, whether it lands inside a resolve
5. Candidate fix: **when a compressed / non-8888 fetch lands inside a resolve, hand that block to the CPU and decode
   it in its own format** instead of reading it with the resolve's format

> Note: the demo mode randomises teams and arenas, so two runs differ by 50–80% of their pixels. **Frame-to-frame
> comparison is useless** — aggregate across a whole segment.

### 2. Box-score headshots are fragmented 🔴 unsolved

**Symptom**: the headshot boxes are filled with something else — team-logo fragments, vertical stripes, grey/black
blocks, or pieces of a different player. (The options-menu variant of this is fixed and confirmed on hardware; the
stats page is a different path.)

**Already ruled out**:

| Tried | Result |
|---|---|
| Refresh the texture alias identity (stale identity hypothesis) | **0 hits** in the device log, no change |
| Detect CPU rewrites of resolve memory (fingerprint compare per frame) | fired 3 times (`0FB21000 1024×1024` etc.), **no change** |
| Raw guest-byte dump (matched as 8888, 128/256 squares) | **0 files captured** — wrong format and range |

**Evidence**:

- `C23 dentro` fires constantly: 256×256 textures land inside `0FB21000` (1024×1024) and are judged as
  "doesn't fit → read from guest memory" or "sample from the resolve"
- `C13 cuadro lleno opaco sin textura: PS F0412447847F6D27 en 1040x1040` — a full-screen opaque draw with no texture
  on the portrait target
- **The 10 pre-game lineup cards (150×300) are not the box-score headshots** — those export clean on PC, so that path
  is fine; the stats page uses another one

**Most likely explanation (hypothesis, unverified)**: the box-score headshot samples a **compressed** texture
(DXT/DXN family) that sits inside somebody else's resolve; a resolve cannot produce compressed formats, so the
renderer reads CPU-written bytes as pixels — which is exactly why the fragments look like *other* images.

**Next step**: rate-limit-log the "different format → read from guest memory" branch (format, base, offset into the
resolve, first 16 bytes); open the stats page once on hardware and let the log say the truth; then decode that block
properly on the CPU. Judgement: exported PNG non-zero pixel ratio and edge gradients.

### 3. Pre-game music video still shows two overlapping images 🟠 half fixed

**Symptom**: during the pre-game video there are two moving pictures at once, one sharp and one blurred.

**What I fixed**: the fallback path ("if the swap buffer has no pixels, present the full-frame copy") was presenting a
**scene intermediate** while the game was drawing into the real swap buffer, alternating between the two. It now checks
whether the swap received draws in that submission first. On PC, frames with a seam went from **10 to 2**.

**But the double image is still there on hardware.** The log shows the new check firing hundreds of times and the
fallback down to a single hit — so there is a **second path** producing two pictures. It is not the presenter picking
the wrong buffer.

**Clue**: the 2 remaining seam frames are during court transitions, where neither the fix nor the fallback fired. The
residual seam looks like a **half-resolution buffer (640×360) blown up into one quadrant** — i.e. wrong UVs or a wrong
crop.

**Next step**: I need a photo from hardware showing which part of the screen the blurred layer occupies (top-left
quarter / full screen / bottom half); then look at `18C3D000` and `1A353000` (both 640×360) and the 640×720 pitch
bucket for their crop windows and UV source. Judgement: seam-detection frame count back to zero.

### 4. Some menu text is clipped 🟡 clear direction

`THUNDER` shows as `UNDER`. Text comes from an atlas; a sampling rect that runs past the edge gets clipped. The suspect
is the "declared size smaller than the resolve → crop" rule hitting the font atlas. **Next step**: read the `C18 tamano`
log for a declared size that matches the font atlas, and check whether the crop rect overruns.

### 5. Memory is tight 🟡 room exists, but it's risky

The guest physical heap is **512 MB**, with 465 MB of it resident from boot. Two things keep it alive today: the LRU cap
on resolved targets (96), and a 16 MB pad that comes with the 64 MB-aligned allocations.

**Don't touch the pad.** I tried removing it to free 16 MB: the game wrote past its block, and the pre-game video froze
every single time at shader load (`PM4_IM_LOAD`). It was found by diffing the log of a working build against a broken
one — two lines of `[PHYSPAD]` and it was obvious. Real optimisation has to come from somewhere else.

### 6. The match drops to ~20 FPS in places 🟡 needs a profile section

CPU 100% and GPU 99.7% at the same time; only the fence wait times will tell which is the wall. (Historical warning:
one "frame drop" turned out to be my own probe — dumping PNGs synchronised the whole pipeline dozens of times a second;
turning it off restored 30 FPS.)

### 7. Menu audio stutters slightly 🟡 needs measurement

Mixer thread priority is already at 44; the XMA baseline is 24,037 kicks per 10 s with a 1.46 ms maximum. The rest is
measuring the kick interval distribution at the moment of the stutter.

> **60 FPS is not on the table.** Measured, not assumed: emulating Xenos costs ~80 µs of CPU per draw; ~900 draws is a
> 12 FPS ceiling. The native renderer costs 1.5–1.8 µs per draw, which is the only reason 30 is reachable. Please don't
> spend time chasing 60.

---

## Where I could use help (pick one)

| Area | What it means |
|---|---|
| **Renderer** | Render targets, resolves, texture identity/aliasing, Xenos formats, lighting and post. **4 of the 7 open items are here — the most valuable one** |
| Performance | GPU/CPU load analysis, draw merging, hot spots |
| Memory | Guest heap policy, texture cache and streaming |
| Platform / input | Switch-side compatibility, input consistency |
| Device testing | **I can cover this** — you don't need the hardware |

**Useful background**: Vulkan render targets, formats and resolves (most needed); or Xbox 360 graphics (PM4 packets,
EDRAM tiling) from Xenia/other recompilation work; or embedded/Switch performance work. Comfortable in a large C++
codebase and able to build on Windows + MSYS2.

**The one non-negotiable**: you reach conclusions from logs and pixel data. "Looks fine to me" has been wrong too many
times on this project to be trusted.

**What I can offer**:

- The full repository: the app project plus the patched runtime SDK
- **A ledger of 49 patches** — symptom, root cause, fix, judgement criterion and status for each, *including the five I
  got wrong and why* (the alias refresh that never fired, the memory saving that corrupted the heap, the ring
  self-heal that threw away a legitimate half packet…)
- **Seven documents**: research overview (with the data behind every rejected route), architecture, patch ledger, open
  issues, asset manifest, build guide, testing & evidence methodology
- **Test hardware**: the console is here; I'll run whatever you need, pull the logs, dump targets and send the data back
- Working tools: scripted inputs, render-target PNG dumps, pixel statistics, seam detection, crash symbolisation
- **Arrangement, plainly**: I've put a lot of money into this — hardware, time, and round after round of trial and
  error. It's at "playable, not finished", and I can't push it further on my own, but I also don't want all of that to
  rot in a folder. So I'm looking for **someone to take it on, not a contractor**: no full-time commitment, no
  deadline, do as much as you want. You change it, I run it on hardware and send back the logs and pixel data — **you
  don't need to buy the console for this**. If you'd rather publish and maintain it yourself, **the repository can be
  transferred to you** — repo name and credit are yours to decide.
  `[keep one line if it applies: small budget available / strictly unpaid]`

  Honestly, what I want isn't a paid outsourcing job — it's for this thing **not to die in my hands**. If you're
  interested, terms are negotiable.

**Contact**: 1325291954@qq.com · GitHub `[fill]` · Discord `[fill]`

**Links**: repository `[fill]` · start with `docs/04-当前卡点.md` (open issues, what's ruled out, next step for each)
and `docs/03-修复账本.md` (the 49 patches) · screenshots `[3 would help: normal gameplay, the black floor, the
fragmented headshot]`

---

**On game files:** the repository contains no game assets, no recompiled code, no shader library and no binaries —
they are all derivative works. Whoever takes this on needs their own copy of the Xbox 360 disc
(`545408A2`, `default.xex` of 8,122,368 bytes) and generates the intermediates from it. That part can't be worked
around.

Thanks — happy to answer anything.
