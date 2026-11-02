$ErrorActionPreference = 'Continue'
function Enum-Seguro($folder, [scriptblock]$filtro) {
  for ($r = 0; $r -lt 3; $r++) {
    try { return @(@($folder.Items()) | Where-Object $filtro) }
    catch { Start-Sleep -Seconds 2 }
  }
  return $null
}
$sh = New-Object -ComObject Shell.Application
$sw = @($sh.NameSpace(17).Items() | Where-Object { $_.Name -eq 'Switch' })[0]
$root = $sh.NameSpace($sw.Path)
$sd = @($root.Items()) | Where-Object { $_.Name -like '1:*' } | Select-Object -First 1
$nb = $null
foreach ($i in @($sd.GetFolder.Items())) { if ($i.Name -eq 'switch') { foreach ($j in @($i.GetFolder.Items())) { if ($j.Name -eq 'nba2k13') { $nb = $j.GetFolder } } } }
'total items: ' + @($nb.Items()).Count
$a = Enum-Seguro $nb { param($x) $x.IsFolder -and $x.Name -eq '_basura_c2z' }
'filtro IsFolder: count=' + @($a).Count
$b = Enum-Seguro $nb { param($x) $x.Name -eq '_basura_c2z' }
'filtro solo nombre: count=' + @($b).Count
$c = @(@($nb.Items()) | Where-Object { $_.Name -eq '_basura_c2z' })
'directo: count=' + @($c).Count
if ($c.Count) { 'directo nombre: ' + $c[0].Name + ' IsFolder=' + $c[0].IsFolder }
$carpetas = @(@($nb.Items()) | Where-Object { $_.IsFolder } | ForEach-Object { $_.Name })
'carpetas: ' + ($carpetas -join ', ')
'TEST_DONE'
