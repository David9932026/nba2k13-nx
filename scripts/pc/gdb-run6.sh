#!/bin/bash
export PATH=/ucrt64/bin:/usr/bin:$PATH
cd /c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex/nba2k13app/out/build/win-amd64-release || exit 1
gdb -batch \
  -ex "set pagination off" \
  -ex "set confirm off" \
  -ex "handle SIGSEGV nostop noprint pass" \
  -ex "handle SIGTRAP nostop noprint pass" \
  -ex "run" \
  -ex "echo \n=== 停在 ===\n" \
  -ex "p \$_siginfo" \
  -ex "x/8i \$pc-16" \
  -ex "echo \n=== BT ===\n" \
  -ex "bt 12" \
  --args ./nba2k13.exe --game_data_root=D:/xox360/00007000/C096DB2DDEE83F64054B --gpu_plugin=xenos 2>&1 | tail -32
