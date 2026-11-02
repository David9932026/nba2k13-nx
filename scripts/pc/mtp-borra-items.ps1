# PATCH(cola): borrar el CONTENIDO de _basura_c2z por verbos sobre los items (el verbo
# 'delete' sobre la carpeta MTP no hace nada). Un dialogo por invocacion; KillYes lo pica.
$ErrorActionPreference = 'Continue'
$sh = New-Object -ComObject Shell.Application
$sw = @($sh.NameSpace(17).Items() | Where-Object { $_.Name -eq 'Switch' }) | Select-Object -First 1
if (-not $sw) { 'X no device'; exit 1 }
$root = $sh.NameSpace($sw.Path)
$sd = @($root.Items()) | Where-Object { $_.Name -like '1:*' } | Select-Object -First 1
$nb = $null; $bas = $null
foreach ($i in @($sd.GetFolder.Items())) { if ($i.Name -eq 'switch') { foreach ($j in @($i.GetFolder.Items())) { if ($j.Name -eq 'nba2k13') { $nb = $j.GetFolder; foreach ($k in @($j.GetFolder.Items())) { if ($k.Name -eq '_basura_c2z') { $bas = $k.GetFolder } } } } } }
if (-not $bas) { 'X no basura'; exit 1 }

Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public class DlgKiller3 {
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

function Cuenta { for ($r = 0; $r -lt 6; $r++) { try { return @($bas.Items()).Count } catch { Start-Sleep -Seconds 2 } } return -1 }

$total0 = Cuenta
"antes: $total0"
$t0 = Get-Date
$ronda = 0
while (((Get-Date) - $t0).TotalMinutes -lt 30) {
  $n = Cuenta
  if ($n -lt 0) { 'X enum'; Start-Sleep -Seconds 5; continue }
  if ($n -eq 0) { break }
  $ronda++
  $hecho = $false
  try { $bas.Items().InvokeVerb('delete'); $hecho = $true } catch { "aviso ronda ${ronda}: " + $_.Exception.Message }
  # picar dialogos hasta que el conteo baje o pasen 45 s
  $tt = Get-Date
  while (((Get-Date) - $tt).TotalSeconds -lt 45) {
    Start-Sleep -Milliseconds 2000
    try { [DlgKiller3]::KillYes() | Out-Null } catch {}
    $m = Cuenta
    if ($m -ge 0 -and $m -lt $n) { break }
  }
  $m = Cuenta
  "ronda ${ronda}: $n -> $m"
}
$fin = Cuenta
"restantes: $fin"
if ($fin -eq 0) { 'CONTENIDO_BORRADO' } else { 'X quedan restos' }
'BORRADO_ITEMS_OK'
