cd /c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex/nba2k13app/out/build/win-amd64-release
export PATH="/c/Users/26095/msys64/msys64/ucrt64/bin:$PATH"
cat > /tmp/crash.gdb <<'EOF'
set pagination off
set confirm off
run --game_data_root=D:\\xox360\\00007000\\C096DB2DDEE83F64054B --gpu_plugin=xenos --mnk_mode=1 --no-protect_zero --mnk_script=C:\\Users\\26095\\cola\\coding-cola\\project-20261028-112651-101fe126\\input-live.txt
bt 40
info threads
EOF
gdb --batch -x /tmp/crash.gdb ./nba2k13.exe 2>&1 | tail -60
