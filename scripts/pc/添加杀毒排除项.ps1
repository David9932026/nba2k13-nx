# 给 Carafe 打包流程加杀毒排除项
# 用法：右键这个文件 → 使用 PowerShell 运行；或者在管理员 PowerShell 里执行本文件
# 必须管理员权限，否则 Defender 会拒绝（"你的权限不足"）

$ErrorActionPreference = 'Continue'

$paths = @(
    'C:\Users\26095\AppData\Local\Carafe',   # Carafe 本体（0.4.0 是装在用户目录下的，不是 Program Files）
    'D:\CarafeLibrary',                      # 打包工作目录
    'D:\nba2k9',                             # 游戏源文件
    'D:\nba2k13'
)

Write-Host '=== Windows Defender 排除项 ===' -ForegroundColor Cyan
foreach ($p in $paths) {
    try {
        Add-MpPreference -ExclusionPath $p -ErrorAction Stop
        Write-Host "  已加入: $p" -ForegroundColor Green
    } catch {
        Write-Host "  失败: $p  ->  $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host ''
Write-Host '=== 当前 Defender 排除项 ===' -ForegroundColor Cyan
$ex = (Get-MpPreference).ExclusionPath
if ($ex) { $ex | ForEach-Object { Write-Host "  $_" } } else { Write-Host '  （空）' }

Write-Host ''
Write-Host '=== 还需要手工做的一步 ===' -ForegroundColor Cyan
Write-Host '  这台机器上还装了「电脑管家」，它有自己的实时防护，Defender 的排除项对它无效。'
Write-Host '  打开 电脑管家 → 病毒查杀 → 信任区/白名单，把上面四个目录加进去，'
Write-Host '  尤其是 C:\Users\26095\AppData\Local\Carafe\hacbrewpack.exe 这个文件。'
Write-Host ''
Write-Host '不做这一步的后果：Carafe 打包到 70% 左右会以 hacBrewPack exit code: 1 失败。'
Write-Host ''
Read-Host '按回车关闭'
