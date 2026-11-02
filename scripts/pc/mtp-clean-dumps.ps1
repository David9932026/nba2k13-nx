param([int]$MaxSeg = 4800)
# PATCH(cola): limpia los volcaneos del C2z (c2z_* y ctx1_*). Sin funciones: llamar a un
# scriptblock parametrizado desde una funcion devuelve vacio con estas colecciones COM, asi
# que todo va en linea con reintento. Mueve a _basura_c2z y al final borra la carpeta.
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

# _basura_c2z (puede existir ya)
$basura = $null
for ($r = 0; $r -lt 6 -and -not $basura; $r++) {
  try { $basura = @(@($nb.Items()) | Where-Object { $_.Name -eq '_basura_c2z' }) } catch { Start-Sleep -Seconds 2 }
  if (-not $basura -or -not $basura.Count) {
    try { $null = $nb.NewFolder('_basura_c2z') } catch { 'aviso: NewFolder ' + $_.Exception.Message }
    Start-Sleep -Seconds 3
    try { $basura = @(@($nb.Items()) | Where-Object { $_.Name -eq '_basura_c2z' }) } catch {}
  }
}
if (-not $basura -or -not $basura.Count) { 'X no se pudo crear _basura_c2z'; exit 1 }
$basuraFolder = $basura[0].GetFolder
'basura lista'

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
  $objetivos = $null
  for ($r = 0; $r -lt 6 -and -not $objetivos; $r++) {
    try { $objetivos = @(@($nb.Items()) | Where-Object { $_.Name -like 'c2z_*' -or $_.Name -like 'ctx1_*' }) } catch { Start-Sleep -Seconds 3 }
  }
  if ($objetivos -eq $null) { 'X enumeracion rota'; break }
  if (-not $objetivos.Count) { "nada queda fuera"; break }
  "quedan " + $objetivos.Count
  foreach ($it in ($objetivos | Select-Object -First 100)) {
    $hecho = $false
    for ($r2 = 0; $r2 -lt 4 -and -not $hecho; $r2++) {
      # 0x1C = silencioso (0x4) + renombrar si colisiona (0x8) + sin confirmacion (0x10):
      # sin el 0x8, cada colision con un nombre ya movido abre "Mover y reemplazar"
      # y se acumulan dialogos en pantalla.
      try { $basuraFolder.MoveHere($it, 0x1C); $n++; $hecho = $true } catch { Start-Sleep -Seconds 2 }
      [DlgKiller3]::KillYes() | Out-Null
    }
    if (-not $hecho) { "X movimiento fallido " + $it.Name }
  }
  Start-Sleep -Seconds 4
  [DlgKiller3]::KillYes() | Out-Null
}
"movidos ~$n en $([int]((Get-Date) - $t0).TotalSeconds)s"

# borrar la carpeta entera de una vez
$carpeta = $null
for ($r = 0; $r -lt 6 -and -not $carpeta; $r++) {
  try { $carpeta = @(@($nb.Items()) | Where-Object { $_.Name -eq '_basura_c2z' }) } catch { Start-Sleep -Seconds 2 }
}
if ($carpeta -and $carpeta.Count) {
  try { $carpeta[0].InvokeVerb('delete') } catch { "aviso delete: " + $_.Exception.Message }
  for ($kk = 0; $kk -lt 240; $kk++) {
    Start-Sleep -Milliseconds 2500
    $pulsado = [DlgKiller3]::KillYes()
    if ($pulsado) { Start-Sleep -Milliseconds 800; [DlgKiller3]::KillYes() | Out-Null }
    try { $queda = @(@($nb.Items()) | Where-Object { $_.Name -eq '_basura_c2z' }) } catch { continue }
    if (-not $queda -or -not $queda.Count) { break }
  }
  $queda = $null
  try { $queda = @(@($nb.Items()) | Where-Object { $_.Name -eq '_basura_c2z' }) } catch {}
  if ($queda -and $queda.Count) { "X la carpeta sigue (quizas pide confirmacion en pantalla)" } else { "carpeta borrada" }
}
$restan = $null
try { $restan = @(@($nb.Items()) | Where-Object { $_.Name -like 'c2z_*' -or $_.Name -like 'ctx1_*' }) } catch {}
if ($restan -eq $null) { 'X enumeracion rota al final' } else { "sueltos restantes: " + $restan.Count }
'CLEAN_DONE'
