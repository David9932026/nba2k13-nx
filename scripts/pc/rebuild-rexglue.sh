#!/usr/bin/env bash
set -u
export PATH=/ucrt64/bin:/usr/bin:$PATH
cd /c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex/nba2k13app || exit 1
echo "=== 重建 rexglue.exe（带 _Exit 补丁）$(date +%H:%M:%S) ==="
cmake --build out/build/win-amd64-release --target rexglue -j 8 > /tmp/rexglue-rebuild.log 2>&1
rc=$?
echo "rc=$rc  $(date +%H:%M:%S)"
tail -4 /tmp/rexglue-rebuild.log
grep -E 'error:' /tmp/rexglue-rebuild.log | head -5
