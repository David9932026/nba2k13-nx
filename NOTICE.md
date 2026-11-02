# NOTICE · 第三方组件与出处

本仓库的代码大量建立在别人的工作之上，这里把出处说清楚。

---

## 1. ReXGlue SDK（运行时 / 工具链）

- 上游：https://github.com/rexglue/rexglue-sdk
- 作用：Xbox 360 PowerPC 代码 → 可移植 C++ 的静态重编译框架；本项目的运行时就是它。
- 本仓库的 `runtime/` 是**打过补丁的版本**（81 个文件改动），保留了上游的许可与文档
  （`runtime/LICENSE`、`runtime/README.upstream-nfsmw-nx.md`、`runtime/THIRD_PARTY_NOTICES.md`）。

## 2. nfsmw-nx（原生 Vulkan 渲染器）

- 上游：https://github.com/StevensND/nfsmw-nx
- 许可：**GPL-3.0**
- 作用：Switch 上的原生 Vulkan 渲染器骨架 —— PM4 环读取、EDRAM-less 渲染目标、resolve 交换、
  纹理指纹缓存、三槽并行提交。本项目把它移植到 2K13。
- 因为它是 GPL-3.0，本仓库的衍生代码（`app/`、`scripts/`）同样以 GPL-3.0 发布。
- `runtime/docs/` 里的文档（`native-renderer.md`、`performance-history.md`、
  `porting-another-game.md`、`measuring.md`、`platform-notes.md` 等）来自该项目，版权归其作者。

## 3. XenosRecomp / xenia 的图形知识

- 着色器微码 → HLSL/SPIR-V 的翻译、Xenos 的纹理格式表、PM4 包语义、EDRAM 瓦片规则，
  都源自 xenia 项目与 XenosRecomp 的公开实现。
- `runtime/shaders/` 下保留上游代码与许可（`runtime/shaders/LICENSE.md`）。

## 4. mesa / NVK

- Switch 上的 Vulkan 驱动由 mesa 的 `nvk` 后端交叉编译而来。
- `runtime/mesa/` 下有构建脚本与对 mesa 的补丁（`mesa-switch-nfsmw.patch`），遵循 mesa 的 MIT 许可。

## 5. devkitPro / libnx

- Switch 原生开发环境与系统接口。https://devkitpro.org

## 6. 游戏

**NBA 2K13** © 2K Sports / Take-Two Interactive。本仓库不包含该游戏的任何内容 ——
不含可执行体、资产、着色器数据，也不含由其派生的重编译代码。使用者需自行拥有正版游戏。

---

## 关于 ripped 内容的说明

本仓库里唯一与游戏本体"沾边"的文件是 `app/huecos.toml` —— 它记录的是
**哪些地址区间 codegen 没能自动识别**（函数边界的分析结果），不含任何指令或数据。
它对你自己的 dump 有参考价值，但不能直接套用。
