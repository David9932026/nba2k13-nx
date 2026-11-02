param([string]$Name = 'nba2k13c.nro')
$src = "C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126\rex\nba2k13app\out\build\sw\nba2k13.nro"
$len = (Get-Item $src).Length
$md5 = (Get-FileHash $src -Algorithm MD5).Hash
"src $len B $md5"
$tmp = "C:\Users\26095\cola\export\one\$Name"
New-Item -ItemType Directory -Force -Path (Split-Path $tmp) | Out-Null
Copy-Item $src $tmp -Force
$sh = New-Object -ComObject Shell.Application
$sw = @($sh.NameSpace(17).Items() | Where-Object { $_.Name -eq 'Switch' })[0]
$root = $sh.NameSpace($sw.Path)
$sd = @(@($root.Items()) | Where-Object { $_.Name -like '1:*' })[0].GetFolder
function Sub($f,$n){ foreach($i in @($f.Items())){ if($i.Name -eq $n){ return $i.GetFolder } }; return $null }
$dir = Sub (Sub $sd 'switch') 'nba2k13'
"push $Name $(Get-Date -Format HH:mm:ss)"
$dir.CopyHere($tmp, 0x0414)
for($k=0; $k -lt 150; $k++){ Start-Sleep 2
  $it = @($dir.Items()) | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
  $sz = $null
  try { $sz = $it.ExtendedProperty('System.Size') } catch {}
  if ($sz -eq $len) { "size ok $(Get-Date -Format HH:mm:ss)"; break }
}
'PUSH_ONE_DONE'
