#!/bin/bash
export PATH=/ucrt64/bin:/usr/bin:/opt/devkitpro/tools/bin:$PATH
export DEVKITPRO=/opt/devkitpro
R=/c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex
SDK=$R/nfsmw-nx-main
MESA=/c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/switch-build/mesa-switch/mesa-unified-install/opt/devkitpro/portlibs/switch
cmake -S $R/nba2k13app -B $R/nba2k13app/out/build/sw -G Ninja -DCMAKE_BUILD_TYPE=Release \
 -DCMAKE_TOOLCHAIN_FILE=$SDK/tools/switch/cmake/switch-devkitA64.cmake \
 -DREXSDK_DIR=$SDK/sdk -DREXGLUE_SWITCH_NVK_SDK=$MESA 2>&1 | tail -40
echo CFG_EXIT=${PIPESTATUS[0]}