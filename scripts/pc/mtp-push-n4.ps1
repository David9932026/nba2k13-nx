$ErrorActionPreference='Continue'
$e='C:\Users\26095\cola\export\n4'
$sh = New-Object -ComObject Shell.Application
$sw = $sh.NameSpace(17).Items() | ? { $_.Name -eq 'Switch' } | select -First 1
$root=$sh.NameSpace($sw.Path)
$sd=($root.Items() | ? { $_.Name -like '1:*' } | select -First 1).GetFolder
function Sub($f,$n){ foreach($i in @($f.Items())){ if($i.Name -eq $n){ return $i.GetFolder } }; return $null }
$sw2=Sub $sd 'switch'; $dir=Sub $sw2 'nba2k13'; $inst=Sub $sw2 'nsp-install'
"existing in nba2k13:"; @($dir.Items()) | ? { -not $_.IsFolder } | % { "  $($_.Name)  $($dir.GetDetailsOf($_,2))" }
"existing in nsp-install:"; @($inst.Items()) | % { "  $($_.Name)" }
function Push($folder,$file){
  $name=[IO.Path]::GetFileName($file); $len=(Get-Item $file).Length
  "push $name ($len B) $(Get-Date -Format HH:mm:ss)"
  $folder.CopyHere($file,0x0414)
  for($k=0;$k -lt 240;$k++){ Start-Sleep 3
    $it=@($folder.Items()) | ? { $_.ExtendedProperty('System.FileName') -eq $name } | select -First 1
    if($it){ $sz=$it.ExtendedProperty('System.Size'); if($sz -eq $len){ "  size ok $sz $(Get-Date -Format HH:mm:ss)"; return } }
  }
  "  TIMEOUT size $sz"
}
Push $inst "$e\forwarder-c.nsp"
Push $dir "$e\nba2k13c.nro"
Start-Sleep 5
$back='C:\Users\26095\cola\swback-n4'; New-Item -ItemType Directory $back -Force | Out-Null
$bk=$sh.NameSpace($back)
foreach($pair in @(@($dir,'NBA2K13_shaders.nfsp'),@($dir,'nba2k13.toml'),@($inst,'forwarder-c.nsp'),@($dir,'nba2k13c.nro'))){
  $f=$pair[0]; $n=$pair[1]
  $it=@($f.Items()) | ? { $_.ExtendedProperty('System.FileName') -eq $n } | select -First 1
  if(-not $it){ "MISSING $n"; continue }
  $bk.CopyHere($it,0x0414)
  $loc=Join-Path $back $n; $loc2=Join-Path $back $it.Name
  for($k=0;$k -lt 200;$k++){ Start-Sleep 2; $p= if(Test-Path $loc){$loc}elseif(Test-Path $loc2){$loc2}else{$null}; if($p -and (Get-Item $p).Length -eq (Get-Item "$e\$n").Length){ break } }
  $h1=(Get-FileHash "$e\$n" -Algorithm MD5).Hash; $h2= if($p){(Get-FileHash $p -Algorithm MD5).Hash}else{'none'}
  "{0}: local {1} card {2} {3}" -f $n,$h1,$h2,($(if($h1 -eq $h2){'MATCH'}else{'DIFF'}))
}
"done $(Get-Date -Format HH:mm:ss)"
