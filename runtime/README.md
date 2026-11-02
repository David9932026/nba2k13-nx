# runtime · 打过补丁的 ReXGlue / nfsmw-nx 运行时

这个目录是 **nfsmw-nx 的 SDK 分支**，本项目对它的改动都在这里。上游说明见
[README.upstream-nfsmw-nx.md](README.upstream-nfsmw-nx.md)，上游许可见 [LICENSE](LICENSE)。

## 改了什么（按作用分）

| 目录 / 文件 | 改动 |
|---|---|
| `sdk/src/graphics/native_sink.cpp` | 新增：原生渲染器的五个挂点（包 / 绘制 / resolve / 传输 / Swap） |
| `sdk/include/rex/graphics/native_sink.h` | 对应的接口 |
| `sdk/src/graphics/vulkan/*` | 渲染目标缓存、纹理缓存、命令处理器、pipeline 缓存的 2K13 适配 |
| `sdk/src/kernel/xboxkrnl/xboxkrnl_memory.cpp` | 物理内存账本（C39）、64MB 对齐申请与保险垫（C41b，已回退） |
| `sdk/src/core/threading_posix.cpp` | futex 定点唤醒（C36）、取消类型（C40） |
| `sdk/src/kernel/xam/xam_net.cpp` | `inet_addr` 缓存（C32） |
| `sdk/src/kernel/xam/xam_input.cpp` | `XamInputGetCapabilities` |
| `sdk/src/audio/*` | XMA 解码失败降级为静音、Switch 混音线程优先级 |
| `sdk/src/input/switch/switch_input_driver.cpp` | 面板组合键改 `L3+R3+十字键右`、索尼布局 |
| `sdk/src/ui/*` | Switch 崩溃钩子、性能叠层、系统时钟（超频） |
| `sdk/src/codegen/*` | codegen 补扫与空洞处理 |
| `cmake/rexglue_switch.cmake` | Switch 工具链 |
| `shaders/XenosRecomp/*` | 2008 版容器（`0x102A1100`）解析、VS fetch 位置规则配对 |

## 为什么不直接给 patch

上游版本一直在变，`patch` 会因为上下文漂移打不上。这里给的是**完整文件树**，
按上面的表对照即可 —— 想知道具体改了哪几行，用 `git diff` 对上游同名文件看。

## 许可

`runtime/sdk/` 与 `runtime/shaders/` 各自保留了原许可（见各自的 `LICENSE` / `LICENSE.md`）。
`runtime/mesa/` 的补丁遵循 mesa 的 MIT 许可。
