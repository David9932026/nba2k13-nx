param(
  [int]$WaitSec = 80,
  [string]$Shots = '35,50,62,72'
)
# A/B the two "swallow the error instead of crashing" patches that landed after the
# run that still reached the player-creation screen.
$proj = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126'
$script = Join-Path $proj 'input-script6.txt'

$combos = @(
  @{ Tag = 'ab1'; Extra = [string[]]@('--lazy_map=false', '--indirect_neighbour_retry=false') },
  @{ Tag = 'ab2'; Extra = [string[]]@('--lazy_map=false') },
  @{ Tag = 'ab3'; Extra = [string[]]@('--indirect_neighbour_retry=false') }
)

foreach ($c in $combos) {
  "=== $($c.Tag): $($c.Extra -join ' ') ==="
  $extra = [string[]](@('--no-protect_zero') + $c.Extra)
  & (Join-Path $proj 'shot-cycle.ps1') -WaitSec $WaitSec -Shots $Shots -Script $script -Tag $c.Tag -Extra $extra
  Start-Sleep -Seconds 1
}
