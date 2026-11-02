$r = 'D:\cola-projects\project-20261028-112651-101fe126'
$d = "$r\rex\nba2k13app\out\build\win-vk"
foreach ($esc in @(70, 100)) {
  if (Test-Path "$d\capturas") { Rename-Item "$d\capturas" ("capturas_prev_" + (Get-Date -Format HHmmss)) }
  & powershell -NoProfile -ExecutionPolicy Bypass -File "$r\nativo-run.ps1" -Seconds 175 -Script input-pause.txt -Tag "somb$esc" -Extra "--NBA2K13_captura_cada_s=4 --NBA2K13_captura_max=70 --nba2k13_nativo_sombras_escala=$esc"
  $log = Get-ChildItem "$d\logs\nba2k13_*.log" | Sort-Object LastWriteTime | Select-Object -Last 1
  "esc=$esc LOG $($log.Name)"
  if (Test-Path "$d\capturas_somb$esc") { Remove-Item "$d\capturas_somb$esc" -Recurse -Force }
  Rename-Item "$d\capturas" "capturas_somb$esc"
}
