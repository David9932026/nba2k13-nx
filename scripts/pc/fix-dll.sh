#!/usr/bin/env bash
OUT=/c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex/nfsmw-nx-main/sdk/out/win-amd64
cp -v /ucrt64/bin/libgcc_s_seh-1.dll /ucrt64/bin/libwinpthread-1.dll /ucrt64/bin/libstdc++-6.dll "$OUT"/ 2>&1 | tail -3
cd "$OUT" || exit 1
echo "=== 运行（带 DLL）==="
out=$(./rexglue.exe --help 2>&1); rc=$?
echo "rc=$rc"
printf '%s\n' "$out" | head -50
