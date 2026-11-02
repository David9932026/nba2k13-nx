#!/usr/bin/env bash
OUT=/c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex/nfsmw-nx-main/sdk/out/win-amd64
cd "$OUT" || exit 1
echo "=== 无参数运行 ==="
out=$(./rexglue.exe 2>&1); rc=$?
echo "rc=$rc"
printf '%s\n' "$out" | head -40
echo "=== --help ==="
out=$(./rexglue.exe --help 2>&1); rc=$?
echo "rc=$rc"
printf '%s\n' "$out" | head -60
