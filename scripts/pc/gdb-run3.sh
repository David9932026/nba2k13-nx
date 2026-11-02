#!/bin/bash
export PATH=/ucrt64/bin:/usr/bin:$PATH
cd /c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex/nba2k13app/out/build/win-amd64-release || exit 1
gdb -batch \
  -ex "set pagination off" \
  -ex "set confirm off" \
  -ex "run" \
  -ex "echo \n=== DISASM AROUND PC ===\n" \
  -ex "x/16i \$pc-56" \
  -ex "echo \n=== REGS ===\n" \
  -ex "p/x \$r11" \
  -ex "p/x \$rdi" \
  -ex "p/x \$r9" \
  -ex "p/x \$r10" \
  -ex "echo \n=== 目标地址是否可读 ===\n" \
  -ex "x/2xw 0x1a21002a0" \
  -ex "echo \n=== 物理镜像区 ===\n" \
  -ex "x/2xw 0x1021002a0" \
  -ex "echo \n=== BT ===\n" \
  -ex "bt 6" \
  --args ./nba2k13.exe --game_data_root=D:/xox360/00007000/C096DB2DDEE83F64054B --gpu_plugin=xenos 2>&1 | tail -50
