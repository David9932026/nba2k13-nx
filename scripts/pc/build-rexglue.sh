#!/usr/bin/env bash
# 把上游 thirdparty 合并进 nfsmw-nx 的 sdk/thirdparty，然后编译 rexglue 代码生成器
set -u
export PATH=/ucrt64/bin:/usr/bin:$PATH
BASE="/c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex"
PORT="$BASE/nfsmw-nx-main"
UP="$BASE/rexglue-sdk-src"

echo "=== 0) 检查 ==="
[ -d "$UP/thirdparty" ] || { echo "缺少 $UP/thirdparty"; exit 1; }
[ -d "$PORT/sdk" ] || { echo "缺少 $PORT/sdk"; exit 1; }

echo "=== 1) 合并 thirdparty（不覆盖已有文件）==="
python - "$UP/thirdparty" "$PORT/sdk/thirdparty" <<'PY'
import os, shutil, sys
src, dst = sys.argv[1], sys.argv[2]
copied = kept = 0
need_git = {'cli11','libmspack','FFmpeg','tomlplusplus','simde','xxHash','spdlog','fmt','utfcpp','imgui','sdl3','inja','o1heap'}
for dirpath, dirnames, filenames in os.walk(src):
    dirnames[:] = [d for d in dirnames if d != '.git']
    for name in filenames:
        if name == '.git':
            continue
        s = os.path.join(dirpath, name)
        d = os.path.join(dst, os.path.relpath(s, src))
        if os.path.exists(d):
            kept += 1
            continue
        os.makedirs(os.path.dirname(d), exist_ok=True)
        try:
            shutil.copy2(s, d)
            copied += 1
        except OSError as e:
            print('  跳过', s, e)
print(f'  复制 {copied}，保留原有 {kept}')
for n in need_git:
    os.makedirs(os.path.join(dst, n, '.git'), exist_ok=True)
print('  已为必需子模块补 .git 占位')
PY

du -sh "$PORT/sdk/thirdparty"

echo "=== 2) 目录自检 ==="
for d in cli11 libmspack FFmpeg tomlplusplus simde xxHash spdlog fmt utfcpp imgui sdl3; do
  n=$(ls -A "$PORT/sdk/thirdparty/$d" 2>/dev/null | wc -l)
  printf "  %-14s %s 项\n" "$d" "$n"
  [ "$n" -lt 2 ] && echo "    !! 内容不足"
done

echo "=== 3) cmake 配置 $(date +%H:%M:%S) ==="
cd "$PORT" || exit 1
rm -rf out/host
cmake -S sdk -B out/host -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
  -DREXGLUE_USE_VULKAN=OFF \
  -DREXGLUE_USE_D3D12=OFF \
  -DREXGLUE_BUILD_TESTS=OFF \
  -DREXGLUE_ENABLE_TRACY=OFF 2>&1 | tail -n 50
rc=${PIPESTATUS[0]}
if [ "$rc" != "0" ]; then echo "!! cmake 配置失败 rc=$rc"; exit 1; fi

echo "=== 4) 编译 rexglue $(date +%H:%M:%S) ==="
cmake --build out/host --target rexglue 2>&1 | tail -n 80
rc=${PIPESTATUS[0]}
echo "=== 5) 结果 rc=$rc $(date +%H:%M:%S) ==="
find out/host -maxdepth 4 -name 'rexglue*' | head -20
ls -la out/host/*.exe 2>/dev/null
echo "=== BUILD DONE ==="
