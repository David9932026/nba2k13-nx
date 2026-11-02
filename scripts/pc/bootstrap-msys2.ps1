$ErrorActionPreference = 'Continue'
$msys = 'C:\Users\26095\msys64'          # 短路径，避免 MAX_PATH
if (Test-Path (Join-Path $msys 'msys64\usr\bin\bash.exe')) { $msys = Join-Path $msys 'msys64' }  # SFX 多套了一层
$bash = Join-Path $msys 'usr\bin\bash.exe'
"MSYS2 根: $msys"
$dl   = 'C:\Users\26095\msys-dl'
New-Item -ItemType Directory -Force -Path $dl | Out-Null
function Log($m) { '{0}  {1}' -f (Get-Date -Format 'HH:mm:ss'), $m }

if (Test-Path $bash) { Log 'MSYS2 已存在，跳过解压'; }
else {
  Log '=== 0) 下载 SFX 包 ==='
  $sfx = Join-Path $dl 'msys2.sfx.exe'
  if (-not (Test-Path $sfx) -or (Get-Item $sfx).Length -lt 20MB) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    Invoke-WebRequest 'https://mirrors.tuna.tsinghua.edu.cn/msys2/distrib/msys2-x86_64-latest.sfx.exe' -OutFile $sfx -UseBasicParsing -TimeoutSec 900
    Log ("下载 {0:N1} MB / {1:N0}s" -f ((Get-Item $sfx).Length/1MB), $sw.Elapsed.TotalSeconds)
  }

  Log '=== 1) 自解压 ==='
  try {
    $p = Start-Process -FilePath $sfx -ArgumentList '-y', "-o$msys" -PassThru -Wait -WindowStyle Hidden
    Log "SFX 退出码 $($p.ExitCode)"
  } catch { Log ('SFX 启动失败: ' + $_.Exception.Message) }

  if (-not (Test-Path $bash)) {
    Log '=== 1b) SFX 不可用，改用 7-Zip ==='
    $7zr = Join-Path $dl '7zr.exe'
    if (-not (Test-Path $7zr)) { Invoke-WebRequest 'https://www.7-zip.org/a/7zr.exe' -OutFile $7zr -UseBasicParsing -TimeoutSec 300 }
    $extra = Join-Path $dl '7z-extra.7z'
    if (-not (Test-Path $extra)) {
      foreach ($v in @('7z2501','7z2409','7z2408')) {
        try { Invoke-WebRequest "https://www.7-zip.org/a/$v-extra.7z" -OutFile $extra -UseBasicParsing -TimeoutSec 300; if ((Get-Item $extra).Length -gt 100KB) { Log "拿到 $v-extra.7z"; break } } catch { Log "$v 失败" }
      }
    }
    if (Test-Path $extra) {
      & $7zr x $extra "-o$dl\7zx" -y | Select-Object -Last 3
      $7za = Get-ChildItem "$dl\7zx" -Recurse -Filter '7za.exe' | Select-Object -First 1
      if ($7za) {
        $txz = Join-Path $dl 'msys2.tar.xz'
        if (-not (Test-Path $txz)) { Invoke-WebRequest 'https://mirrors.tuna.tsinghua.edu.cn/msys2/distrib/msys2-x86_64-latest.tar.xz' -OutFile $txz -UseBasicParsing -TimeoutSec 900 }
        & $7za.FullName x $txz "-o$dl\xtar" -y | Select-Object -Last 3
        $tarFile = Get-ChildItem "$dl\xtar" -Filter '*.tar' | Select-Object -First 1
        if ($tarFile) {
          New-Item -ItemType Directory -Force -Path $msys | Out-Null
          & $7za.FullName x $tarFile.FullName "-o$msys" -y | Select-Object -Last 3
        }
      }
    }
  }
}

if (-not (Test-Path $bash)) { Log 'X 仍然没有 bash.exe，终止'; exit 1 }
Log '解压完成'

Log '=== 2) 配镜像 ==='
$ml = Join-Path $msys 'etc\pacman.d'
Set-Content (Join-Path $ml 'mirrorlist.msys')    'Server = https://mirrors.tuna.tsinghua.edu.cn/msys2/msys/$arch/' -Encoding ASCII
foreach ($f in @('mirrorlist.mingw32','mirrorlist.mingw64','mirrorlist.ucrt64','mirrorlist.clang64')) {
  Set-Content (Join-Path $ml $f) 'Server = https://mirrors.tuna.tsinghua.edu.cn/msys2/mingw/$repo/' -Encoding ASCII
}
Log '镜像已写入'

Log '=== 3) pacman -Syuu ==='
& $bash -lc 'pacman --noconfirm -Syuu 2>&1 | tail -n 12'

Log '=== 4) 装工具链 ==='
& $bash -lc 'pacman --noconfirm -S --needed mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-clang mingw-w64-ucrt-x86_64-cmake mingw-w64-ucrt-x86_64-ninja python git 2>&1 | tail -n 30'

Log '=== 5) 版本 ==='
& $bash -lc 'export PATH=/ucrt64/bin:$PATH; gcc --version|head -1; clang --version|head -1; cmake --version|head -1; ninja --version; python --version; git --version'
Log '=== DONE ==='
