param(
  [string[]]$Items = @(),
  [string]$RootLike = '1:*',
  [switch]$DryRun
)
# 用法: mtp-del.ps1 -Items "emuMMC/xxx/a.nca","emuMMC/yyy" [-DryRun]
$ErrorActionPreference = 'Continue'

$Items = @($Items | ForEach-Object { $_ -split ',' } | Where-Object { $_ -ne '' })

$sh = New-Object -ComObject Shell.Application
$pc = $sh.NameSpace(17)
$sw = $pc.Items() | Where-Object { $_.Name -eq 'Switch' } | Select-Object -First 1
if (-not $sw) { "X 设备不在"; exit 1 }
$root = $sh.NameSpace($sw.Path)
$entry = $root.Items() | Where-Object { $_.Name -like $RootLike } | Select-Object -First 1
if (-not $entry) { "X 无根"; exit 1 }

function Get-Item-BySegments($startFolder, $segments) {
  $cur = $startFolder
  $last = $null
  foreach ($seg in $segments) {
    $nxt = $null
    foreach ($i in @($cur.Items())) { if ($i.Name -eq $seg) { $nxt = $i; break } }
    if (-not $nxt) { return $null }
    $last = $nxt
    try { $cur = $nxt.GetFolder } catch { break }
  }
  return $last
}

# 找到 "是否删除" 类确认对话框并按「是/Yes」
$sig = @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class DlgKiller {
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
  delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowTextW(IntPtr hWnd, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassNameW(IntPtr hWnd, StringBuilder s, int n);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hWnd);
  [DllImport("user32.dll")] static extern IntPtr GetDlgItem(IntPtr hDlg, int id);
  [DllImport("user32.dll")] static extern IntPtr SendMessageW(IntPtr hWnd, uint msg, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] static extern bool PostMessageW(IntPtr hWnd, uint msg, IntPtr w, IntPtr l);
  static List<IntPtr> wins = new List<IntPtr>();
  public static string[] List() {
    wins.Clear();
    List<string> outp = new List<string>();
    EnumWindows((h,l) => {
      if (!IsWindowVisible(h)) return true;
      StringBuilder cn = new StringBuilder(256); GetClassNameW(h, cn, 256);
      StringBuilder tt = new StringBuilder(512); GetWindowTextW(h, tt, 512);
      uint pid; GetWindowThreadProcessId(h, out pid);
      outp.Add(h.ToString() + "|" + pid + "|" + cn.ToString() + "|" + tt.ToString());
      return true;
    }, IntPtr.Zero);
    return outp.ToArray();
  }
  // 点掉 #32770 里的 是(Y)/Yes 按钮
  public static string KillYes(string titleHint) {
    string log = "";
    EnumWindows((h,l) => {
      if (!IsWindowVisible(h)) return true;
      StringBuilder cn = new StringBuilder(256); GetClassNameW(h, cn, 256);
      if (cn.ToString() != "#32770") return true;
      StringBuilder tt = new StringBuilder(512); GetWindowTextW(h, tt, 512);
      string t = tt.ToString();
      if (titleHint != "" && t.IndexOf(titleHint, StringComparison.OrdinalIgnoreCase) < 0) return true;
      IntPtr yes = GetDlgItem(h, 6); // IDYES
      if (yes == IntPtr.Zero) yes = GetDlgItem(h, 1);
      if (yes != IntPtr.Zero) {
        SendMessageW(yes, 0x00F5, IntPtr.Zero, IntPtr.Zero); // BM_CLICK
        PostMessageW(h, 0x0010, IntPtr.Zero, IntPtr.Zero);   // WM_CLOSE 兜底
        log += "clicked-yes:" + t + ";";
      }
      return true;
    }, IntPtr.Zero);
    return log;
  }
}
'@
try { Add-Type -TypeDefinition $sig -ErrorAction Stop } catch { }

foreach ($rel in $Items) {
  "== $rel =="
  $segs = $rel -split '/'
  $it = Get-Item-BySegments $entry.GetFolder $segs
  if (-not $it) { "  跳过: 找不到"; continue }
  $sz = 0; try { $sz = $it.Size } catch {}
  $isDir = $false; try { if ($it.IsFolder) { $isDir = $true } } catch {}
  "  目标: $($it.Name)  $(if($isDir){'[目录]'}else{"$([math]::Round($sz/1MB,1)) MB"})"
  if ($DryRun) { "  (DryRun 不删)"; continue }
  $items_ok = $true

  $done = $false
  $t0 = Get-Date
  try {
    $it.InvokeVerb('delete')
    $done = $true
  } catch { "  InvokeVerb 异常: $($_.Exception.Message)" }

  # 处理可能的确认框，最多等 12 秒
  for ($k = 0; $k -lt 6; $k++) {
    Start-Sleep -Milliseconds 2000
    $killed = ''
    try { $killed = [DlgKiller]::KillYes('') } catch {}
    if ($killed -ne '') { "  对话框: $killed" }
  }
  "  用时 $([int]((Get-Date)-$t0).TotalSeconds)s"

  # 复核
  $still = Get-Item-BySegments $entry.GetFolder $segs
  if ($still) { "  ✗ 仍存在" } else { "  ✓ 已删除" }
}
"DONE"
