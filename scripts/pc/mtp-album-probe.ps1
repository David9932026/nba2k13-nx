$Dest='C:\Users\26095\cola\swlogs14\album'
New-Item -ItemType Directory -Force $Dest | Out-Null
$sh = New-Object -ComObject Shell.Application
$sw = @($sh.NameSpace(17).Items() | Where-Object { $_.Name -eq 'Switch' })[0]
$root = $sh.NameSpace($sw.Path)
$alb = @(@($root.Items()) | Where-Object { $_.Name -like '*Album*' })[0]
if(-not $alb){ 'X no album'; exit }
"alb: " + $alb.Name
$f = $alb.GetFolder
foreach($y in @($f.Items())){ "  item: " + $y.Name + " folder=" + $y.IsFolder }
