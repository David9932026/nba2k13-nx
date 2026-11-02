param([string]$Dest='C:\Users\26095\cola\swlogs17\album',[int]$Ultimas=10)
New-Item -ItemType Directory -Force -Path $Dest | Out-Null
$sh = New-Object -ComObject Shell.Application
$sw = @($sh.NameSpace(17).Items() | Where-Object { $_.Name -eq 'Switch' })[0]
$root = $sh.NameSpace($sw.Path)
$alb = @(@($root.Items()) | Where-Object { $_.Name -like '*Album*' })[0].GetFolder
$g = @(@($alb.Items()) | Where-Object { $_.Name -eq 'NBA 2K13' })[0].GetFolder
$todos = @(@($g.Items()) | Where-Object { -not $_.IsFolder } | Sort-Object { $_.ExtendedProperty('System.FileName') })
$sel = $todos | Select-Object -Last $Ultimas
$loc = $sh.NameSpace($Dest)
foreach ($i in $sel) { "img " + $_.Name; $loc.CopyHere($i, 0x14) }
Start-Sleep 4
'DONE'
