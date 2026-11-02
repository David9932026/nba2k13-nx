param(
  [string]$At = '35,50,65,80,95,110',
  [string]$Script = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126\input-all.txt',
  [string]$Tag = 'tl'
)
$AtList = @($At.Split(',') | ForEach-Object { [int]$_ })
$ErrorActionPreference = 'Continue'
$proj = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126'
$exe  = Join-Path $proj 'rex\nba2k13app\out\build\win-amd64-release\nba2k13.exe'
$runDir = Split-Path $exe
Get-Process nba2k13 -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

$root = 'C:\Users\26095\Documents\nba2k13'
$stamp = Get-Date -Format 'HHmmss'
if (Test-Path $root) { Rename-Item $root "C:\Users\26095\Documents\nba2k13_bak_$stamp" }
New-Item -ItemType Directory -Path "$root\B13EBABEBABEBABE\545408A2\00000001" -Force | Out-Null

$argList = @(
  '--game_data_root=D:\xox360\00007000\C096DB2DDEE83F64054B',
  '--gpu_plugin=xenos','--mnk_mode=1','--no-protect_zero',"--mnk_script=$Script"
)
$proc = Start-Process -FilePath $exe -ArgumentList $argList -WorkingDirectory $runDir -PassThru
"pid=$($proc.Id)"
$started = Get-Date

$gdb = 'C:\Users\26095\msys64\msys64\ucrt64\bin\gdb.exe'
$gdbFile = Join-Path $proj 'tl.gdb'
Set-Content -Path $gdbFile -Encoding ascii -Value @(
  'set pagination off',
  'set height 0',
  'set print frame-arguments none',
  'thread apply all bt 14',
  'detach',
  'quit'
)

foreach ($t in $AtList) {
  while (((Get-Date) - $started).TotalSeconds -lt $t) {
    if ($proc.HasExited) { break }
    Start-Sleep -Milliseconds 400
  }
  if ($proc.HasExited) { "exited before ${t}s"; break }
  $out = Join-Path $proj "stack-$Tag-$t.txt"
  & $gdb -batch -x $gdbFile -p $proc.Id 2>&1 | Out-File -FilePath $out -Encoding utf8
  "sample ${t}s -> $out"
}

if (-not $proc.HasExited) { $proc.Kill(); "killed" }
