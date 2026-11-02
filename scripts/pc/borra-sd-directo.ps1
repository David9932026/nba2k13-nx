# PATCH(cola): vigila la aparicion de la SD con switch/nba2k13 y la borra de verdad por
# sistema de ficheros (rapido). Solo borra _basura_c2z si todo su contenido es c2z_*/ctx1_*.
$ErrorActionPreference = 'Continue'
$objetivo = $null
for ($i = 0; $i -lt 240 -and -not $objetivo; $i++) {
  foreach ($d in [System.IO.DriveInfo]::GetDrives()) {
    try {
      if (-not $d.IsReady) { continue }
      $p = Join-Path $d.RootDirectory.FullName 'switch\nba2k13'
      if (Test-Path -LiteralPath $p) { $objetivo = $p; break }
    } catch {}
  }
  if (-not $objetivo) { Start-Sleep -Seconds 3 }
}
if (-not $objetivo) { 'X no aparecio la SD'; 'WATCH_DONE'; exit 1 }
"SD: $objetivo"
$basura = Join-Path $objetivo '_basura_c2z'
if (-not (Test-Path -LiteralPath $basura)) { 'no hay _basura_c2z'; 'WATCH_DONE'; exit 0 }
$todo = @(Get-ChildItem -LiteralPath $basura -Force -ErrorAction SilentlyContinue)
"ficheros en _basura_c2z: " + $todo.Count
$ajenos = @($todo | Where-Object { $_.Name -notlike 'c2z_*' -and $_.Name -notlike 'ctx1_*' })
if ($ajenos.Count -gt 0) {
  'X contenido inesperado, no borro:'
  $ajenos | Select-Object -First 10 | ForEach-Object { '  ' + $_.Name }
  'WATCH_DONE'; exit 1
}
$t0 = Get-Date
Remove-Item -LiteralPath $basura -Recurse -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
if (Test-Path -LiteralPath $basura) {
  $resto = @(Get-ChildItem -LiteralPath $basura -Force -ErrorAction SilentlyContinue).Count
  "X quedan $resto tras Remove-Item"
  Remove-Item -LiteralPath $basura -Recurse -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 2
}
if (Test-Path -LiteralPath $basura) { 'X la carpeta sigue ahi' } else { 'carpeta borrada en ' + [math]::Round(((Get-Date)-$t0).TotalSeconds,1) + ' s' }
$otros = @(Get-ChildItem -LiteralPath $objetivo -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'c2z_*' -or $_.Name -like 'ctx1_*' }).Count
"sueltos en nba2k13: $otros"
'dirs: ' + (@(Get-ChildItem -LiteralPath $objetivo -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object { $_.Name }) -join ', ')
'libreGB: ' + [math]::Round(([System.IO.DriveInfo]::new((Split-Path $objetivo -Qualifier))).AvailableFreeSpace/1GB,1)
'WATCH_DONE'
