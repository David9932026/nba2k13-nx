#!/usr/bin/env bash
# 单个子模块下载器：fetch-one.sh <name> <owner/repo> <sha>
set -u
export PATH=/ucrt64/bin:/usr/bin:$PATH
TP="/c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex/rexglue-sdk-src/thirdparty"
name="$1"; repo="$2"; sha="$3"
dest="$TP/$name"
tmp="/tmp/sub_$name.tgz"

if [ -d "$dest/.git" ] && [ -n "$(ls -A "$dest" 2>/dev/null | grep -v '^\.git$')" ]; then
  echo "[$name] 已有，跳过"; exit 0
fi

BASES=("https://codeload.github.com" "https://gh-proxy.com/https://codeload.github.com" "https://ghfast.top/https://codeload.github.com")
for round in 1 2 3; do
  for b in "${BASES[@]}"; do
    url="$b/$repo/tar.gz/$sha"
    rm -f "$tmp"
    curl -sL --max-time 240 --connect-timeout 20 --speed-limit 1024 --speed-time 45 -o "$tmp" "$url"
    sz=$(stat -c %s "$tmp" 2>/dev/null || echo 0)
    if [ "$sz" -lt 20480 ]; then continue; fi
    if ! tar -tzf "$tmp" >/dev/null 2>&1; then continue; fi
    rm -rf "$dest"; mkdir -p "$dest"
    tar -xzf "$tmp" -C "$dest" --strip-components=1 2>/dev/null
    mkdir -p "$dest/.git"
    echo "[$name] OK $((sz/1024)) KB $(ls -A "$dest" | grep -vc '^\.git$') 项  ($round 轮, ${b:8:14})"
    rm -f "$tmp"
    exit 0
  done
  sleep 2
done
echo "[$name] !! 失败"
rm -f "$tmp"
exit 1
