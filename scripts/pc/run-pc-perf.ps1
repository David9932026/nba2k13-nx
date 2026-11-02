param(
  [int]$Seconds = 175,
  [string]$Script = 'input-pause.txt',
  [string]$Tag = 'pcmenu',
  [string]$Extra = ''
)
$ErrorActionPreference = 'Continue'
$proj = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126'
$dir  = Join-Path $proj 'rex\nba2k13app\out\build\win-vk'
$log  = Join-Path $dir 'logs'

Add-Type -AssemblyName System.Drawing
Add-Type -Namespace W -Name U -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
'@

Get-Process nba2k13 -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

# clean capturas
Get-ChildItem (Join-Path $dir 'capturas') -Filter '*.png' -ErrorAction SilentlyContinue | Remove-Item -Force

Set-Content -Path (Join-Path $dir 'shaderlib.txt') -Value '0' -NoNewline -Encoding ascii

# enable auto capture of presented frame every 2s
Set-Content -Path (Join-Path $dir 'nba2k13.toml') -Value "NBA2K13_renderizador = `"nativo`"`nNBA2K13_captura_cada_s = 10`nNBA2K13_captura_max = 30`nnba2k13_nativo_estadisticas_pipeline = true`n$($Extra.Replace('NBA2K13_nativo_','nba2k13_nativo_').Replace('|',"`n"))" -Encoding ascii

$icd = 'C:\Windows\System32\DriverStore\FileRepository\nvaci.inf_amd64_ccd761b957fdaf7d\nvoglv64.dll'
$setEnv = "set REX_GPU_BACKEND=vulkan&& set REX_VK_ICD=$icd&& "
$scriptPath = Join-Path $proj $Script
$argsList = @(
  "--game_data_root=D:\xox360\00007000\C096DB2DDEE83F64054B",
  "--gpu_plugin=xenos",
  "--mnk_mode=1",
  "--no-protect_zero",
  "--mnk_script=$scriptPath"
)

$before = Get-ChildItem (Join-Path $log 'nba2k13_*.log') | Sort-Object LastWriteTime | Select-Object -Last 1
$beforeName = $before.Name

$cmd = "cmd.exe /c `"" + $setEnv + "`"$dir\nba2k13.exe`" " + ($argsList -join ' ') + "`""
$r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cmd; CurrentDirectory = $dir }
"pid=$($r.ProcessId) tag=$Tag secs=$Seconds"

$shots = @(6, 12, 18, 24, 30, 36, 42, 50, 60, 70, 82, 90, 100, 120, 140, 160)
$hwnd = [IntPtr]::Zero
$started = Get-Date
for ($i = 0; $i -lt ($Seconds * 2); $i++) {
  Start-Sleep -Milliseconds 500
  $p = Get-Process nba2k13 -ErrorAction SilentlyContinue
  if (-not $p) { "process exited at $([int]((Get-Date)-$started).TotalSeconds)s"; break }
  if ($hwnd -eq [IntPtr]::Zero -and $p.MainWindowHandle -ne 0) { $hwnd = $p.MainWindowHandle }
  $elapsed = [int]((Get-Date) - $started).TotalSeconds
  if ($shots -contains $elapsed -and $hwnd -ne [IntPtr]::Zero) {
    [W.U]::SetForegroundWindow($hwnd) | Out-Null
    Start-Sleep -Milliseconds 200
    $rect = New-Object W.U+RECT
    if ([W.U]::GetWindowRect($hwnd, [ref]$rect)) {
      $w = $rect.R - $rect.L; $h = $rect.B - $rect.T
      if ($w -gt 0 -and $h -gt 0) {
        $bmp = New-Object System.Drawing.Bitmap $w, $h
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.CopyFromScreen($rect.L, $rect.T, 0, 0, $bmp.Size)
        $out = Join-Path $proj ("shot-{0}-{1}s.png" -f $Tag, $elapsed)
        $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
        $g.Dispose(); $bmp.Dispose()
        "shot ${elapsed}s"
      }
    }
  }
}
$alive = Get-Process nba2k13 -ErrorAction SilentlyContinue
if ($alive) { Stop-Process -Id $alive.Id -Force; "killed after $Seconds s" }
Start-Sleep -Seconds 2

$after = Get-ChildItem (Join-Path $log 'nba2k13_*.log') | Sort-Object LastWriteTime | Select-Object -Last 1
"last log before: $beforeName"
if ($after) { "last log after : $($after.Name)  $($after.Length) B" }
$cap = Get-ChildItem (Join-Path $dir 'capturas') -Filter '*.png' -ErrorAction SilentlyContinue
"capturas: $($cap.Count) files, sizes: $(($cap | Group-Object Length | ForEach-Object { "$($_.Name)x$($_.Count)" }) -join ', ')"






$keep = Join-Path 'C:\Users\26095\cola\pcruns' $Tag; New-Item -ItemType Directory -Force $keep | Out-Null; Copy-Item (Join-Path $dir 'capturas\*.png') $keep -Force; "kept in $keep"
