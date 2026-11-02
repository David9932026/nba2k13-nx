param([string]$RootLike = '1:*')
$ErrorActionPreference = 'Continue'
$paths = @(
  'emuMMC/SD00/Nintendo/Contents/registered',
  'emuMMC/SD00/Nintendo/tickets',
  'emuMMC/SD00/Nintendo/Contents/save',
  'switch/carafe'
)

$sh = New-Object -ComObject Shell.Application
$pc = $sh.NameSpace(17)
$sw = $pc.Items() | Where-Object { $_.Name -eq 'Switch' } | Select-Object -First 1
if (-not $sw) { "X 设备不在"; exit 1 }
$root = $sh.NameSpace($sw.Path)
$entry = $root.Items() | Where-Object { $_.Name -like $RootLike } | Select-Object -First 1
if (-not $entry) { "X 无根 $RootLike"; exit 1 }

function Find-Folder($startFolder, $segments) {
  $cur = $startFolder
  foreach ($seg in $segments) {
    $nxt = $null
    foreach ($i in @($cur.Items())) {
      if ($i.Name -eq $seg) { $nxt = $i; break }
    }
    if (-not $nxt) { return $null }
    $cur = $nxt.GetFolder
  }
  return $cur
}

foreach ($p in $paths) {
  "== $p =="
  $f = Find-Folder $entry.GetFolder ($p -split '/')
  if (-not $f) { "  (不存在)"; continue }
  $items = @($f.Items())
  "{0} 项" -f $items.Count
  foreach ($i in $items) {
    $isDir = $false
    try { if ($i.IsFolder) { $isDir = $true } } catch {}
    $sz = 0
    try { $sz = $i.Size } catch {}
    ('  {0}{1}  {2}' -f $(if($isDir){'[D] '}else{''}), $i.Name, $sz)
  }
}
