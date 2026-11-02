export PATH=/ucrt64/bin:$PATH
cd /d/cola-projects/project-20261028-112651-101fe126/rex/nba2k13app/out/build/win-vk
ninja -j 4 > /d/cola-projects/pcb.log 2>&1
echo "EXIT=$?" >> /d/cola-projects/pcb.log
grep -E "error|EXIT|Linking" /d/cola-projects/pcb.log | head -20
