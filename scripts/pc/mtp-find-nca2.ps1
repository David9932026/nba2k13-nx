param([string]$RootLike = '1:*', [string]$Since = '2026-10-27')
$ErrorActionPreference = 'Continue'
$base = 'emuMMC/SD00/Nintendo/Contents/registered'

$sh = New-Object -ComObject Shell.Application
$pc = $sh.NameSpace(17)
$sw = $pc.Items() | Where-Object { $_.Name -eq 'Switch' } | Select-Object -First 1
if (-not $sw) { "X 设备不在"; exit 1 }
$root = $sh.NameSpace($sw.Path)
$entry = $root.Items() | Where-Object { $_.Name -like $RootLike } | Select-Object -First 1

function Find-Folder($startFolder, $segments) {
  $cur = $startFolder
  foreach ($seg in $segments) {
    $nxt = $null
    foreach ($i in @($cur.Items())) { if ($i.Name -eq $seg) { $nxt = $i; break } }
    if (-not $nxt) { return $null }
    $cur = $nxt.GetFolder
  }
  return $cur
}

$sinceDt = [datetime]::Parse($Since)
$reg = Find-Folder $entry.GetFolder ($base -split '/')
$buckets = @($reg.Items()) | Where-Object { try { $_.IsFolder } catch { $false } }
"bucket: $($buckets.Count)  过滤: ModifyDate >= $Since"

foreach ($b in $buckets) {
  $hits = @()
  try { $kids = @($b.GetFolder.Items()) } catch { continue }
  foreach ($f in $kids) {
    $dt = $null; $sz = -1
    try { $dt = $f.ModifyDate } catch {}
    try { $sz = $f.Size } catch {}
    $keep = $false
    if ($dt -ne $null -and $dt -ne '' ) { try { if ([datetime]$dt -ge $sinceDt) { $keep = $true } } catch {} }
    if ($keep) { $hits += ('    {0}   size={1}   {2}' -f $f.Name, $sz, $dt) }
  }
  if ($hits.Count -gt 0) { "  == $($b.Name) =="; $hits }
}
"DONE"
