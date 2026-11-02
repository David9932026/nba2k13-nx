#!/usr/bin/env bash
OUT=/c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex/nfsmw-nx-main/sdk/out/win-amd64
cd "$OUT" || exit 1
obj=$(find . -name 'xboxkrnl_rtl.cpp.obj' | head -1)
echo "obj=$obj"
echo "=== 裸名符号 ==="
nm "$obj" 2>/dev/null | grep 'RtlEnterCriticalSection' | head -8
echo "=== 定义型（T/D）符号 ==="
nm --defined-only "$obj" 2>/dev/null | grep -c 'RtlEnterCriticalSection'
echo "=== rexruntime 目标是否有 .def 生成 ==="
find . -name '*.def' 2>/dev/null | head -5
echo "=== rexruntime.dll 导出总数 ==="
objdump -p librexruntime.dll 2>/dev/null | grep -cE '^\s+\[[0-9]+\]'
