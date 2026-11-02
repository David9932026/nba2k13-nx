param([string]$Dest = 'C:\Users\26095\cola\swlogs13b', [int]$MinLog = 46)
$ErrorActionPreference = 'Continue'
New-Item -ItemType Directory -Force -Path $Dest, (Join-Path $Dest 'rex'), (Join-Path $Dest 'album') | Out-Null
$sh = New-Object -ComObject Shell.Application
$sw = $sh.NameSpace(17).Items() | Where-Object { $_.Name -eq 'Switch' } | Select-Object -First 1
if (-not $sw) { 'NO_SWITCH'; exit 1 }
$root = $sh.NameSpace($sw.Path)
$sd = ($root.Items() | Where-Object { $_.Name -like '1:*' } | Select-Object -First 1).GetFolder
function Sub($f,$n){ if(-not $f){return $null}; foreach($i in @($f.Items())){ if($i.Name -eq $n){ return $i.GetFolder } }; return $null }
$nb = Sub (Sub $sd 'switch') 'nba2k13'
$logs = Sub $nb 'logs'; $rex = Sub $logs 'rex'
$loc = $sh.NameSpace($Dest); $locRex = $sh.NameSpace((Join-Path $Dest 'rex')); $locAlb = $sh.NameSpace((Join-Path $Dest 'album'))
foreach ($i in @($logs.Items())) {
  if ($i.IsFolder) { continue }
  if ($i.Name -match 'nba2k13_0*(\d+)') { if ([int]$Matches[1] -ge $MinLog) { "log $($i.Name)"; $loc.CopyHere($i, 0x14) } }
}
foreach ($i in @($rex.Items())) { if (-not $i.IsFolder) { "rex $($i.Name)"; $locRex.CopyHere($i, 0x14) } }
# Album: Nintendo/Album/2026/10/31 and 2026/11/01
$alb = Sub (Sub $sd 'Nintendo') 'Album'
foreach ($ym in @(@('2026','10','31'), @('2026','11','01'))) {
  $d = Sub (Sub (Sub $alb $ym[0]) $ym[1]) $ym[2]
  if (-not $d) { "no album $($ym -join '/')"; continue }
  foreach ($i in @($d.Items())) { if (-not $i.IsFolder) { "img $($ym -join '/') $($i.Name)"; $locAlb.CopyHere($i, 0x14) } }
}
Start-Sleep 5
'DONE'
