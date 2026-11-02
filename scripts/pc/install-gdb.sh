#!/bin/bash
export PATH=/ucrt64/bin:/usr/bin:$PATH
pacman -S --noconfirm --needed mingw-w64-ucrt-x86_64-gdb 2>&1 | tail -8
ls -la /ucrt64/bin/gdb.exe 2>/dev/null
