param([int]$WaitSec = 240, [int]$ShotAt = 50)
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

$shotDone = $false
for ($i = 1; $i -le $WaitSec; $i++) {
  Start-Sleep -Seconds 1
  $p.Refresh()
  if ($p.HasExited) { break }
  if (-not $shotDone -and $i -ge $ShotAt) {
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
        $bmp.Save("$proj\shot_live.png", [System.Drawing.Imaging.ImageFormat]::Png)
        $g.Dispose(); $bmp.Dispose()
        "截图: $w x $hh  (第 $i 秒)"
      }
      $shotDone = $true
    }
  }
}
$p.Refresh()
if ($p.HasExited) { "退出码=$($p.ExitCode)  存活约 $i 秒" } else { "存活满 $WaitSec 秒，主动结束"; Stop-Process -Id $p.Id -Force }
'=== stderr ==='
if (Test-Path $err) { Get-Content $err -Tail 6 }
