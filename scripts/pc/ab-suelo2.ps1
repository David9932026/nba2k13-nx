$r = 'D:\cola-projects\project-20261028-112651-101fe126'
$d = "$r\rex\nba2k13app\out\build\win-vk"
if (Test-Path "$d\capturas") { Rename-Item "$d\capturas" ("capturas_prev_" + (Get-Date -Format HHmmss)) }
& powershell -NoProfile -ExecutionPolicy Bypass -File "$r\nativo-run.ps1" -Seconds 245 -Script input-menu.txt -Tag "suelo_no982" -Extra "--NBA2K13_captura_cada_s=4 --NBA2K13_captura_max=70 --nba2k13_nativo_diag_omitir_ps=982" | Out-Null
$log = Get-ChildItem "$d\logs\nba2k13_*.log" | Sort-Object LastWriteTime | Select-Object -Last 1
"no982 LOG $($log.Name)"
if (Test-Path "$d\capturas_suelo_no982") { Remove-Item "$d\capturas_suelo_no982" -Recurse -Force }
Rename-Item "$d\capturas" "capturas_suelo_no982"
"DONE"
