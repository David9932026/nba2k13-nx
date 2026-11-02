#!/bin/bash
export PATH=/ucrt64/bin:/usr/bin:$PATH
cd /c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/switch-build
for i in 1 2 3 4 5; do
  git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=40 clone --depth 1 --no-tags https://github.com/danfromtico/mesa-switch.git mesa-switch && break
  echo "retry $i"; sleep 3
done
cd mesa-switch && git log --oneline -1 && du -sm .