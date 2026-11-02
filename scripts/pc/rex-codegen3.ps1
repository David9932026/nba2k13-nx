param(
  [int]$TimeoutSec = 1800
)
$exe = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126\rex\nfsmw-nx-main\sdk\out\win-amd64\rexglue.exe'
$wd  = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126\rex\nba2k13app'
$out = "$wd\codegen_stdout.txt"
$err = "$wd\codegen_stderr.txt"
Remove-Item $out,$err -ErrorAction SilentlyContinue
$sw = [Diagnostics.Stopwatch]::StartNew()
# 放宽单文件上限到 2 MB（那两个巨型函数各约 1.58 MB），强制生成
$args = 'codegen nba2k13_manifest.toml -f --ignore-stamp --max_file_size_bytes=2097152'
$p = Start-Process -FilePath $exe -ArgumentList $args -WorkingDirectory $wd -PassThru `
      -RedirectStandardOutput $out -RedirectStandardError $err -WindowStyle Hidden
$waited = 0
while (-not $p.HasExited -and $waited -lt $TimeoutSec) {
  Start-Sleep -Seconds 2
  $waited += 2
}
$sw.Stop()
if (-not $p.HasExited) { $p.Kill(); "=== 超时 ${TimeoutSec}s，已强杀 ===" }
else { "=== 退出码: $($p.ExitCode)  用时: $([math]::Round($sw.Elapsed.TotalSeconds,1))s ===" }
'--- stderr (tail 30) ---'
if (Test-Path $err) { Get-Content $err -Tail 30 }
'--- 产物统计 ---'
$gen = Join-Path $wd 'generated\default'
if (Test-Path $gen) {
  $files = Get-ChildItem $gen -Recurse -File
  "文件数=$($files.Count) 总大小=$([math]::Round((($files | Measure-Object -Property Length -Sum).Sum)/1MB,2))MB"
  '最大的 6 个：'
  $files | Sort-Object Length -Descending | Select-Object -First 6 | ForEach-Object { "  $($_.Name)  $([math]::Round($_.Length/1KB))KB" }
}
