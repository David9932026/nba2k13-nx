#!/usr/bin/env bash
# 配置 + 编译 rexglue（D3D12 后端开着以满足 CMake 要求，但只编 rexglue 这个 target）
set -u
export PATH=/ucrt64/bin:/usr/bin:$PATH
PORT="/c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex/nfsmw-nx-main"
cd "$PORT" || exit 1

echo "=== cmake 配置 $(date +%H:%M:%S) ==="
cmake -S sdk -B out/host -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
  -DREXGLUE_USE_D3D12=ON \
  -DREXGLUE_USE_VULKAN=OFF \
  -DREXGLUE_BUILD_TESTS=OFF \
  -DREXGLUE_ENABLE_TRACY=OFF > /tmp/cfg.log 2>&1
rc=$?
echo "配置 rc=$rc"
if [ "$rc" != "0" ]; then
  echo "--- 错误摘要 ---"
  grep -iE 'error|CMake Error|not found|Could NOT' /tmp/cfg.log | head -30
  echo "--- 尾部 ---"
  tail -25 /tmp/cfg.log
  exit 1
fi
echo "--- 配置尾部 ---"
tail -8 /tmp/cfg.log

echo "=== 编译 rexglue target $(date +%H:%M:%S) ==="
cmake --build out/host --target rexglue > /tmp/build.log 2>&1
rc=$?
echo "编译 rc=$rc  $(date +%H:%M:%S)"
if [ "$rc" != "0" ]; then
  echo "--- 错误摘要 ---"
  grep -iE 'error:|fatal error|FAILED' /tmp/build.log | head -40
  echo "--- 尾部 40 行 ---"
  tail -40 /tmp/build.log
else
  echo "--- 尾部 15 行 ---"
  tail -15 /tmp/build.log
  echo "--- 产物 ---"
  find out/host -name 'rexglue*' -o -name '*.exe' | head -20
  ls -la out/host/*.exe 2>/dev/null
fi
echo "=== DONE $(date +%H:%M:%S) ==="
