#!/usr/bin/env bash
# 拉 rexglue-sdk（含子模块）到 rex/rexglue-sdk —— HTTP/1.1 + 多镜像重试
set -u
export PATH=/ucrt64/bin:/usr/bin:$PATH
REX="/c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex"
COMMIT="c94f5ebdcb3c9d1a460ca48e04f9758448f8d518"

git config --global http.version HTTP/1.1
git config --global http.postBuffer 524288000
git config --global core.compression 0
git config --global http.lowSpeedLimit 0
git config --global http.lowSpeedTime 999999
echo "[0] git 已切到 HTTP/1.1，关闭传输压缩"

PROXIES=(
  "https://ghfast.top/https://github.com/"
  "https://gh-proxy.com/https://github.com/"
  "https://github.com/"
)

cd "$REX" || exit 1
if [ ! -d rexglue-sdk/.git ]; then
  rm -rf rexglue-sdk
  mkdir -p rexglue-sdk && cd rexglue-sdk || exit 1
  git init -q
  git remote add origin https://github.com/rexglue/rexglue-sdk.git
else
  cd rexglue-sdk || exit 1
fi

ok=0
for P in "${PROXIES[@]}"; do
  for attempt in 1 2; do
    git config --global url."${P}".insteadOf "https://github.com/"
    echo "[1] 尝试 $attempt 镜像=${P} $(date +%H:%M:%S)"
    if git fetch --depth 1 origin "$COMMIT"; then ok=1; break 2; fi
    echo "    失败，清理残留"
    rm -f .git/shallow .git/FETCH_HEAD
    git gc --prune=now -q 2>/dev/null
    sleep 3
  done
done
[ "$ok" = "1" ] || { echo "所有镜像 fetch 都失败"; exit 1; }

git checkout -q FETCH_HEAD || exit 1
echo "[2] checkout 完成 $(date +%H:%M:%S)"

echo "[3] 子模块 $(date +%H:%M:%S)"
for P in "${PROXIES[@]}"; do
  git config --global url."${P}".insteadOf "https://github.com/"
  echo "    用镜像 ${P}"
  if git submodule update --init --recursive --depth 1; then echo "    子模块 OK"; break; fi
  echo "    子模块失败，换镜像"
  sleep 3
done

echo "[4] 结果 $(date +%H:%M:%S)"
du -sh "$REX/rexglue-sdk" 2>/dev/null
du -sh "$REX/rexglue-sdk/thirdparty" 2>/dev/null
ls "$REX/rexglue-sdk/thirdparty" 2>/dev/null | head -30
echo "=== CLONE DONE $(date +%H:%M:%S) ==="
