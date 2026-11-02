param([string]$RootLike = '1:*')
$ErrorActionPreference = 'Continue'

$sh = New-Object -ComObject Shell.Application
$pc = $sh.NameSpace(17)
$sw = $pc.Items() | Where-Object { $_.Name -eq 'Switch' } | Select-Object -First 1
if (-not $sw) { "X 设备不在"; exit 1 }
$root = $sh.NameSpace($sw.Path)
$entry = $root.Items() | Where-Object { $_.Name -like $RootLike } | Select-Object -First 1
$folder = $entry.GetFolder

"--- 属性名尝试 (item) ---"
foreach ($p in @('System.FreeSpace','System.Storage.FreeSpace','System.Volume.FreeSpace','System.Volume.TotalSize','System.Storage.TotalSize','System.Size')) {
  $v = ''
  try { $v = $entry.ExtendedProperty($p) } catch { $v = "<异常>" }
  "  $p = $v"
}
"--- 属性名尝试 (folder) ---"
foreach ($p in @('System.FreeSpace','System.Storage.FreeSpace','System.Volume.FreeSpace','System.Volume.TotalSize','System.Size')) {
  $v = ''
  try { $v = $folder.ExtendedProperty($p) } catch { $v = "<异常>" }
  "  $p = $v"
}

"--- GetDetailsOf 扫描 (folder, 找含 GB/可用 的项) ---"
for ($i = 0; $i -lt 340; $i++) {
  $name = ''; $val = ''
  try { $name = $folder.GetDetailsOf($null, $i) } catch {}
  try { $val = $folder.GetDetailsOf($entry, $i) } catch {}
  if (($name -ne '' -and $name -match '可用|空间|大小|容量|Free|space|size') -or ($val -match 'GB|MB|字节')) {
    "  [$i] $name = $val"
  }
}

"--- .Trashes / .TemporaryItems / .Spotlight-V100 ---"
foreach ($n in @('.Trashes','.TemporaryItems','.Spotlight-V100')) {
  $it = @($folder.Items()) | Where-Object { $_.Name -eq $n } | Select-Object -First 1
  if (-not $it) { "  $n : 不存在"; continue }
  $sub = @($it.GetFolder.Items())
  "  $n : $($sub.Count) 项"
  foreach ($s in ($sub | Select-Object -First 10)) {
    $sz = 0; try { $sz = [long]$s.ExtendedProperty('System.Size') } catch {}
    "     - $($s.Name)  $sz B"
  }
}
"DONE"
