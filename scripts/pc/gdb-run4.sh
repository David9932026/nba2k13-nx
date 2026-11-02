#!/bin/bash
export PATH=/ucrt64/bin:/usr/bin:$PATH
cd /c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex/nba2k13app/out/build/win-amd64-release || exit 1
gdb -batch \
  -ex "set pagination off" \
  -ex "set confirm off" \
  -ex "run" \
  -ex "echo \n=== 写 0xA2 视图 ===\n" \
  -ex "set {int}0x1a21002a0 = 1" \
  -ex "x/1xw 0x1a21002a0" \
  -ex "echo \n=== 写 0xA0 视图低端 ===\n" \
  -ex "set {int}0x1a0010000 = 1" \
  -ex "echo \n=== 写 physical 视图 ===\n" \
  -ex "set {int}0x1021002a0 = 1" \
  -ex "echo \n=== 写 0xE0 视图 ===\n" \
  -ex "set {int}0x1e21002a0 = 1" \
  -ex "echo \n=== 结束 ===\n" \
  --args ./nba2k13.exe --game_data_root=D:/xox360/00007000/C096DB2DDEE83F64054B --gpu_plugin=xenos 2>&1 | tail -30
