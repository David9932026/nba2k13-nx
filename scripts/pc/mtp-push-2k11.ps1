$ErrorActionPreference = 'Continue'
$src = 'D:\Carafe\058582bb98a4a000.nsp'

$sh = New-Object -ComObject Shell.Application
$pc = $sh.NameSpace(17)
$sw = $pc.Items() | Where-Object { $_.Name -eq 'Switch' } | Select-Object -First 1
if (-not $sw) { "X 设备不在"; exit 1 }
$root = $sh.NameSpace($sw.Path)
$it = $root.Items() | Where-Object { $_.Name -like '5:*' } | Select-Object -First 1
if (-not $it) { "X 无安装目录"; exit 1 }
$folder = $it.GetFolder
"目标: 5: SD Card install"

$srcItem = $sh.NameSpace((Split-Path $src)).ParseName((Split-Path $src -Leaf))
"源: $($srcItem.Name) $([math]::Round($srcItem.Size/1GB,2))GB"

"完成登记 $(Get-Date -Format HH:mm:ss)"
$folder.CopyHere($srcItem, 0x0414)

# 保活：不重建 Shell 对象，只轻量轮询，绝不提前退出
$prev = ''
for ($i = 1; $i -le 90; $i++) {
  Start-Sleep -Seconds 20
  $ts = Get-Date -Format HH:mm:ss
  try {
    $names = (@($folder.Items()) | ForEach-Object { $_.Name + '@' + $_.Size }) -join ' | '
  } catch {
    $names = '(读取异常)'
  }
  if ($names -ne $prev) {
    "[$i] $ts 变化: $names"
    $prev = $names
  } else {
    "[$i] $ts 无变化"
  }
}
"DONE $(Get-Date -Format HH:mm:ss)"

