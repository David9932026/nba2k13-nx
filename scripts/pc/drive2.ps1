param(
  [int]$WarmupSec = 70,
  [int]$StepSec = 6,
  [string]$Keys = 'Return,Return,Semicolon,Semicolon,Semicolon,Semicolon'
)
$ErrorActionPreference = 'SilentlyContinue'
$proj = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126'
$dir = "$proj\rex\nba2k13app\out\build\win-amd64-release"
$out = "$proj\stderr-drive2.txt"; $err = "$proj\stderr-drive2-err.txt"
Remove-Item $out, $err -ErrorAction SilentlyContinue

Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;using System.Collections.Generic;using System.Runtime.InteropServices;using System.Text;
public class W2 {
  public delegate bool EnumProc(IntPtr h, IntPtr p);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr p);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern void SwitchToThisWindow(IntPtr h, bool alt);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, IntPtr extra);
  [DllImport("user32.dll")] public static extern IntPtr SetFocus(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x,int y,int cx,int cy,uint flags);
  public struct RECT { public int L,T,R,B; }

  public static List<IntPtr> FindWindows(uint targetPid) {
    var list = new List<IntPtr>();
    EnumWindows(delegate(IntPtr h, IntPtr p) {
      uint pid; GetWindowThreadProcessId(h, out pid);
      if (pid == targetPid && IsWindowVisible(h)) {
        RECT r; GetWindowRect(h, out r);
        if ((r.R - r.L) >= 320 && (r.B - r.T) >= 200) list.Add(h);
      }
      return true;
    }, IntPtr.Zero);
    return list;
  }
  public static bool ForceForeground(IntPtr h) {
    // 先制造一次本进程输入，解除 Windows 的前台锁定
    keybd_event(0x10, 0, 0, IntPtr.Zero); keybd_event(0x10, 0, 2, IntPtr.Zero);
    SwitchToThisWindow(h, true);
    SetForegroundWindow(h);
    return GetForegroundWindow() == h;
  }
  public static void KeyTap(IntPtr h, byte vk) {
    keybd_event(vk, 0, 0, IntPtr.Zero);
    System.Threading.Thread.Sleep(80);
    keybd_event(vk, 0, 2, IntPtr.Zero);
    // 兜底：直接投递窗口消息（不依赖焦点）
    PostMessage(h, 0x0100, (IntPtr)vk, (IntPtr)0x00010001);
    System.Threading.Thread.Sleep(40);
    PostMessage(h, 0x0101, (IntPtr)vk, (IntPtr)0xC0010001);
  }
}
"@

$p = Start-Process -FilePath "$dir\nba2k13.exe" -ArgumentList @(
  '--game_data_root=D:\xox360\00007000\C096DB2DDEE83F64054B',
  '--gpu_plugin=xenos',
  '--mnk_mode=1'
) -WorkingDirectory $dir -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
"启动 pid=$($p.Id)"

# 轮询直到出现「真正可用」的窗口（有合理尺寸）
$h = [IntPtr]::Zero
$deadline = (Get-Date).AddSeconds($WarmupSec)
while ((Get-Date) -lt $deadline) {
  Start-Sleep -Seconds 2
  $p.Refresh()
  if ($p.HasExited) { "游戏在 $([int]((Get-Date) - $p.StartTime).TotalSeconds) 秒退出，码=$($p.ExitCode)"; exit 1 }
  $wins = [W2]::FindWindows([uint32]$p.Id)
  if ($wins.Count -gt 0) { $h = $wins[0]; break }
}
"窗口句柄: $h  (第 $([int]((Get-Date) - $p.StartTime).TotalSeconds) 秒，找到 $($wins.Count) 个)"
if ($h -eq [IntPtr]::Zero) { "等不到可用窗口"; Stop-Process -Id $p.Id -Force; exit 1 }
Start-Sleep -Seconds 3

$fgOk = [W2]::ForceForeground($h)
"前台抢占: $fgOk  (前台=0x$([W2]::GetForegroundWindow().ToInt64().ToString('X'))  目标=0x$($h.ToInt64().ToString('X')))"
[void][W2]::SetFocus($h)
Start-Sleep -Milliseconds 400

function Save-Shot([string]$name) {
  $r = New-Object W2+RECT
  [void][W2]::GetWindowRect($h, [ref]$r)
  $w = $r.R - $r.L; $hh = $r.B - $r.T
  if ($w -le 0 -or $hh -le 0) { "${name}: rect invalid"; return }
  $bmp = New-Object System.Drawing.Bitmap $w, $hh
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size)
  $bmp.Save("$proj\drive2_$name.png", [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
}
Save-Shot 'before'
"已截图 before"

$vkMap = @{ 'Return'=0x0D; 'Space'=0x20; 'Semicolon'=0xBA; 'A'=0x41; 'B'=0x42; 'X'=0x58; 'Z'=0x5A; 'Tab'=0x09; 'Escape'=0x1B; 'Up'=0x26; 'Down'=0x28; 'Left'=0x25; 'Right'=0x27; 'NumEnter'=0x0D }
$list = $Keys -split ','
$i = 0
foreach ($k in $list) {
  $k = $k.Trim()
  if (-not $k) { continue }
  $i++
  $vk = $vkMap[$k]
  if ($null -eq $vk) { "跳过未知键 [$k]"; continue }
  [W2]::KeyTap($h, [byte]$vk)
  "按键 #$i : $k (vk=0x$($vk.ToString('X2')))"
  Start-Sleep -Seconds $StepSec
  $p.Refresh()
  if ($p.HasExited) { "游戏已退出（按键 #$i 之后）"; break }
  Save-Shot "after$i"
  "  已截图 after$i"
}

$p.Refresh()
if (-not $p.HasExited) { "仍存活，主动结束"; Stop-Process -Id $p.Id -Force }
'=== stderr 尾部 ==='
if (Test-Path $err) { Get-Content $err -Tail 4 }
