#!/usr/bin/env bash
export PATH=/ucrt64/bin:/usr/bin:$PATH
echo "=== 安装 lld $(date +%H:%M:%S) ==="
pacman -S --noconfirm mingw-w64-ucrt-x86_64-lld 2>&1 | tail -12
echo "rc=$?"
ls -la /ucrt64/bin/ld.lld.exe /ucrt64/bin/lld.exe 2>/dev/null
