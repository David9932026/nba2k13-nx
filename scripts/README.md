# scripts

脚本都按"在哪跑"分目录。路径里的 `C:\Users\...`、`D:\cola-projects\...` 是原开发机的，
换机器要自己改 —— 这些脚本的价值在**做法**，不在能直接跑。

```
pc/        Windows 侧：构建、跑游戏、抓帧、代码生成、MTP 传输、日志分析
switch/    Switch 侧：构建、配置、上卡
analysis/  纯 Python：PNG 解码与像素统计、接缝检测、帧对比、崩溃栈符号化
input/     脚本化按键序列（毫秒时间戳 + 按键名），用来复现"进比赛/进技术统计"这类路径
```

## pc/

| 脚本 | 用途 |
|---|---|
| `pcb.sh` | PC 构建（ninja，win-vk） |
| `nativo-run.ps1` | 跑一段并抓帧：`-Seconds` / `-Script input-xxx.txt` / `-Tag` / `-Extra "--cvar=val …"` |
| `rex-codegen.ps1` | 从 `default.xex` 生成重编译代码 |
| `apply-gen-patches.ps1` | 重新生成代码后把手工修的片段打回去（**注：第 92 行的 3 参插桩已过时，待修**） |
| `build-app-vk.sh` / `build-app.sh` | 应用工程配置与构建 |
| `ab-*.ps1` | A/B 实验（每次只改一个 cvar，跨整段聚合统计） |
| `mtp-*.ps1` | 走 MTP 推/拉文件、列目录、核对大小 |
| `borra-sd-directo.ps1` | 清卡上的探针垃圾（挂载后直删，比 MTP 快得多） |
| `xenia-shot.ps1` | Xenia 侧截图（可行性预检阶段用） |

## switch/

| 脚本 | 用途 |
|---|---|
| `build-sw.sh` | Switch 构建（**先 cd 到工程根**） |
| `mtp-push-c42.ps1` / `mtp-verify-c42.ps1` | MTP 推 NRO 并核对 MD5 |
| `run-mesa.sh` / `cfg-sw.sh` / `chk.sh` | 交叉编译与环境检查 |

## analysis/

| 脚本 | 用途 |
|---|---|
| `chequea_png.py` | PNG 解码（unfilter）+ 逐通道统计 —— 所有像素结论的基础 |
| `suelo_tot.py` | 一段截图里"黑像素占比 ≥N%"的帧数（跨整段聚合，A/B 用） |
| `abdiff.py` / `abdiff48.py` | 两轮截图的逐像素差异百分比 |
| `borde48.py` | 接缝检测：边界梯度 vs 参考梯度 |
| `c45chk*.py` | 头像修复的集合运算验证（非零像素、A∩B、A−B） |
| `simboliza-freeze.py` / `simb2.py` / `simboliza-pilas.py` | 崩溃/冻死栈符号化（配 `nm-final.txt`） |

## input/

| 文件 | 走到哪 |
|---|---|
| `input-menu.txt` | 进演示模式（菜单 + 自动比赛） |
| `input-pause.txt` | 一路确认到比赛，再反复暂停 |
| `input-stats.txt` | 同上，额外按 RB 翻页（**到不了技术统计页**，PC 上这条路走不通） |
| `input-live.txt` / `input-a30.txt` / `input-larga.txt` | 长短不同的推进序列 |

格式：每行 `起始毫秒 结束毫秒 按键名`，例如 `30000 30600 A`。
