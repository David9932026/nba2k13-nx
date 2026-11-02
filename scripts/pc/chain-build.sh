#!/usr/bin/env bash
# 等 13 个子模块全部就位（每个都有 .git 占位，说明解压完成了），然后自动开始编译
set -u
export PATH=/ucrt64/bin:/usr/bin:$PATH
TP="/c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex/rexglue-sdk-src/thirdparty"
HERE="/c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126"
NEED="cli11 libmspack FFmpeg tomlplusplus simde xxHash spdlog fmt utfcpp imgui sdl3 inja o1heap"

echo "[等待] 子模块就绪检查开始 $(date +%H:%M:%S)"
for i in $(seq 1 120); do
  ok=0; missing=""
  for n in $NEED; do
    if [ -d "$TP/$n/.git" ] && [ -n "$(ls -A "$TP/$n" 2>/dev/null | grep -v '^\.git$')" ]; then
      ok=$((ok+1))
    else
      missing="$missing $n"
    fi
  done
  echo "  $(date +%H:%M:%S)  就绪 $ok/13  缺:$missing"
  [ "$ok" -eq 13 ] && break
  sleep 15
done

if [ "$ok" -ne 13 ]; then echo "!! 等了 30 分钟仍不齐，放弃"; exit 1; fi
echo "[等待] 全部就位，10 秒后开始编译"
sleep 10
cd "$HERE" || exit 1
bash build-rexglue.sh
