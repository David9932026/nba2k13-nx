#!/usr/bin/env bash
OUT=/c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex/nfsmw-nx-main/sdk/out/win-amd64
cd "$OUT" || exit 1
echo "=== DLL 导出表：含 RtlLeaveCriticalSection 的行 ==="
objdump -p librexruntime.dll 2>/dev/null | grep 'RtlLeaveCriticalSection' | head -5
echo "=== DLL 导出表：__imp__ 开头的裸名数量 ==="
objdump -p librexruntime.dll 2>/dev/null | grep -c '__imp__Rtl\|__imp__Ke\|__imp__Xam'
echo "=== 导入库：裸名函数桩 ==="
nm -g librexruntime.dll.a 2>/dev/null | grep 'RtlLeaveCriticalSection' | head -6
echo "=== 生成代码实际调用的形式（抽样）==="
grep -rh 'RtlLeaveCriticalSection' /c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex/nba2k13app/generated/default/*.cpp 2>/dev/null | head -3
