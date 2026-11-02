#!/usr/bin/env bash
# 加一个 stub 头目录（DXProgrammableCapture.h），然后继续编 rexglue
set -u
export PATH=/ucrt64/bin:/usr/bin:$PATH
PORT="/c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex/nfsmw-nx-main"
STUBS="C:/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex/stubs"
cd "$PORT" || exit 1

echo "=== 重新配置 $(date +%H:%M:%S) ==="
cmake -S sdk -B out/host -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_C_FLAGS="-march=x86-64-v2 -fms-extensions -isystem $STUBS" \
  -DCMAKE_CXX_FLAGS="-march=x86-64-v2 -fms-extensions -isystem $STUBS" \
  -DREXGLUE_USE_D3D12=ON -DREXGLUE_USE_VULKAN=OFF \
  -DREXGLUE_BUILD_TESTS=OFF -DREXGLUE_ENABLE_TRACY=OFF > /tmp/cfg5.log 2>&1
rc=$?; echo "配置 rc=$rc"
[ "$rc" != "0" ] && { tail -15 /tmp/cfg5.log; exit 1; }

echo "=== 编译 rexglue $(date +%H:%M:%S) ==="
cmake --build out/host --target rexglue > /tmp/build5.log 2>&1
rc=$?
echo "编译 rc=$rc  $(date +%H:%M:%S)"
tail -3 /tmp/build5.log
if [ "$rc" != "0" ]; then
  echo "--- 错误（前 15）---"
  grep -E 'error:|fatal error' /tmp/build5.log | head -15
  echo "--- FAILED ---"
  grep -E '^FAILED' /tmp/build5.log | head -8
else
  echo "--- 产物 ---"
  ls -la out/host/rexglue* out/host/*.exe 2>/dev/null
  find out/host -maxdepth 3 -type f -name 'rexglue*' 2>/dev/null
fi
echo "=== DONE $(date +%H:%M:%S) ==="
