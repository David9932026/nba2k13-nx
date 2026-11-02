$ErrorActionPreference='Continue'
$e='C:\Users\26095\cola\export\n7'
$back='C:\Users\26095\cola\swback-n7'
New-Item -ItemType Directory -Force $back | Out-Null
Remove-Item "$back\nba2k13c.nro","$back\nba2k13.nro","$back\nba2k13.toml" -Force -ErrorAction SilentlyContinue
$sh = New-Object -ComObject Shell.Application
$sw = @($sh.NameSpace(17).Items() | Where-Object { $_.Name -eq 'Switch' })[0]
$root = $sh.NameSpace($sw.Path)
$sd = @(@($root.Items()) | Where-Object { $_.Name -like '1:*' })[0].GetFolder
function Sub($f,$n){ foreach($i in @($f.Items())){ if($i.Name -eq $n){ return $i.GetFolder } }; return $null }
$dir = Sub (Sub $sd 'switch') 'nba2k13'
$bk = $sh.NameSpace($back)
foreach($n in @('nba2k13c.nro','nba2k13.nro','nba2k13.toml')){
  "pull $n $(Get-Date -Format HH:mm:ss)"
  $it = @($dir.Items()) | Where-Object { $_.ExtendedProperty('System.FileName') -eq $n } | Select-Object -First 1
  if(-not $it){ "  MISSING $n"; continue }
  $bk.CopyHere($it, 0x0414)
  $loc = Join-Path $back $n
  for($k=0;$k -lt 200;$k++){ Start-Sleep 2; if((Test-Path $loc) -and ((Get-Item $loc).Length -eq (Get-Item "$e\$n").Length)){ break } }
  $h1=(Get-FileHash "$e\$n" -Algorithm MD5).Hash
  $h2= if(Test-Path $loc){(Get-FileHash $loc -Algorithm MD5).Hash}else{'none'}
  "{0}: local {1} card {2} {3}" -f $n,$h1,$h2,($(if($h1 -eq $h2){'MATCH'}else{'DIFF'}))
}
'VERIFY_DONE'
