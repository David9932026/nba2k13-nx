$ErrorActionPreference='Continue'
$e='C:\Users\26095\cola\export\n7'
$src="$e\nba2k13c.nro"
$len=(Get-Item $src).Length
$hash=(Get-FileHash $src -Algorithm MD5).Hash
"new build: $len B md5 $hash"
$sh = New-Object -ComObject Shell.Application
$sw = @($sh.NameSpace(17).Items() | Where-Object { $_.Name -eq 'Switch' })[0]
$root = $sh.NameSpace($sw.Path)
$sd = @(@($root.Items()) | Where-Object { $_.Name -like '1:*' })[0].GetFolder
function Sub($f,$n){ foreach($i in @($f.Items())){ if($i.Name -eq $n){ return $i.GetFolder } }; return $null }
$dir = Sub (Sub $sd 'switch') 'nba2k13'
foreach($name in @('nba2k13.nro','nba2k13c.nro','nba2k13b.nro','nba2k13i.nro','nba2k13j.nro')){
  Copy-Item $src "$e\$name" -Force
  "push $name $(Get-Date -Format HH:mm:ss)"
  $dir.CopyHere("$e\$name", 0x0414)
  for($k=0;$k -lt 120;$k++){ Start-Sleep 2
    $it=@($dir.Items()) | Where-Object { $_.ExtendedProperty('System.FileName') -eq $name } | Select-Object -First 1
    if($it -and $it.ExtendedProperty('System.Size') -eq $len){ "  size ok $(Get-Date -Format HH:mm:ss)"; break }
  }
}
'PUSH_ALL_DONE'
