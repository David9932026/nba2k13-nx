param([int]$WaitSec = 100)
$ErrorActionPreference = 'SilentlyContinue'
$dir = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126\rex\nba2k13app\out\build\win-amd64-release'
$logs = Join-Path $dir 'logs'
$before = @(Get-ChildItem $logs -Filter '*.log' | ForEach-Object { $_.Name })
$p = Start-Process -FilePath "$dir\nba2k13.exe" -ArgumentList @(
  '--game_data_root=D:\xox360\00007000\C096DB2DDEE83F64054B',
  '--gpu_plugin=xenos',
  '--log_noisy=true'
) -WorkingDirectory $dir -PassThru
for ($i = 0; $i -lt $WaitSec; $i++) { Start-Sleep -Seconds 1; $p.Refresh(); if ($p.HasExited) { break } }
$p.Refresh()
if ($p.HasExited) { "退出码=$($p.ExitCode) 存活=$i 秒" } else { "仍存活 $i 秒"; Stop-Process -Id $p.Id -Force }
Start-Sleep -Milliseconds 300
$log = Get-ChildItem $logs -Filter '*.log' | Where-Object { $before -notcontains $_.Name } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
"日志: $($log.Name)  $([math]::Round($log.Length/1KB,1)) KB"
