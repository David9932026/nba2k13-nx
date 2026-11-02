param([int]$MaxSeg = 100, [ValidateSet('mover','borrar')][string]$Fase = 'mover')
# PATCH(cola): una sola fase. El proceso que mueve muere de vez en cuando (el COM se
# desconecta tras unos minutos), asi que el supervisor lo relanza; el estado vive en la
# tarjeta, no aqui. mover: manda ficheros sueltos a _basura_c2z. borrar: borra la carpeta.
$ErrorActionPreference = 'Continue'

$sh = New-Object -ComObject Shell.Application
$sw = @($sh.NameSpace(17).Items() | Where-Object { $_.Name -eq 'Switch' }) | Select-Object -First 1
if (-not $sw) { 'X no device'; exit 1 }
$root = $sh.NameSpace($sw.Path)
$sd = @($root.Items()) | Where-Object { $_.Name -like '1:*' } | Select-Object -First 1
if (-not $sd) { 'X no sd'; exit 1 }
$nb = $null
foreach ($i in @($sd.GetFolder.Items())) { if ($i.Name -eq 'switch') { foreach ($j in @($i.GetFolder.Items())) { if ($j.Name -eq 'nba2k13') { $nb = $j.GetFolder } } } }
if (-not $nb) { 'X no dir'; exit 1 }

function Sueltos {
  for ($r = 0; $r -lt 6; $r++) {
    try { return @(@($nb.Items()) | Where-Object { $_.Name -like 'c2z_*' -or $_.Name -like 'ctx1_*' }) } catch { Start-Sleep -Seconds 2 }
  }
  return $null
}

if ($Fase -eq 'borrar') {
  Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public class DlgKiller3 {
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
  delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassNameW(IntPtr hWnd, StringBuilder s, int n);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hWnd);
  [DllImport("user32.dll")] static extern IntPtr GetDlgItem(IntPtr hDlg, int id);
  [DllImport("user32.dll")] static extern IntPtr SendMessageW(IntPtr hWnd, uint msg, IntPtr w, IntPtr l);
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
  $carpeta = $null
  for ($r = 0; $r -lt 6 -and -not $carpeta; $r++) {
    try { $carpeta = @(@($nb.Items()) | Where-Object { $_.Name -eq '_basura_c2z' }) } catch { Start-Sleep -Seconds 2 }
  }
  if (-not $carpeta -or -not $carpeta.Count) { 'no hay _basura_c2z'; 'BORRADO_OK' }
  else {
    try { $carpeta[0].InvokeVerb('delete') } catch { "aviso delete: " + $_.Exception.Message }
    for ($kk = 0; $kk -lt 240; $kk++) {
      Start-Sleep -Milliseconds 2500
      try { if ([DlgKiller3]::KillYes()) { Start-Sleep -Milliseconds 800; [DlgKiller3]::KillYes() | Out-Null } } catch {}
      $queda = $null
      try { $queda = @(@($nb.Items()) | Where-Object { $_.Name -eq '_basura_c2z' }) } catch { continue }
      if (-not $queda -or -not $queda.Count) { break }
    }
    $queda = $null
    try { $queda = @(@($nb.Items()) | Where-Object { $_.Name -eq '_basura_c2z' }) } catch {}
    if ($queda -and $queda.Count) { 'X la carpeta sigue' } else { 'carpeta borrada' }
    'BORRADO_OK'
  }
  exit 0
}

# fase mover
$basura = $null
for ($r = 0; $r -lt 6 -and -not $basura; $r++) {
  try { $basura = @(@($nb.Items()) | Where-Object { $_.Name -eq '_basura_c2z' }) } catch { Start-Sleep -Seconds 2 }
  if (-not $basura -or -not $basura.Count) {
    try { $null = $nb.NewFolder('_basura_c2z') } catch {}
    Start-Sleep -Seconds 3
    try { $basura = @(@($nb.Items()) | Where-Object { $_.Name -eq '_basura_c2z' }) } catch {}
  }
}
if (-not $basura -or -not $basura.Count) { 'X no basura'; exit 1 }
$basuraFolder = $basura[0].GetFolder

Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public class DlgKiller3 {
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
  delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassNameW(IntPtr hWnd, StringBuilder s, int n);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hWnd);
  [DllImport("user32.dll")] static extern IntPtr GetDlgItem(IntPtr hDlg, int id);
  [DllImport("user32.dll")] static extern IntPtr SendMessageW(IntPtr hWnd, uint msg, IntPtr w, IntPtr l);
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

$t0 = Get-Date
$n = 0
while (((Get-Date) - $t0).TotalSeconds -lt $MaxSeg) {
  $objetivos = Sueltos
  if ($objetivos -eq $null) { 'X enum'; break }
  if (-not $objetivos.Count) { 'nada queda fuera'; break }
  foreach ($it in ($objetivos | Select-Object -First 100)) {
    try { $basuraFolder.MoveHere($it, 0x1C); $n++ } catch { Start-Sleep -Seconds 2 }
    try { [DlgKiller3]::KillYes() | Out-Null } catch {}
  }
  Start-Sleep -Seconds 4
}
$s = Sueltos
"movidos ~$n; sueltos restantes: " + $(if ($s -eq $null) { '??' } else { $s.Count })
'FASE_MOVER_OK'
