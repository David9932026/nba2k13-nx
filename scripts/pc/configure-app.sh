#!/usr/bin/env bash
# 配置 nba2k13 宿主编译（PC / Windows x64 / D3D12），并为 SDK 打上 clang 方言所需的开关
set -u
export PATH=/ucrt64/bin:/usr/bin:$PATH

BASE="/c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex"
APP="$BASE/nba2k13app"
SDK="$BASE/nfsmw-nx-main/sdk"
STUBS="C:/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex/stubs"

cd "$APP" || exit 1

echo "=== configure $(date +%H:%M:%S) ==="
cmake -S . -B out/build/win-amd64-release -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_C_FLAGS="-march=x86-64-v2 -fms-extensions -isystem $STUBS" \
  -DCMAKE_CXX_FLAGS="-march=x86-64-v2 -fms-extensions -isystem $STUBS" \
  -DREXSDK_DIR="$SDK" \
  -DREXGLUE_USE_D3D12=ON -DREXGLUE_USE_VULKAN=OFF \
  -DREXGLUE_BUILD_TESTS=OFF -DREXGLUE_ENABLE_TRACY=OFF \
  -DREXGLUE_RECOMP_DEBUG_INFO=none > /tmp/appcfg.log 2>&1
rc=$?
echo "configure rc=$rc"
tail -20 /tmp/appcfg.log
