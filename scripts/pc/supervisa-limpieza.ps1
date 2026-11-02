# PATCH(cola): supervisor. Relanza la fase mover hasta que no queden sueltos y despues
# borra la carpeta. Los hijos pueden morir con COM desconectado: no pasa nada, el estado
# vive en la tarjeta.
$ErrorActionPreference = 'Continue'
$fin = $false
for ($i = 1; $i -le 40 -and -not $fin; $i++) {
  "=== ronda $i ==="
  $out = & powershell -NoProfile -ExecutionPolicy Bypass -File .\mtp-clean-fase.ps1 -Fase mover -MaxSeg 100 2>&1
  $out | Select-String -Pattern 'quedan|movidos|nada|err|aviso|X |fallido' | ForEach-Object { $_.Line }
  if (($out | Select-String -Pattern 'sueltos restantes: 0' -Quiet) -or ($out | Select-String -Pattern 'nada queda fuera' -Quiet)) { $fin = $true }
  Start-Sleep -Seconds 3
}
if ($fin) { 'supervisor: todo movido, borrando carpeta' }
else { 'supervisor: agotadas 40 rondas' }
$out2 = & powershell -NoProfile -ExecutionPolicy Bypass -File .\mtp-clean-fase.ps1 -Fase borrar 2>&1
$out2 | Select-String -Pattern 'carpeta|aviso|X |BORRADO_OK' | ForEach-Object { $_.Line }
'SUPERVISOR_DONE'
