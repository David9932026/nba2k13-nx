# nba2k13 - ReXGlue Recompiled Project
#
# SDK boilerplate lives in generated/rexglue.cmake.

cmake_minimum_required(VERSION 3.25)
project(nba2k13 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 静态 GPU 插件：把 rexgpu-xenos 直接链进 exe。
# 否则插件 DLL 会带一份独立的 rexruntime 全局状态（XThread/KernelState 对不上，
# 表现为 SetupGuestGpu → CommandProcessor::Initialize → XThread::Create 里段错误）。
# Switch 分支本来就走静态链接，这里让 Windows 宿主保持一致。
set(REXGLUE_STATIC_GPU_PLUGIN ON CACHE BOOL "" FORCE)

include(generated/rexglue.cmake)

# Sources
set(NBA2K13_SOURCES
    src/main.cpp
    src/nba2k13_nativo.cpp
    src/cola_subpasos.cpp
)

# 原生渲染器：整套从 nfsmw-nx 移植过来的图形系统（读游戏自己的 PM4 命令环，直接发 Vulkan），
# 不经过 Xenos 模拟。源码在 src/nativo/，和这个游戏有关的东西全在 src/nba2k13_d3d_dir.h 里。
# 可以随时用 -DNBA2K13_NATIVO=OFF 摘掉，摘掉后就是原来那条模拟路径。
option(NBA2K13_NATIVO "编译移植过来的原生渲染器" ON)
if(NBA2K13_NATIVO)
    list(APPEND NBA2K13_SOURCES
        src/nativo/nba2k13_nativo_sistema.cpp
        src/nativo/nba2k13_nativo_destinos.cpp
        src/nativo/nba2k13_nativo_dibujos.cpp
        src/nativo/nba2k13_nativo_ganchos.cpp
        src/nativo/nba2k13_nativo_shaders.cpp
        src/nativo/nba2k13_nativo_texturas_pool.cpp
        src/nativo/nba2k13_shader_library.cpp
        src/nativo/nba2k13_nativo_captura.cpp
    src/nativo/nba2k13_espera_anillo.cpp
    src/nativo/nba2k13_espera_fotograma.cpp
    src/nativo/nba2k13_nativo_servicios.cpp
    )
endif()

if(WIN32)
    add_executable(nba2k13 WIN32 ${NBA2K13_SOURCES})
    # SDK 的 windowed_app_main_sdl.cpp 定义的是 wWinMain（宽字符入口），
    # MinGW 默认找 WinMain。加 -municode 让链接器改用 wWinMainCRTStartup。
    if(NOT MSVC)
        target_link_options(nba2k13 PRIVATE -municode)
    endif()
else()
    add_executable(nba2k13 ${NBA2K13_SOURCES})
endif()

rexglue_setup_target(nba2k13 GPU_PLUGINS xenos)

if(NBA2K13_NATIVO)
    # 呈现器用到的预编译 SPIR-V（guest_output_*），原生渲染器把游戏画面画到它上面。
    target_include_directories(nba2k13 PRIVATE "${REXSDK_DIR}/src/ui/shaders")
    # rex/ui/vulkan/instance.h 在非 Switch 上 include renderdoc_app.h，rex_app.cpp include imgui.h，
    # 而 rexruntime 是私有链接 imgui/renderdoc 的，头文件路径伸不到可执行文件。
    if(NOT REXGLUE_PLATFORM_SWITCH AND TARGET imgui)
        target_include_directories(nba2k13 PRIVATE $<TARGET_PROPERTY:imgui,INTERFACE_INCLUDE_DIRECTORIES>)
    endif()
    if(NOT REXGLUE_PLATFORM_SWITCH AND TARGET renderdoc)
        target_include_directories(nba2k13 PRIVATE $<TARGET_PROPERTY:renderdoc,INTERFACE_INCLUDE_DIRECTORIES>)
    endif()
    # SDK 的 xxHash：着色器库和原生渲染器都用它做指纹。
    find_path(NBA2K13_XXHASH_INCLUDE xxhash.h HINTS "${REXSDK_DIR}/thirdparty/xxHash" NO_CMAKE_FIND_ROOT_PATH)
    if(NBA2K13_XXHASH_INCLUDE)
        target_include_directories(nba2k13 PRIVATE "${NBA2K13_XXHASH_INCLUDE}")
    else()
        message(WARNING "找不到 xxhash.h，原生渲染器可能编不过")
    endif()
endif()

if(NOT REXGLUE_PLATFORM_SWITCH AND TARGET rex::gpu-xenos)
    target_link_libraries(nba2k13 PRIVATE rex::gpu-xenos)
endif()

if(REXGLUE_PLATFORM_SWITCH)
    rexglue_switch_add_nro(nba2k13 NAME "NBA 2K13" AUTHOR "port" VERSION "0.1.0")
endif()
