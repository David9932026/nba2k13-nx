$ErrorActionPreference='Continue'
# Push only the toml (small, no rebuild). Overwrites the card's nba2k13.toml via MTP CopyHere.
$src='C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126\rex\nba2k13app\out\build\win-vk\nba2k13.toml'
$sh = New-Object -ComObject Shell.Application
$sw = $sh.NameSpace(17).Items() | ? { $_.Name -eq 'Switch' } | select -First 1
if (-not $sw) { 'NO_SWITCH_DEVICE'; exit 1 }
$root=$sh.NameSpace($sw.Path)
$sd=($root.Items() | ? { $_.Name -like '1:*' } | select -First 1).GetFolder
function Sub($f,$n){ foreach($i in @($f.Items())){ if($i.Name -eq $n){ return $i.GetFolder } }; return $null }
$sw2=Sub $sd 'switch'; $dir=Sub $sw2 'nba2k13'
if (-not $dir) { 'NO_NBA2K13_DIR'; exit 1 }
"toml local:"; Get-Content $src
$len=(Get-Item $src).Length
"push nba2k13.toml ($len B) $(Get-Date -Format HH:mm:ss)"
$dir.CopyHere($src,0x0414)
for($k=0;$k -lt 60;$k++){ Start-Sleep 2
  $it=@($dir.Items()) | ? { $_.ExtendedProperty('System.FileName') -eq 'nba2k13.toml' } | select -First 1
  if($it){ $sz=$it.ExtendedProperty('System.Size'); if($sz -eq $len){ "  size ok $sz $(Get-Date -Format HH:mm:ss)"; 'TOML_DONE'; exit 0 } }
}
'TOML_TIMEOUT'
