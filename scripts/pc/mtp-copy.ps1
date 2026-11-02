$ErrorActionPreference = 'Continue'
$src = 'D:\Carafe\053c11a8112cc000.nsp'

function Get-SwitchRoot {
  $sh = New-Object -ComObject Shell.Application
  $sw = $sh.NameSpace(17).Items() | Where-Object { $_.Name -eq 'Switch' } | Select-Object -First 1
  if (-not $sw) { return $null }
  return $sh.NameSpace($sw.Path)
}

function Get-InstallFolder($root) {
  $it = $root.Items() | Where-Object { $_.Name -like '5:*' } | Select-Object -First 1
  if (-not $it) { return $null }
  return $it.GetFolder
}

$root = Get-SwitchRoot
if (-not $root) { "X Switch 设备不在"; exit 1 }
$target = Get-InstallFolder $root
if (-not $target) { "X 找不到 5: SD Card install"; exit 1 }

"目标: 5: SD Card install"
"开始复制 $(Get-Date -Format HH:mm:ss)"
$target.CopyHere($src, 0x0414)

$lastTotal = -1
$stableCount = 0
for ($i = 1; $i -le 160; $i++) {
  Start-Sleep -Seconds 15
  $ts = Get-Date -Format HH:mm:ss
  try { $items = @($target.Items()) } catch { $items = @() }
  $real = @($items | Where-Object { $_.Name -like '*.nsp' -or $_.Name -like '*.nsz' -or $_.Name -like '*.xci' })
  $total = ($real | Measure-Object -Property Size -Sum).Sum
  if (-not $total) { $total = 0 }
  "[$i] $ts 条目=$($items.Count) nsp条目=$($real.Count) 总大小=$([math]::Round($total/1MB,1))MB"
  foreach ($r in $real) { "      $($r.Name) $([math]::Round($r.Size/1MB,1))MB" }

  $rr = Get-SwitchRoot
  if (-not $rr) { "X 设备消失 @ $ts"; break }
  $tt = Get-InstallFolder $rr
  if (-not $tt) { "X 安装目录消失 @ $ts"; break }
  $target = $tt

  if ($total -eq $lastTotal -and $total -gt 0) {
    $stableCount++
    if ($stableCount -ge 2) { "-> 大小稳定在 $([math]::Round($total/1GB,2))GB @ $ts"; break }
  } else {
    $stableCount = 0
  }
  $lastTotal = $total
}
"结束 $(Get-Date -Format HH:mm:ss)"
try {
  $final = @($target.Items() | Where-Object { $_.Name -like '*.nsp' })
  "最终 nsp 条目: $($final.Count)"
  $final | ForEach-Object { "  $($_.Name) $([math]::Round($_.Size/1GB,2))GB" }
} catch { "读最终状态失败" }
