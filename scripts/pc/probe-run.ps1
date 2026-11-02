param(
  [int]$WaitSec = 90,
  [string]$GameRoot = "D:\xox360\00007000\C096DB2DDEE83F64054B"
)
$dir = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126\rex\nba2k13app\out\build\win-amd64-release'
$exe = Join-Path $dir 'nba2k13.exe'
$logs = Join-Path $dir 'logs'

$before = @(Get-ChildItem $logs -Filter '*.log' -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })

$p = Start-Process -FilePath $exe -ArgumentList "--game_data_root=$GameRoot", "--gpu_plugin=xenos", "--mnk_mode=1" -WorkingDirectory $dir -PassThru
$i = 0
for ($i = 0; $i -lt $WaitSec; $i++) {
  Start-Sleep -Seconds 1
  $p.Refresh()
  if ($p.HasExited) { break }
}

$p.Refresh()
if ($p.HasExited) { "退出码=$($p.ExitCode)  存活约 $i 秒" }
else {
  "仍存活 $i 秒  CPU=$([math]::Round($p.CPU,1))s  WS=$([math]::Round($p.WorkingSet64/1MB))MB"
  Stop-Process -Id $p.Id -Force
  "已结束进程"
}
Start-Sleep -Milliseconds 300

# 只认本轮新产生的日志，绝不回退到旧日志
$log = Get-ChildItem $logs -Filter '*.log' | Where-Object { $before -notcontains $_.Name } |
       Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $log) {
  "!! 本轮没有新日志产生"
  "=== 探测到的未登记地址 ==="
  "（无）"
  exit 0
}
"日志: $($log.FullName)  ($($log.Length) 字节)"

"=== 探测到的未登记地址 ==="
$addr = Select-String -Path $log.FullName -Pattern 'PROBE unregistered indirect target 0x([0-9A-Fa-f]{8})' -AllMatches |
  ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value.ToUpper() } | Sort-Object -Unique
if ($addr) { $addr | ForEach-Object { "  0x$_" }; "共 $($addr.Count) 个不同地址" }
else { "（无）" }

"=== 其他 critical / error ==="
Select-String -Path $log.FullName -Pattern '\[critical\]|FATAL|\[error\]' | Select-Object -Last 12 | ForEach-Object { $_.Line }
