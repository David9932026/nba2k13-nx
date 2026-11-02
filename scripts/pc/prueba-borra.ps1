# PATCH(cola): prueba de borrado item a item sobre _basura_c2z. Mide tiempo por item y
# si aparece dialogo de confirmacion. Mueve a la papelera logica: NADA, borra de verdad.
$ErrorActionPreference = 'Continue'
$sh = New-Object -ComObject Shell.Application
$sw = @($sh.NameSpace(17).Items() | Where-Object { $_.Name -eq 'Switch' }) | Select-Object -First 1
$root = $sh.NameSpace($sw.Path)
$sd = @($root.Items()) | Where-Object { $_.Name -like '1:*' } | Select-Object -First 1
$bas = $null
foreach ($i in @($sd.GetFolder.Items())) { if ($i.Name -eq 'switch') { foreach ($j in @($i.GetFolder.Items())) { if ($j.Name -eq 'nba2k13') { foreach ($k in @($j.GetFolder.Items())) { if ($k.Name -eq '_basura_c2z') { $bas = $k.GetFolder } } } } } }
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

$items = @($bas.Items())
"total: " + $items.Count
for ($k = 0; $k -lt 3 -and $k -lt $items.Count; $k++) {
  $it = $items[$k]
  $nombre = $it.Name
  $a = Get-Date
  try { $it.InvokeVerb('delete') } catch { "aviso: " + $_.Exception.Message }
  $dlgs = ''
  for ($w = 0; $w -lt 10; $w++) {
    Start-Sleep -Milliseconds 500
    try { $dlgs += [DlgKiller3]::KillYes() } catch {}
    $queda = $null
    try { $queda = @(@($bas.Items()) | Where-Object { $_.Name -eq $nombre }) } catch {}
    if (-not $queda -or -not $queda.Count) { break }
  }
  $b = Get-Date
  $sigue = $null
  try { $sigue = @(@($bas.Items()) | Where-Object { $_.Name -eq $nombre }) } catch {}
  "item '$nombre': $([math]::Round((($b-$a).TotalSeconds),1))s dialogs=$dlgs borrado=$(-not ($sigue -and $sigue.Count))"
}
"restantes: " + @($bas.Items()).Count
'PRUEBA_OK'
