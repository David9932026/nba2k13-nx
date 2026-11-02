param([int]$WaitSec = 75)
$dir = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126\rex\nba2k13app\out\build\win-amd64-release'
$exe = Join-Path $dir 'nba2k13.exe'
$logs = Join-Path $dir 'logs'
$before = @(Get-ChildItem $logs -Filter '*.log' | ForEach-Object { $_.Name })

$p = Start-Process -FilePath $exe -ArgumentList "--game_data_root=D:\xox360\00007000\C096DB2DDEE83F64054B","--gpu_plugin=xenos","--mnk_mode=1","--log_verbose=1" -WorkingDirectory $dir -PassThru
$i = 0
for ($i = 0; $i -lt $WaitSec; $i++) {
  Start-Sleep -Seconds 1
  $p.Refresh()
  if ($p.HasExited) { break }
}
$p.Refresh()
if ($p.HasExited) { "exit=$($p.ExitCode) alive=${i}s" } else { "still alive ${i}s"; Stop-Process -Id $p.Id -Force }
Start-Sleep -Milliseconds 400
$log = Get-ChildItem $logs -Filter '*.log' | Where-Object { $before -notcontains $_.Name } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $log) { "no new log"; exit 0 }
"log=$($log.FullName) size=$($log.Length)"
