#!/usr/bin/env bash
OUT=/c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex/nfsmw-nx-main/sdk/out/win-amd64
cd "$OUT" || exit 1
echo "=== ldd ==="
ldd ./rexglue.exe 2>&1 | grep -i 'not found\|=>' | head -20
echo "=== 目录内 dll ==="
ls "$OUT" | grep -i '\.dll$' | head
