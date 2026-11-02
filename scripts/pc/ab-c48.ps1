$d = 'D:\cola-projects\project-20261028-112651-101fe126\rex\nba2k13app\out\build\win-vk'
$run = 'D:\cola-projects\project-20261028-112651-101fe126\nativo-run.ps1'
foreach ($modo in @('on', 'off')) {
  if (Test-Path "$d\capturas") { Rename-Item "$d\capturas" ("capturas_prev_" + (Get-Date -Format HHmmss)) }
  $v = if ($modo -eq 'on') { 'true' } else { 'false' }
  & powershell -NoProfile -ExecutionPolicy Bypass -File $run -Seconds 240 -Script input-menu.txt -Tag "c48$modo" -Extra "--NBA2K13_captura_cada_s=4 --NBA2K13_captura_max=70 --nba2k13_nativo_c5g_respeta_swap_dibujado=$v"
  $log = Get-ChildItem "$d\logs\nba2k13_*.log" | Sort-Object LastWriteTime | Select-Object -Last 1
  "$modo LOG $($log.Name) C5g=$((Select-String -Path $log.FullName -Pattern '\[nativo\] C5g').Count) C48=$((Select-String -Path $log.FullName -Pattern '\[nativo\] C48').Count) C47=$((Select-String -Path $log.FullName -Pattern '\[nativo\] C47').Count)"
  if (Test-Path "$d\capturas_c48$modo") { Remove-Item "$d\capturas_c48$modo" -Recurse -Force }
  Rename-Item "$d\capturas" "capturas_c48$modo"
}
