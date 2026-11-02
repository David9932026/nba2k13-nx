$ErrorActionPreference='Continue'
$e='C:\Users\26095\cola\export\n6'
$back='C:\Users\26095\cola\swback-n6v'
New-Item -ItemType Directory $back -Force | Out-Null
Remove-Item "$back\nba2k13c.nro","$back\NBA2K13_shaders.nfsp" -Force -ErrorAction SilentlyContinue
$sh = New-Object -ComObject Shell.Application
$sw = $sh.NameSpace(17).Items() | ? { $_.Name -eq 'Switch' } | select -First 1
if (-not $sw) { 'NO_SWITCH_DEVICE'; exit 1 }
$root=$sh.NameSpace($sw.Path)
$sd=($root.Items() | ? { $_.Name -like '1:*' } | select -First 1).GetFolder
function Sub($f,$n){ foreach($i in @($f.Items())){ if($i.Name -eq $n){ return $i.GetFolder } }; return $null }
$sw2=Sub $sd 'switch'; $dir=Sub $sw2 'nba2k13'
$bk=$sh.NameSpace($back)
foreach($n in @('nba2k13c.nro','NBA2K13_shaders.nfsp')){
  $it=@($dir.Items()) | ? { $_.ExtendedProperty('System.FileName') -eq $n } | select -First 1
  if(-not $it){ "MISSING $n"; continue }
  "pull $n $(Get-Date -Format HH:mm:ss)"
  $bk.CopyHere($it,0x0414)
  $loc=Join-Path $back $n
  $want=(Get-Item "$e\$n").Length
  $ok=$false
  for($k=0;$k -lt 300;$k++){ Start-Sleep 2; if((Test-Path $loc) -and (Get-Item $loc).Length -eq $want){ $ok=$true; break } }
  if(-not $ok){ "PULL_TIMEOUT $n"; continue }
  $h1=(Get-FileHash "$e\$n" -Algorithm MD5).Hash
  $h2=(Get-FileHash $loc -Algorithm MD5).Hash
  "{0}: local {1} card {2} {3}" -f $n,$h1,$h2,($(if($h1 -eq $h2){'MATCH'}else{'DIFF'}))
}
"VERIFY_DONE $(Get-Date -Format HH:mm:ss)"
