param([string]$RootLike = '1:*', [long]$BigFile = 1GB)
$ErrorActionPreference = 'Continue'

$sh = New-Object -ComObject Shell.Application
$pc = $sh.NameSpace(17)
$sw = $pc.Items() | Where-Object { $_.Name -eq 'Switch' } | Select-Object -First 1
if (-not $sw) { "X 设备不在"; exit 1 }
$root = $sh.NameSpace($sw.Path)
$entry = $root.Items() | Where-Object { $_.Name -like $RootLike } | Select-Object -First 1
$sd = $entry.GetFolder

$skip = @('.Spotlight-V100','.Trashes','.TemporaryItems','System Volume Information')
$script:big = New-Object System.Collections.ArrayList

function Walk-Size($folder, $label) {
  $sum = [long]0
  $files = 0
  $dirs = 0
  $stack = New-Object System.Collections.Stack
  $stack.Push($folder)
  while ($stack.Count -gt 0) {
    $f = $stack.Pop()
    try { $kids = @($f.Items()) } catch { continue }
    foreach ($k in $kids) {
      $isDir = $false
      try { if ($k.IsFolder) { $isDir = $true } } catch {}
      if ($isDir) {
        try { $stack.Push($k.GetFolder); $dirs++ } catch {}
      } else {
        $sz = 0
        try { $sz = [long]$k.ExtendedProperty('System.Size') } catch {}
        $sum += $sz; $files++
        if ($sz -ge $BigFile) { [void]$script:big.Add(('{0}   {1}   {2}' -f $sz, [math]::Round($sz/1GB,2) + ' GiB', $k.Path)) }
      }
    }
  }
  '{0,-32} {1,14:N0} B  {2,8:N2} GiB   ({3} 文件 / {4} 目录)' -f $label, $sum, ($sum/1GB), $files, $dirs
  return $sum
}

$total = [long]0
foreach ($i in @($sd.Items())) {
  $isDir = $false
  try { if ($i.IsFolder) { $isDir = $true } } catch {}
  if ($isDir) {
    if ($skip -contains $i.Name) { "  跳过 $($i.Name)"; continue }
    $total += Walk-Size $i.GetFolder $i.Name
  } else {
    $sz = 0; try { $sz = [long]$i.ExtendedProperty('System.Size') } catch {}
    $total += $sz
    '{0,-32} {1,14:N0} B  (根目录文件)' -f $i.Name, $sz
  }
}
'==== 根目录总计 {0:N0} B = {1:N2} GiB ====' -f $total, ($total/1GB)
'==== 其中 >= 1 GiB 的文件 ===='
$script:big | ForEach-Object { $_ }
"DONE"
