param(
  [int]$Rounds = 6,
  [int]$WaitSec = 45,
  [string]$Script = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126\input-script3.txt',
  [int]$CodegenTimeoutSec = 600
)
$ErrorActionPreference = 'Continue'
$proj = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126'
$bash = 'C:\Users\26095\msys64\msys64\usr\bin\bash.exe'
$logs = "$proj\rex\nba2k13app\out\build\win-amd64-release\logs"

for ($r = 1; $r -le $Rounds; $r++) {
  Write-Output "########## round $r  $(Get-Date -Format 'HH:mm:ss') ##########"

  Write-Output "--- codegen ---"
  $cg = & powershell -NoProfile -ExecutionPolicy Bypass -File "$proj\rex-cg-verify.ps1" -TimeoutSec $CodegenTimeoutSec 2>&1 | Out-String
  $cg -split "`r?`n" | Where-Object { $_ -match 'summary|Done in|Failed|Unresolved' } | Select-Object -First 5 | ForEach-Object { "  $_" }
  if ($cg -match 'Failed to parse|Failed to load manifest') { Write-Output "!! codegen 失败"; break }
  Get-Process rexglue -ErrorAction SilentlyContinue | Stop-Process -Force

  # codegen 会覆盖生成代码，重新打补丁
  Write-Output "--- gen patches ---"
  & powershell -NoProfile -ExecutionPolicy Bypass -File "$proj\apply-gen-patches.ps1" 2>&1 | ForEach-Object { "  $_" }

  Write-Output "--- build ---"
  $bl = & $bash -lc "cd /c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126 && JOBS=8 bash build-app.sh" 2>&1 | Out-String
  $bl -split "`r?`n" | Where-Object { $_ -match 'error|Linking CXX executable|FAILED|产物' } | Select-Object -Last 4 | ForEach-Object { "  $_" }
  if ($bl -match 'ninja: build stopped') { Write-Output "!! 构建失败"; break }

  Write-Output "--- 脚本输入跑一轮（$WaitSec 秒） ---"
  $before = @(Get-ChildItem $logs -Filter '*.log' | ForEach-Object { $_.Name })
  & powershell -NoProfile -ExecutionPolicy Bypass -Command "& '$proj\drive-script.ps1' -WaitSec $WaitSec -Shots @() -Script '$Script' -Tag iter$r" 2>&1 |
    Where-Object { $_ -match 'exit=|alive|mnk-script\] t=' } | Select-Object -Last 4 | ForEach-Object { "  $_" }

  $log = Get-ChildItem $logs -Filter '*.log' | Where-Object { $before -notcontains $_.Name } |
         Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $log) { Write-Output "!! 没有新日志"; break }
  $hits = @(Select-String -Path $log.FullName -Pattern 'Call to invalid or unregistered function at guest address 0x([0-9A-Fa-f]{8})|Unhandled guest access violation|Jump table out of range')
  if ($hits.Count -eq 0) { Write-Output ">>> 干净：无未登记地址 / 无 AV"; break }
  Write-Output "  命中 $($hits.Count) 条:"
  $hits | Select-Object -First 4 | ForEach-Object { "   " + $_.Line.Substring([Math]::Max(0, $_.Line.Length - 110)) }

  $add = & powershell -NoProfile -ExecutionPolicy Bypass -File "$proj\add-hole.ps1" 2>&1 | Out-String
  $add -split "`r?`n" | Where-Object { $_ -match '0x|写入|落' } | Select-Object -First 4 | ForEach-Object { "  $_" }
  if ($add -match '没有未登记地址|取不到地址') { Write-Output ">>> 无新地址可补（可能是 AV，不是缺函数）"; break }
}
Write-Output "=== 迭代结束 $(Get-Date -Format 'HH:mm:ss') ==="
