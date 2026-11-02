#!/bin/bash
export PATH=/ucrt64/bin:/usr/bin:$PATH
cd /c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex/nba2k13app/out/build/win-amd64-release || exit 1
gdb -batch \
  -ex "set pagination off" \
  -ex "set confirm off" \
  -ex "run" \
  -ex "echo \n=== 物理视图 0x2021002a0 读 ===\n" \
  -ex "x/2xw 0x2021002a0" \
  -ex "echo \n=== 物理视图 0x2021002a0 写 ===\n" \
  -ex "set {int}0x2021002a0 = 7" \
  -ex "x/1xw 0x2021002a0" \
  -ex "echo \n=== 镜像视图 0x1a21002a0 写 ===\n" \
  -ex "set {int}0x1a21002a0 = 7" \
  -ex "x/1xw 0x1a21002a0" \
  -ex "echo \n=== 0xA0 低端 写 ===\n" \
  -ex "set {int}0x1a0010000 = 7" \
  -ex "echo \n=== 0xA0 中段 0xA1800000 写 ===\n" \
  -ex "set {int}0x1a1800000 = 7" \
  -ex "echo \n=== 结束 ===\n" \
  --args ./nba2k13.exe --game_data_root=D:/xox360/00007000/C096DB2DDEE83F64054B --gpu_plugin=xenos 2>&1 | tail -30
