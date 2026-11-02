# 从 sf4-nx 借鉴的待办（整理于 2026-10-30）

来源：https://github.com/jvankooo/sf4-nx（Xbox 360 街霸4 → Switch，ReXGlue + Vulkan/NVK，锁 30 帧）
本地副本：ref-sf4/（native-renderer、performance-history、platform-notes、porting-another-game 等）

## A. Switch 平台层（第 ④⑤ 层之前就要做）
1. **apm 性能配置**：掌机模式程序默认 GPU 只有 307.2 MHz。向系统申请 `0x92220008`（GPU 460.8 MHz + 内存 1331.2 MHz，官方档位，不是超频）。注意 `apmSetPerformanceConfiguration` 是异步的，设完立刻读时钟读到的还是旧值；不要猜配置 ID，要查真表。
2. **异常栈池**：libnx 全进程只有一个异常栈和一份异常转储。我们有大量线程 + 懒映射缺页（`xmemory.cpp` 的懒映射本来就是靠缺页），两个线程同时进异常处理会互相覆盖寄存器，且无声。做 8 个槽的栈池，用 `ldaxr/stlxr` 原子占槽。位置：Switch 版 `exception_handler`。
3. **禁用 `std::thread::detach()`**：Horizon 上线程已结束时会抛 `std::system_error` → `std::terminate`。改成常驻 worker 线程 + 任务队列，或 try/catch。
4. **线程优先级**：只有 `0x3B` 会时间片轮转；其它优先级是协作式，忙线程会霸占核心。guest 线程和批量活放 `0x3B`，渲染/环线程用 `0x2D`，音频 `0x2B`。饿死时降低霸占者优先级，不要抬高被饿的那个。
5. **内存映射上限**：`LimitableResource_Memory` 耗尽会报 `0xCE01`（2001-0103），不是 OOM。guest 内存多视图（0x7F000000/0xA0000000/0xC0000000/0xE0000000）不要全映射，按 4 MB 块、首次被某视图访问时再映射。
6. **GPU 时间戳**：NVK 的 `timestampPeriod` 说 1 ns，实际 1.627 ns，测 GPU 耗时要乘 1.627。
7. **nvmap 上限**：约 4000 个句柄会报 `0x235C`（SharedMemoryTooSmall），不是 OOM；可在 `nvInitialize` 之前覆盖 `__nx_nv_transfermem_size`。
8. **纹理用大块子分配**：单独分配一张纹理约 1.9 ms CPU，用 32 MB 共享块降到约 0.75 ms。
9. **管线缓存**：不带缓存创建管线约 59 ms 一条；存 `VkPipelineCache` + 已知管线列表，后台线程预热。（我们 PC Vulkan 版实测同步创建比异步更稳，Switch 上要重新评估。）
10. **呈现限制**：只有一个队列、3 张交换链图像、只有 FIFO/IMMEDIATE；`MESA_SHADER_CACHE_DISABLE` 关掉 SD 卡上的重复着色器缓存。

## B. 渲染架构（影响“Switch 上能不能稳 30”的关键决策）
11. sf4-nx 实测：沿用 Xenia/ReXGlue 自带的 Xenos GPU 模拟，Switch 上只有 4~5 帧；换成**直接读 PM4 命令环画 Vulkan 的原生渲染器**才到约 30 帧。我们现在的 `graphics/vulkan` 就是模拟路线。需要决定：照搬 masseffect-nx 的原生渲染器（sf4-nx 依赖它），还是继续优化现有后端。
12. **tile collapse**：游戏分 3 个预测式 tile 画 3D 场景，合并成一次绘制，环上 draw 数减少约 60%。2K13 未确认是否也有分块，待对 PM4 做统计。
13. **MSAA 关闭 + 1x 表面**，以及 EDRAM 模式选择（mode 0 每个 (base, format, pitch) 一张图，不做视图间拷贝）。
14. **忙等**：游戏 D3D 层有等待 GPU fence 的忙循环，PC 上每秒空转 1500 万~2600 万次。要 hook 成真正的等待（睡到环线程写回进度）。我们的 2K13 也很可能有同样的忙等，值得查 CPU 占用。
15. **VBlank 追帧**：游戏落后 60Hz 时让它等待的 VBlank 立即触发。
16. **30 帧模式**：逻辑每秒 60 步，画面 30 帧（每画一帧跑两步逻辑，两步之间读手柄避免重复按键）；`sf4_scene_480p`：只有 3D 场景 480p，菜单/HUD/影片保持 720p。——对应我们“掌机稳定 30 帧”的目标，可作为降负载的备选方案。
17. **生成代码提速**：直接调用、LTO、PGO、函数排序；寄存器放 C++ 局部变量（`perf_overrides.toml`），去掉 MSR 栅栏、去掉死 `lr` 存储。其中 guest setjmp/longjmp 要映射到宿主，`share_registers` 的误标会导致寄存器回写错误。
18. **Bink 影片变绿块的原因**：VMX 常量表（v64–v127）没按函数标记，IDCT 叶函数读到的常量全 0。2K13 影片若走 Bink，要检查同类问题。

## C. porting-another-game.md 的流程提示（对照我们的进度）
- 步骤顺序：PC 跑通 → 迁到 Switch 系统层 → 看到第一帧，再写更快的渲染器 → 着色器提前翻译 → 在真机测量 → 优化。我们现在在“PC 跑通 + 画面质量”阶段，还没碰 Switch 真机。
- 着色器提前翻译：XenosRecomp → HLSL → DXC → SPIR-V，按微码哈希存成着色器库，避免运行时翻译卡顿和 CPU 开销。
- 在真机上看 `tools/pm4_frame.py` 这类工具：dump 一帧 PM4 并回放寄存器，列出每个 draw 的目标、窗口、scissor、贴图——对我们定位黑屏/花屏帧非常合适，建议自己写一个等价工具。
- 测量原则：PC 只能告诉你工作量在哪，不能告诉你在 Switch 上花多少；同一会话 A/B；看帧时间分布而不是平均 FPS；别在超频下测。
- 没用的：降分辨率（帧不一定受分辨率限制）、FP16、可变速率着色、扩展动态状态。

## D. 待决定
- 选择渲染器路线（B-11）。
- 是否按 sf4-nx 的做法拆分“3D 场景 480p + UI 720p”（B-16）。
- Switch 上 ROV/互锁是否可用（我们 PC 上 fsi/rov 压住了黑屏，Maxwell 未确认）。
