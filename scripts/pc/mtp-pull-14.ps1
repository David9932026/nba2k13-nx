param([string]$Dest = 'C:\Users\26095\cola\swlogs14')
$ErrorActionPreference = 'Continue'
New-Item -ItemType Directory -Force -Path $Dest | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Dest 'rex') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Dest 'album') | Out-Null

$sh = New-Object -ComObject Shell.Application
$sw = $sh.NameSpace(17).Items() | Where-Object { $_.Name -eq 'Switch' } | Select-Object -First 1
if (-not $sw) { 'X Switch device not present'; exit 1 }
$root = $sh.NameSpace($sw.Path)

function Get-Sub($folder, $name) {
  if (-not $folder) { return $null }
  $it = $folder.Items() | Where-Object { $_.Name -eq $name } | Select-Object -First 1
  if (-not $it) { return $null }
  return $it.GetFolder
}

$sd = $root.Items() | Where-Object { $_.Name -like '1:*' } | Select-Object -First 1
if (-not $sd) { 'X no SD'; exit 1 }
$sd = $sd.GetFolder
$nb = Get-Sub (Get-Sub $sd 'switch') 'nba2k13'
if (-not $nb) { 'X no switch/nba2k13'; exit 1 }
$logs = Get-Sub $nb 'logs'
$rex = Get-Sub $logs 'rex'

$local = $sh.NameSpace($Dest)
$localRex = $sh.NameSpace((Join-Path $Dest 'rex'))

function PullLogs($srcFolder, $dstFolder) {
  if (-not $srcFolder) { "  - no logs"; return }
  foreach ($i in @($srcFolder.Items())) {
    if ($i.IsFolder) { continue }
    if ($i.Name -notlike 'nba2k13_0*') { continue }
    try { $dstFolder.CopyHere($i, 0x14) } catch { "    copy fail $($i.Name)" }
  }
}
PullLogs $logs $local
if ($rex) { foreach ($i in @($rex.Items())) { if (-not $i.IsFolder) { try { $localRex.CopyHere($i,0x14) } catch {} } } }

# album
$albumRoot = $sh.NameSpace((Join-Path $Dest 'album'))
$nac = Get-Sub (Get-Sub $sd 'Nintendo') 'Album'
if ($nac) {
  $extra = Get-Sub $nac 'NBA 2K13'
  if ($extra) {
    $sorted = @($extra.Items()) | Where-Object { -not $_.IsFolder } | Sort-Object { $_.Name } -Descending | Select-Object -First 14
    foreach ($i in $sorted) { try { $albumRoot.CopyHere($i, 0x14) } catch {} }
  } else { '  - no NBA 2K13 album folder' }
} else { '  - no Album folder' }

Start-Sleep -Seconds 3
Get-ChildItem -Recurse -File $Dest | Sort-Object LastWriteTime -Descending |
  Select-Object @{n='KB';e={[math]::Round($_.Length/1KB,1)}}, FullName | Format-Table -AutoSize
