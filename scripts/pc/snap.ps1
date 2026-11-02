param([string]$Tag = 'live', [int]$DelayMs = 0)
Add-Type -AssemblyName System.Drawing
Add-Type -Namespace W -Name U -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
[DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
[DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
[DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
'@
Add-Type -Namespace W -Name FG -MemberDefinition @'
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, System.IntPtr p);
'@
$proj = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126'
$p = Get-Process nba2k13 -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $p) { "no nba2k13 process"; exit 1 }
if ($DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }
$hwnd = $p.MainWindowHandle
if ($hwnd -eq 0) { $p.Refresh(); $hwnd = $p.MainWindowHandle }
if ($hwnd -eq 0) { "no main window"; exit 1 }

$mode = 'screen'
# PrintWindow returns a frozen frame on this D3D12 swapchain (identical bytes shot after shot),
# so the screen copy stays primary; the foreground check below says who is really in front.
if ([W.U]::IsIconic($hwnd)) { [W.U]::ShowWindow($hwnd, 9) | Out-Null; Start-Sleep -Milliseconds 300 }
$r = New-Object W.U+RECT
[W.U]::GetWindowRect($hwnd, [ref]$r) | Out-Null
$w = $r.R - $r.L; $h = $r.B - $r.T
if ($w -le 0 -or $h -le 0) { "bad window rect"; exit 1 }
$bmp = New-Object System.Drawing.Bitmap $w, $h
$g = [System.Drawing.Graphics]::FromImage($bmp)
[W.U]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 350
$fg = [W.FG]::GetForegroundWindow()
$title = ''
if ($fg -eq $hwnd) { $title = '<game>' } else {
  try {
    $fgp = Get-Process -Id ([W.FG]::GetWindowThreadProcessId($fg, [ref]$null)) -ErrorAction SilentlyContinue
    if ($fgp) { $title = $fgp.ProcessName }
  } catch { $title = '?' }
}
$g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size)
$out = Join-Path $proj ("shot-{0}.png" -f $Tag)
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
$age = [int]((Get-Date) - $p.StartTime).TotalSeconds
"shot $Tag -> $out $((Get-Item $out).Length) B via $mode front=$title window=${w}x${h} alive=${age}s"
