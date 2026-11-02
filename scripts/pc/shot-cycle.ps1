param(
  [int]$WaitSec = 60,
  [string]$Shots = '12,22,32,45,58',
  [string]$Script = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126\input-script1.txt',
  [string]$Tag = 'sc',
  [string[]]$Extra = @(),
  [switch]$KeepSave
)
$proj = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126'
$dir = Join-Path $proj 'rex\nba2k13app\out\build\win-amd64-release'
$exe = Join-Path $dir 'nba2k13.exe'
$logs = Join-Path $dir 'logs'
$save = 'C:\Users\26095\Documents\nba2k13'
$bak = Join-Path 'C:\Users\26095\Documents' ("nba2k13_bak_" + (Get-Date -Format 'HHmmss'))

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

if (-not $KeepSave -and (Test-Path $save)) {
  Move-Item $save $bak -Force
  "save rotated -> $bak"
}

$before = @(Get-ChildItem $logs -Filter '*.log' | ForEach-Object { $_.Name })
$args = @("--game_data_root=D:\xox360\00007000\C096DB2DDEE83F64054B", "--gpu_plugin=xenos", "--mnk_mode=1")
if ($Script) { $args += "--mnk_script=$Script" }
foreach ($e in $Extra) { $args += $e }
$p = Start-Process -FilePath $exe -ArgumentList $args -WorkingDirectory $dir -PassThru

$shotTimes = @($Shots.Split(',') | ForEach-Object { [int]$_ })
$bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
Add-Type -Namespace W2 -Name U2 -MemberDefinition '[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r); [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h); [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow(); [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }'
for ($i = 1; $i -le $WaitSec; $i++) {
  Start-Sleep -Seconds 1
  $p.Refresh()
  if ($p.HasExited) { break }
  if ($shotTimes -contains $i) {
    $hwnd = $p.MainWindowHandle
    if ($hwnd -ne 0) { [void][W2.U2]::SetForegroundWindow($hwnd); Start-Sleep -Milliseconds 250 }
    $rect = New-Object W2.U2+RECT
    $useRect = $false
    if ($hwnd -ne 0 -and [W2.U2]::GetWindowRect($hwnd, [ref]$rect)) {
      if (($rect.R - $rect.L) -gt 100 -and ($rect.B - $rect.T) -gt 100) { $useRect = $true }
    }
    if ($useRect) {
      $srcX = $rect.L; $srcY = $rect.T; $w = $rect.R - $rect.L; $h = $rect.B - $rect.T
    } else {
      $srcX = $bounds.X; $srcY = $bounds.Y; $w = $bounds.Width; $h = $bounds.Height
    }
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($srcX, $srcY, 0, 0, $bmp.Size)
    $fg = [W2.U2]::GetForegroundWindow()
    if ($fg -ne $hwnd) { "  (aviso: ventana del juego NO esta al frente)" }
    $out = Join-Path $proj ("shot-{0}-{1}s.png" -f $Tag, $i)
    $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    "shot ${i}s -> $(Split-Path $out -Leaf) $((Get-Item $out).Length) B rect=$useRect"
  }
}
$p.Refresh()
if ($p.HasExited) { "exit=$($p.ExitCode) alive=$($i-1)s" } else { "alive $($i-1)s"; Stop-Process -Id $p.Id -Force }
Start-Sleep -Milliseconds 500
$log = Get-ChildItem $logs -Filter '*.log' | Where-Object { $before -notcontains $_.Name } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($log) {
  "log=$($log.Name) $($log.Length) B"
  Select-String -Path $log.FullName -Pattern 'Unhandled guest access|NULLNODE|FATAL|\[error\]' | Select-Object -Last 8 | ForEach-Object { "  " + $_.Line.Substring(0, [Math]::Min(160, $_.Line.Length)) }
}
