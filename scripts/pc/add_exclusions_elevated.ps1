$ErrorActionPreference = 'Continue'
$log = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126\exclusion_log.txt'
function W($m) { $m | Tee-Object -FilePath $log -Append }

W "=== 开始 $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
W ("当前是否管理员: " + ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))

$paths = @(
    'C:\Users\26095\AppData\Local\Carafe',
    'D:\CarafeLibrary',
    'D:\nba2k9',
    'D:\nba2k13'
)

foreach ($p in $paths) {
    try {
        Add-MpPreference -ExclusionPath $p -ErrorAction Stop
        W "OK    $p"
    } catch {
        W "FAIL  $p  ->  $($_.Exception.Message)"
    }
}

# 按文件排除打包工具本体（有些杀软按文件命中更准）
try {
    Add-MpPreference -ExclusionProcess 'hacbrewpack.exe' -ErrorAction Stop
    W "OK    process: hacbrewpack.exe"
} catch {
    W "FAIL  process hacbrewpack.exe -> $($_.Exception.Message)"
}

W "--- 当前 Defender 排除路径 ---"
try {
    $ex = (Get-MpPreference -ErrorAction Stop).ExclusionPath
    if ($ex) { foreach ($e in $ex) { W "  $e" } } else { W "  (空)" }
} catch { W "  读取失败: $($_.Exception.Message)" }

W "--- 当前 Defender 排除进程 ---"
try {
    $px = (Get-MpPreference -ErrorAction Stop).ExclusionProcess
    if ($px) { foreach ($e in $px) { W "  $e" } } else { W "  (空)" }
} catch { W "  读取失败: $($_.Exception.Message)" }

W "=== 结束 ==="
