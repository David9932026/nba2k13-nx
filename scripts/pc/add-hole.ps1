param(
  [string]$Addr,
  [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$proj = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126'
$huecos = "$proj\rex\nba2k13app\huecos.toml"
$gen = "$proj\rex\nba2k13app\generated\default"
$logDir = "$proj\rex\nba2k13app\out\build\win-amd64-release\logs"

# 1) 没给地址就从最新日志里取最后一个未登记调用
if (-not $Addr) {
  $lf = Get-ChildItem $logDir -Filter '*.log' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  $hit = Select-String -Path $lf.FullName -Pattern 'unregistered function at guest address 0x([0-9A-Fa-f]{8})' | Select-Object -Last 1
  if (-not $hit) { "最新日志 $($lf.Name) 里没有新的未登记地址"; exit 0 }
  $Addr = $hit.Matches[0].Groups[1].Value
  "从 $($lf.Name) 取到地址: 0x$Addr"
}
$target = [Convert]::ToUInt32($Addr, 16)

# 2) 收集所有已生成函数的入口地址
$addrs = New-Object 'System.Collections.Generic.HashSet[uint32]'
Get-ChildItem $gen -Filter '*.cpp' | ForEach-Object {
  $m = [regex]::Matches([System.IO.File]::ReadAllText($_.FullName), 'DEFINE_REX_FUNC\(sub_([0-9A-F]{8})\)')
  foreach ($x in $m) { [void]$addrs.Add([Convert]::ToUInt32($x.Groups[1].Value, 16)) }
}
"已生成函数入口: $($addrs.Count) 个"

$sorted = $addrs | Sort-Object

# 3) 判断类型
if ($addrs.Contains($target)) {
  "0x$Addr 本身已经是函数入口，无需处理"
  exit 0
}
$parent = ($sorted | Where-Object { $_ -le $target } | Select-Object -Last 1)
$parentHex = $parent.ToString('X8')
$offset = $target - $parent

$existing = [System.IO.File]::ReadAllText($huecos)
if ($existing -match "(?i)0x$Addr") {
  "huecos.toml 里已经有 0x$Addr，跳过"
  exit 0
}

if ($parent -eq 0) {
  "0x$Addr 之前没有已知函数，按普通洞处理"
  $block = "# Hole: unregistered indirect target 0x$Addr`r`n`"0x$Addr`" = { }`r`n"
  $kind = 'hole'
} else {
  "0x$Addr 落在 sub_$parentHex 内部（+0x$($offset.ToString('X'))），按 chunk 处理"
  $block = "# Alt entry inside sub_$parentHex (indirectly called at runtime)`r`n[functions.`"0x$Addr`"]`r`nparent = 0x$parentHex`r`nshare_registers = true`r`n"
  $kind = 'chunk'
}

if ($DryRun) { "--- 预演（未写入）---"; $block; exit 0 }

[System.IO.File]::AppendAllText($huecos, $block, (New-Object System.Text.UTF8Encoding($false)))
"已写入 huecos.toml  类型=$kind  父=sub_$parentHex  偏移=+0x$($offset.ToString('X'))"
