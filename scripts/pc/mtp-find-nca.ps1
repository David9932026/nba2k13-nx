param([string]$RootLike = '1:*', [long]$MinSize = 50000000)
$ErrorActionPreference = 'Continue'
$base = 'emuMMC/SD00/Nintendo/Contents/registered'

$sh = New-Object -ComObject Shell.Application
$pc = $sh.NameSpace(17)
$sw = $pc.Items() | Where-Object { $_.Name -eq 'Switch' } | Select-Object -First 1
if (-not $sw) { "X 设备不在"; exit 1 }
$root = $sh.NameSpace($sw.Path)
$entry = $root.Items() | Where-Object { $_.Name -like $RootLike } | Select-Object -First 1
if (-not $entry) { "X 无根"; exit 1 }

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

# 先看 Nintendo 层和 Contents 层有哪些目录
foreach ($p in @('emuMMC/SD00/Nintendo', 'emuMMC/SD00/Nintendo/Contents')) {
  "== $p =="
  $f = Find-Folder $entry.GetFolder ($p -split '/')
  if (-not $f) { "  (不存在)"; continue }
  foreach ($i in @($f.Items())) {
    $isDir = $false; try { if ($i.IsFolder) { $isDir = $true } } catch {}
    ('  {0}{1}' -f $(if($isDir){'[D] '}else{''}), $i.Name)
  }
}

"== 扫描 registered 下的大文件 (>= $([math]::Round($MinSize/1MB))MB) =="
$reg = Find-Folder $entry.GetFolder ($base -split '/')
if (-not $reg) { "X 无 registered"; exit 1 }
$buckets = @($reg.Items()) | Where-Object { try { $_.IsFolder } catch { $false } }
"bucket 数: $($buckets.Count)"
$n = 0
foreach ($b in $buckets) {
  $n++
  $lines = @()
  try {
    foreach ($f in @($b.GetFolder.Items())) {
      $sz = 0; try { $sz = $f.Size } catch {}
      if ($sz -ge $MinSize) { $lines += ('    {0}  {1} MB  {2}' -f $f.Name, [math]::Round($sz/1MB,1), $f.ModifyDate) }
    }
  } catch { continue }
  if ($lines.Count -gt 0) {
    "  [$($b.Name)]"
    $lines
  }
  if ($n % 40 -eq 0) { "  ...进度 $n/$($buckets.Count)" }
}
"DONE"
