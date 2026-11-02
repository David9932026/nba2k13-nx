param(
  [int]$WaitSec = 70,
  [string]$Script = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126\input-all.txt',
  [string]$Tag = 'main',
  [int]$Samples = 6
)

$ErrorActionPreference = 'Stop'
$dir = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126'
$exe = Join-Path $dir 'rex\nba2k13app\out\build\win-amd64-release\nba2k13.exe'
Set-Location (Split-Path $exe)

$proc = Start-Process -FilePath $exe -ArgumentList @(
  '--game_data_root=D:\xox360\00007000\C096DB2DDEE83F64054B',
  '--gpu_plugin=xenos',
  '--mnk_mode=1',
  "--mnk_script=$Script",
  '--no-protect_zero'
) -PassThru
"pid=$($proc.Id)"

Start-Sleep -Seconds $WaitSec
if ($proc.HasExited) { "exited early code=$($proc.ExitCode)"; exit 1 }

$gdb = 'C:\Users\26095\msys64\msys64\ucrt64\bin\gdb.exe'
$gdbFile = Join-Path $dir 'main.gdb'
Set-Content -Path $gdbFile -Encoding ascii -Value @(
  'set pagination off',
  'set height 0',
  'thread find Main XThread',
  'bt 8',
  'detach',
  'quit'
)
$out = Join-Path $dir "main-$Tag.txt"
Set-Content -Path $out -Value '' -Encoding utf8
for ($i = 1; $i -le $Samples; $i++) {
  if ($proc.HasExited) { "exited before sample $i"; break }
  Add-Content -Path $out -Value "===== sample $i ====="
  & $gdb -batch -x $gdbFile -p $proc.Id 2>&1 | Out-File -FilePath $out -Encoding utf8 -Append
  Start-Sleep -Milliseconds 250
}
"dumped -> $out"
if (-not $proc.HasExited) { $proc.Kill(); "killed" }
