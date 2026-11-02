$ErrorActionPreference = 'Continue'
$msys = 'C:\Users\26095\msys64\msys64'
$bash = Join-Path $msys 'usr\bin\bash.exe'
function Log($m) { '{0}  {1}' -f (Get-Date -Format 'HH:mm:ss'), $m }

$ml = Join-Path $msys 'etc\pacman.d'
# 主镜像 TUNA，备用 USTC / 官方
Set-Content (Join-Path $ml 'mirrorlist.msys') @(
  'Server = https://mirrors.tuna.tsinghua.edu.cn/msys2/msys/$arch/',
  'Server = https://mirrors.ustc.edu.cn/msys2/msys/$arch/'
) -Encoding ASCII
foreach ($f in @('mirrorlist.mingw32','mirrorlist.mingw64','mirrorlist.ucrt64','mirrorlist.clang64')) {
  Set-Content (Join-Path $ml $f) @(
    'Server = https://mirrors.tuna.tsinghua.edu.cn/msys2/mingw/$repo/',
    'Server = https://mirrors.ustc.edu.cn/msys2/mingw/$repo/'
  ) -Encoding ASCII
}
Log '镜像已重置（TUNA + USTC）'

Log '=== 清缓存 ==='
& $bash -lc 'rm -f /var/cache/pacman/pkg/*.part; pacman -Scc --noconfirm 2>&1 | tail -n 3'

Log '=== 更新数据库 ==='
& $bash -lc 'pacman --noconfirm -Syy 2>&1 | tail -n 5'

Log '=== 升级系统 ==='
& $bash -lc 'pacman --noconfirm --disable-download-timeout -Su 2>&1 | tail -n 15'

Log '=== 逐个装（失败重试 3 次） ==='
foreach ($pkg in @('mingw-w64-ucrt-x86_64-gcc','mingw-w64-ucrt-x86_64-cmake','mingw-w64-ucrt-x86_64-ninja','mingw-w64-ucrt-x86_64-clang','python','git')) {
  $ok = $false
  for ($i = 1; $i -le 3 -and -not $ok; $i++) {
    Log "装 $pkg （第 $i 次）"
    $out = & $bash -lc "pacman --noconfirm --disable-download-timeout -S --needed $pkg 2>&1 | tail -n 6"
    $out
    $chk = & $bash -lc "pacman -Q $pkg 2>&1"
    if ($chk -notmatch '未找到|not found') { $ok = $true; Log "$pkg OK: $chk" }
  }
  if (-not $ok) { Log "!! $pkg 失败" }
}

Log '=== 版本 ==='
& $bash -lc 'export PATH=/ucrt64/bin:$PATH; for c in gcc clang cmake ninja python git; do printf "%-8s " $c; ($c --version 2>&1 | head -1) || echo MISSING; done'
Log '=== DONE ==='
