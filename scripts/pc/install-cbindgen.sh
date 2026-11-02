#!/bin/bash
export CARGO_HOME=/c/Users/26095/.cargo
export RUSTUP_HOME=/c/Users/26095/.rustup
export PATH=/c/Users/26095/.cargo/bin:$PATH
echo "cargo: $(which cargo)"
cargo install cbindgen --locked 2>&1 | tail -8
echo "--- 检查产物 ---"
ls -la /c/Users/26095/.cargo/bin/ | grep -i cbindgen
