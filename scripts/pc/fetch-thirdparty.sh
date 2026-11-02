#!/usr/bin/env bash
# 用 codeload tarball 逐个补齐 rexglue-sdk 的 thirdparty 子模块（不需要 git）
set -u
export PATH=/ucrt64/bin:/usr/bin:$PATH
SRC="/c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex/rexglue-sdk-src"
TP="$SRC/thirdparty"

# name|owner/repo|sha
LIST="
cli11|CLIUtils/CLI11|bfffd37e1f804ca4fae1caae106935791696b6a9
libmspack|kyz/libmspack|305907723a4e7ab2018e58040059ffb5e77db837
FFmpeg|wmarti/FFmpeg|0604b464c7cb4ebc94940cf1f324a3b26b87717c
tomlplusplus|marzer/tomlplusplus|30172438cee64926dc41fdd9c11fb3ba5b2ba9de
simde|simd-everywhere/simde|71fd833d9666141edcd1d3c109a80e228303d8d7
xxHash|Cyan4973/xxHash|e626a72bc2321cd320e953a0ccf1584cad60f363
spdlog|gabime/spdlog|79524ddd08a4ec981b7fea76afd08ee05f83755d
fmt|fmtlib/fmt|407c905e45ad75fc29bf0f9bb7c5c2fd3475976f
utfcpp|nemtrif/utfcpp|63d64de49fd6b829f7c8694df5ab2ee625cb7134
imgui|ocornut/imgui|6d910d5487d11ca567b61c7824b0c78c569d62f
sdl3|libsdl-org/SDL|8bf3b7215ad9fc3deb583c6a3a37c6c67f2e24e4
inja|pantor/inja|7d1b4600b68595085a949743331c2e5673f511ea
o1heap|pavel-kirienko/o1heap|388a73fd9007300e5130c5fe352d9ce3288b6dde
"

fetch_one() {
  name="$1"; repo="$2"; sha="$3"
  dest="$TP/$name"
  if [ -d "$dest" ] && [ -n "$(ls -A "$dest" 2>/dev/null)" ]; then
    echo "  [$name] 已存在，跳过"
    return 0
  fi
  for base in "https://codeload.github.com" "https://gh-proxy.com/https://codeload.github.com"; do
    url="$base/$repo/tar.gz/$sha"
    echo "  [$name] $url"
    rm -f /tmp/sub.tgz
    curl -sL --max-time 300 --speed-limit 1024 --speed-time 60 -o /tmp/sub.tgz "$url"
    sz=$(stat -c %s /tmp/sub.tgz 2>/dev/null || echo 0)
    if [ "$sz" -lt 10240 ]; then echo "    太小 ($sz B)，换源"; continue; fi
    if ! tar -tzf /tmp/sub.tgz >/dev/null 2>&1; then echo "    压缩包损坏，换源"; continue; fi
    rm -rf "$dest"; mkdir -p "$dest"
    tar -xzf /tmp/sub.tgz -C "$dest" --strip-components=1
    mkdir -p "$dest/.git"          # CMake 只检查这个目录是否存在
    echo "    OK $((sz/1024)) KB -> $(ls -A "$dest" | wc -l) 项"
    return 0
  done
  echo "  [$name] !! 全部源失败"
  return 1
}

echo "=== 开始 $(date +%H:%M:%S) ==="
fail=0
echo "$LIST" | while IFS='|' read -r name repo sha; do
  [ -z "${name:-}" ] && continue
  fetch_one "$name" "$repo" "$sha" || fail=$((fail+1))
done

echo "=== 结果统计 $(date +%H:%M:%S) ==="
for d in cli11 libmspack FFmpeg tomlplusplus simde xxHash spdlog fmt utfcpp imgui sdl3 inja o1heap; do
  n=$(ls -A "$TP/$d" 2>/dev/null | wc -l)
  printf "  %-14s %s 项\n" "$d" "$n"
done
du -sh "$TP" 2>/dev/null
echo "=== SUBMODULES DONE $(date +%H:%M:%S) ==="
