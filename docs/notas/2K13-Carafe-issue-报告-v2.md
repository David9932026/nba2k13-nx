# Carafe issue 草稿 v2：32 位游戏要一块 512 MB 连续内存，几乎总是要不到

> 用途：提交到 https://github.com/carafe-nx/carafe/issues（用你自己的 GitHub 账号）
> 语言：仓库是英文，正文用英文，标题与正文都准备好了，直接复制粘贴即可。
> 证据来自 `switch/carafe/<session>/logs/` 下两个游戏、共 13 次运行的日志。

---

## Title

32-bit games that reserve one 512 MB contiguous block almost always fail with 0xc0000017 — placement-dependent (NBA 2K13: 0xC0000005 at exe+0x928370, NBA 2K11: same reserve, then 0xc000001d)

## Where does it happen?

When the game starts or runs on the Switch

## What happened

Two 32-bit Direct3D 9 games from the same engine family both ask for **exactly one
512 MB + 64 KB block** right after startup, and on most boots the runtime cannot give
it to them.

**NBA 2K13** — loading screen, then the error screen at `00:05`, `0xC0000005 access
violation` at `nba2k13.exe + 0x928370`. The game reserves, the reservation is refused,
and it stores to NULL without checking.

**NBA 2K11** — same thing over 6 boots, but one boot got a big enough hole and got
further (see below), which is the most useful part of this report.

Both games request the identical size, `size=0x20010000` (512 MB + 64 KB), even though
they are three years apart. They share the same engine and the same startup allocator,
so I read this as the engine's fixed startup pool, not as something the runtime asks
for.

## The failure is pure placement luck (13 runs, same settings)

The request never changes. What changes between boots is the largest contiguous free
range, and that decides everything:

| run | `early guest reservations` | largest free range | 512 MB reserve |
|---|---|---|---|
| 2K13 #1 | 1323 MB | 432 MB | **fails** 0xc0000017 |
| 2K13 #2 | 1326 MB | 550 MB | **fails** 0xc0000017 |
| 2K13 #3 | 1323 MB | 400 MB | **fails** 0xc0000017 |
| 2K13 #4 | 1324 MB | 528 MB | **fails** 0xc0000017 |
| 2K13 #5 | 1325 MB | 464 MB | **fails** 0xc0000017 |
| 2K13 #6 | 1323 MB | 383 MB | **fails** 0xc0000017 |
| 2K11 #1–#5 | 1323–1403 MB | 342/532/408/383/447 MB | **fails** 0xc0000017 |
| **2K13 (earlier build)** | **1405 MB** | **627 MB** | **succeeds** → boots, loads menus, reaches a game |
| **2K11 #6** | 1325 MB | **603 MB** | **succeeds** → then dies later |

So whenever a run happens to leave a ≥ 512 MB hole below 4 GB, the reserve succeeds
and the game starts. When it does not, the game dies in the first 5–10 seconds.

Typical failing session:

```
[VA] early guest reservations: 1323 MB, largest 383 MB; protected from native mappings
[VA] out of address space: 524352 KB (type 0x2000) at 0x0 below 0xfffeffff
[VA] 97 views below 4 GB: anonymous 46 MB (24 MB committed), images 58 MB, file mappings 0 MB, system 2048 MB
[VA] view 0x54e00000 2097152 KB, 0 KB committed, protect 0x200
[VA] largest free ranges: 363 MB at 0xcda00000 259 MB at 0xe45d2000 223 MB at 0x3fffc000
     199 MB at 0x3830000 129 MB at 0x1003f000 87 MB at 0x4f6ae000
[VAFAIL] tid=0004 base=0x0 size=0x20010000 type=0x2000 prot=0x4 zero_bits=0xffffffff status=0xc0000017 count=1
[CARAFE] the game failed (kind 0, code 0xc0000005, nba2k13.exe + 0x928370)
```

The successful 2K11 boot went past the reserve and then failed for an unrelated
reason, so the memory problem is a separate, earlier blocker:

