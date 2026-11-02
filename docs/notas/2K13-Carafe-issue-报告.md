# Carafe issue 草稿：NBA 2K13 32 位游戏 512 MB 连续分配失败

> 用途：提交到 https://github.com/carafe-nx/carafe/issues
> 语言：仓库是英文/俄文，下面正文用英文。
> 证据全部来自 `F:\switch\carafe\053c11a8112cc000\` 下的日志。

---

## 标题

NBA 2K13 (32-bit, D3D9): 0xC0000005 at exe+0x928370 after 5 s — a 512 MB contiguous reservation fails with 0xc0000017 (largest free range 432 MB)

## Where does it happen?

When the game starts or runs on the Switch

## What happened

NBA 2K13 (32-bit, Direct3D 9) shows the loading screen, then the error screen at
00:05 with `0xC0000005 access violation`, module `nba2k13.exe + 0x928370`.

The crash is a NULL write: the game reserves a 512 MB + 64 KB block, the runtime
refuses it, and the game immediately stores to address 0 without checking:

```
[THREAD] create failed rc=0x10801 threads=96/96 tls_retries=0
[TLS] 89 placeholder threads (the next refused: rc=0x10801), 12 kept to hold a thread-local page each
[VA] early guest reservations: 1323 MB, largest 400 MB; protected from native mappings
[VA] out of address space: 524352 KB (type 0x2000) at 0x0 below 0xfffeffff
[VA] 77 views below 4 GB: anonymous 25 MB (14 MB committed), images 54 MB, file mappings 0 MB, system 2048 MB
[VA] view 0x51600000 2097152 KB, 0 KB committed, protect 0x200
[VA] largest free ranges: 432 MB at 0xca200000 372 MB at 0xe6f82000 196 MB at 0x3ba0000
     177 MB at 0x1003f000 120 MB at 0x49d52000 81 MB at 0x25f3c000
[VAFAIL] tid=0004 base=0x0 size=0x20010000 type=0x2000 prot=0x4 zero_bits=0xffffffff status=0xc0000017 count=1
[EXC] desc=0x00000101 esr=0x92000046 pc=0x2d253eb4 far=0x0 kind=write ...
[BOX64 FAULT] x86=00d28370 block=00d28340+11d eax=00000000 ebx=20000000
[CARAFE] the game failed (kind 0, code 0xc0000005, nba2k13.exe + 0x928370)
```

Same failure with FEX (Reliable preset) and with Box64, byte for byte at the same
`exe+0x928370`, so it is not an emulator-precision problem:

* FEX:  `early guest reservations: 1326 MB, largest 550 MB`, free ranges up to 619 MB — still 0xc0000017
* Box64: `early guest reservations: 1323 MB, largest 400 MB`, free ranges up to 432 MB — 0xc0000017

Things I checked:

* **The game is not heavy.** On Windows x64 the same exe (Large Address Aware, fixed
  base 0x400000) reserves only **1.38 GB** of virtual memory and 69 threads in the
  first 20 seconds. It just needs one 512 MB + 64 KB `MEM_RESERVE`/`PAGE_READWRITE`
  block. 512 MB + 64 KB looks like a `HeapCreate`-style initial reserve.
* **The 2 GB view is not DXVK.** Graphics never initialise in this run — there is no
  `DXVK: v3.1…` line at all — yet `view 0x51600000 2097152 KB` is already there. The
  same 2 GB view appears in every session (SSFIV which runs fine, 2K9), and
  `[INIT] processors=3 memory=2048 MB` matches it exactly, so I read it as the
  runtime's 2 GB guest arena.
* **Changing the presets does not help.** FEX 稳定/平衡/自定义 (self-modifying-code
  check MTrack and Full, translation block size, L2/L1, x87) and Box64 all fail at
  the same place. DXVK memory knobs cannot matter here because D3D is never reached.

My reading of the layout: ~1.3 GB of early guest reservations + a 2 GB arena at
0x43000000/0x51600000 leave the low 4 GB fragmented into ≤432 MB chunks, so a
512 MB contiguous reservation cannot be satisfied even though ~1.9 GB is free in
total.

## What I would like

1. Would it be possible to place the 2 GB arena at the **top** of the guest address
   space (just below the DLL/native area) instead of the middle, so that the low
   ~2 GB stays one contiguous free block? That alone should make this game start.
2. Or serve large `MEM_RESERVE`-only allocations from the host VA region, as
   suggested in #79, or from anywhere in the 4 GB the guest accepts (the game passes
   `base=0x0`, i.e. "anywhere").
3. Or make the guest arena size configurable per game, so a 32-bit game that needs a
   big contiguous block can trade RAM for address space.

Happy to test builds and send full logs (`carafe-loader.log`, `logs\nba2k13.log`,
`autorun_runtime.log`, `failures.txt` = 2).

## Steps to reproduce

1. Pick the NBA 2K13 game folder, executable `nba2k13.exe` (32-bit, 30.1 MB, D3D9).
2. Settings: Direct3D = DXVK (official 3.1.1), frame limit 30, CPU = FEX with the
   Reliable preset (also reproduced with Box64 defaults), sync = Horizon,
   fourth core for graphics = on.
3. Build, install with DBI, start from HOME. Loading screen, then the error screen
   at 00:05 with 0xC0000005 `nba2k13.exe + 0x928370`.

## Carafe version

0.4.0

## Windows

x64, Windows 10 22H2 (19045)

## Switch firmware, Atmosphère and DBI versions

<!-- 需要你补：系统设置 → 主机 → 系统更新里看固件版本；DBI 界面顶部有版本号；Atmosphère 版本在相册里查 -->

## Game and its version

NBA 2K13 (2012), `nba2k13.exe` 1.1, 32-bit, ~7.1 GB game folder

## Logs

<!-- 用 Carafe 库里的「获取日志」按钮导出 zip 附上 -->

## Before you send

- [x] I searched the existing issues and did not find this bug.
- [x] This report contains no firmware, games or links to them.
