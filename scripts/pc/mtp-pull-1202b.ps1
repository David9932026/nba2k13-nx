# Targeted pull: latest 6 spdlog logs + rex_perfil.log + rex_stderr
$ErrorActionPreference = 'Continue'
Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public class DlgKiller11 {
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

$dest = 'C:\Users\26095\cola\sw-todo\pull1202'
New-Item -ItemType Directory -Force -Path $dest | Out-Null
$loc = $sh.NameSpace($dest)

function Pull-One($item, $waitSec) {
  $loc.CopyHere($item, 0x14)
  for ($k = 0; $k -lt ([int]($waitSec)); $k++) { Start-Sleep -Seconds 1; [DlgKiller11]::KillYes() | Out-Null }
}

# 1) latest 6 spdlog logs
$logsDir = $null
foreach ($i in @($nb2.Items())) { if ($i.IsFolder -and $i.Name -eq 'logs') { $logsDir = $i.GetFolder } }
$max = 0; $names = @{}
foreach ($i in @($logsDir.Items())) {
  if ($i.IsFolder) { continue }
  if ($i.Name -match 'nba2k13_(\d+)') {
    $n = [int]$Matches[1]
    if ($n -gt $max) { $max = $n }
    $names[$n] = $i
  }
}
"max log index = $max"
$want = @()
for ($n = $max; $n -gt $max - 8 -and $n -ge 1; $n--) { if ($names.ContainsKey($n)) { $want += $names[$n] } }
foreach ($w in $want) { "pull log $($w.Name)"; Pull-One $w 25 }

# 2) rex_perfil.log
$rexDir = $null
foreach ($i in @($nb2.Items())) { if ($i.IsFolder -and $i.Name -eq 'rex') { $rexDir = $i.GetFolder } }
foreach ($i in @($rexDir.Items())) {
  if ($i.IsFolder) { continue }
  if ($i.Name -like 'rex_perfil*') { "pull $($i.Name)"; Pull-One $i 40 }
}

# 3) stderr in root
foreach ($i in @($nb2.Items())) {
  if ($i.IsFolder) { continue }
  $fn = ''
  try { $fn = $i.ExtendedProperty('System.FileName') } catch {}
  if ($fn -like 'rex_stderr*') { "pull $fn"; Pull-One $i 30 }
}
'PULL_DONE'
Get-ChildItem $dest -File | Select-Object Name, Length | Format-Table -AutoSize | Out-String -Width 200
