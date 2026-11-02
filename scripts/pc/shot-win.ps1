param([int]$WaitSec = 20, [string]$Out = 'shot_win.png')
$ErrorActionPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class W32 {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetWindowTextW(IntPtr h, System.Text.StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern int GetClassNameW(IntPtr h, System.Text.StringBuilder s, int n);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
}
"@
$dir = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126\rex\nba2k13app\out\build\win-amd64-release'
$p = Start-Process -FilePath "$dir\nba2k13.exe" `
      -ArgumentList '--game_data_root=D:\xox360\00007000\C096DB2DDEE83F64054B', '--gpu_plugin=xenos' `
      -WorkingDirectory $dir -PassThru
Start-Sleep -Seconds $WaitSec
$p.Refresh()
if ($p.HasExited) { "退出码=$($p.ExitCode)"; exit }
$h = $p.MainWindowHandle
"MainWindowHandle = $h  CPU=$([math]::Round($p.CPU,1))s WS=$([math]::Round($p.WorkingSet64/1MB))MB"
if ($h -eq [IntPtr]::Zero) { "没有主窗口"; Stop-Process -Id $p.Id -Force; exit }

$sb = New-Object System.Text.StringBuilder 256
[W32]::GetWindowTextW($h, $sb, 256) | Out-Null; "标题: $($sb.ToString())"
$sb2 = New-Object System.Text.StringBuilder 256
[W32]::GetClassNameW($h, $sb2, 256) | Out-Null; "类名: $($sb2.ToString())"
$r = New-Object W32+RECT
[W32]::GetWindowRect($h, [ref]$r) | Out-Null
"位置: ($($r.L),$($r.T)) 大小 $($r.R-$r.L) x $($r.B-$r.T)  可见=$([W32]::IsWindowVisible($h))"

$w = [Math]::Max(1, $r.R - $r.L); $ht = [Math]::Max(1, $r.B - $r.T)
$bmp = New-Object System.Drawing.Bitmap $w, $ht
$g = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $g.GetHdc()
[W32]::PrintWindow($h, $hdc, 2) | Out-Null
$g.ReleaseHdc($hdc)
$path = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126\' + $Out
$bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
"截图: $path"
Stop-Process -Id $p.Id -Force