```
[VA] early guest reservations: 1325 MB, largest 603 MB
[CARAFE] the game failed (kind 0, code 0xc000001d, nba2k11.exe + 0x36f8b)
```

## What I already ruled out

* **Not the CPU backend.** FEX (Reliable preset, MTrack and Full) and Box64 both fail
  at the same `exe+0x928370`, byte for byte.
* **Not FEX code-cache pressure.** Translation block size 1000 → 250 and
  `multiblock` on → off made no difference to the free ranges.
* **Not the D3D9 memory knobs.** d3d9 `maxAvailableMemory` 256/512/1024 MiB,
  `textureMemory` 32/64/128 MiB, DXVK `maxMemoryBudget` 768/1024/1536 MiB,
  compiler threads 2/default — identical `0x20010000` request and identical failure.
  D3D is never even reached in the failing runs (no `DXVK: v3.1` line at all).
* **Not the window compositor.** `系统 › 窗口输出` = 帧缓冲 (instead of 自动/合成器)
  changed nothing.
* **Not the D3D backend.** Direct3D = WineD3D（compatibility mode）instead of DXVK also
  fails at the same `nba2k13.exe + 0x928370` after 5 s.
* **Not the games being heavy.** On Windows the 2K13 exe reserves only 1.38 GB of VM
  and 69 threads; it needs one 512 MB block and nothing exotic.

My reading: ~1.3 GB of early guest reservations plus a fixed 2 GB arena view in the
middle of the low 4 GB (`view 0x54e00000 2097152 KB`, 0 KB committed) fragment the
guest address space into ≤ 640 MB chunks, so a single 512 MB `MEM_RESERVE` with
`base=0x0` ("anywhere") is usually unsatisfiable even though roughly 1.9 GB is free
in total.

## What I would like

1. Place the 2 GB guest arena at the **top** of the 32-bit address space (just below
   the native/DLL area) instead of the middle, so the low ~2 GB stays one contiguous
   free block. That alone should make both games start.
2. Or serve large `MEM_RESERVE`-only allocations from a region that is guaranteed to
   have room, or retry the placement when a big `base=0x0` reserve fails instead of
   returning 0xc0000017 on the first attempt.
3. Or expose the guest arena size / placement as a per-game option.

Happy to test builds and send full logs (`carafe-loader.log`, `logs\<game>.log`,
`autorun_runtime.log`, `failures.txt`) for both games.

## Steps to reproduce

1. NBA 2K13: game folder with `nba2k13.exe` (32-bit, 30.1 MB, D3D9), ~7.1 GB.
   NBA 2K11: game folder with `nba2k11.exe` (32-bit, 111.8 MB, D3D9), ~6.3 GB.
2. Settings: Direct3D = DXVK official 3.1.1 (also tried WineD3D), frame limit 30,
   CPU = FEX Reliable (also Box64), sync = Horizon, fourth core = on, d3d9
   `maxAvailableMemory` 256 MiB.
3. Build, install with DBI, start from HOME. 2K13: error at 00:05,
   `0xC0000005 nba2k13.exe + 0x928370`. 2K11: error within ~10 s; on roughly 1 boot
   in 6 it gets past the loader and dies later at `nba2k11.exe + 0x36f8b`.

## Carafe version

0.4.0

## Windows

x64, Windows 10 22H2 (19045)

## Switch firmware, Atmosphère and DBI versions

Firmware 22.1.0, DBI 898.

<!-- Atmosphère 版本如果方便就在相册里查一下补上，不补也能提交 -->

## Games and versions

* NBA 2K13 (2012), `nba2k13.exe`, 32-bit, ~7.1 GB folder
* NBA 2K11 (2010), `nba2k11.exe`, 32-bit, ~6.3 GB folder

## Logs

<!-- 用 Carafe 库里的「获取日志」按钮导出 zip 附上 -->

## Before you send

- [x] I searched the existing issues and did not find this bug.
- [x] This report contains no firmware, games or links to them.
