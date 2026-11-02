$ErrorActionPreference = 'Stop'
$shell = New-Object -ComObject Shell.Application
$dev = @($shell.NameSpace(0x11).Items()) | Where-Object { $_.Name -eq 'Switch' } | Select-Object -First 1
if (-not $dev) { throw "no Switch device" }
function Nav($folder, $name) {
  foreach ($it in @($folder.GetFolder.Items())) { if ($it.Name -ieq $name) { return $it } }
  throw "not found: $name"
}
$sd = Nav $dev '1: SD Card'
$sw = Nav $sd 'switch'
$gdir = Nav $sw 'nba2k13'
"--- card files:"
@($gdir.GetFolder.Items()) | ForEach-Object { "  {0}  {1} B" -f $_.Name, $gdir.GetFolder.GetDetailsOf($_, 1) }
# 1) push new nro (overwrite, silent)
$nro = 'C:\Users\26095\cola\push1102\nba2k13.nro'
if (-not (Test-Path $nro)) { Copy-Item 'D:\cola-projects\project-20261028-112651-101fe126\rex\nba2k13app\out\build\sw\nba2k13.nro' $nro -Force }
"local nro: " + (Get-Item $nro).Length + " B  md5=" + (Get-FileHash $nro -Algorithm MD5).Hash
$gdir.GetFolder.CopyHere($nro, 0x14)
Start-Sleep -Seconds 4
# wait until card copy settles (size appears)
$ok = $false
for ($i = 0; $i -lt 60; $i++) {
  $it = $null
  foreach ($x in @($gdir.GetFolder.Items())) { if ($x.Name -ieq 'nba2k13.nro') { $it = $x } }
  if ($it) {
    $sz = $gdir.GetFolder.GetDetailsOf($it, 1)
    "card nro now: $sz"
    if ($sz -match '83,86\d\d\d,\d\d\d|83\.8') { $ok = $true; break }
  }
  Start-Sleep -Seconds 2
}
if (-not $ok) { "WARN: card nro size not confirmed, will verify via copy-back" }
# 2) copy nro back for MD5
$tmp = 'C:\Users\26095\cola\push1102\card-verify'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
Get-ChildItem $tmp -Filter 'nba2k13.nro' -ErrorAction SilentlyContinue | Remove-Item -Force
$dst = $shell.NameSpace((Resolve-Path $tmp).Path)
foreach ($x in @($gdir.GetFolder.Items())) {
  if ($x.Name -ieq 'nba2k13.nro') { $dst.CopyHere($x, 0x14) }
}
for ($i = 0; $i -lt 90; $i++) {
  Start-Sleep -Seconds 2
  $f = Get-ChildItem $tmp -Filter 'nba2k13.nro' -ErrorAction SilentlyContinue
  if ($f) {
    try { $s = $f.OpenRead(); $len = $s.Length; $s.Close() } catch { continue }
    if ($len -eq 83863749) { break }
  }
}
$f = Get-ChildItem $tmp -Filter 'nba2k13.nro' -ErrorAction SilentlyContinue
if ($f) {
  "copy-back: $($f.Length) B  md5=" + (Get-FileHash $f.FullName -Algorithm MD5).Hash
} else { "WARN: copy-back failed" }
# 3) pull logs
$lg = $null
foreach ($x in @($gdir.GetFolder.Items())) { if ($x.Name -ieq 'logs') { $lg = $x } }
if ($lg) {
  $out = 'C:\Users\26095\cola\sw-todo\pull1202c'
  New-Item -ItemType Directory -Force -Path "$out\logs" | Out-Null
  $d = $shell.NameSpace((Resolve-Path "$out\logs").Path)
  foreach ($x in @($lg.GetFolder.Items())) {
    if ($x.IsFolder) {
      $sub = $x.Name
      New-Item -ItemType Directory -Force -Path "$out\logs\$sub" | Out-Null
      $d2 = $shell.NameSpace((Resolve-Path "$out\logs\$sub").Path)
      foreach ($y in @($x.GetFolder.Items())) { $d2.CopyHere($y, 0x14) }
    } else {
      $d.CopyHere($x, 0x14)
    }
  }
  "logs pull requested -> $out\logs (async, verify next)"
}
"DONE"
