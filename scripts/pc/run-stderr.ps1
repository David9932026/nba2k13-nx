param([int]$WaitSec = 130)
$ErrorActionPreference = 'SilentlyContinue'
$dir = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126\rex\nba2k13app\out\build\win-amd64-release'
$out = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126\stderr-assert.txt'
$err = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126\stderr-assert-err.txt'
Remove-Item $out, $err -ErrorAction SilentlyContinue
$p = Start-Process -FilePath "$dir\nba2k13.exe" -ArgumentList @(
  '--game_data_root=D:\xox360\00007000\C096DB2DDEE83F64054B',
  '--gpu_plugin=xenos'
) -WorkingDirectory $dir -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
for ($i = 0; $i -lt $WaitSec; $i++) { Start-Sleep -Seconds 1; $p.Refresh(); if ($p.HasExited) { break } }
$p.Refresh()
if ($p.HasExited) { "退出码=$($p.ExitCode)  存活约 $i 秒" } else { "仍存活 $i 秒"; Stop-Process -Id $p.Id -Force }
'=== stderr ==='
if (Test-Path $err) { Get-Content $err -Tail 40 }
