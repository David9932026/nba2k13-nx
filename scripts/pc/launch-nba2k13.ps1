param(
  [int]$WaitSec = 45,
  [string]$Shot = "C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126\run_shot.png"
)
$dir = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126\rex\nba2k13app\out\build\win-amd64-release'
$exe = Join-Path $dir 'nba2k13.exe'

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class W {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  public struct RECT { public int Left, Top, Right, Bottom; }
}
"@

Write-Output "启动 $exe"
if ($ExtraArgs) { $p = Start-Process -FilePath $exe -ArgumentList $ExtraArgs -WorkingDirectory $dir -PassThru } else { $p = Start-Process -FilePath $exe -WorkingDirectory $dir -PassThru }
Start-Sleep -Seconds $WaitSec

$alive = -not $p.HasExited
if ($alive) {
  Write-Output "进程存活 pid=$($p.Id) CPU=$([math]::Round($p.CPU,1))s WS=$([math]::Round($p.WorkingSet64/1MB))MB 线程=$($p.Threads.Count)"
  $p.Refresh()
  if ($p.MainWindowHandle -ne 0) { Write-Output "窗口标题: $($p.MainWindowTitle)" }
} else {
  Write-Output "进程已退出 code=$($p.ExitCode)"
}

# 截屏（全屏），保存为 PNG
$bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
$bmp.Save($Shot, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Output "截图: $Shot"

