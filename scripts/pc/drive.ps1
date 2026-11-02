param(
  [int]$WarmupSec = 55,      # 等游戏初始化/过场的时间
  [int]$StepSec = 6,         # 每个动作之间的间隔
  [string[]]$Keys = @('Return','Semicolon','Semicolon','Semicolon','Semicolon','Semicolon','Semicolon')
)
$ErrorActionPreference = 'SilentlyContinue'
$proj = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126'
$dir = "$proj\rex\nba2k13app\out\build\win-amd64-release"
$out = "$proj\stderr-drive.txt"; $err = "$proj\stderr-drive-err.txt"
Remove-Item $out, $err -ErrorAction SilentlyContinue

Add-Type -AssemblyName System.Drawing, System.Windows.Forms
Add-Type @"
using System;using System.Runtime.InteropServices;
public class D {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, IntPtr pid);
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool attach);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, IntPtr extra);
  public struct RECT { public int L,T,R,B; }
}
"@

$p = Start-Process -FilePath "$dir\nba2k13.exe" -ArgumentList @(
  '--game_data_root=D:\xox360\00007000\C096DB2DDEE83F64054B',
  '--gpu_plugin=xenos',
  '--mnk_mode=1'
) -WorkingDirectory $dir -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
"启动 pid=$($p.Id)  预热 $WarmupSec 秒"

# -File 传数组会拼成一个逗号串，这里再拆回数组
if ($Keys.Count -eq 1 -and $Keys[0] -match ',') { $Keys = $Keys[0] -split ',' }

# 窗口句柄要轮询：游戏要过几十秒才建窗口
$deadline = (Get-Date).AddSeconds($WarmupSec)
$h = [IntPtr]::Zero
while ((Get-Date) -lt $deadline) {
  Start-Sleep -Seconds 2
  $p.Refresh()
  if ($p.HasExited) { "游戏在等窗口阶段就退出了，退出码=$($p.ExitCode)"; exit 1 }
  if ($p.MainWindowHandle -ne 0) { $h = $p.MainWindowHandle; break }
}
"窗口句柄: $h  (第 $([int]((Get-Date) - $p.StartTime).TotalSeconds) 秒)"
if ($h -eq [IntPtr]::Zero) { "等不到窗口，退出"; Stop-Process -Id $p.Id -Force; exit 1 }
Start-Sleep -Seconds 3

# 强制前台：AttachThreadInput 绕开焦点限制
[void][D]::ShowWindow($h, 9)
$fg = [D]::GetForegroundWindow()
$tidFg = [D]::GetWindowThreadProcessId($fg, [IntPtr]::Zero)
$tidMe = [D]::GetCurrentThreadId()
[void][D]::AttachThreadInput($tidMe, $tidFg, $true)
[void][D]::SetForegroundWindow($h)
[void][D]::AttachThreadInput($tidMe, $tidFg, $false)
Start-Sleep -Milliseconds 500
"前台窗口: $([D]::GetForegroundWindow())  (目标 $h)"

function Save-Shot([string]$name) {
  $r = New-Object D+RECT
  [void][D]::GetWindowRect($h, [ref]$r)
  $w = $r.R - $r.L; $hh = $r.B - $r.T
  if ($w -le 0 -or $hh -le 0) { "${name}: window rect invalid" ; return }
  $bmp = New-Object System.Drawing.Bitmap $w, $hh
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size)
  $bmp.Save("$proj\drive_$name.png", [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
  "截图 $name  ($w x $hh)"
}

$vkMap = @{ 'Return'=0x0D; 'Space'=0x20; 'Semicolon'=0xBA; 'Escape'=0x1B; 'Up'=0x26; 'Down'=0x28; 'Left'=0x25; 'Right'=0x27; 'Z'=0x5A; 'X'=0x58; 'Tab'=0x09 }
Save-Shot 'before'
$i = 0
foreach ($k in $Keys) {
  $i++
  $vk = $vkMap[$k]
  if ($null -eq $vk -or $null -eq $k) { "跳过未知键 [$k]"; continue }
  [D]::keybd_event([byte]$vk, 0, 0, [IntPtr]::Zero)      # down
  Start-Sleep -Milliseconds 90
  [D]::keybd_event([byte]$vk, 0, 2, [IntPtr]::Zero)      # up
  "按键 #$i : $k  (vk=0x$($vk.ToString('X2')))"
  Start-Sleep -Seconds $StepSec
  $p.Refresh()
  if ($p.HasExited) { "游戏已退出，退出码=$($p.ExitCode)  停在键 #$i"; break }
  Save-Shot ("after$i")
}

$p.Refresh()
if (-not $p.HasExited) { "还活着，主动结束"; Stop-Process -Id $p.Id -Force }
'=== stderr 尾部 ==='
if (Test-Path $err) { Get-Content $err -Tail 4 }
