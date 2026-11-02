param(
  [Parameter(Mandatory=$true)][string]$ArgsLine,
  [int]$TimeoutSec = 120,
  [string]$OutFile = "$env:TEMP\rexglue_out.txt",
  [string]$ErrFile = "$env:TEMP\rexglue_err.txt"
)
$exe = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126\rex\nfsmw-nx-main\sdk\out\win-amd64\rexglue.exe'
$dir = Split-Path $exe
Remove-Item $OutFile,$ErrFile -ErrorAction SilentlyContinue
$p = Start-Process -FilePath $exe -ArgumentList $ArgsLine -WorkingDirectory $dir -PassThru `
      -RedirectStandardOutput $OutFile -RedirectStandardError $ErrFile -WindowStyle Hidden
$waited = 0
while (-not $p.HasExited -and $waited -lt $TimeoutSec) {
  Start-Sleep -Seconds 1
  $waited++
}
if (-not $p.HasExited) {
  $p.Kill()
  "=== 超时 ${TimeoutSec}s，已强杀 ==="
} else {
  "=== 退出码: $($p.ExitCode)  用时: ${waited}s ==="
}
"--- stdout ---"
if (Test-Path $OutFile) { Get-Content $OutFile -Raw }
"--- stderr ---"
if (Test-Path $ErrFile) { Get-Content $ErrFile -Raw }
