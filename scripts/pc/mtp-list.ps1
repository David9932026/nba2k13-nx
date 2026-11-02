param(
  [string]$Path = '',
  [string]$RootLike = '1:*',
  [int]$Recurse = 0
)
# 用法: mtp-list.ps1 -Path "Nintendo/Contents/registered" [-RootLike '1:*'] [-Recurse 0]
$ErrorActionPreference = 'Continue'

$sh = New-Object -ComObject Shell.Application
$pc = $sh.NameSpace(17)
$sw = $pc.Items() | Where-Object { $_.Name -eq 'Switch' } | Select-Object -First 1
if (-not $sw) { "X 设备不在"; exit 1 }
$root = $sh.NameSpace($sw.Path)

$entry = $root.Items() | Where-Object { $_.Name -like $RootLike } | Select-Object -First 1
if (-not $entry) { "X 无根 $RootLike"; exit 1 }
$folder = $entry.GetFolder
"ROOT: $($entry.Name)"

function Walk($f, $prefix, $depth) {
  $items = @($f.Items())
  foreach ($i in $items) {
    $isDir = $false
    try { if ($i.IsFolder) { $isDir = $true } } catch {}
    $sz = 0
    try { $sz = $i.Size } catch {}
    $line = ('{0}{1}{2}  {3}' -f $prefix, $(if($isDir){'[D] '}else{''}), $i.Name, $sz)
    $line
    if ($isDir -and $depth -lt $Recurse) {
      try { Walk $i.GetFolder ($prefix + '  ') ($depth + 1) } catch { "$prefix  (无法进入)" }
    }
  }
}

if ($Path -eq '') {
  foreach ($i in @($folder.Items())) {
    $isDir = $false
    try { if ($i.IsFolder) { $isDir = $true } } catch {}
    $sz = 0
    try { $sz = $i.Size } catch {}
    ('{0}{1}  {2}' -f $(if($isDir){'[D] '}else{''}), $i.Name, $sz)
  }
  exit 0
}

$cur = $folder
foreach ($seg in ($Path -split '/')) {
  $nxt = $null
  foreach ($i in @($cur.Items())) {
    if ($i.Name -eq $seg) { $nxt = $i; break }
  }
  if (-not $nxt) { "X 找不到: $seg (在 $Path)"; exit 1 }
  $cur = $nxt.GetFolder
}
"PATH: $Path"
Walk $cur '' 0
