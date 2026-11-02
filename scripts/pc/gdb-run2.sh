#!/bin/bash
export PATH=/ucrt64/bin:/usr/bin:$PATH
cd /c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex/nba2k13app/out/build/win-amd64-release || exit 1
gdb -batch \
  -ex "set pagination off" \
  -ex "set confirm off" \
  -ex "run" \
  -ex "echo \n=== PC ===\n" \
  -ex "x/2i \$pc" \
  -ex "echo \n=== HOST REGS ===\n" \
  -ex "info registers rax rbx rcx rdx rsi rdi r8 r9 r10 r11 r12 r13 r14 r15" \
  -ex "echo \n=== BACKTRACE ===\n" \
  -ex "bt 8" \
  --args ./nba2k13.exe --game_data_root=D:/xox360/00007000/C096DB2DDEE83F64054B --gpu_plugin=xenos 2>&1 | tail -45
