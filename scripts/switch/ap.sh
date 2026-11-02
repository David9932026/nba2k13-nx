#!/bin/bash
export PATH=/ucrt64/bin:/usr/bin:$PATH
cd /c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/switch-build/mesa-switch
git apply ../../rex/nfsmw-nx-main/mesa/mesa-switch-nfsmw.patch && echo APPLIED
git status --short | wc -l
grep -l 'C:/msys64' *.txt *.sh 2>/dev/null