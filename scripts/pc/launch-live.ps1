param(
  [string]$Script = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126\input-live.txt',
  [switch]$KeepSave,
  [int]$Attempts = 5
)
$proj = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126'
$dir = Join-Path $proj 'rex\nba2k13app\out\build\win-amd64-release'
$logs = Join-Path $dir 'logs'
Get-Process nba2k13 -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 3
if (-not $KeepSave) {
  $root = 'C:\Users\26095\Documents\nba2k13'
  $stamp = Get-Date -Format 'HHmmss'
  if (Test-Path $root) {
    Rename-Item $root "C:\Users\26095\Documents\nba2k13_bak_$stamp"
  }
  New-Item -ItemType Directory -Path "$root\B13EBABEBABEBABE\545408A2\00000001" -Force | Out-Null
  "save rotated -> C:\Users\26095\Documents\nba2k13_bak_$stamp"
}
$args = @(
  '--game_data_root=D:\xox360\00007000\C096DB2DDEE83F64054B',
  '--gpu_plugin=xenos', '--mnk_mode=1', '--no-protect_zero',
  "--mnk_script=$Script"
)
for ($a = 1; $a -le $Attempts; $a++) {
  $before = @(Get-ChildItem $logs -Filter '*.log' | ForEach-Object { $_.Name })
  $p = Start-Process -FilePath (Join-Path $dir 'nba2k13.exe') -ArgumentList $args -WorkingDirectory $dir -PassThru
  $ok = $true
  for ($t = 0; $t -lt 10; $t++) {
    Start-Sleep -Seconds 1
    $p.Refresh()
    if ($p.HasExited) { $ok = $false; break }
  }
  $log = Get-ChildItem $logs -Filter '*.log' | Where-Object { $before -notcontains $_.Name } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($ok) {
    "pid=$($p.Id) alive after 10s (attempt $a) log=$($log.Name) start=$($p.StartTime.ToString('HH:mm:ss'))"
    exit 0
  }
  "attempt $a died early (log=$($log.Name)); retrying"
  Start-Sleep -Seconds 3
}
"all attempts failed"
exit 1
