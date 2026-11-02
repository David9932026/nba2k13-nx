#!/bin/bash
export PATH=/ucrt64/bin:/usr/bin:/c/Users/26095/.cargo/bin:$PATH
export MSYSTEM=UCRT64
export DEVKITPRO=/opt/devkitpro
export RUSTUP_TOOLCHAIN=stable-x86_64-pc-windows-gnu
export MESA_SWITCH_RUSTC=/c/Users/26095/.cargo/bin/rustc.exe
export MESA_SWITCH_BINDGEN=/c/Users/26095/.cargo/bin/bindgen.exe
export ALLOW_DIRTY=1
export SOURCE_DATE_EPOCH=1761800000
export PYTHON=python
cd /c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/switch-build/mesa-switch
bash build-unified.sh
echo "BUILD_EXIT=$?"