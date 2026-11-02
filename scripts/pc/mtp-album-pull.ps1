$Dest='C:\Users\26095\cola\swlogs14\album'
New-Item -ItemType Directory -Force $Dest | Out-Null
$sh = New-Object -ComObject Shell.Application
$sw = @($sh.NameSpace(17).Items() | Where-Object { $_.Name -eq 'Switch' })[0]
$root = $sh.NameSpace($sw.Path)
$alb = @(@($root.Items()) | Where-Object { $_.Name -like '*Album*' })[0].GetFolder
$g = @(@($alb.Items()) | Where-Object { $_.Name -eq 'NBA 2K13' })[0].GetFolder
$loc = $sh.NameSpace($Dest)
$items = @($g.Items()) | Where-Object { -not $_.IsFolder -and $_.ExtendedProperty('System.FileName') -like '*.jpg' } | Sort-Object { $_.ExtendedProperty('System.FileName') } -Descending
"found: " + $items.Count
$take = $items | Select-Object -First 16
foreach($i in $take){ $loc.CopyHere($i, 0x14) }
Start-Sleep -Seconds 3
Get-ChildItem $Dest -File | % { $_.Name + "  " + [math]::Round($_.Length/1KB) + " KB" }
