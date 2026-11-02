param(
  [string]$Script = 'input-all.txt',
  [int]$End = 90,
  [int]$Every = 60,
  [string]$Tag = 'dump'
)
$ErrorActionPreference = 'Continue'
$proj = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126'
$dir  = Join-Path $proj 'rex\nba2k13app\out\build\win-amd64-release'
Get-Process nba2k13 -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

$root = 'C:\Users\26095\Documents\nba2k13'
$stamp = Get-Date -Format 'HHmmss'
if (Test-Path $root) { Rename-Item $root "C:\Users\26095\Documents\nba2k13_bak_$stamp" }
New-Item -ItemType Directory -Path "$root\B13EBABEBABEBABE\545408A2\00000001" -Force | Out-Null

Get-ChildItem (Join-Path $dir 'guest_output_dump\*.bmp') -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem (Join-Path $dir 'rt_probe_*.bmp') -ErrorAction SilentlyContinue | Remove-Item -Force

$scriptPath = Join-Path $proj $Script
$appArgs = @(
  "--game_data_root=D:\xox360\00007000\C096DB2DDEE83F64054B",
  "--gpu_plugin=xenos",
  "--mnk_mode=1",
  "--no-protect_zero",
  "--mnk_script=$scriptPath"
)
$cmd = "cmd.exe /c set REX_GUEST_OUTPUT_DUMP_EVERY=$Every&& `"$dir\nba2k13.exe`" " + ($appArgs -join ' ')
$r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cmd; CurrentDirectory = $dir }
"pid=$($r.ProcessId) every=$Every end=${End}s"
$started = Get-Date
while (((Get-Date) - $started).TotalSeconds -lt $End) {
  Start-Sleep -Milliseconds 500
  if (-not (Get-Process nba2k13 -ErrorAction SilentlyContinue)) { "process ended at $([int]((Get-Date) - $started).TotalSeconds)s"; break }
}
Get-Process nba2k13 -ErrorAction SilentlyContinue | Stop-Process -Force
"dumps:"
Get-ChildItem (Join-Path $dir 'guest_output_dump\*.bmp') -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum | ForEach-Object { "  go count=$($_.Count) bytes=$($_.Sum)" }
Get-ChildItem (Join-Path $dir 'rt_probe_*.bmp') -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum | ForEach-Object { "  rt count=$($_.Count) bytes=$($_.Sum)" }
