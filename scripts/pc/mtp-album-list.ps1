$sh = New-Object -ComObject Shell.Application
$sw = @($sh.NameSpace(17).Items() | Where-Object { $_.Name -eq 'Switch' })[0]
$root = $sh.NameSpace($sw.Path)
$alb = @(@($root.Items()) | Where-Object { $_.Name -like '*Album*' })[0].GetFolder
$g = @(@($alb.Items()) | Where-Object { $_.Name -eq 'NBA 2K13' })[0].GetFolder
$names = @(@($g.Items()) | Where-Object { -not $_.IsFolder } | % { $_.ExtendedProperty('System.FileName') })
"count " + $names.Count
($names | Sort-Object) -join "`n"
