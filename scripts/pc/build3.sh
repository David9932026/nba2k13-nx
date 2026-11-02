#!/usr/bin/env bash
# 重新配置（开 SSSE3 等 x86-64-v2 指令集）+ 编译 rexglue
set -u
export PATH=/ucrt64/bin:/usr/bin:$PATH
PORT="/c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex/nfsmw-nx-main"
cd "$PORT" || exit 1

echo "=== 重新配置 $(date +%H:%M:%S) ==="
cmake -S sdk -B out/host -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_C_FLAGS="-march=x86-64-v2" \
  -DCMAKE_CXX_FLAGS="-march=x86-64-v2" \
  -DREXGLUE_USE_D3D12=ON \
  -DREXGLUE_USE_VULKAN=OFF \
  -DREXGLUE_BUILD_TESTS=OFF \
  -DREXGLUE_ENABLE_TRACY=OFF > /tmp/cfg2.log 2>&1
rc=$?
echo "配置 rc=$rc"
if [ "$rc" != "0" ]; then tail -20 /tmp/cfg2.log; exit 1; fi

echo "=== 编译 rexglue $(date +%H:%M:%S) ==="
cmake --build out/host --target rexglue > /tmp/build3.log 2>&1
rc=$?
echo "编译 rc=$rc  $(date +%H:%M:%S)"
if [ "$rc" != "0" ]; then
  echo "--- 错误（前 12）---"
  grep -E 'error:|fatal error' /tmp/build3.log | head -12
  echo "--- FAILED ---"
  grep -E '^FAILED' /tmp/build3.log | head -6
  echo "--- 尾部 10 ---"
  tail -10 /tmp/build3.log
else
  echo "--- 尾部 6 ---"
  tail -6 /tmp/build3.log
  ls -la out/host/rexglue* out/host/*.exe 2>/dev/null
  find out/host -maxdepth 3 -name 'rexglue' -type f 2>/dev/null
fi
echo "=== DONE $(date +%H:%M:%S) ==="
