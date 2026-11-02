param([string]$Dest = 'C:\Users\26095\cola\swlogs12')
$ErrorActionPreference = 'Continue'
New-Item -ItemType Directory -Force -Path $Dest | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Dest 'rex') | Out-Null

$sh = New-Object -ComObject Shell.Application
$sw = $sh.NameSpace(17).Items() | Where-Object { $_.Name -eq 'Switch' } | Select-Object -First 1
if (-not $sw) { 'X Switch 设备不在'; exit 1 }
$root = $sh.NameSpace($sw.Path)

function Get-Sub($folder, $name) {
  if (-not $folder) { return $null }
  $it = $folder.Items() | Where-Object { $_.Name -eq $name } | Select-Object -First 1
  if (-not $it) { return $null }
  return $it.GetFolder
}

$sd = $root.Items() | Where-Object { $_.Name -like '1:*' } | Select-Object -First 1
if (-not $sd) { 'X 找不到 1: SD Card'; exit 1 }
$sd = $sd.GetFolder
$nb = Get-Sub (Get-Sub $sd 'switch') 'nba2k13'
if (-not $nb) { 'X 找不到 switch/nba2k13'; exit 1 }
$logs = Get-Sub $nb 'logs'
if (-not $logs) { 'X 找不到 logs'; exit 1 }
$rex = Get-Sub $logs 'rex'

$local = $sh.NameSpace($Dest)
$localRex = $sh.NameSpace((Join-Path $Dest 'rex'))

function Pull($srcFolder, $dstFolder, $label) {
  if (-not $srcFolder) { "  - $label 不存在"; return }
  $items = @($srcFolder.Items())
  foreach ($i in $items) {
    if ($i.IsFolder) {
      # skip perfil dumps subfolders, handled below if needed
      continue
    }
    if ($label -eq 'logs' -and $i.Name -notlike 'nba2k13_0*') { continue }
    try { $dstFolder.CopyHere($i, 0x14) } catch { "    复制失败 $($i.Name)" }
  }
}

Pull $logs $local 'logs'
Pull $rex $localRex 'rex'
Start-Sleep -Seconds 3

Get-ChildItem -Recurse -File $Dest | Sort-Object LastWriteTime -Descending |
  Select-Object @{n='KB';e={[math]::Round($_.Length/1KB,1)}}, FullName |
  Format-Table -AutoSize

