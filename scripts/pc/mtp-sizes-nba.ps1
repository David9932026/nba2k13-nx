$ErrorActionPreference = 'Continue'
$sh = New-Object -ComObject Shell.Application
$sw = $sh.NameSpace(17).Items() | Where-Object { $_.Name -eq 'Switch' } | Select-Object -First 1
if (-not $sw) { 'X Switch MTP device not present'; exit 1 }
$root = $sh.NameSpace($sw.Path)
$sd = $root.Items() | Where-Object { $_.Name -like '1:*' } | Select-Object -First 1
$sd = $sd.GetFolder
$nb = $null
foreach ($i in $sd.Items()) { if ($i.Name -eq 'switch') { foreach ($j in $i.GetFolder.Items()) { if ($j.Name -eq 'nba2k13') { $nb = $j.GetFolder; break } }; break } }
if (-not $nb) { 'X no switch/nba2k13'; exit 1 }
foreach ($i in @($nb.Items())) {
  if ($i.IsFolder) { '[D] ' + $i.Name; continue }
  $sz = $i.ExtendedProperty('System.Size')
  '{0}  {1}' -f $i.Name, $sz
}
