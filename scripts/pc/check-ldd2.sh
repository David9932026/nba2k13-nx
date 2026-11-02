#!/usr/bin/env bash
OUT=/c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex/nfsmw-nx-main/sdk/out/win-amd64
cd "$OUT" || exit 1
echo "=== ldd 全部缺失项 ==="
ldd ./rexglue.exe 2>&1 | grep -i 'not found'
echo "=== ldd 总数 ==="
ldd ./rexglue.exe 2>&1 | wc -l
echo "=== libstdc++/libgcc/libwinpthread 是否被依赖 ==="
ldd ./rexglue.exe 2>&1 | grep -i 'stdc++\|libgcc\|winpthread\|libc++'
