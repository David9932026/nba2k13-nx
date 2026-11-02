param(
  [int]$Seconds = 100,
  [string]$Script = 'input-menu.txt',
  [string]$Tag = 'slib'
)
$ErrorActionPreference = 'Continue'
$proj = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126'
$dir  = Join-Path $proj 'rex\nba2k13app\out\build\win-vk'
$log  = Join-Path $dir 'logs'

Get-Process nba2k13 -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

# Fresh save dir so the run reaches the menu the same way every time.
$root = 'C:\Users\26095\Documents\nba2k13'
$stamp = Get-Date -Format 'HHmmss'
if (Test-Path $root) { Rename-Item $root "C:\Users\26095\Documents\nba2k13_bak_$stamp" -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path "$root\B13EBABEBABEBABE\545408A2\00000001" -Force | Out-Null

# The collector switch, read from the working directory on PC.
Set-Content -Path (Join-Path $dir 'shaderlib.txt') -Value '1' -NoNewline -Encoding ascii
Remove-Item (Join-Path $log 'shaders_2k13.nflib') -ErrorAction SilentlyContinue
Remove-Item (Join-Path $log 'shaders_2k13.txt') -ErrorAction SilentlyContinue

$env:REX_VK_ICD = 'C:\Windows\System32\DriverStore\FileRepository\nvaci.inf_amd64_ccd761b957fdaf7d\nvoglv64.dll'
# The build has both backends compiled in and picks D3D12 first. The shader
# library collector lives in the Vulkan pipeline cache, so force Vulkan.
$env:REX_GPU_BACKEND = 'vulkan'
$icd = $env:REX_VK_ICD
$env:REX_GPU_BACKEND = 'vulkan'
# Win32_Process.Create does NOT inherit this session's environment (it inherits
# the WMI host's), so the variables have to be set inside the command line.
$setEnv = "set REX_GPU_BACKEND=vulkan&& set REX_VK_ICD=$icd&& "
$scriptPath = Join-Path $proj $Script
$args = @(
  "--game_data_root=D:\xox360\00007000\C096DB2DDEE83F64054B",
  "--gpu_plugin=xenos",
  "--mnk_mode=1",
  "--no-protect_zero",
  "--mnk_script=$scriptPath"
)
$cmd = "cmd.exe /c `"" + $setEnv + "`"$dir\nba2k13.exe`" " + ($args -join ' ') + "`""
$r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cmd; CurrentDirectory = $dir }
"pid=$($r.ProcessId) script=$Script secs=$Seconds"

$started = Get-Date
for ($i = 0; $i -lt ($Seconds * 2); $i++) {
  Start-Sleep -Milliseconds 500
  if (-not (Get-Process nba2k13 -ErrorAction SilentlyContinue)) { "process exited at $([int]((Get-Date)-$started).TotalSeconds)s"; break }
}
$alive = Get-Process nba2k13 -ErrorAction SilentlyContinue
if ($alive) { Stop-Process -Id $alive.Id -Force; "killed after $Seconds s" } else { "already gone" }
Start-Sleep -Seconds 2

foreach ($f in 'shaders_2k13.nflib','shaders_2k13.txt') {
  $p = Join-Path $log $f
  if (Test-Path $p) { "{0} {1} B" -f $f, (Get-Item $p).Length } else { "$f MISSING" }
}
