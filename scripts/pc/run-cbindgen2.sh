#!/bin/bash
export PATH=/c/Users/26095/.cargo/bin:/usr/bin:$PATH
cd "/c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/switch-toolchain/switch-toolchain-verify/cbindgen-test" || exit 1
echo "--- cbindgen 鐗堟湰 ---"
cbindgen --version
echo "--- 鐢熸垚澶存枃浠?---"
cbindgen --crate cbindgen-test --output point.h . 2>&1 | tail -3
if [ -f point.h ]; then
  echo "--- point.h ---"
  cat point.h
else
  echo "鏈敓鎴?point.h"
fi
