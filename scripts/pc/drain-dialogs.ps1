# PATCH(cola): drena los dialogos "Mover y reemplazar" acumulados en pantalla.
# Por cada #32770 visible: marca la casilla "para todos los elementos" y pulsa el boton
# afirmativo (Reemplazar/Si/Yes/Continuar). Repite hasta que no queden dialogos.
$ErrorActionPreference = 'Continue'
Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class Drain {
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
  delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hWnd);
  [DllImport("user32.dll")] static extern IntPtr GetDlgItem(IntPtr hDlg, int id);
  [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr h, EnumChildProc p, IntPtr l);
  delegate bool EnumChildProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] static extern IntPtr SendMessageW(IntPtr h, uint m, IntPtr w, IntPtr l);
  public static List<IntPtr> dgs = new List<IntPtr>();
  static List<IntPtr> hijos = new List<IntPtr>();
  static StringBuilder sb = new StringBuilder(512);
  public static string[] Dialogos() {
    dgs.Clear();
    EnumWindows((h,l) => {
      if (!IsWindowVisible(h)) return true;
      sb.Clear(); GetClassNameW(h, sb, 256);
      if (sb.ToString() == "#32770") dgs.Add(h);
      return true;
    }, IntPtr.Zero);
    string[] r = new string[dgs.Count];
    for (int i = 0; i < dgs.Count; i++) { sb.Clear(); GetWindowTextW(dgs[i], sb, 512); r[i] = dgs[i].ToString() + "|" + sb.ToString(); }
    return r;
  }
  static string Txt(IntPtr h) { sb.Clear(); GetWindowTextW(h, sb, 512); return sb.ToString(); }
  public static string Drenar() {
    string log = "";
    foreach (IntPtr d in dgs.ToArray()) {
      hijos.Clear();
      EnumChildWindows(d, (h,l) => { hijos.Add(h); return true; }, IntPtr.Zero);
      // casilla "hacer esto para todos"
      foreach (IntPtr h in hijos) {
        sb.Clear(); GetClassNameW(h, sb, 256);
        if (sb.ToString() == "Button" && Txt(h).Length > 4 && (Txt(h).IndexOf("todos") >= 0 || Txt(h).IndexOf("all") >= 0 || Txt(h).IndexOf("所有") >= 0)) {
          SendMessageW(h, 0x00F5, IntPtr.Zero, IntPtr.Zero); // BM_CLICK
          log += "check";
          break;
        }
      }
      // boton afirmativo por texto
      foreach (IntPtr h in hijos) {
        sb.Clear(); GetClassNameW(h, sb, 256);
        string t = Txt(h);
        if (sb.ToString() == "Button" && t.Length > 0 && (t.IndexOf("eemplazar") >= 0 || t.IndexOf("eplace") >= 0 || t.IndexOf("是(&Y)") >= 0 || t.IndexOf("是(Y)") >= 0 || t == "是" || t.IndexOf("Yes") >= 0 || t.IndexOf("Continuar") >= 0 || t.IndexOf("继续") >= 0)) {
          SendMessageW(h, 0x00F5, IntPtr.Zero, IntPtr.Zero);
          log += "+" + t.Trim();
          break;
        }
      }
      // si no hay boton de texto util, IDYES/IDOK estandar
      if (log == "" || !log.Contains("+")) {
        IntPtr b = GetDlgItem(d, 6);
        if (b == IntPtr.Zero) b = GetDlgItem(d, 1);
        if (b != IntPtr.Zero) { SendMessageW(b, 0x00F5, IntPtr.Zero, IntPtr.Zero); log += "+ID1/6"; }
      }
      log += " | ";
    }
    return log;
  }
}
'@ -ErrorAction Stop

$ronda = 0
while ($true) {
  $d = [Drain]::Dialogos()
  if (-not $d -or $d.Count -eq 0) { "sin dialogos"; break }
  $ronda++
  "ronda $ronda : " + $d.Count + " dialogos -> " + (([Drain]::Drenar()) -replace '\| ', '; ')
  Start-Sleep -Milliseconds 700
  if ($ronda -gt 400) { "X demasiado tiempo"; break }
}
"DRAIN_DONE ($ronda rondas)"
