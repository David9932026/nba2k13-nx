param([int]$Seconds = 180, [string]$Tag = 'independent-20261029-1652-r1')
$ErrorActionPreference = 'Stop'
$proj = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126'
$exe = Join-Path $proj 'rex\nba2k13app\out\build\win-amd64-release\nba2k13.exe'
if (Get-Process nba2k13,ninja,rexglue -ErrorAction SilentlyContinue) { throw 'Another game/build instance exists; refusing to launch.' }
$run = Join-Path $proj ("recheck-$Tag")
if (Test-Path $run) { throw "Run directory already exists: $run" }
New-Item -ItemType Directory $run | Out-Null
$inputFile = Join-Path $run 'input.txt'
'' | Set-Content $inputFile -Encoding ascii
$save = 'C:\Users\26095\Documents\nba2k13'
if (Test-Path $save) {
  Get-ChildItem $save -Recurse -File | Select-Object FullName,Length,LastWriteTimeUtc | Export-Csv (Join-Path $run 'save-before.csv') -NoTypeInformation -Encoding UTF8
}
$info = New-Object System.Diagnostics.ProcessStartInfo
$info.FileName = $exe
$info.WorkingDirectory = $run
$info.UseShellExecute = $false
$info.EnvironmentVariables.Remove('REX_RT_PROBE')
$info.EnvironmentVariables.Remove('REX_EDRAM_PROBE')
$info.EnvironmentVariables.Remove('REX_FB_DUMP_EVERY')
$info.EnvironmentVariables['REX_GUEST_OUTPUT_DUMP_EVERY'] = '120'
$info.Arguments = '--game_data_root=D:\xox360\00007000\C096DB2DDEE83F64054B --gpu_plugin=xenos --mnk_mode=1 --no-protect_zero --mnk_script="' + $inputFile + '"'
$p = New-Object System.Diagnostics.Process
$p.StartInfo = $info
$timer = [System.Diagnostics.Stopwatch]::StartNew()
$started = Get-Date
$termination = 'natural_exit'
$aliveAtLimit = $false
try {
  if (-not $p.Start()) { throw 'Process failed to start' }
  @{ pid=$p.Id; start=$started.ToString('o'); tag=$Tag; seconds=$Seconds; run=$run; input=$inputFile; rt_probe=$false; edram_probe=$false } | ConvertTo-Json | Set-Content (Join-Path $run 'state.json') -Encoding UTF8
  "Started pid=$($p.Id) tag=$Tag input=$inputFile"
  $nextShot = 12
  while ($timer.Elapsed.TotalSeconds -lt $Seconds -and -not $p.HasExited) {
    if ($timer.Elapsed.TotalSeconds -ge $nextShot) {
      $shotTag = "$Tag-$nextShot"
      $shotPath = Join-Path $proj "shot-$shotTag.png"
      if (Test-Path $shotPath) { throw "Refusing to overwrite $shotPath" }
      & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $proj 'snap.ps1') -Tag $shotTag
      $nextShot += 12
    }
    Start-Sleep -Milliseconds 200
  }
  $aliveAtLimit = -not $p.HasExited
  if ($aliveAtLimit) {
    $finalPath = Join-Path $proj "shot-$Tag-final.png"
    if (Test-Path $finalPath) { throw "Refusing to overwrite $finalPath" }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $proj 'snap.ps1') -Tag "$Tag-final"
    $termination = 'requested_window_close'
    $closed = $p.CloseMainWindow()
    if (-not $p.WaitForExit(8000)) { $termination = 'forced_stop_after_time_limit'; $p.Kill(); $p.WaitForExit() }
  }
} finally {
  if ($p.Id -and -not $p.HasExited) { $termination = 'forced_cleanup_after_script_error'; $p.Kill(); $p.WaitForExit() }
  $result = @{ pid=$p.Id; started=$started.ToString('o'); finished=(Get-Date).ToString('o'); elapsed_seconds=$timer.Elapsed.TotalSeconds; alive_at_limit=$aliveAtLimit; termination=$termination; exit_code=if ($p.HasExited) {$p.ExitCode} else {$null}; tag=$Tag }
  $result | ConvertTo-Json | Set-Content (Join-Path $run 'result.json') -Encoding UTF8
  $result | ConvertTo-Json
  if (Test-Path $save) { Get-ChildItem $save -Recurse -File | Select-Object FullName,Length,LastWriteTimeUtc | Export-Csv (Join-Path $run 'save-after.csv') -NoTypeInformation -Encoding UTF8 }
}
