param(
  [string]$Expr,
  [string]$ExprFile,
  [int]$Port = 9222,
  [int]$TimeoutSec = 25
)
if ($ExprFile) { $Expr = [System.IO.File]::ReadAllText($ExprFile, [System.Text.Encoding]::UTF8) }
if (-not $Expr) { throw 'need -Expr or -ExprFile' }
$ErrorActionPreference = 'Stop'

function Get-Target {
  param([int]$p)
  $list = Invoke-RestMethod -Uri "http://127.0.0.1:$p/json/list" -TimeoutSec 10
  $page = $list | Where-Object { $_.type -eq 'page' } | Select-Object -First 1
  if (-not $page) { throw 'no page target' }
  return $page.webSocketDebuggerUrl
}

$wsUrl = Get-Target -p $Port
$ws = [System.Net.WebSockets.ClientWebSocket]::new()
$cts = [System.Threading.CancellationTokenSource]::new()
$cts.CancelAfter([TimeSpan]::FromSeconds($TimeoutSec))
$ws.ConnectAsync([Uri]$wsUrl, $cts.Token).GetAwaiter().GetResult()

$payload = @{
  id = 1
  method = 'Runtime.evaluate'
  params = @{
    expression = $Expr
    returnByValue = $true
    awaitPromise = $true
    userGesture = $true
    allowUnsafeEvalBlockedByCSP = $true
  }
} | ConvertTo-Json -Depth 8 -Compress

$bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
$seg = [ArraySegment[byte]]::new($bytes)
$ws.SendAsync($seg, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $cts.Token).GetAwaiter().GetResult()

$buf = [byte[]]::new(4MB)
$sb = [System.Text.StringBuilder]::new()
while ($true) {
  $res = $ws.ReceiveAsync([ArraySegment[byte]]::new($buf), $cts.Token).GetAwaiter().GetResult()
  [void]$sb.Append([System.Text.Encoding]::UTF8.GetString($buf, 0, $res.Count))
  if ($res.EndOfMessage) {
    $msg = $sb.ToString() | ConvertFrom-Json
    if ($msg.id -eq 1) {
      if ($msg.result.exceptionDetails) {
        'JS-ERROR: ' + $msg.result.exceptionDetails.text
        if ($msg.result.exceptionDetails.exception) { $msg.result.exceptionDetails.exception.description }
      } else {
        if ($msg.result.result.value -is [string]) { $msg.result.result.value }
        else { $msg.result.result.value | ConvertTo-Json -Depth 12 }
      }
      break
    }
    [void]$sb.Clear()
  }
}
try { $ws.Dispose() } catch {}
