#!/bin/bash
export PATH=/ucrt64/bin:/usr/bin:$PATH
D=/c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex/nfsmw-nx-main/sdk/out/win-amd64
echo "=== librexgpu-xenos.dll 依赖 ==="
objdump -p "$D/librexgpu-xenos.dll" | grep -i "DLL Name" | sort -u
echo "=== 导出 rex_gpu_* ==="
objdump -p "$D/librexgpu-xenos.dll" | grep -i "rex_gpu" | head -5
echo "=== nba2k13.exe 依赖 ==="
objdump -p /c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex/nba2k13app/out/build/win-amd64-release/nba2k13.exe | grep -i "DLL Name" | sort -u
