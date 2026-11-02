#!/usr/bin/env bash
# 配置 + 编译 nba2k13 宿主程序（PC / D3D12 / lld 链接）
set -u
export PATH=/ucrt64/bin:/usr/bin:$PATH

BASE="/c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex"
APP="$BASE/nba2k13app"
SDK="$BASE/nfsmw-nx-main/sdk"
STUBS="C:/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex/stubs"
JOBS="${JOBS:-8}"

cd "$APP" || exit 1

echo "=== configure $(date +%H:%M:%S) ==="
cmake -S . -B out/build/win-amd64-release -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_C_FLAGS="-march=x86-64-v2 -fms-extensions -isystem $STUBS" \
  -DCMAKE_CXX_FLAGS="-march=x86-64-v2 -fms-extensions -isystem $STUBS" \
  -DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=lld" \
  -DCMAKE_SHARED_LINKER_FLAGS="-fuse-ld=lld" \
  -DREXSDK_DIR="$SDK" \
  -DREXGLUE_USE_D3D12=ON -DREXGLUE_USE_VULKAN=OFF \
  -DREXGLUE_BUILD_TESTS=OFF -DREXGLUE_ENABLE_TRACY=OFF \
  -DREXGLUE_RECOMP_DEBUG_INFO=none > /tmp/appcfg.log 2>&1
rc=$?
echo "configure rc=$rc  $(date +%H:%M:%S)"
if [ "$rc" != "0" ]; then
  echo "--- configure 错误 ---"
  grep -E 'CMake Error|error:' /tmp/appcfg.log | head -20
  tail -20 /tmp/appcfg.log
  exit 1
fi

echo "=== build -j$JOBS $(date +%H:%M:%S) ==="
cmake --build out/build/win-amd64-release -j "$JOBS" > /tmp/appbuild.log 2>&1
rc=$?
echo "build rc=$rc  $(date +%H:%M:%S)"
tail -5 /tmp/appbuild.log
if [ "$rc" != "0" ]; then
  echo "--- FAILED 行 ---"
  grep -E '^FAILED' /tmp/appbuild.log | head -8
  echo "--- error: 明细 ---"
  grep -E 'error:|undefined reference' /tmp/appbuild.log | head -20
else
  echo "--- 产物 ---"
  ls -la out/build/win-amd64-release/nba2k13.exe 2>/dev/null
fi
