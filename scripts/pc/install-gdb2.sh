#!/bin/bash
export PATH=/ucrt64/bin:/usr/bin:$PATH
M=/etc/pacman.d/mirrorlist.mingw
[ -f "$M" ] && cp "$M" "$M.bak-cola" 2>/dev/null
cat > /etc/pacman.d/mirrorlist.mingw <<'EOF'
Server = https://mirrors.tuna.tsinghua.edu.cn/msys2/mingw/ucrt64
Server = https://mirrors.ustc.edu.cn/msys2/mingw/ucrt64
EOF
for i in 1 2 3; do
  echo "=== 第 $i 次尝试 ==="
  pacman -S --noconfirm --needed mingw-w64-ucrt-x86_64-gdb 2>&1 | tail -4
  if [ -x /ucrt64/bin/gdb.exe ]; then echo "OK 已安装"; break; fi
  sleep 5
done
ls -la /ucrt64/bin/gdb.exe 2>/dev/null || echo "仍未安装"
