param(
  [string]$Script = 'input-all.txt',
  [int]$End = 200,
  [string]$Shots = '60,90,120,150,180',
  [string]$Tag = 'full',
  [switch]$KeepSave,
  [string[]]$Extra = @()
)
$ErrorActionPreference = 'Continue'
$proj = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126'
$dir  = Join-Path $proj 'rex\nba2k13app\out\build\win-amd64-release'
Get-Process nba2k13 -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

$root = 'C:\Users\26095\Documents\nba2k13'
if (-not $KeepSave) {
  $stamp = Get-Date -Format 'HHmmss'
  if (Test-Path $root) { Rename-Item $root "C:\Users\26095\Documents\nba2k13_bak_$stamp" }
  New-Item -ItemType Directory -Path "$root\B13EBABEBABEBABE\545408A2\00000001" -Force | Out-Null
}

$scriptPath = Join-Path $proj $Script
$args = @(
  "--game_data_root=D:\xox360\00007000\C096DB2DDEE83F64054B",
  "--gpu_plugin=xenos",
  "--mnk_mode=1",
  "--no-protect_zero",
  "--mnk_script=$scriptPath"
) + $Extra
$cmd = "cmd.exe /c `"$dir\nba2k13.exe`" " + ($args -join ' ')
$r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cmd; CurrentDirectory = $dir }
"pid=$($r.ProcessId) script=$Script end=${End}s extra=$($Extra -join ' ')"
$started = Get-Date

$shotTimes = @($Shots.Split(',') | ForEach-Object { [int]$_ } | Sort-Object)
foreach ($t in $shotTimes) {
  for ($i = 0; $i -lt ($End * 2); $i++) {
    Start-Sleep -Milliseconds 500
    if (-not (Get-Process nba2k13 -ErrorAction SilentlyContinue)) { break }
    if (((Get-Date) - $started).TotalSeconds -ge $t) { break }
  }
  if (-not (Get-Process nba2k13 -ErrorAction SilentlyContinue)) { "dead before ${t}s"; break }
  $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $proj 'snap.ps1') -Tag "$Tag-$t" -DelayMs 400
  $out
}
$alive = Get-Process nba2k13 -ErrorAction SilentlyContinue
if ($alive) {
  "still alive at $([int]((Get-Date) - $started).TotalSeconds)s"
} else { "process ended" }
