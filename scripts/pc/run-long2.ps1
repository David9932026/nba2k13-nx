param([int]$WaitSec = 300, [int[]]$Shots = @(60,150,240))
$ErrorActionPreference = 'SilentlyContinue'
$proj = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126'
$dir = "$proj\rex\nba2k13app\out\build\win-amd64-release"
$out = "$proj\stderr-long.txt"; $err = "$proj\stderr-long-err.txt"
Remove-Item $out, $err -ErrorAction SilentlyContinue

Add-Type -AssemblyName System.Drawing, System.Windows.Forms
Add-Type @"
using System;using System.Runtime.InteropServices;
public class W { [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
public struct RECT { public int L,T,R,B; } }
"@

$p = Start-Process -FilePath "$dir\nba2k13.exe" -ArgumentList @(
  '--game_data_root=D:\xox360\00007000\C096DB2DDEE83F64054B',
  '--gpu_plugin=xenos'
) -WorkingDirectory $dir -PassThru -RedirectStandardOutput $out -RedirectStandardError $err

$shotNz = 0
for ($i = 1; $i -le $WaitSec; $i++) {
  Start-Sleep -Seconds 1
  $p.Refresh()
  if ($p.HasExited) { break }
  if ($shotNz -lt $Shots.Count -and $i -ge $Shots[$shotNz]) {
    $h = $p.MainWindowHandle
    if ($h -ne 0) {
      [W]::ShowWindow($h, 9) | Out-Null
      [W]::SetForegroundWindow($h) | Out-Null
      Start-Sleep -Milliseconds 600
      $r = New-Object W+RECT
      [W]::GetWindowRect($h, [ref]$r) | Out-Null
      $w = $r.R - $r.L; $hh = $r.B - $r.T
      if ($w -gt 0 -and $hh -gt 0) {
        $bmp = New-Object System.Drawing.Bitmap $w, $hh
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size)
        $n = $Shots[$shotNz]; $bmp.Save("$proj\shot_live_$n.png", [System.Drawing.Imaging.ImageFormat]::Png)
        $g.Dispose(); $bmp.Dispose()
        "shot: $w x $hh  (at $i s) -> shot_live_$n.png"
      }
      $shotNz++
    }
  }
}
$p.Refresh()
if ($p.HasExited) { "exit=$($p.ExitCode)  lived $i s" } else { "alive_full $WaitSec sstopping"; Stop-Process -Id $p.Id -Force }
'=== stderr ==='
if (Test-Path $err) { Get-Content $err -Tail 6 }
