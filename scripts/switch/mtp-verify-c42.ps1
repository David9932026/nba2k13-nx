$ErrorActionPreference = 'Stop'
$shell = New-Object -ComObject Shell.Application
$dev = @($shell.NameSpace(0x11).Items()) | Where-Object { $_.Name -eq 'Switch' } | Select-Object -First 1
if (-not $dev) { throw "no Switch device" }
function Nav($folder, $name) { foreach ($it in @($folder.GetFolder.Items())) { if ($it.Name -ieq $name) { return $it } }; throw "not found: $name" }
$gdir = Nav (Nav (Nav $dev '1: SD Card') 'switch') 'nba2k13'
$n = $null
foreach ($x in @($gdir.GetFolder.Items())) { if ($x.Name -ieq 'nba2k13.nro' -or ($x.Name -ieq 'nba2k13' -and $x.Type -match 'NRO')) { $n = $x } }
if (-not $n) { throw "no nro on card; have: " + ((@($gdir.GetFolder.Items()) | Where-Object { $_.Type -match 'NRO|文件$' -and $_.Name -match '^nba2k13$' } | ForEach-Object { $_.Name + '/' + $_.Type }) -join ', ') }
"card nro listed, copying back..."
$tmp = 'C:\Users\26095\cola\push1102\card-verify'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
Get-ChildItem $tmp -Filter '*.nro' -ErrorAction SilentlyContinue | Remove-Item -Force
$dst = $shell.NameSpace((Resolve-Path $tmp).Path)
$dst.CopyHere($n, 0x14)
$want = 83871941
for ($i = 0; $i -lt 120; $i++) {
  Start-Sleep -Seconds 2
  $f = Get-ChildItem $tmp -Filter '*.nro' -ErrorAction SilentlyContinue
  if ($f) {
    $len = -1
    try { $s = $f.OpenRead(); $len = $s.Length; $s.Close() } catch {}
    if ($len -eq $want) { break }
  }
}
$f = Get-ChildItem $tmp -Filter '*.nro' -ErrorAction SilentlyContinue
if ($f -and $f.Length -eq $want) {
  $h = (Get-FileHash $f.FullName -Algorithm MD5).Hash
  if ($h -eq '59319373ACF36CD37F624FB7F8377917') { "CARD_OK md5=$h size=$($f.Length)" } else { "MISMATCH md5=$h" }
} else { "VERIFY_FAIL size=$(if($f){$f.Length}else{'none'})" }
