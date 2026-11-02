#!/usr/bin/env bash
OUT=/c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex/nfsmw-nx-main/sdk/out/win-amd64
echo "=== 产物 ==="
ls -la "$OUT"/rexglue.exe "$OUT"/rexcodegen.exe "$OUT"/librexruntime.dll 2>/dev/null
echo "=== rexglue --help ==="
cd "$OUT" && ./rexglue.exe --help 2>&1 | head -40
echo "=== rc=$? ==="
