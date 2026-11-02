param([string]$RootLike = '1:*')
$ErrorActionPreference = 'Continue'

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

"--- 属性探测: hbmenu ---"
$hb = @($entry.GetFolder.Items()) | Where-Object { $_.Name -eq 'hbmenu' } | Select-Object -First 1
if ($hb) {
  "Name=$($hb.Name)  Path=$($hb.Path)"
  foreach ($prop in @('Size','ModifyDate','Type','IsFolder','IsFileSystem','IsLink','ExtendedProperty')) {
    try {
      if ($prop -eq 'ExtendedProperty') { "  ExtendedProperty(System.Size)=" + $hb.ExtendedProperty('System.Size') }
      else { "  $prop = " + $hb.$prop }
    } catch { "  $prop = <异常: $($_.Exception.Message)>" }
  }
}

foreach ($p in @('emuMMC', 'emuMMC/SD00', 'emuMMC/SD00/Nintendo/save', 'switch')) {
  "== $p =="
  $f = Find-Folder $entry.GetFolder ($p -split '/')
  if (-not $f) { "  (不存在)"; continue }
  $c = 0
  foreach ($i in @($f.Items())) {
    $c++
    if ($c -le 30) {
      $isDir = $false; try { if ($i.IsFolder) { $isDir = $true } } catch {}
      ('  {0}{1}' -f $(if($isDir){'[D] '}else{''}), $i.Name)
    }
  }
  "  (共 $c 项)"
}
"DONE"
