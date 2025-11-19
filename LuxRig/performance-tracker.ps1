#Requires -Version 7.0
<#
.SYNOPSIS
    LuxRig Performance Tracker
.DESCRIPTION
    Real-time performance tracking and analytics:
    - Live P&L tracking
    - Strategy comparison
    - Daily/weekly/monthly stats
    - Export reports
#>

$script:PerformanceDB = @{
    Trades = @()
    DailyStats = @()
    StrategyStats = @{}
}

$script:DBPath = Join-Path $PSScriptRoot "data/performance.json"

function Initialize-PerformanceTracker {
    if (Test-Path $script:DBPath) {
        $script:PerformanceDB = Get-Content $script:DBPath | ConvertFrom-Json -AsHashtable
    }

    Write-Host "✅ Performance Tracker initialized" -ForegroundColor Green
}

function Add-Trade {
    param(
        [Parameter(Mandatory)][string]$Strategy,
        [Parameter(Mandatory)][string]$Symbol,
        [Parameter(Mandatory)][ValidateSet("BUY","SELL")][string]$Side,
        [Parameter(Mandatory)][double]$Price,
        [Parameter(Mandatory)][double]$Size,
        [double]$PnL = 0,
        [string]$Exchange = "Unknown"
    )

    $trade = @{
        Id = [guid]::NewGuid().ToString()
        Timestamp = Get-Date
        Strategy = $Strategy
        Symbol = $Symbol
        Side = $Side
        Price = $Price
        Size = $Size
        PnL = $PnL
        Exchange = $Exchange
    }

    $script:PerformanceDB.Trades += $trade
    Update-StrategyStats -Strategy $Strategy -Trade $trade
    Save-PerformanceDB

    Write-Host "✅ Trade logged: $Side $Size $Symbol @ `$$Price" -ForegroundColor Green
}

function Update-StrategyStats {
    param([string]$Strategy, [hashtable]$Trade)

    if (-not $script:PerformanceDB.StrategyStats.ContainsKey($Strategy)) {
        $script:PerformanceDB.StrategyStats[$Strategy] = @{
            TotalTrades = 0
            WinningTrades = 0
            LosingTrades = 0
            TotalPnL = 0
            BestTrade = 0
            WorstTrade = 0
        }
    }

    $stats = $script:PerformanceDB.StrategyStats[$Strategy]
    $stats.TotalTrades++

    if ($Trade.PnL -gt 0) { $stats.WinningTrades++ }
    elseif ($Trade.PnL -lt 0) { $stats.LosingTrades++ }

    $stats.TotalPnL += $Trade.PnL
    $stats.BestTrade = [Math]::Max($stats.BestTrade, $Trade.PnL)
    $stats.WorstTrade = [Math]::Min($stats.WorstTrade, $Trade.PnL)
}

