# Fix toml name: move wrongly-named one (665 B) into _respaldo2, push correctly-named nba2k13.toml.
$ErrorActionPreference = 'Continue'
Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public class DlgKiller8 {
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
if (-not $nb2) { 'X no switch/nba2k13'; exit 1 }

function Refresh($f) { $f.Items() | Out-Null; Start-Sleep -Milliseconds 800; @($f.Items()) }
function Find-BySize($folder, [long]$size) {
  foreach ($i in @(Refresh $folder)) {
    if ($i.IsFolder) { continue }
    $sz = 0
    try { $sz = [long]($i.ExtendedProperty('System.Size')) } catch {}
    if ($sz -eq $size) { return $i }
  }
  return $null
}
$respaldo = $null
foreach ($i in @(Refresh $nb2)) { if ($i.IsFolder -and $i.Name -eq '_respaldo2') { $respaldo = $i.GetFolder } }
if (-not $respaldo) { 'X _respaldo2 no existe'; exit 1 }

$malo = Find-BySize $nb2 665
if ($malo) {
  'moviendo toml mal nombrado -> _respaldo2'
  $respaldo.MoveHere($malo, 0x14)
  for ($k = 0; $k -lt 16; $k++) {
    Start-Sleep -Milliseconds 1500
    [DlgKiller8]::KillYes() | Out-Null
    if (-not (Find-BySize $nb2 665)) { break }
  }
}
if (Find-BySize $nb2 665) { 'AVISO: el de 665 sigue en raiz' } else { 'fuera' }

$tomlSrc = 'C:\Users\26095\cola\push1102\nba2k13.toml'
"CopyHere nba2k13.toml (665 B)..."
$nb2.CopyHere($tomlSrc, 0x0414)
$ok = $false
for ($k = 0; $k -lt 30; $k++) {
  Start-Sleep -Seconds 2
  [DlgKiller8]::KillYes() | Out-Null
  $it = $null
  foreach ($i in @(Refresh $nb2)) {
    if ($i.IsFolder) { continue }
    try {
      if (($i.ExtendedProperty('System.FileName') -eq 'nba2k13.toml') -and ([long]$i.ExtendedProperty('System.Size')) -eq 665) { $it = $i; break }
    } catch {}
  }
  if ($it) { $ok = $true; break }
}
if ($ok) { 'TOML_OK nba2k13.toml 665 B' } else { 'X toml con nombre correcto sin verificar' }
