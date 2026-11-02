param([string]$RootLike = '1:*')
$ErrorActionPreference = 'Continue'

$tmp = Join-Path $env:TEMP 'cola-del-test.txt'
('x' * 1024) | Out-File -FilePath $tmp -Encoding ascii

$sh = New-Object -ComObject Shell.Application
$pc = $sh.NameSpace(17)
$sw = $pc.Items() | Where-Object { $_.Name -eq 'Switch' } | Select-Object -First 1
if (-not $sw) { "X 设备不在"; exit 1 }
$root = $sh.NameSpace($sw.Path)
$entry = $root.Items() | Where-Object { $_.Name -like $RootLike } | Select-Object -First 1
$folder = $entry.GetFolder

"1) 上传测试文件"
$srcItem = $sh.NameSpace((Split-Path $tmp)).ParseName((Split-Path $tmp -Leaf))
$folder.CopyHere($srcItem, 0x0414)
$target = $null
for ($i=0; $i -lt 10; $i++) {
  Start-Sleep -Milliseconds 800
  $target = @($folder.Items()) | Where-Object { $_.Name -like 'cola-del-test*' } | Select-Object -First 1
  if ($target) { break }
}
if (-not $target) { "X 上传失败"; exit 1 }
"   已到达: $($target.Name)"

"2) 尝试删除（InvokeVerb delete），观察是否有确认框"
$item = $target
$before = @($folder.Items()).Count
$item.InvokeVerb('delete')
for ($i=1; $i -le 8; $i++) {
  Start-Sleep -Milliseconds 1000
  $still = @($folder.Items()) | Where-Object { $_.Name -like 'cola-del-test*' } | Select-Object -First 1
  "[$i] 还存在: $([bool]$still)"
  if (-not $still) { break }
}
"   项数 $before -> $(@($folder.Items()).Count)"
"3) 清理残留"
$still = @($folder.Items()) | Where-Object { $_.Name -like 'cola-del-test*' } | Select-Object -First 1
if ($still) { "   仍残留 $($still.Name)（说明 delete verb 未生效或有框阻挡）" } else { "   ✓ 干净" }
Remove-Item $tmp -ErrorAction SilentlyContinue
"DONE"
