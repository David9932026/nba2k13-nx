param(
  [Parameter(Mandatory = $true)][string[]]$Button,
  [int]$Hold = 600,
  [int]$After = 0,
  [int]$Gap = 300,
  [string]$File = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126\input-live.txt'
)
# Appends button presses to the live mnk script. The game hot-reloads the file,
# and event times are relative to process start, so we translate "from now" into
# an absolute offset before writing.
$p = Get-Process nba2k13 -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $p) { 'no nba2k13 process'; exit 1 }
$ageMs = [int]((Get-Date) - $p.StartTime).TotalMilliseconds
$t = $ageMs + $After
# Split on commas manually: the argument comes in as a single string when the
# whole list is passed as one token.
$Button = @($Button | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$lines = @()
foreach ($b in $Button) {
  $lines += ("{0} {1} {2}" -f $t, ($t + $Hold), $b)
  $t += $Hold + $Gap
}
# rewrite the whole file so a reload never sees a half-written line
$existing = @()
if (Test-Path $File) { $existing = @(Get-Content $File | Where-Object { $_ -match '\S' }) }
$all = @($existing + $lines) | Sort-Object { [int]($_ -split '\s+')[0] }
Set-Content -Path $File -Value $all -Encoding ascii
"appended at t=${ageMs}ms:"
$lines | ForEach-Object { "  $_" }
