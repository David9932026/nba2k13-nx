$Dest='C:\Users\26095\cola\swlogs15\album'
New-Item -ItemType Directory -Force $Dest | Out-Null
$sh = New-Object -ComObject Shell.Application
$sw = @($sh.NameSpace(17).Items() | Where-Object { $_.Name -eq 'Switch' })[0]
$root = $sh.NameSpace($sw.Path)
$alb = @(@($root.Items()) | Where-Object { $_.Name -like '*Album*' })[0].GetFolder
$g = @(@($alb.Items()) | Where-Object { $_.Name -eq 'NBA 2K13' })[0].GetFolder
$loc = $sh.NameSpace($Dest)
$pick = @(@($g.Items()) | Where-Object { -not $_.IsFolder } | Where-Object { $_.ExtendedProperty('System.FileName') -ge '2026110103000000.jpg' })
"picking " + $pick.Count
foreach($i in $pick){ $loc.CopyHere($i, 0x14) }
Start-Sleep -Seconds 4
Get-ChildItem $Dest -File | % { $_.Name + "  " + [math]::Round($_.Length/1KB) + " KB" }
