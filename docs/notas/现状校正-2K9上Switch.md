# 现状校正 · 5800H 笔记本（2026-10-28 13:10）

> 对着《5800H笔记本-操作手册.md》逐条核对这台机器的真实情况。手册里的路径表跟机器对不上，以本文件为准。

## 一、路径校对（手册表格 → 实际）

| 手册写的 | 实际 | 说明 |
| --- | --- | --- |
| `[2K9]` = `D:\nba2k9\` | ✅ 存在，但游戏本体在子目录 | 根目录是「游民碟屋 / 极速游戏管理器」的 repack 外壳 |
| `[2K9]bin\` | ❌ 不存在 | 没有 `bin\` 这一层 |
| `[2K9]bin\nba2k9.exe` | ✅ `D:\nba2k9\game\nba2k9.exe` | 47.83 MB，2009-01-09 |
| `[2K9EXE]` `nba2k9_unpacked.exe` | ❌ **机上没有** | 脱壳版不在这台机器上 |
| `[2K9]PlayGame.exe` | ❌ 不存在 | 这个 repack 用的是 `1极速游戏管理器.exe`（1.86 MB） |
| `[2K9]vcredist_x86.exe` | ❌ 不存在 | 改从微软官方下载安装（见下） |
| `[2K13]` = `D:\nba2k13\` | ✅ 存在，游戏在 `D:\nba2k13\game\` | 主程序是 `nba2k13.exe`（30.14 MB），不是 `nba2k12.exe` |
| `[KEYS]` `D:\prod.keys` | ❌ **找不到** | 打包必须，需要你自己放一份进来 |
| `D:\CarafeLibrary` | ❌ 未创建 | Carafe 还没装 |

盘位：C 剩 88.1 GB，D 剩 188.9 GB，E 剩 461.2 GB。系统 Windows 10 家庭中文版 build 19045。WebView2 已装（118.0.2088.61）。

## 二、真正的卡点：不是 0xC000001D，是缺 VC++ 2005

双击 `D:\nba2k9\game\nba2k9.exe` 的时候，进程根本没跑起来，系统直接拒绝：

```
The application has failed to start because its side-by-side configuration is incorrect.
事件日志：Dependent Assembly Microsoft.VC80.MFC, version="8.0.50608.0" could not be found.
```

原因：这个 exe 内嵌的 manifest 要求 `Microsoft.VC80.CRT` 和 `Microsoft.VC80.MFC` 两个 8.0.50608.0 的并行程序集，机器上只有 zero 散的 vc80.crt，**一个 vc80.mfc 都没有**。

处理：装微软官方 `vcredist_x86`（VC++ 2005 SP1，签名有效，已装成 8.0.61001）。装完 WinSxS 里补上了 vc80.crt / mfc / mfcloc / atl / openmp。

结果：**nba2k9.exe 直接起来了**，窗口标题 `NBA 2K9`，进到湖人 vs 凯尔特人的主菜单。进程无崩溃事件。

所以手册里「在两台 Windows 上都崩 0xC000001D」这个结论，在这台机器上复现不出来 —— 在 5800H 上它压根没走到那一步。

## 三、剩下的缺口

1. **`prod.keys` 没有** → Carafe 打包这一步做不了。需要一份 14 KB 的原始文件，别用记事本打开。
2. 脱壳版不在机上 → 但既然原版（FuckALI 壳）能跑，先考虑直接拿它打包；壳在 Wine 下能不能跑，是 Carafe 那边要试的事。
3. Carafe 还没装；装之前要加两处杀毒排除项：`C:\Program Files\Carafe`、`D:\CarafeLibrary`。

## 四、Carafe 打包时的填写（按实际路径）

| 项 | 填什么 |
| --- | --- |
| 游戏文件夹 | `D:\nba2k9\game` |
| 启动程序 | `nba2k9.exe` |
| 密钥 | `prod.keys`（等你放进来） |
| Library folder | `D:\CarafeLibrary` |
| 版本 | 0.4.0 x64 及以上（修了 32 位游戏地址空间耗尽 #47） |
