# Push C36/C37 package: MoveHere old nro+toml into _respaldo2, CopyHere new ones, verify each step.
$ErrorActionPreference = 'Continue'
Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public class DlgKiller7 {
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
'_respaldo2 ok'

# --- old nro (83843269): MoveHere into _respaldo2 (removes from root)
$viejo = Find-BySize $nb2 83843269
if ($viejo) {
  'MoveHere nro viejo -> _respaldo2 ...'
  $respaldo.MoveHere($viejo, 0x14)
  for ($k = 0; $k -lt 30; $k++) {
    Start-Sleep -Seconds 2
    [DlgKiller7]::KillYes() | Out-Null
    if (-not (Find-BySize $nb2 83843269)) { break }
  }
  if (Find-BySize $respaldo 83843269) { 'nro viejo en _respaldo2' }
  if (Find-BySize $nb2 83843269) { 'AVISO: nro viejo sigue en raiz' } else { 'raiz sin nro viejo' }
} else {
  'nro viejo no esta en raiz'
}

# --- old toml (563): MoveHere into _respaldo2
$viejoT = Find-BySize $nb2 563
if ($viejoT) {
  'MoveHere toml viejo -> _respaldo2 ...'
  $respaldo.MoveHere($viejoT, 0x14)
  for ($k = 0; $k -lt 16; $k++) {
    Start-Sleep -Milliseconds 1500
    [DlgKiller7]::KillYes() | Out-Null
    if (-not (Find-BySize $nb2 563)) { break }
  }
  if (Find-BySize $nb2 563) { 'AVISO: toml viejo sigue' } else { 'toml viejo fuera' }
} else {
  'toml viejo no esta en raiz'
}

# --- push new nro
$nroSrc = 'D:\cola-projects\project-20261028-112651-101fe126\rex\nba2k13app\out\build\sw\nba2k13.nro'
$lenNro = (Get-Item $nroSrc).Length
"CopyHere nro nuevo ($lenNro B)..."
$nb2.CopyHere($nroSrc, 0x0414)
$ok = $false
for ($k = 0; $k -lt 60; $k++) {
  Start-Sleep -Seconds 2
  [DlgKiller7]::KillYes() | Out-Null
  if (Find-BySize $nb2 $lenNro) { $ok = $true; break }
}
if ($ok) { "NRO_NUEVO_OK ($lenNro B)" } else { 'X nro nuevo sin verificar' }

# --- push new toml
$tomlSrc = 'C:\Users\26095\cola\push1102\nba2k13-siguiente.toml'
$lenToml = (Get-Item $tomlSrc).Length
"CopyHere toml nuevo ($lenToml B)..."
$nb2.CopyHere($tomlSrc, 0x0414)
$ok = $false
for ($k = 0; $k -lt 30; $k++) {
  Start-Sleep -Seconds 2
  [DlgKiller7]::KillYes() | Out-Null
  if (Find-BySize $nb2 $lenToml) { $ok = $true; break }
}
if ($ok) { "TOML_NUEVO_OK ($lenToml B)" } else { 'X toml nuevo sin verificar' }

'--- final ---'
foreach ($i in @(Refresh $nb2)) {
  if ($i.IsFolder) { '[D] ' + $i.Name; continue }
  $sz = 0
  try { $sz = $i.ExtendedProperty('System.Size') } catch {}
  '{0}  {1}' -f $i.Name, $sz
}
