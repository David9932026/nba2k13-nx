#!/bin/bash
export PATH=/ucrt64/bin:/usr/bin:$PATH
cd /c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex/nba2k13app/out/build/win-amd64-release || exit 1
gdb -batch \
  -ex "set pagination off" \
  -ex "set confirm off" \
  -ex "handle SIGSEGV nostop noprint pass" \
  -ex "break sub_823DB198" \
  -ex "run" \
  -ex "echo \n=== 跳转表原始内容 (guest 0x823DB19C) ===\n" \
  -ex "x/24wx 0x1823DB19C" \
  -ex "echo \n=== 索引寄存器 r11 ===\n" \
  -ex "p/x \$r11" \
  -ex "bt 3" \
  --args ./nba2k13.exe --game_data_root=D:/xox360/00007000/C096DB2DDEE83F64054B --gpu_plugin=xenos 2>&1 | tail -25
