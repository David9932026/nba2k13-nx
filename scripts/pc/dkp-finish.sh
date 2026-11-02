#!/usr/bin/env bash
export PATH=/ucrt64/bin:/usr/bin:$PATH
echo "=== 补装 make + switch-ffmpeg $(date +%H:%M:%S) ==="
for p in make switch-ffmpeg; do
  echo "--- $p ---"
  for try in 1 2 3; do
    pacman -S --noconfirm --needed "$p" 2>&1 | tail -4
    if pacman -Q "$p" >/dev/null 2>&1; then echo "OK: $p"; break; fi
    echo "重试 $try"
    sleep 2
  done
done
echo "=== 核对 ==="
pacman -Q make switch-ffmpeg 2>&1
echo "=== devkitA64 ==="
/opt/devkitpro/devkitA64/bin/aarch64-none-elf-gcc --version | head -1
