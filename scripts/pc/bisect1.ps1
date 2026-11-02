param([string]$Extra,[string]$Tag,[int]$Seconds=25)
$proj='C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126'
Set-Location $proj
$null = powershell -NoProfile -ExecutionPolicy Bypass -File .\nativo-run.ps1 -Seconds $Seconds -Tag $Tag -Extra "--NBA2K13_renderizador=nativo $Extra"
$l=Get-ChildItem rex\nba2k13app\out\build\win-vk\logs\nba2k13_*.log | Sort LastWriteTime | Select -Last 1
$lost = Select-String -LiteralPath $l.FullName -Pattern 'PRIMER envio fallido' | Select -First 1
$c6 = Select-String -LiteralPath $l.FullName -Pattern 'C6: dibujados=' | Select -Last 1
$st = if ($lost) { 'LOST: ' + ($lost.Line -replace '^.*PRIMER','') } else { 'OK' }
"[$Tag] $($l.Name) $st | " + ($(if($c6){$c6.Line -replace '^.*C6: ','' -replace 'rechazos por causa.*',''}else{'no C6'}))
