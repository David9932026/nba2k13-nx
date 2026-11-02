Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public class WinSpy {
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumWindowsProc f, IntPtr l);
  delegate bool EnumWindowsProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr h, EnumWindowsProc f, IntPtr l);
  public static string Dump() {
    StringBuilder outp = new StringBuilder();
    EnumWindows((h,l) => {
      if (!IsWindowVisible(h)) return true;
      StringBuilder cn = new StringBuilder(256); GetClassNameW(h, cn, 256);
      StringBuilder tt = new StringBuilder(512); GetWindowTextW(h, tt, 512);
      string c = cn.ToString(); string t = tt.ToString();
      if (c == "#32770") {
        outp.AppendLine("DLG hwnd=" + h + " titulo='" + t + "'");
        EnumChildWindows(h, (ch,cl) => {
          StringBuilder cc = new StringBuilder(256); GetClassNameW(ch, cc, 256);
          StringBuilder ct = new StringBuilder(512); GetWindowTextW(ch, ct, 512);
          outp.AppendLine("  hijo " + ch + " " + cc + " '" + ct + "'");
          return true;
        }, IntPtr.Zero);
      } else if (t.Length > 0 && c != "Shell_TrayWnd") {
        outp.AppendLine("win " + c + " '" + t + "'");
      }
      return true;
    }, IntPtr.Zero);
    return outp.ToString();
  }
}
'@
[WinSpy]::Dump()
'SPY_DONE'
