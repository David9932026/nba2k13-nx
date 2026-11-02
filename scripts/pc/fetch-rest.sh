#!/usr/bin/env bash
# 并行补齐剩余子模块（3 路并发），齐了直接编译
set -u
export PATH=/ucrt64/bin:/usr/bin:$PATH
HERE="/c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126"
TP="$HERE/rex/rexglue-sdk-src/thirdparty"

cat > /tmp/rest.txt <<'EOF'
simde|simd-everywhere/simde|71fd833d9666141edcd1d3c109a80e228303d8d7
fmt|fmtlib/fmt|407c905e45ad75fc29bf0f9bb7c5c2fd3475976f
utfcpp|nemtrif/utfcpp|63d64de49fd6b829f7c8694df5ab2ee625cb7134
imgui|ocornut/imgui|6d910d5487d11ca567b61c7824b0c78c569d62f
sdl3|libsdl-org/SDL|8bf3b7215ad9fc3deb583c6a3a37c6c67f2e24e4
inja|pantor/inja|7d1b4600b68595085a949743331c2e5673f511ea
o1heap|pavel-kirienko/o1heap|388a73fd9007300e5130c5fe352d9ce3288b6dde
EOF

echo "=== 并行下载 $(date +%H:%M:%S) ==="
cat /tmp/rest.txt | while IFS='|' read -r n r s; do echo "$n $r $s"; done | \
  xargs -P 3 -L 1 bash -c 'bash "'"$HERE"'/fetch-one.sh" "$0" "$1" "$2"' 2>&1

echo "=== 下载阶段结束 $(date +%H:%M:%S) ==="
ok=0
for n in cli11 libmspack FFmpeg tomlplusplus simde xxHash spdlog fmt utfcpp imgui sdl3 inja o1heap; do
  if [ -d "$TP/$n/.git" ]; then ok=$((ok+1)); else echo "  仍缺 $n"; fi
done
echo "  就绪 $ok/13"
if [ "$ok" -ne 13 ]; then echo "!! 不齐，先不编译"; exit 1; fi

cd "$HERE" || exit 1
bash build-rexglue.sh
