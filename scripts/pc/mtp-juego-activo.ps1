param([int]$Seconds = 12)
$ErrorActionPreference = 'Continue'
$sh = New-Object -ComObject Shell.Application
$sw = $sh.NameSpace(17).Items() | Where-Object { $_.Name -eq 'Switch' } | Select-Object -First 1
if (-not $sw) { 'X Switch MTP device not present'; exit 1 }
$root = $sh.NameSpace($sw.Path)
$sdEntry = $root.Items() | Where-Object { $_.Name -like '1:*' } | Select-Object -First 1
if (-not $sdEntry) { 'X no SD volume'; exit 1 }
$sd = $sdEntry.GetFolder

function Get-Sub($folder, $name) {
  if (-not $folder) { return $null }
  foreach ($i in @($folder.Items())) {
    if ($i.Name -eq $name) { return $i.GetFolder }
  }
  return $null
}

function Get-Path($start, $path) {
  $cur = $start
  foreach ($seg in ($path -split '/')) {
    $cur = Get-Sub $cur $seg
    if (-not $cur) { return $null }
  }
  return $cur
}

$rex = Get-Path $sd 'switch/nba2k13/logs/rex'
if (-not $rex) { 'X no logs/rex'; exit 1 }
$perfil = $null
foreach ($m in @($rex.Items())) { if ($m.Name -like 'rex_perfil*') { $perfil = $m; break } }
if (-not $perfil) { 'X no rex_perfil.log'; exit 1 }
$s1 = $perfil.ExtendedProperty('System.Size')
"perfil size t0: $s1"
Start-Sleep -Seconds $Seconds
$perfil2 = $null
foreach ($m in @($rex.Items())) { if ($m.Name -like 'rex_perfil*') { $perfil2 = $m; break } }
$s2 = $perfil2.ExtendedProperty('System.Size')
"perfil size t1: $s2"
if ($s2 -gt $s1) {
  "JUEGO EN MARCHA (log crece +$($s2 - $s1) B en ${Seconds}s) - NO TOCAR LA TARJETA"
  exit 2
}
"log quieto - juego probablemente cerrado"
$nb = Get-Path $sd 'switch/nba2k13'
foreach ($m in @($nb.Items())) {
  if ($m.Name -like 'nba2k13*') {
    $sz = $m.ExtendedProperty('System.Size')
    "{0}  {1}" -f $m.Name, $sz
  }
}
