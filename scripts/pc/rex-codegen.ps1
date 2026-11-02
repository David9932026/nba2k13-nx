param(
  [string]$ArgsLine = 'codegen manifest.toml',
  [int]$TimeoutSec = 900
)
$exe = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126\rex\nfsmw-nx-main\sdk\out\win-amd64\rexglue.exe'
$wd  = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126\rex\nba2k13'
$out = "$wd\codegen_stdout.txt"
$err = "$wd\codegen_stderr.txt"
Remove-Item $out,$err -ErrorAction SilentlyContinue
$p = Start-Process -FilePath $exe -ArgumentList $ArgsLine -WorkingDirectory $wd -PassThru `
      -RedirectStandardOutput $out -RedirectStandardError $err -WindowStyle Hidden
$waited = 0
while (-not $p.HasExited -and $waited -lt $TimeoutSec) {
  Start-Sleep -Seconds 2
  $waited += 2
}
if (-not $p.HasExited) {
  $p.Kill()
  "=== 超时 ${TimeoutSec}s，已强杀 ==="
} else {
  "=== 退出码: $($p.ExitCode)  用时: ${waited}s ==="
}
"--- stdout ---"
if (Test-Path $out) { Get-Content $out -Raw }
"--- stderr ---"
if (Test-Path $err) { Get-Content $err -Raw }
