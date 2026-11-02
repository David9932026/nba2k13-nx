param([int]$WaitSec = 25, [string]$Out = 'shot_gpu.png')
$ErrorActionPreference = 'SilentlyContinue'
$dir = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126\rex\nba2k13app\out\build\win-amd64-release'
$p = Start-Process -FilePath "$dir\nba2k13.exe" `
      -ArgumentList '--game_data_root=D:\xox360\00007000\C096DB2DDEE83F64054B', '--gpu_plugin=xenos' `
      -WorkingDirectory $dir -PassThru
Start-Sleep -Seconds $WaitSec
$p.Refresh()
if ($p.HasExited) { "进程已退出，码=$($p.ExitCode)"; exit }
"存活，CPU=$([math]::Round($p.CPU,1))s WS=$([math]::Round($p.WorkingSet64/1MB))MB"

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
$path = 'C:\Users\26095\cola\coding-cola\project-20261028-112651-101fe126\' + $Out
$bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
"截图: $path"

Start-Sleep -Seconds 3
$p.Refresh()
if ($p.HasExited) { "之后退出，码=$($p.ExitCode)" } else { "仍在跑，结束进程"; Stop-Process -Id $p.Id -Force }
