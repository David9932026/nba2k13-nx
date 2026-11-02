param(
  [double]$X,
  [double]$Y,
  [int]$Port = 9222,
  [int]$TimeoutSec = 20
)
$ErrorActionPreference = 'Stop'

function Send-Cdp {
  param($ws, $cts, $id, $method, $params)
  $payload = @{ id = $id; method = $method; params = $params } | ConvertTo-Json -Depth 8 -Compress
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
  $ws.SendAsync([ArraySegment[byte]]::new($bytes), [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $cts.Token).GetAwaiter().GetResult() | Out-Null
  $buf = [byte[]]::new(256KB)
  $sb = [System.Text.StringBuilder]::new()
  while ($true) {
    $res = $ws.ReceiveAsync([ArraySegment[byte]]::new($buf), $cts.Token).GetAwaiter().GetResult()
    [void]$sb.Append([System.Text.Encoding]::UTF8.GetString($buf, 0, $res.Count))
    if ($res.EndOfMessage) {
      $msg = $sb.ToString() | ConvertFrom-Json
      if ($msg.id -eq $id) { return $msg }
      [void]$sb.Clear()
    }
  }
}

$list = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/json/list" -TimeoutSec 10
$page = $list | Where-Object { $_.type -eq 'page' } | Select-Object -First 1
$ws = [System.Net.WebSockets.ClientWebSocket]::new()
$cts = [System.Threading.CancellationTokenSource]::new()
$cts.CancelAfter([TimeSpan]::FromSeconds($TimeoutSec))
$ws.ConnectAsync([Uri]$page.webSocketDebuggerUrl, $cts.Token).GetAwaiter().GetResult()

$base = @{ x = $X; y = $Y; button = 'left'; clickCount = 1 }
$null = Send-Cdp $ws $cts 1 'Input.dispatchMouseEvent' (@{ type='mouseMoved'; x=$X; y=$Y; button='none' })
Start-Sleep -Milliseconds 120
$null = Send-Cdp $ws $cts 2 'Input.dispatchMouseEvent' (@{ type='mousePressed'; x=$X; y=$Y; button='left'; clickCount=1 })
Start-Sleep -Milliseconds 90
$null = Send-Cdp $ws $cts 3 'Input.dispatchMouseEvent' (@{ type='mouseReleased'; x=$X; y=$Y; button='left'; clickCount=1 })
'trusted click sent at ' + $X + ',' + $Y
try { $ws.Dispose() } catch {}