function Get-PerformanceSummary {
    param([int]$Days = 30)

    Write-Host "`n╔══════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║        📊 PERFORMANCE SUMMARY (Last $Days days)       ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════╝`n" -ForegroundColor Green

    $cutoff = (Get-Date).AddDays(-$Days)
    $recentTrades = $script:PerformanceDB.Trades | Where-Object { $_.Timestamp -gt $cutoff }

    if ($recentTrades.Count -eq 0) {
        Write-Host "No trades in the last $Days days`n" -ForegroundColor Yellow
        return
    }

    # Overall stats
    $totalPnL = ($recentTrades.PnL | Measure-Object -Sum).Sum
    $wins = ($recentTrades | Where-Object { $_.PnL -gt 0 }).Count
    $losses = ($recentTrades | Where-Object { $_.PnL -lt 0 }).Count
    $winRate = if ($recentTrades.Count -gt 0) { ($wins / $recentTrades.Count) * 100 } else { 0 }

    Write-Host "Overall Performance:" -ForegroundColor Yellow
    Write-Host "  Total Trades: $($recentTrades.Count)" -ForegroundColor White
    Write-Host "  Win Rate: $([Math]::Round($winRate, 1))% ($wins wins, $losses losses)" -ForegroundColor $(if ($winRate -gt 50) { "Green" } else { "Red" })
    Write-Host "  Total P&L: `$$([Math]::Round($totalPnL, 2))" -ForegroundColor $(if ($totalPnL -gt 0) { "Green" } else { "Red" })
    Write-Host "  Avg Trade: `$$([Math]::Round($totalPnL / $recentTrades.Count, 2))" -ForegroundColor White

    # Best/worst trades
    $bestTrade = $recentTrades | Sort-Object PnL -Descending | Select-Object -First 1
    $worstTrade = $recentTrades | Sort-Object PnL | Select-Object -First 1

    Write-Host "`n  Best Trade: `$$([Math]::Round($bestTrade.PnL, 2)) ($($bestTrade.Symbol) on $($bestTrade.Strategy))" -ForegroundColor Green
    Write-Host "  Worst Trade: `$$([Math]::Round($worstTrade.PnL, 2)) ($($worstTrade.Symbol) on $($worstTrade.Strategy))" -ForegroundColor Red

    # Strategy breakdown
    Write-Host "`nStrategy Performance:" -ForegroundColor Yellow
    foreach ($strategy in $script:PerformanceDB.StrategyStats.Keys) {
        $stats = $script:PerformanceDB.StrategyStats[$strategy]
        $stratWinRate = if ($stats.TotalTrades -gt 0) { ($stats.WinningTrades / $stats.TotalTrades) * 100 } else { 0 }

        Write-Host "  $strategy`:" -ForegroundColor Cyan
        Write-Host "    Trades: $($stats.TotalTrades) | Win Rate: $([Math]::Round($stratWinRate, 1))%" -ForegroundColor White
        Write-Host "    P&L: `$$([Math]::Round($stats.TotalPnL, 2))" -ForegroundColor $(if ($stats.TotalPnL -gt 0) { "Green" } else { "Red" })
    }

    Write-Host ""
}

function Export-PerformanceReport {
    param([string]$OutputPath = "./reports/performance-report.html")

    $trades = $script:PerformanceDB.Trades
    $totalPnL = ($trades.PnL | Measure-Object -Sum).Sum

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>LuxRig Performance Report</title>
    <style>
        body { font-family: Arial; background: #0a0a0a; color: #fff; padding: 20px; }
        h1 { color: #0ff; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #333; }
        th { background: #1a1a1a; color: #0f0; }
        .positive { color: #0f0; }
        .negative { color: #f00; }
    </style>
</head>
<body>
    <h1>💎 LuxRig Performance Report</h1>
    <p>Generated: $(Get-Date)</p>
    <p>Total P&L: <span class="$(if ($totalPnL -gt 0) { 'positive' } else { 'negative' })">`$$([Math]::Round($totalPnL, 2))</span></p>

    <h2>Recent Trades</h2>
    <table>
        <tr><th>Time</th><th>Strategy</th><th>Symbol</th><th>Side</th><th>Price</th><th>Size</th><th>P&L</th></tr>
        $(foreach ($trade in $trades[-50..-1]) {
            "<tr><td>$($trade.Timestamp)</td><td>$($trade.Strategy)</td><td>$($trade.Symbol)</td><td>$($trade.Side)</td><td>`$$($trade.Price)</td><td>$($trade.Size)</td><td class='$(if ($trade.PnL -gt 0) { 'positive' } else { 'negative' })'>`$$([Math]::Round($trade.PnL, 2))</td></tr>"
        })
    </table>
</body>
</html>
"@

    $dir = Split-Path $OutputPath -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $html | Out-File $OutputPath
    Write-Host "✅ Performance report exported: $OutputPath" -ForegroundColor Green
}

function Save-PerformanceDB {
    $dir = Split-Path $script:DBPath -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $script:PerformanceDB | ConvertTo-Json -Depth 10 | Out-File $script:DBPath
}

Export-ModuleMember -Function Initialize-PerformanceTracker, Add-Trade, Get-PerformanceSummary, Export-PerformanceReport

if ($MyInvocation.InvocationName -ne '.') {
    Initialize-PerformanceTracker
    Write-Host "Performance Tracker ready" -ForegroundColor Yellow
}
