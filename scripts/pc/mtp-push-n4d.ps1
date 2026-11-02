$e='C:\Users\26095\cola\export\n4'
$sh = New-Object -ComObject Shell.Application
$sw = $sh.NameSpace(17).Items() | ? { $_.Name -eq 'Switch' } | select -First 1
$sd=(($sh.NameSpace($sw.Path)).Items() | ? { $_.Name -like '1:*' }).GetFolder
function Sub($f,$n){ foreach($i in @($f.Items())){ if($i.Name -eq $n){ return $i.GetFolder } } }
$dir=Sub (Sub $sd 'switch') 'nba2k13'
$back='C:\Users\26095\cola\swback-n4d'; New-Item -ItemType Directory $back -Force | Out-Null; Get-ChildItem $back | Remove-Item -Force
$bk=$sh.NameSpace($back)
foreach($n in 'nba2k13c.nro','nba2k13b.nro'){
  $len=(Get-Item "$e\$n").Length
  "push $n $(Get-Date -Format HH:mm:ss)"; $dir.CopyHere("$e\$n",0x0414)
  for($k=0;$k -lt 200;$k++){ Start-Sleep 3; $it=@($dir.Items()) | ? { $_.ExtendedProperty('System.FileName') -eq $n } | select -First 1; if($it -and $it.ExtendedProperty('System.Size') -eq $len){ break } }
  Start-Sleep 5
  $bk.CopyHere($it,0x0414)
  for($k=0;$k -lt 200;$k++){ Start-Sleep 2; if((Test-Path "$back\$n") -and (Get-Item "$back\$n").Length -eq $len){ break } }
  Start-Sleep 2
  $h1=(Get-FileHash "$e\$n" -Algorithm MD5).Hash; $h2=(Get-FileHash "$back\$n" -Algorithm MD5).Hash
  "{0}: local {1} card {2} {3}" -f $n,$h1,$h2,($(if($h1 -eq $h2){'MATCH'}else{'DIFF'}))
}
