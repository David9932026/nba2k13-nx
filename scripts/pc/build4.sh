#!/usr/bin/env bash
# 打开 -fms-extensions（让 clang 认识 __try/__except）再编
set -u
export PATH=/ucrt64/bin:/usr/bin:$PATH
PORT="/c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex/nfsmw-nx-main"
cd "$PORT" || exit 1

echo "=== 重新配置 $(date +%H:%M:%S) ==="
cmake -S sdk -B out/host -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_C_FLAGS="-march=x86-64-v2 -fms-extensions" \
  -DCMAKE_CXX_FLAGS="-march=x86-64-v2 -fms-extensions" \
  -DREXGLUE_USE_D3D12=ON -DREXGLUE_USE_VULKAN=OFF \
  -DREXGLUE_BUILD_TESTS=OFF -DREXGLUE_ENABLE_TRACY=OFF > /tmp/cfg4.log 2>&1
rc=$?; echo "配置 rc=$rc"
[ "$rc" != "0" ] && { tail -15 /tmp/cfg4.log; exit 1; }

echo "=== 先单独试 threading_win.cpp ==="
cmake --build out/host --target rexcore > /tmp/tw.log 2>&1
rc=$?
echo "rexcore rc=$rc"
if [ "$rc" != "0" ]; then
  grep -E 'error:|fatal error' /tmp/tw.log | head -10
  grep -E '^FAILED' /tmp/tw.log | head -3
fi
