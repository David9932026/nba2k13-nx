$r = 'D:\cola-projects\project-20261028-112651-101fe126'
$d = "$r\rex\nba2k13app\out\build\win-vk"
$casos = [ordered]@{
  'base'   = ''
  'nosub'  = '--nba2k13_nativo_sub_resueltas=false'
  'norec'  = '--nba2k13_nativo_recortar_resueltas=false'
  'nomips' = '--nba2k13_nativo_mipmaps=false'
}
foreach ($k in $casos.Keys) {
  if (Test-Path "$d\capturas") { Rename-Item "$d\capturas" ("capturas_prev_" + (Get-Date -Format HHmmss)) }
  $extra = "--NBA2K13_captura_cada_s=4 --NBA2K13_captura_max=70"
  if ($casos[$k]) { $extra += " " + $casos[$k] }
  & powershell -NoProfile -ExecutionPolicy Bypass -File "$r\nativo-run.ps1" -Seconds 245 -Script input-menu.txt -Tag "suelo$k" -Extra $extra | Out-Null
  $log = Get-ChildItem "$d\logs\nba2k13_*.log" | Sort-Object LastWriteTime | Select-Object -Last 1
  "$k LOG $($log.Name)"
  if (Test-Path "$d\capturas_suelo_$k") { Remove-Item "$d\capturas_suelo_$k" -Recurse -Force }
  Rename-Item "$d\capturas" "capturas_suelo_$k"
}
"DONE"
