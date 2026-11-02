$ErrorActionPreference = 'Continue'
$sh = New-Object -ComObject Shell.Application
$sw = @($sh.NameSpace(17).Items() | Where-Object { $_.Name -eq 'Switch' })[0]
$root = $sh.NameSpace($sw.Path)
$sd = @($root.Items()) | Where-Object { $_.Name -like '1:*' } | Select-Object -First 1
$nb = $null
foreach ($i in @($sd.GetFolder.Items())) { if ($i.Name -eq 'switch') { foreach ($j in @($i.GetFolder.Items())) { if ($j.Name -eq 'nba2k13') { $nb = $j.GetFolder } } } }
if (-not $nb) { 'X no dir'; exit }
$b = @(@($nb.Items()) | Where-Object { $_.Name -eq '_basura_c2z' })
if ($b.Count) { 'carpeta ya existe' } else {
  try { $null = $nb.NewFolder('_basura_c2z'); Start-Sleep 2
    $b2 = @(@($nb.Items()) | Where-Object { $_.Name -eq '_basura_c2z' })
    if ($b2.Count) { 'creada' } else { 'X no aparece' }
  } catch { 'X NewFolder: ' + $_.Exception.Message }
}
$n = @(@($nb.Items()) | Where-Object { -not $_.IsFolder -and ($_.Name -like 'c2z_*' -or $_.Name -like 'ctx1_*') })
'sueltos: ' + $n.Count
$carpetas = @(@($nb.Items()) | Where-Object { $_.IsFolder } | ForEach-Object { $_.Name })
'carpetas: ' + ($carpetas -join ', ')
# prueba de movimiento con 2 ficheros
if ($b.Count -and $n.Count) {
  $basura = $b[0].GetFolder
  foreach ($it in ($n | Select-Object -First 2)) {
    try { $basura.MoveHere($it, 0x14); 'movido ' + $it.Name } catch { 'X mover: ' + $_.Exception.Message }
  }
  Start-Sleep -Milliseconds 800
  $n2 = @(@($nb.Items()) | Where-Object { -not $_.IsFolder -and ($_.Name -like 'c2z_*' -or $_.Name -like 'ctx1_*') })
  'sueltos despues: ' + $n2.Count
}
'PROBE_DONE'
