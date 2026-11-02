#!/bin/bash
# 装 ucrt64 的 llvm 主体（含 llvm-config / llvm-ar / llvm-nm），给第 ④ 层编 Mesa 用
export PATH=/usr/bin:/ucrt64/bin:$PATH
MSYS=/c/Users/26095/msys64/msys64

echo "=== 0) 清锁（若上次被掐断） ==="
if [ -f "$MSYS/var/lib/pacman/db.lck" ]; then
  if tasklist 2>/dev/null | grep -qi 'pacman.exe'; then
    echo "还有 pacman 进程在跑，放弃"
    exit 1
  fi
  rm -f "$MSYS/var/lib/pacman/db.lck"
  echo "已删 db.lck"
fi

echo "=== 1) 目标包信息 ==="
pacman -Si mingw-w64-ucrt-x86_64-llvm 2>&1 | grep -E '^(版本|Version|仓库|Repository|下载大小|Download Size|安装后大小|Installed Size)' 

echo "=== 2) 安装（--noconfirm） ==="
pacman -S --needed --noconfirm mingw-w64-ucrt-x86_64-llvm 2>&1 | tail -15
rc=${PIPESTATUS[0]}
echo "pacman rc=$rc"

echo "=== 3) 验证 ==="
for t in llvm-config llvm-ar llvm-nm clang; do
  p="/ucrt64/bin/$t.exe"
  if [ -x "$p" ]; then
    echo -n "$t: "
    "$p" --version 2>&1 | head -2 | tr '\n' ' '
    echo
  else
    echo "$t: 缺失"
  fi
done
echo "--- llvm-config 关键输出 ---"
/ucrt64/bin/llvm-config.exe --version 2>/dev/null
/ucrt64/bin/llvm-config.exe --libdir 2>/dev/null
echo "--- 磁盘 ---"
df -h /c | tail -1
