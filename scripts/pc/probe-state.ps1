$ErrorActionPreference = 'Continue'
$sh = New-Object -ComObject Shell.Application
$sw = @($sh.NameSpace(17).Items() | Where-Object { $_.Name -eq 'Switch' })[0]
$root = $sh.NameSpace($sw.Path)
$sd = @($root.Items()) | Where-Object { $_.Name -like '1:*' } | Select-Object -First 1
$nb = $null; $bas = $null
foreach ($i in @($sd.GetFolder.Items())) { if ($i.Name -eq 'switch') { foreach ($j in @($i.GetFolder.Items())) { if ($j.Name -eq 'nba2k13') { $nb = $j.GetFolder; foreach ($k in @($j.GetFolder.Items())) { if ($k.Name -eq '_basura_c2z') { $bas = $k.GetFolder } } } } } }
$fuera = @(@($nb.Items()) | Where-Object { $_.Name -like 'c2z_*' -or $_.Name -like 'ctx1_*' })
'dentro basura: ' + @($bas.Items()).Count
'fuera (sueltos): ' + @($fuera).Count
'STATE_DONE'
