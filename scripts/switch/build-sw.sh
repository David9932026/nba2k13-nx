#!/bin/bash
export PATH=/ucrt64/bin:/usr/bin:/opt/devkitpro/tools/bin:$PATH
export DEVKITPRO=/opt/devkitpro
B=/c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex/nba2k13app/out/build/sw
cmake --build $B -j 6 -- -k 50
echo BUILD_EXIT=$?