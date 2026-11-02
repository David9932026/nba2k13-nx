#!/usr/bin/env bash
# 用 tarball 拉 rexglue-sdk：直连 codeload 优先（实测 ~1 MB/s），失败退回 gh-proxy
set -u
export PATH=/ucrt64/bin:/usr/bin:$PATH
REX="/c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex"
COMMIT="c94f5ebdcb3c9d1a460ca48e04f9758448f8d518"
OUT="$REX/rexglue-sdk.tar.gz"
mkdir -p "$REX"; cd "$REX" || exit 1
rm -f "$OUT"

URLS=(
 "https://codeload.github.com/rexglue/rexglue-sdk/tar.gz/$COMMIT"
 "https://gh-proxy.com/https://codeload.github.com/rexglue/rexglue-sdk/tar.gz/$COMMIT"
)

done_ok=0
for round in 1 2 3 4 5; do
  for u in "${URLS[@]}"; do
    echo "[轮 $round] ${u:0:52} $(date +%H:%M:%S)"
    # 后台跑 curl，同时每 5 秒报一次进度
    curl -sL -C - --retry 3 --retry-all-errors --connect-timeout 20 \
         --speed-limit 2048 --speed-time 40 -o "$OUT" "$u" &
    cp=$!
    while kill -0 $cp 2>/dev/null; do
      sleep 5
      sz=$(stat -c %s "$OUT" 2>/dev/null || echo 0)
      printf "    %s  %d KB\n" "$(date +%H:%M:%S)" $((sz/1024))
    done
    wait $cp; rc=$?
    sz=$(stat -c %s "$OUT" 2>/dev/null || echo 0)
    echo "    rc=$rc  最终 $((sz/1024/1024)) MB"
    if [ "$rc" = "0" ] && [ "$sz" -gt 1048576 ] && tar -tzf "$OUT" >/dev/null 2>&1; then
      done_ok=1; break 2
    fi
    echo "    不完整，换源重试"
  done
  sleep 2
done

if [ "$done_ok" != "1" ]; then echo "!! 所有源都失败"; exit 1; fi

echo "=== 解压 ==="
rm -rf rexglue-sdk-src; mkdir -p rexglue-sdk-src
tar -xzf "$OUT" -C rexglue-sdk-src --strip-components=1
echo "--- 顶层 ---"; ls rexglue-sdk-src | head -30
echo "--- thirdparty ---"; ls rexglue-sdk-src/thirdparty 2>/dev/null | head -40
echo "--- .gitmodules ---"; cat rexglue-sdk-src/.gitmodules 2>/dev/null | head -80
echo "=== GET SDK DONE $(date +%H:%M:%S) ==="
