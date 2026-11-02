#!/usr/bin/env bash
# 逐步编译：libavutil -> libavcodec -> rexglue，遇错即停并打印错误
export PATH=/ucrt64/bin:/usr/bin:$PATH
cd /c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex/nfsmw-nx-main || exit 1

for tgt in "$@"; do
  echo "=== 编译 target: $tgt  $(date +%H:%M:%S) ==="
  cmake --build out/host --target "$tgt" > /tmp/step.log 2>&1
  rc=$?
  errs=$(grep -cE 'error:|fatal error|FAILED' /tmp/step.log)
  echo "  rc=$rc  错误行数=$errs"
  if [ "$rc" != "0" ]; then
    echo "--- 前 12 条错误 ---"
    grep -E 'error:|fatal error|FAILED' /tmp/step.log | head -12
    echo "--- 尾部 12 行 ---"
    tail -12 /tmp/step.log
    exit 1
  fi
done
echo "=== 全部成功 $(date +%H:%M:%S) ==="
find out/host -name 'rexglue*' -maxdepth 4 | head
ls -la out/host/rexglue.exe out/host/*.exe 2>/dev/null
