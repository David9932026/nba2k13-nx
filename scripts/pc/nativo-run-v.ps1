param(
  [int]$Seconds = 45,
  [string]$Script = 'input-menu.txt',
  [string]$Extra = '',
  [string]$Tag = 'n2b',
  [switch]$FreshSave
)
$ErrorActionPreference = 'Continue'
$proj = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126'
$dir  = Join-Path $proj 'rex\nba2k13app\out\build\win-vk'
$log  = Join-Path $dir 'logs'

Get-Process nba2k13 -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

if ($FreshSave) {
  $root = 'C:\Users\26095\Documents\nba2k13'
  $stamp = Get-Date -Format 'HHmmss'
  if (Test-Path $root) { Rename-Item $root "C:\Users\26095\Documents\nba2k13_bak_$stamp" -ErrorAction SilentlyContinue }
  New-Item -ItemType Directory -Path "$root\B13EBABEBABEBABE\545408A2\00000001" -Force | Out-Null
}

# The collector must stay off unless we ask for it: it writes a 20 MB file.
Set-Content -Path (Join-Path $dir 'shaderlib.txt') -Value '0' -NoNewline -Encoding ascii

$icd = 'C:\Windows\System32\DriverStore\FileRepository\nvaci.inf_amd64_ccd761b957fdaf7d\nvoglv64.dll'
if ($env:COLA_VVL -eq "1") { $vl="C:\Users\26095\msys64\msys64\ucrt64\bin"; $setEnv = "set REX_GPU_BACKEND=vulkan&& set PATH=$vl;%PATH%&& set REX_VK_ICD=$vl\vulkan-1.dll&& set VK_DRIVER_FILES=C:\Windows\System32\DriverStore\FileRepository\nvaci.inf_amd64_ccd761b957fdaf7d\nv-vk64.json&& set VK_LAYER_PATH=$vl&& set VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation&& set VK_KHRONOS_VALIDATION_LOG_FILENAME=$dir\vvl.txt&& set VK_KHRONOS_VALIDATION_DEBUG_ACTION=VK_DBG_LAYER_ACTION_LOG_MSG&& set VK_KHRONOS_VALIDATION_REPORT_FLAGS=error&& " } else { $setEnv = "set REX_GPU_BACKEND=vulkan&& set REX_VK_ICD=$icd&& " }
$scriptPath = Join-Path $proj $Script
$argsList = @(
  "--game_data_root=D:\xox360\00007000\C096DB2DDEE83F64054B",
  "--gpu_plugin=xenos",
  "--mnk_mode=1",
  "--no-protect_zero",
  "--mnk_script=$scriptPath"
)
if ($Extra -ne '') { $argsList += $Extra.Split(' ') }

$before = Get-ChildItem (Join-Path $log 'nba2k13_*.log') -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
$beforeName = if ($before) { $before.Name } else { '(none)' }

$cmd = "cmd.exe /c `"" + $setEnv + "`"$dir\nba2k13.exe`" " + ($argsList -join ' ') + "`""
$pp = Start-Process -FilePath cmd.exe -ArgumentList ("/c `"" + $setEnv + "`"$dir\nba2k13.exe`" " + ($argsList -join " ") + "`"") -WorkingDirectory $dir -WindowStyle Normal -PassThru; $r = @{ProcessId=$pp.Id}
"pid=$($r.ProcessId) tag=$Tag secs=$Seconds extra='$Extra'"

$started = Get-Date
for ($i = 0; $i -lt ($Seconds * 2); $i++) {
  Start-Sleep -Milliseconds 500
  if (-not (Get-Process nba2k13 -ErrorAction SilentlyContinue)) { "process exited at $([int]((Get-Date)-$started).TotalSeconds)s"; break }
}
$alive = Get-Process nba2k13 -ErrorAction SilentlyContinue
if ($alive) { Stop-Process -Id $alive.Id -Force; "killed after $Seconds s" } else { "already gone" }
Start-Sleep -Seconds 2

$after = Get-ChildItem (Join-Path $log 'nba2k13_*.log') -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
"last log before: $beforeName"
if ($after) { "last log after : $($after.Name)  $($after.Length) B" } else { "no logs" }
foreach ($f in 'rex_crash.log','rex_stderr.log') {
  $p = Join-Path $log "rex\$f"
  if (Test-Path $p) { "{0} {1} B  {2}" -f $f, (Get-Item $p).Length, (Get-Item $p).LastWriteTime }
}


