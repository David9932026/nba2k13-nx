param(
  [string]$ArgsLine = 'codegen manifest.toml -f --ignore-stamp',
  [int]$TimeoutSec = 1800
)
$exe = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126\rex\nfsmw-nx-main\sdk\out\win-amd64\rexglue.exe'
$wd  = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126\rex\nba2k13'
$out = "$wd\codegen2_stdout.txt"
$err = "$wd\codegen2_stderr.txt"
Remove-Item $out,$err -ErrorAction SilentlyContinue
$sw = [Diagnostics.Stopwatch]::StartNew()
$p = Start-Process -FilePath $exe -ArgumentList $ArgsLine -WorkingDirectory $wd -PassThru `
      -RedirectStandardOutput $out -RedirectStandardError $err -WindowStyle Hidden
$waited = 0
while (-not $p.HasExited -and $waited -lt $TimeoutSec) {
  Start-Sleep -Seconds 2
  $waited += 2
}
$sw.Stop()
if (-not $p.HasExited) {
  $p.Kill()
  "=== 超时 ${TimeoutSec}s，已强杀 ==="
} else {
  "=== 退出码: $($p.ExitCode)  用时: $([math]::Round($sw.Elapsed.TotalSeconds,1))s ==="
}
"--- stderr (tail 40) ---"
if (Test-Path $err) { Get-Content $err -Tail 40 }
"--- 产物统计 ---"
$gen = "$wd\generated"
if (Test-Path $gen) {
  $files = Get-ChildItem $gen -Recurse -File
  $sum = ($files | Measure-Object -Property Length -Sum).Sum
  "文件数=$($files.Count) 总大小=$([math]::Round($sum/1MB,2))MB"
  $files | Sort-Object Length -Descending | Select-Object -First 10 | ForEach-Object { "  $($_.FullName.Replace($gen+'\',''))  $($_.Length)" }
}
