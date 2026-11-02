$sh = New-Object -ComObject Shell.Application
$sw = $sh.NameSpace(17).Items() | Where-Object { $_.Name -eq 'Switch' } | Select-Object -First 1
if (-not $sw) { 'X no device'; exit 1 }
$root = $sh.NameSpace($sw.Path)
function Get-Sub($folder, $name) {
  if (-not $folder) { return $null }
  $it = $folder.Items() | Where-Object { $_.Name -eq $name } | Select-Object -First 1
  if (-not $it) { return $null }
  return $it.GetFolder
}
$sd = $root.Items() | Where-Object { $_.Name -like '1:*' } | Select-Object -First 1
$sd = $sd.GetFolder
$nb = Get-Sub (Get-Sub $sd 'switch') 'nba2k13'
foreach ($i in @($nb.Items())) {
  if ($i.IsFolder) { continue }
  $n = $i.Name
  if ($n -notlike '*.nro' -and $n -notlike '*.toml') { continue }
  $sz = $i.ExtendedProperty('System.Size')
  $dm = $i.ExtendedProperty('System.DateModified')
  "{0,-22} {1,12} {2}" -f $n, $sz, $dm
}
