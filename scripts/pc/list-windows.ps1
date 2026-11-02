$ErrorActionPreference = 'Continue'
Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class WinList {
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
  delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hWnd);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  public static string[] Todos() {
    List<string> r = new List<string>();
    StringBuilder cn = new StringBuilder(256);
    StringBuilder tt = new StringBuilder(512);
    EnumWindows((h,l) => {
      if (!IsWindowVisible(h)) return true;
      cn.Clear(); GetClassNameW(h, cn, 256);
      tt.Clear(); GetWindowTextW(h, tt, 512);
      string t = tt.ToString();
      string c = cn.ToString();
      if (t.Length > 0 || c == "#32770") {
        uint pid; GetWindowThreadProcessId(h, out pid);
        r.Add(h.ToString() + "|" + pid + "|" + c + "|" + t);
      }
      return true;
    }, IntPtr.Zero);
    return r.ToArray();
  }
}
'@ -ErrorAction Stop
$ws = [WinList]::Todos()
"total ventanas visibles: " + $ws.Count
$ws | Where-Object {
  $p = $_ -split '\|'
  $p[2] -eq '#32770' -or $p[3] -match '替换|移动|删除|复制|确认|Mover|Reemplazar|Eliminar|Confirm|Replace|Move'
} | Select-Object -First 30
'LIST_DONE'
