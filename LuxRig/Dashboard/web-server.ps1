# ==================================================================
# LuxRig Web Dashboard Server
# Simple HTTP server for real-time monitoring
# ==================================================================

param(
    [int]$Port = 8080,
    [switch]$OpenBrowser
)

$dataAccessModule = Join-Path $PSScriptRoot '../Database/data-access.ps1'
if (Test-Path $dataAccessModule) { . $dataAccessModule }

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()

Write-Host "🌐 LuxRig Dashboard running at http://localhost:$Port" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop`n" -ForegroundColor Yellow

if ($OpenBrowser) {
    Start-Process "http://localhost:$Port"
}

function Get-DashboardHTML {
    $revenue = Get-RevenueByDateRange -StartDate (Get-Date).AddDays(-30) -EndDate (Get-Date)
    $trades = Get-Trades -Limit 10
    $content = Get-Content -Type 'BLOG' -Status 'PUBLISHED' -Limit 10

    $totalRevenue = ($revenue | Measure-Object -Property total_amount -Sum).Sum

    return @"
<!DOCTYPE html>
<html><head>
<title>LuxRig Dashboard</title>
<meta http-equiv='refresh' content='60'>
<style>
body{margin:0;padding:20px;background:#0f1419;color:#fff;font-family:sans-serif}
.container{max-width:1400px;margin:0 auto}
h1{color:#58a6ff;margin-bottom:30px}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:20px;margin-bottom:30px}
.card{background:#161b22;padding:20px;border-radius:8px;border:1px solid#30363d}
.card h2{color:#58a6ff;font-size:16px;margin-bottom:15px}
.metric{font-size:32px;font-weight:bold;color:#3fb950;margin:10px 0}
table{width:100%;border-collapse:collapse;margin-top:15px}
th,td{padding:10px;text-align:left;border-bottom:1px solid#30363d}
th{color:#8b949e;font-weight:normal;font-size:12px}
.positive{color:#3fb950}.negative{color:#f85149}
</style>
</head><body>
<div class='container'>
<h1>💎 LuxRig Dashboard</h1>
<div class='grid'>
<div class='card'>
<h2>💰 Revenue (30d)</h2>
<div class='metric'>`$$totalRevenue</div>
</div>
<div class='card'>
<h2>📈 Trades</h2>
<div class='metric'>$($trades.Count)</div>
</div>
<div class='card'>
<h2>📝 Content</h2>
<div class='metric'>$($content.Count)</div>
</div>
</div>
<div class='card'>
<h2>Recent Trades</h2>
<table>
<tr><th>Time</th><th>Symbol</th><th>Side</th><th>Amount</th><th>P/L</th></tr>
$(foreach($t in $trades){
"<tr><td>$($t.created_at)</td><td>$($t.symbol)</td><td>$($t.side)</td><td>`$$($t.total_value)</td><td class='$(if($t.profit_loss -gt 0){'positive'}else{'negative'})'>`$$($t.profit_loss)</td></tr>"
})
</table>
</div>
<p style='text-align:center;color:#666;margin-top:30px'>Auto-refresh every 60s | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
</div>
</body></html>
"@
}

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $response = $context.Response

        $html = Get-DashboardHTML
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)

        $response.ContentLength64 = $buffer.Length
        $response.ContentType = "text/html"
        $response.OutputStream.Write($buffer, 0, $buffer.Length)
        $response.Close()
    }
}
finally {
    $listener.Stop()
}
