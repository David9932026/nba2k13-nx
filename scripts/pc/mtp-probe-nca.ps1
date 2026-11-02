param([string]$RootLike = '1:*', [string[]]$Buckets = @('000000D2','00000044'))
$ErrorActionPreference = 'Continue'
$Items = @($Buckets | ForEach-Object { $_ -split ',' } | Where-Object { $_ -ne '' })
$base = 'emuMMC/SD00/Nintendo/Contents/registered'
$outDir = Join-Path $PSScriptRoot 'nca-probe'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$sh = New-Object -ComObject Shell.Application
$pc = $sh.NameSpace(17)
$sw = $pc.Items() | Where-Object { $_.Name -eq 'Switch' } | Select-Object -First 1
if (-not $sw) { "X 设备不在"; exit 1 }
$root = $sh.NameSpace($sw.Path)
$entry = $root.Items() | Where-Object { $_.Name -like $RootLike } | Select-Object -First 1
$sdRoot = $entry.GetFolder

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

$local = $sh.NameSpace($outDir)

foreach ($b in $Items) {
  "== bucket $b =="
  $bf = Find-Folder $sdRoot (($base + '/' + $b) -split '/')
  if (-not $bf) { "  (不存在)"; continue }
  foreach ($f in @($bf.Items())) {
    $sz = 0; try { $sz = [long]$f.ExtendedProperty('System.Size') } catch {}
    $mark = if ($sz -lt 2000000) { 'copy' } else { 'big' }
    "  {0}  {1} B  [{2}]" -f $f.Name, $sz, $mark
    if ($mark -eq 'copy') {
      try { $local.CopyHere($f, 0x0414) } catch { "    复制异常: $($_.Exception.Message)" }
    }
  }
}

Start-Sleep -Seconds 3
"== 已复制到本地的文件，解析 NCA 头 0x210 的 title id =="
Get-ChildItem $outDir -File | Sort-Object Name | ForEach-Object {
  $fs = [System.IO.File]::OpenRead($_.FullName)
  $buf = New-Object byte[] 0x240
  $n = $fs.Read($buf, 0, $buf.Length)
  $fs.Close()
  $magic = [System.Text.Encoding]::ASCII.GetString($buf, 0, 4)
  $tid = ($buf[0x210..0x217] | ForEach-Object { $_.ToString('x2') }) -join ''
  $raw = ($buf[0x200..0x22F] | ForEach-Object { $_.ToString('x2') }) -join ''
  "{0}  {1} B  magic={2}  tid@0x210={3}" -f $_.Name, $_.Length, $magic, $tid
  "    0x200..0x22F: $raw"
}
"DONE"
