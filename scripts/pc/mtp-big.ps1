param([string]$RootLike = '1:*', [long]$MinSize = 100MB)
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

$reg = Find-Folder $entry.GetFolder ($base -split '/')
$buckets = @($reg.Items()) | Where-Object { try { $_.IsFolder } catch { $false } }
"扫描 $($buckets.Count) 个桶，阈值 $([math]::Round($MinSize/1MB)) MB"
$total = 0; $cnt = 0
foreach ($b in $buckets) {
  try { $kids = @($b.GetFolder.Items()) } catch { continue }
  foreach ($f in $kids) {
    $sz = 0
    try { $sz = [long]$f.ExtendedProperty('System.Size') } catch {}
    if ($sz -ge $MinSize) {
      $cnt++; $total += $sz
      "  [$($b.Name)] $($f.Name)  $sz B  ($([math]::Round($sz/1GB,2)) GiB)"
    }
  }
}
"---- 合计 $cnt 个文件，$([math]::Round($total/1GB,2)) GiB"
"DONE"
