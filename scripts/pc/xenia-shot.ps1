param([int]$WaitSec = 45, [int[]]$Shots = @(10,16,22,28,34,40))
$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Drawing
Add-Type -Namespace WX -Name U -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
'@
$exe = 'D:\xenia\xenia_canary.exe'
if (-not (Test-Path $exe)) { $exe = (Get-ChildItem 'D:\xenia' -Filter 'xenia*.exe' | Select-Object -First 1).FullName }
"exe = $exe"
$p = Start-Process -FilePath $exe -ArgumentList 'D:\xenia\content\545408A2\00007000\C096DB2DDEE83F64054B\default.xex' -WorkingDirectory 'D:\xenia' -PassThru
$hwnd = [IntPtr]::Zero
for ($i = 1; $i -le $WaitSec; $i++) {
  Start-Sleep -Seconds 1
  $p.Refresh()
  if ($p.HasExited) { "xenia 退出 code=$($p.ExitCode) at ${i}s"; break }
  if ($hwnd -eq [IntPtr]::Zero -and $p.MainWindowHandle -ne 0) { $hwnd = $p.MainWindowHandle }
  if ($Shots -contains $i -and $hwnd -ne [IntPtr]::Zero) {
    [WX.U]::SetForegroundWindow($hwnd) | Out-Null
    Start-Sleep -Milliseconds 300
    $r = New-Object WX.U+RECT
    if ([WX.U]::GetWindowRect($hwnd, [ref]$r)) {
      $w = $r.R - $r.L; $h = $r.B - $r.T
      if ($w -gt 0 -and $h -gt 0) {
        $bmp = New-Object System.Drawing.Bitmap $w, $h
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size)
        $out = "C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126\xen-$($i)s.png"
        $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
        $g.Dispose(); $bmp.Dispose()
        "shot $i s -> $out"
      }
    }
  }
}
if (-not $p.HasExited) { "xenia 还活着，关闭"; Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
