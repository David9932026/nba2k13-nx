#!/bin/bash
# 用 trace 日志跑一次 codegen，只为了看 0x823B76B0 这张跳转表的识别过程
export PATH=/ucrt64/bin:/usr/bin:$PATH
PROJ="/c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126"
REXGLUE="$PROJ/rex/nfsmw-nx-main/sdk/out/win-amd64/rexglue.exe"
MANIFEST="$PROJ/rex/nba2k13app/nba2k13_manifest.toml"
LOG="/c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/cg-trace.log"
cd "$PROJ/rex/nba2k13app" || exit 1
"$REXGLUE" codegen "$MANIFEST" --log_level=trace --ignore-stamp > "$LOG" 2>&1
echo "exit=$?"
echo "--- 与 823B76B0 相关的 trace ---"
grep -i '823B76B0' "$LOG" | head -40
echo "--- detectJumpTable 失败/截断行 ---"
grep -i 'detectJumpTable' "$LOG" | grep -i 'fail\|invalid\|not 4-byte\|null' | head -20
