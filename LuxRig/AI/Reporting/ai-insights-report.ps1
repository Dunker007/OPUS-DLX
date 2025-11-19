#Requires -Version 7.0
<#
.SYNOPSIS
    AI Insights Report Generator
.DESCRIPTION
    Comprehensive AI trading insights:
    - Model performance summary
    - Prediction analysis
    - Market regime insights
    - Trading recommendations
.NOTES
    Part of Phase 4: Advanced AI Systems
#>

function Get-AIInsightsReport {
    param(
        [hashtable]$ModelPerformance = @{},
        [hashtable]$MarketData = @{},
        [array]$RecentPredictions = @()
    )

    Write-Host "`n╔══════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║         🤖 AI INSIGHTS REPORT                        ║" -ForegroundColor Magenta
    Write-Host "╚══════════════════════════════════════════════════════╝`n" -ForegroundColor Magenta

    # Model Performance Summary
    Write-Host "📊 MODEL PERFORMANCE SUMMARY:" -ForegroundColor Yellow

    if ($ModelPerformance.Count -gt 0) {
        foreach ($model in $ModelPerformance.Keys) {
            $accuracy = $ModelPerformance[$model]
            $color = if ($accuracy -gt 0.7) { "Green" } elseif ($accuracy -gt 0.6) { "Yellow" } else { "Red" }
            Write-Host "   $model`: $([Math]::Round($accuracy * 100, 2))% accuracy" -ForegroundColor $color
        }
    }
    else {
        Write-Host "   No model performance data available" -ForegroundColor Gray
    }

    Write-Host ""

    # Recent Predictions Analysis
    Write-Host "🔮 RECENT PREDICTIONS (Last 10):" -ForegroundColor Yellow

    if ($RecentPredictions.Count -gt 0) {
        $buyCount = ($RecentPredictions | Where-Object { $_.signal -eq "BUY" }).Count
        $sellCount = ($RecentPredictions | Where-Object { $_.signal -eq "SELL" }).Count
        $holdCount = ($RecentPredictions | Where-Object { $_.signal -eq "HOLD" }).Count

        Write-Host "   BUY: $buyCount | SELL: $sellCount | HOLD: $holdCount" -ForegroundColor White

        $avgConfidence = ($RecentPredictions.confidence | Measure-Object -Average).Average
        Write-Host "   Average confidence: $([Math]::Round($avgConfidence, 2))" -ForegroundColor White
    }
    else {
        Write-Host "   No recent predictions" -ForegroundColor Gray
    }

    Write-Host ""

    # Market Regime Analysis
    Write-Host "📈 MARKET REGIME ANALYSIS:" -ForegroundColor Yellow

    $regime = if ($MarketData.trend -eq "BULL") {
        "Bullish trend detected - Favor momentum strategies"
    } elseif ($MarketData.trend -eq "BEAR") {
        "Bearish trend detected - Defensive positioning recommended"
    } else {
        "Sideways market - Range trading strategies optimal"
    }

    Write-Host "   $regime" -ForegroundColor Cyan
    Write-Host "   Volatility: $(if ($MarketData.volatility -gt 0.05) { 'HIGH' } elseif ($MarketData.volatility -gt 0.02) { 'MEDIUM' } else { 'LOW' })" -ForegroundColor White
    Write-Host ""

    # AI Recommendations
    Write-Host "💡 AI RECOMMENDATIONS:" -ForegroundColor Yellow

    $recommendations = @()

    # Based on model consensus
    if ($RecentPredictions.Count -gt 0) {
        $consensus = ($RecentPredictions | Group-Object signal | Sort-Object Count -Descending | Select-Object -First 1).Name

        if ($consensus -eq "BUY") {
            $recommendations += "✓ AI models show bullish consensus - Consider entering long positions"
        }
        elseif ($consensus -eq "SELL") {
            $recommendations += "✓ AI models show bearish consensus - Consider reducing exposure or shorting"
        }
    }

    # Based on model performance
    $topModel = $ModelPerformance.Keys | Sort-Object { $ModelPerformance[$_] } -Descending | Select-Object -First 1

    if ($topModel) {
        $recommendations += "✓ Top performing model: $topModel ($([Math]::Round($ModelPerformance[$topModel] * 100, 1))% accuracy)"
    }

    # Risk management
    if ($MarketData.volatility -gt 0.05) {
        $recommendations += "⚠️  High volatility detected - Reduce position sizes"
    }

    foreach ($rec in $recommendations) {
        Write-Host "   $rec" -ForegroundColor Cyan
    }

    Write-Host ""

    # Performance Insights
    Write-Host "📊 KEY INSIGHTS:" -ForegroundColor Yellow

    $insights = @(
        "Ensemble predictions show higher accuracy than individual models",
        "Model performance varies with market regime - adapt strategy selection",
        "Retraining recommended when accuracy drops below 60%",
        "Combine AI signals with traditional technical analysis for best results"
    )

    foreach ($insight in $insights) {
        Write-Host "   • $insight" -ForegroundColor Gray
    }

    Write-Host ""

    return @{
        modelPerformance = $ModelPerformance
        recentPredictions = $RecentPredictions
        marketRegime = $MarketData
        recommendations = $recommendations
        insights = $insights
    }
}

function Export-AIReport {
    param(
        [Parameter(Mandatory)][hashtable]$Report,
        [string]$OutputPath = "ai-insights-report.html"
    )

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>LuxRig AI Insights Report</title>
    <style>
        body { font-family: Arial, sans-serif; background: #0a0a0a; color: #fff; padding: 20px; }
        h1 { color: #0ff; }
        h2 { color: #0f0; border-bottom: 2px solid #0f0; padding-bottom: 10px; }
        .metric { background: #1a1a1a; padding: 15px; margin: 10px 0; border-radius: 8px; }
        .good { color: #0f0; }
        .warning { color: #ff0; }
        .bad { color: #f00; }
    </style>
</head>
<body>
    <h1>🤖 LuxRig AI Insights Report</h1>
    <p>Generated: $(Get-Date)</p>

    <h2>Model Performance</h2>
    $(foreach ($model in $Report.modelPerformance.Keys) {
        "<div class='metric'>$model: $([Math]::Round($Report.modelPerformance[$model] * 100, 2))%</div>"
    })

    <h2>Recommendations</h2>
    <ul>
    $(foreach ($rec in $Report.recommendations) {
        "<li>$rec</li>"
    })
    </ul>

    <h2>Insights</h2>
    <ul>
    $(foreach ($insight in $Report.insights) {
        "<li>$insight</li>"
    })
    </ul>
</body>
</html>
"@

    $html | Out-File $OutputPath
    Write-Host "`n✅ AI report exported to: $OutputPath`n" -ForegroundColor Green
}

Export-ModuleMember -Function Get-AIInsightsReport, Export-AIReport

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "AI Insights Report ready. Comprehensive AI trading analytics" -ForegroundColor Yellow
}
