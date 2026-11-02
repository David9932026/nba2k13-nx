#!/bin/bash
export PATH=/ucrt64/bin:/usr/bin:$PATH
cd /c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/switch-build/mesa-switch
H=1a8c1a66d6fd8d65f10107c4627ffc3606ba5631
for i in 1 2 3 4; do
  git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=40 fetch --depth 1 origin $H && break
  echo "retry $i"; sleep 3
done
git checkout -q $H 2>&1 | tail -2
git log --oneline -1
git apply --check ../../rex/nfsmw-nx-main/mesa/mesa-switch-nfsmw.patch && echo PATCH_OK