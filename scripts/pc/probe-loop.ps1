param([int]$Runs = 3, [int]$WaitSec = 120)
$proj = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126'
$dir = Join-Path $proj 'rex\nba2k13app\out\build\win-amd64-release'
$exe = Join-Path $dir 'nba2k13.exe'
$logs = Join-Path $dir 'logs'

for ($r = 1; $r -le $Runs; $r++) {
  $before = @(Get-ChildItem $logs -Filter '*.log' | ForEach-Object { $_.Name })
  $p = Start-Process -FilePath $exe -ArgumentList "--game_data_root=D:\xox360\00007000\C096DB2DDEE83F64054B","--gpu_plugin=xenos","--mnk_mode=1" -WorkingDirectory $dir -PassThru
  $i = 0
  for ($i = 0; $i -lt $WaitSec; $i++) {
    Start-Sleep -Seconds 1
    $p.Refresh()
    if ($p.HasExited) { break }
  }
  $p.Refresh()
  if ($p.HasExited) { $res = "退出码=$($p.ExitCode) 存活=${i}s" } else { $res = "存活满 ${i}s（未崩）"; Stop-Process -Id $p.Id -Force }
  "run $r : $res"
  Start-Sleep -Milliseconds 400
  $log = Get-ChildItem $logs -Filter '*.log' | Where-Object { $before -notcontains $_.Name } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($log) {
    "   日志 $($log.Name)"
    $hits = Select-String -Path $log.FullName -Pattern 'NULLNODE|Unhandled guest access|Jump table out of range|FATAL'
    if ($hits) { $hits | ForEach-Object { "   !! " + $_.Line.Substring(0, [Math]::Min(170, $_.Line.Length)) } } else { "   干净：无 AV / 无 NULLNODE / 无 FATAL" }
  } else { "   没产生新日志" }
}
