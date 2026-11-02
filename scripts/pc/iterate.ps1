param(
  [int]$Rounds = 6,
  [int]$WaitSec = 60,
  [int]$CodegenTimeoutSec = 600
)
$ErrorActionPreference = 'Continue'
$proj = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126'
$huecos = "$proj\rex\nba2k13app\huecos.toml"
$bash = 'C:\Users\26095\msys64\msys64\usr\bin\bash.exe'
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Append-Utf8([string]$path, [string]$text) {
  [System.IO.File]::AppendAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

for ($r = 1; $r -le $Rounds; $r++) {
  Write-Output "########## round $r  $(Get-Date -Format 'HH:mm:ss') ##########"

  # ---------- codegen ----------
  Write-Output "--- codegen ---"
  $cg = & powershell -NoProfile -ExecutionPolicy Bypass -File "$proj\rex-cg-verify.ps1" -TimeoutSec $CodegenTimeoutSec 2>&1 | Out-String
  $cg -split "`r?`n" | Where-Object { $_ -match 'done|summary|Failed|Unresolved|error|UNIMPLEMENTED' } | Select-Object -First 8 | ForEach-Object { "  $_" }
  if ($cg -match 'Failed to parse|Failed to load manifest|Failed:') {
    Write-Output "!! codegen 失败，停止本次迭代（不当作收敛）"
    break
  }
  Get-Process rexglue -ErrorAction SilentlyContinue | Stop-Process -Force

  # ---------- build ----------
  Write-Output "--- build ---"
  $bl = & $bash -lc "cd /c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126 && JOBS=8 bash build-app.sh" 2>&1 | Out-String
  $bl -split "`r?`n" | Where-Object { $_ -match 'error|Linking CXX executable|FAILED' } | Select-Object -Last 5 | ForEach-Object { "  $_" }

  $exe = "$proj\rex\nba2k13app\out\build\win-amd64-release\nba2k13.exe"
  if (-not (Test-Path $exe)) { Write-Output "!! 没有产物，停止"; break }
  $ei = Get-Item $exe
  Write-Output "  产物 $($ei.Length) 字节  $($ei.LastWriteTime.ToString('HH:mm:ss'))"
  if ($bl -match 'FAILED|ninja: build stopped') { Write-Output "!! 构建失败，停止"; break }

  # ---------- probe ----------
  Write-Output "--- probe ---"
  $out = & powershell -NoProfile -ExecutionPolicy Bypass -File "$proj\probe-run.ps1" -WaitSec $WaitSec 2>&1
  $out | Select-Object -First 10 | ForEach-Object { "  $_" }
  $found = @()
  foreach ($line in $out) {
    if ($line -match '^\s+0x([0-9A-F]{8})$') { $found += $Matches[1].ToUpper() }
  }
  Write-Output "  本轮撞到 $($found.Count) 个地址"
  if ($out -match '本轮没有新日志产生') { Write-Output "!! 没有新日志（游戏没启动成功），停止"; break }

  $existing = @{}
  Select-String -Path $huecos -Pattern '0x([0-9A-Fa-f]{8})' -AllMatches | ForEach-Object {
    foreach ($m in $_.Matches) { $existing[$m.Groups[1].Value.ToUpper()] = $true }
  }
  $new = @($found | Where-Object { -not $existing.ContainsKey($_) })
  if ($new.Count -eq 0) {
    if ($found.Count -eq 0) { Write-Output ">>> 没有未登记地址，收敛" } else { Write-Output ">>> 撞到的地址都已登记，收敛" }
    break
  }

  Write-Output ">>> 新增 $($new.Count) 个: $($new -join ', ')"
  $txt = "`r`n# probe round $r $(Get-Date -Format 'HH:mm')`r`n"
  foreach ($a in $new) { $txt += "`"0x$a`" = { }`r`n" }
  Append-Utf8 $huecos $txt
}
Write-Output "=== 迭代结束 $(Get-Date -Format 'HH:mm:ss') ==="
