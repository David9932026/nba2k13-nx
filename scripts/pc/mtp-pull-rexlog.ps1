param([int]$Take = 3)
$ErrorActionPreference = 'Continue'
$sh = New-Object -ComObject Shell.Application
$sw = $sh.NameSpace(17).Items() | Where-Object { $_.Name -eq 'Switch' } | Select-Object -First 1
if (-not $sw) { 'X Switch MTP device not present'; exit 1 }
$root = $sh.NameSpace($sw.Path)
$sd = $root.Items() | Where-Object { $_.Name -like '1:*' } | Select-Object -First 1
$sd = $sd.GetFolder
$logs = $null
foreach ($i in $sd.Items()) { if ($i.Name -eq 'switch') { foreach ($j in $i.GetFolder.Items()) { if ($j.Name -eq 'nba2k13') { foreach ($k in $j.GetFolder.Items()) { if ($k.Name -eq 'logs') { foreach ($m in $k.GetFolder.Items()) { if ($m.Name -eq 'rex') { $logs = $null } }; }; break } }; break } }; break }

# navigate properly: switch/nba2k13/logs
$nb = $null
foreach ($i in $sd.Items()) { if ($i.Name -eq 'switch') { $sw2 = $i.GetFolder; break } }
foreach ($j in $sw2.Items()) { if ($j.Name -eq 'nba2k13') { $nb = $j.GetFolder; break } }
$logdir = $null
foreach ($k in $nb.Items()) { if ($k.Name -eq 'logs') { $logdir = $k.GetFolder; break } }
if (-not $logdir) { 'X no logs dir'; exit 1 }

# newest by numeric suffix
$cands = @()
foreach ($m in @($logdir.Items())) {
  if ($m.IsFolder) { continue }
  if ($m.Name -match '^nba2k13_(\d+)') { $cands += [pscustomobject]@{ Name = $m.Name; N = [int]$matches[1]; It = $m } }
}
$pick = $cands | Sort-Object N -Descending | Select-Object -First $Take
$dest = 'C:\Users\26095\cola\sw-todo\rexfile'
New-Item -ItemType Directory -Force -Path $dest | Out-Null
$loc = $sh.NameSpace($dest)
foreach ($p in $pick) {
  $sz = $p.It.ExtendedProperty('System.Size')
  "pulling $($p.Name) ($sz B)"
  $loc.CopyHere($p.It, 0x14)
}
Start-Sleep -Seconds 8
Get-ChildItem $dest -File | ForEach-Object { $_.Name + ' ' + $_.Length }
