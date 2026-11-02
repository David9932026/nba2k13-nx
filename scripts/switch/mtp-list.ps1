$shell = New-Object -ComObject Shell.Application
$dev = @($shell.NameSpace(0x11).Items()) | Where-Object { $_.Name -eq 'Switch' } | Select-Object -First 1
if (-not $dev) { 'DEVICE GONE'; exit }
$sd = @($dev.GetFolder.Items()) | Where-Object { $_.Name -eq '1: SD Card' }
$sw = @($sd.GetFolder.Items()) | Where-Object { $_.Name -eq 'switch' }
$g = @($sw.GetFolder.Items()) | Where-Object { $_.Name -eq 'nba2k13' }
'--- nba2k13 dir:'
@($g.GetFolder.Items()) | ForEach-Object { '{0}  {1}' -f $_.Name, $_.Type }
'--- logs dir count:'
$lg = @($g.GetFolder.Items()) | Where-Object { $_.Name -eq 'logs' }
if ($lg) { 'logs entries: ' + @($lg.GetFolder.Items()).Count }
