param([int]$TimeoutSec = 600)
$exe = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126\rex\nfsmw-nx-main\sdk\out\win-amd64\rexglue.exe'
$wd  = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126\rex\nba2k13app'
$out = "$wd\cg_out.txt"; $err = "$wd\cg_err.txt"
Remove-Item $out,$err -ErrorAction SilentlyContinue
$sw = [Diagnostics.Stopwatch]::StartNew()
$p = Start-Process -FilePath $exe -ArgumentList "codegen $wd\nba2k13_manifest.toml --max_file_size_bytes=1048576 --ignore-stamp" -WorkingDirectory $wd -PassThru -RedirectStandardOutput $out -RedirectStandardError $err -WindowStyle Hidden
$waited = 0
while (-not $p.HasExited -and $waited -lt $TimeoutSec) { Start-Sleep -Seconds 1; $waited++ }
$sw.Stop()
if (-not $p.HasExited) { "=== 超时 ${TimeoutSec}s，仍卡住 ==="; $p.Kill() }
else { "=== 退出码: $($p.ExitCode)  用时: $([math]::Round($sw.Elapsed.TotalSeconds,1))s ===" }
'--- stderr 尾部 ---'
if (Test-Path $err) { Get-Content $err -Tail 8 }
'--- stamp 时间 ---'
Get-ChildItem "$wd\generated\default\codegen.*" -Force -ErrorAction SilentlyContinue | ForEach-Object { "  $($_.Name)  $($_.LastWriteTime.ToString('HH:mm:ss'))" }

