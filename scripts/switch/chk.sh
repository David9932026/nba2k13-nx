#!/bin/bash
export PATH=/ucrt64/bin:/usr/bin:$PATH
cd /c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/switch-build/mesa-switch
git log --oneline -2
git rev-parse HEAD
git cat-file -t 1a8c1a66d6f 2>&1
git status -sb | head -3
git apply --check ../../rex/nfsmw-nx-main/mesa/mesa-switch-nfsmw.patch 2>&1 | grep -c 'patch does not apply\|补丁未应用'