param(
  [int]$WaitSec = 60,
  [int[]]$Shots = @(12, 18, 22, 28, 36, 45, 55),
  [string]$Script = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126\input-script1.txt',
  [string]$Tag = 'drv',
  [string[]]$Extra = @()
)
$proj = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126'
$dir = Join-Path $proj 'rex\nba2k13app\out\build\win-amd64-release'
$exe = Join-Path $dir 'nba2k13.exe'
$logs = Join-Path $dir 'logs'
Add-Type -AssemblyName System.Drawing
Add-Type -Namespace W -Name U -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
'@

$before = @(Get-ChildItem $logs -Filter '*.log' | ForEach-Object { $_.Name })
$args = @("--game_data_root=D:\xox360\00007000\C096DB2DDEE83F64054B", "--gpu_plugin=xenos", "--mnk_mode=1")
if ($Script) { $args += "--mnk_script=$Script" }
foreach ($e in $Extra) { $args += $e }
$p = Start-Process -FilePath $exe -ArgumentList $args -WorkingDirectory $dir -PassThru
& 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -NoProfile -Command "exit 0" | Out-Null

$hwnd = [IntPtr]::Zero
for ($i = 0; $i -lt $WaitSec; $i++) {
  Start-Sleep -Seconds 1
  $p.Refresh()
  if ($p.HasExited) { break }
  if ($hwnd -eq [IntPtr]::Zero) {
    if ($p.MainWindowHandle -ne 0) { $hwnd = $p.MainWindowHandle }
  }
  $elapsed = $i + 1
  if ($Shots -contains $elapsed -and $hwnd -ne [IntPtr]::Zero) {
    [W.U]::SetForegroundWindow($hwnd) | Out-Null
    Start-Sleep -Milliseconds 250
    $r = New-Object W.U+RECT
    if ([W.U]::GetWindowRect($hwnd, [ref]$r)) {
      $w = $r.R - $r.L; $h = $r.B - $r.T
      if ($w -gt 0 -and $h -gt 0) {
        $bmp = New-Object System.Drawing.Bitmap $w, $h
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size)
        $out = Join-Path $proj ("shot-{0}-{1}s.png" -f $Tag, $elapsed)
        $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
        $g.Dispose(); $bmp.Dispose()
        "shot ${elapsed}s -> $out"
      }
    }
  }
}
$p.Refresh()
if ($p.HasExited) { "exit=$($p.ExitCode) alive=${i}s" } else { "alive ${i}s"; Stop-Process -Id $p.Id -Force }
Start-Sleep -Milliseconds 400
$log = Get-ChildItem $logs -Filter '*.log' | Where-Object { $before -notcontains $_.Name } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($log) {
  "log=$($log.Name)"
  Select-String -Path $log.FullName -Pattern 'mnk-script|Unhandled guest access|NULLNODE|FATAL' | ForEach-Object { "  " + $_.Line.Substring(0, [Math]::Min(150, $_.Line.Length)) }
}
