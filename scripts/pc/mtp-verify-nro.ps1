$ErrorActionPreference = 'Continue'
Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public class DlgKiller9 {
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumWindowsProc f, IntPtr l);
  delegate bool EnumWindowsProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] static extern IntPtr GetDlgItem(IntPtr h, int id);
  [DllImport("user32.dll")] static extern IntPtr SendMessageW(IntPtr h, uint m, IntPtr w, IntPtr l);
  public static string KillYes() {
    string log = "";
    EnumWindows((h,l) => {
      if (!IsWindowVisible(h)) return true;
      StringBuilder cn = new StringBuilder(256); GetClassNameW(h, cn, 256);
      if (cn.ToString() != "#32770") return true;
      IntPtr yes = GetDlgItem(h, 6);
      if (yes == IntPtr.Zero) yes = GetDlgItem(h, 1);
      if (yes != IntPtr.Zero) { SendMessageW(yes, 0x00F5, IntPtr.Zero, IntPtr.Zero); log += "y"; }
      return true;
    }, IntPtr.Zero);
    return log;
  }
}
'@ -ErrorAction SilentlyContinue
$sh = New-Object -ComObject Shell.Application
$sw = @($sh.NameSpace(17).Items() | Where-Object { $_.Name -eq 'Switch' }) | Select-Object -First 1
if (-not $sw) { 'X Switch MTP device not present'; exit 1 }
$root = $sh.NameSpace($sw.Path)
$sd = @($root.Items()) | Where-Object { $_.Name -like '1:*' } | Select-Object -First 1
$nb2 = $null
foreach ($i in @($sd.GetFolder.Items())) { if ($i.Name -eq 'switch') { foreach ($j in @($i.GetFolder.Items())) { if ($j.Name -eq 'nba2k13') { $nb2 = $j.GetFolder } } } }
$dest = 'C:\Users\26095\cola\sw-todo\card-nro'
New-Item -ItemType Directory -Force -Path $dest | Out-Null
$loc = $sh.NameSpace($dest)
$nro = $null
foreach ($i in @($nb2.Items())) {
  if ($i.IsFolder) { continue }
  $sz = 0
  try { $sz = [long]($i.ExtendedProperty('System.Size')) } catch {}
  if ($sz -eq 83859653) { $nro = $i; break }
}
if (-not $nro) { 'X nro 83859653 no encontrado'; exit 1 }
$loc.CopyHere($nro, 0x14)
$ok = $false
for ($k = 0; $k -lt 120; $k++) {
  Start-Sleep -Seconds 2
  [DlgKiller9]::KillYes() | Out-Null
  $f = Get-ChildItem $dest -Filter *.nro -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($f -and $f.Length -eq 83859653) { $ok = $true; break }
  if ($f -and $f.Length -gt 0 -and $k -gt 90) { break }
}
if ($ok) {
  $h = (Get-FileHash -Algorithm MD5 (Get-ChildItem $dest -Filter *.nro | Select-Object -First 1).FullName).Hash
  "CARD_NRO_MD5 $h"
} else { 'X descarga sin completar' }
