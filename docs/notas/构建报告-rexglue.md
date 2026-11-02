# rexglue 代码生成器构建报告

- 完成时间：2026-10-28 19:58
- 产物：`rex\nfsmw-nx-main\sdk\out\win-amd64\rexglue.exe`（4,241,519 字节）
- 配套：`librexruntime.dll`（14,251,751 字节）+ 3 个 MinGW 运行时 DLL
- 最终错误数：**0**；警告 41 条（全部无害）

## 一、最终结果

```
[56/57] Linking CXX executable ...\sdk\out\win-amd64\rexglue.exe
[57/57] ...
error: 0 个
```

`rexglue.exe --version` 退出码 0，`codegen --help` 正常输出：

```
rexglue codegen [OPTIONS] [config]
POSITIONALS:
  config PATH   Path to manifest TOML (auto-discovered in cwd if omitted)
OPTIONS:
  -h, --help        Print this help message and exit
      --target NAME  DLL target to build (repeatable; entrypoint always included)
      --ignore-stamp Regenerate even when inputs match the recorded stamp
```

## 二、环境

| 项 | 值 |
|---|---|
| 编译器 | clang（MSYS2 UCRT64） |
| 构建系统 | CMake + Ninja，`out/host` |
| SDK | rexglue-sdk `c94f5ebdcb3c9d1a460ca48e04f9758448f8d518`（v0.10.0） |
| 图形后端 | D3D12 开、Vulkan 关（codegen 不需要图形） |
| 目标 | `rexglue`（codegen / init / test-recompiler 三个子命令） |

## 三、补丁与 stub 完整清单

全部改动都是**编译器方言差异**，没有触碰 SDK 逻辑。

### 1. FFmpeg 预置配置（源码）

`thirdparty/FFmpeg/config_windows_x86_64.h`

```c
#define HAVE_LIBC_MSVCRT 1   →   0
```

那份配置按 MSVC 写的，会去找 `crtversion.h`（MSVC CRT 私有头），MinGW 没有。

### 2. 三条编译开关（CMake）

```cmake
-DCMAKE_C_FLAGS="-march=x86-64-v2 -fms-extensions -isystem <stubs>"
-DCMAKE_CXX_FLAGS="-march=x86-64-v2 -fms-extensions -isystem <stubs>"
```

- `-march=x86-64-v2`：`memory.cpp` 用 `_mm_shuffle_epi8`（SSSE3），MSVC x64 默认开、clang 基线只有 SSE2。5800H 完全支持。
- `-fms-extensions`：让 clang 认 `__try/__except`。SDK 的 `include/rex/platform/exceptions.h` 整个异常保护层在 Windows 分支直接展开成 MSVC SEH 语法。
- `-isystem <stubs>`：指向下面的 stub 目录。

### 3. stub 头（新增文件）

`rex\stubs\DXProgrammableCapture.h` —— Windows SDK 的 PIX 程序化捕获头，MinGW 不带。

```cpp
#include <guiddef.h>
#include <unknwn.h>

MIDL_INTERFACE("9F50E42C-F136-499E-9A97-73036C94ED2D")
IDXGraphicsAnalysis : public IUnknown {
 public:
  virtual void STDMETHODCALLTYPE BeginCapture() = 0;
  virtual void STDMETHODCALLTYPE EndCapture() = 0;
};

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IDXGraphicsAnalysis, 0x9F50E42C, 0xF136, 0x499E, 0x9A, 0x97,
                0x73, 0x03, 0x6C, 0x94, 0xED, 0x2D)
#endif
```

`__CRT_UUID_DECL` 那段不能省：MSVC 用 `__declspec(uuid())` 挂 GUID，MinGW 靠模板特化，漏了就会**编过但链接报 undefined reference**。

### 4. 源码补丁 A：函数指针转 void*

`src/input/xinput/xinput_input_driver.cpp` 第 119~125 行

```cpp
XInputGetCapabilities_ = reinterpret_cast<void*>(xigc);   // 原来是直接 = xigc
XInputGetState_        = reinterpret_cast<void*>(xigs);
XInputGetStateEx_      = reinterpret_cast<void*>(xigsEx);
XInputGetKeystroke_    = reinterpret_cast<void*>(xigk);
XInputSetState_        = reinterpret_cast<void*>(xiss);
XInputEnable_          = reinterpret_cast<void*>(xie);
```

成员声明是 `void*`，而 `GetProcAddress` 返回 `FARPROC`。MSVC 默认放行，clang 按标准禁止。

### 5. 源码补丁 B：GUID 常量

`src/ui/d3d12/d3d12_provider.cpp` 第 259 行

```cpp
_uuidof(ID3D12Device)   →   IID_ID3D12Device
```

MinGW 的 `d3d12.h` 不提供 `__declspec(uuid)` 风格的 GUID，`IID_ID3D12Device` 常量可以直接用。

### 6. 运行时 DLL（非补丁，部署需要）

`rexglue.exe` 动态链接 MinGW 运行时，从 `C:\Users\26095\msys64\msys64\ucrt64\bin` 复制到 exe 同目录：

- `libgcc_s_seh-1.dll`
- `libwinpthread-1.dll`
- `libstdc++-6.dll`

缺任何一个，程序启动时 **退出码 127、零输出**。

## 四、警告统计（共 41 条，全部无害）

```
17  -Wunused-parameter
12  -Wmissing-field-initializers
 3  -Wunused-but-set-variable
 3  -Wmissing-designated-field-initializers
 2  -Wunused-variable
 2  -Wpessimizing-move
 1  -Wunused-function
 1  -Wsign-compare
```

## 五、踩过的坑（时间线）

| 时刻 | 报错 | 处理 |
|---|---|---|
| 19:50 | `threading_win.cpp:62: expected catch` / `__except` 未声明 | `-fms-extensions` |
| 19:53 | `FFmpeg/.../internal.h:181: 'crtversion.h' file not found` | `HAVE_LIBC_MSVCRT 0` |
| 19:53 | `memory.cpp:70: '_mm_shuffle_epi8' requires ssse3` | `-march=x86-64-v2` |
| 19:54 | `d3d12_api.h:24: 'DXProgrammableCapture.h' file not found` | 自写 stub |
| 19:56 | `xinput_input_driver.cpp:118-123: void* ← FARPROC`（6 条） | 显式 `reinterpret_cast` |
| 19:56 | `d3d12_provider.cpp:259: cannot call __uuidof on a type with no GUID` | `IID_ID3D12Device` |
| 19:57 | `undefined reference to __mingw_uuidof<IDXGraphicsAnalysis>()` | stub 补 `__CRT_UUID_DECL` |
| 19:58 | 链接成功 | — |

## 六、已知行为怪异

从 MSYS2 bash 里直接跑 `rexglue.exe` **会挂住不返回**（`--version` 也一样），但从 PowerShell 用 `Start-Process` 跑就立刻退出、返回码正常。是 MSYS2 pty/管道与控制台初始化的冲突，不是程序的问题。所有验证脚本因此走 PowerShell（`rex-run.ps1` / `rex-codegen.ps1`）。
