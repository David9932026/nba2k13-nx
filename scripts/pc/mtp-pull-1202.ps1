# Pull all diagnostics from card: spdlog logs (all), rex_perfil.log, rex_stderr.log
$ErrorActionPreference = 'Continue'
Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public class DlgKiller10 {
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

$dest = 'C:\Users\26095\cola\sw-todo\pull1202'
New-Item -ItemType Directory -Force -Path $dest | Out-Null
$loc = $sh.NameSpace($dest)

# targets: logs dir, rex dir, stderr
$targets = @()
foreach ($i in @($nb2.Items())) {
  if (-not $i.IsFolder) { continue }
  if ($i.Name -eq 'logs') { $targets += ,@('logs', $i.GetFolder) }
  if ($i.Name -eq 'rex') { $targets += ,@('rex', $i.GetFolder) }
}
foreach ($i in @($nb2.Items())) {
  if ($i.IsFolder) { continue }
  $fn = ''
  try { $fn = $i.ExtendedProperty('System.FileName') } catch {}
  if ($fn -like 'rex_stderr*') { $targets += ,@('stderr_' + $fn, $i) }
}

foreach ($t in $targets) {
  $tag = $t[0]; $obj = $t[1]
  if ($obj -is [System.__ComObject] -and $tag -like 'stderr_*') {
    # single file item
    "pull $tag ..."
    $loc.CopyHere($obj, 0x14)
  } else {
    # folder of files
    $sub = Join-Path $dest $tag
    New-Item -ItemType Directory -Force -Path $sub | Out-Null
    $subLoc = $sh.NameSpace($sub)
    $items = @($obj.Items())
    "folder $tag : $($items.Count) items"
    foreach ($f in $items) {
      if ($f.IsFolder) { continue }
      "  pull $($f.Name)"
      $subLoc.CopyHere($f, 0x14)
      # wait for size stable
      for ($k = 0; $k -lt 20; $k++) {
        Start-Sleep -Milliseconds 1500
        [DlgKiller10]::KillYes() | Out-Null
      }
    }
  }
}
'PULL_DONE'
Get-ChildItem $dest -Recurse -File | Select-Object @{n='Rel';e={$_.FullName.Substring($dest.Length+1)}}, Length | Format-Table -AutoSize | Out-String -Width 200
