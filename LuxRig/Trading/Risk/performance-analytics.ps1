#Requires -Version 7.0
<#
.SYNOPSIS
    Performance Analytics - Institutional-grade metrics
.DESCRIPTION
    Comprehensive performance analysis:
    - Sharpe ratio (risk-adjusted return)
    - Sortino ratio (downside deviation)
    - Calmar ratio (return / max drawdown)
    - Alpha and Beta (vs benchmark)
    - Information ratio
    - Win rate and profit factor
    - R-multiple analysis
.NOTES
    Part of Phase 4: Risk Management
#>

$script:Config = @{
    RiskFreeRate = 0.04    # 4% annual
    BenchmarkSymbol = "BTC-USD"
    TradingDaysPerYear = 365
}

# ============================================================================
# RISK-ADJUSTED RETURNS
# ============================================================================

function Get-SharpeRatio {
    param(
        [Parameter(Mandatory)][array]$Returns,
        [double]$RiskFreeRate = 0.04,
        [int]$PeriodsPerYear = 365
    )

    if ($Returns.Count -lt 2) { return 0 }

    # Annualized return
    $avgReturn = ($Returns | Measure-Object -Average).Average
    $annualizedReturn = $avgReturn * $PeriodsPerYear

    # Annualized volatility
    $stdDev = [Math]::Sqrt((($Returns | ForEach-Object { [Math]::Pow($_ - $avgReturn, 2) }) | Measure-Object -Average).Average)
    $annualizedVolatility = $stdDev * [Math]::Sqrt($PeriodsPerYear)

    if ($annualizedVolatility -eq 0) { return 0 }

    # Sharpe = (Return - RiskFree) / Volatility
    $sharpe = ($annualizedReturn - $RiskFreeRate) / $annualizedVolatility

    return [Math]::Round($sharpe, 3)
}

function Get-SortinoRatio {
    param(
        [Parameter(Mandatory)][array]$Returns,
        [double]$RiskFreeRate = 0.04,
        [int]$PeriodsPerYear = 365
    )

    if ($Returns.Count -lt 2) { return 0 }

    # Annualized return
    $avgReturn = ($Returns | Measure-Object -Average).Average
    $annualizedReturn = $avgReturn * $PeriodsPerYear

    # Downside deviation (only negative returns)
    $negativeReturns = $Returns | Where-Object { $_ -lt 0 }

    if ($negativeReturns.Count -eq 0) { return 999 }  # Perfect (no downside)

    $downsideDeviation = [Math]::Sqrt((($negativeReturns | ForEach-Object { [Math]::Pow($_, 2) }) | Measure-Object -Average).Average)
    $annualizedDownside = $downsideDeviation * [Math]::Sqrt($PeriodsPerYear)

    if ($annualizedDownside -eq 0) { return 999 }

    # Sortino = (Return - RiskFree) / Downside Deviation
    $sortino = ($annualizedReturn - $RiskFreeRate) / $annualizedDownside

    return [Math]::Round($sortino, 3)
}

function Get-CalmarRatio {
    param(
        [Parameter(Mandatory)][array]$Returns,
        [int]$PeriodsPerYear = 365
    )

    if ($Returns.Count -lt 2) { return 0 }

    # Annualized return
    $avgReturn = ($Returns | Measure-Object -Average).Average
    $annualizedReturn = $avgReturn * $PeriodsPerYear

    # Max drawdown
    $equity = @(1000)
    foreach ($ret in $Returns) {
        $equity += $equity[-1] * (1 + $ret)
    }

    $maxDrawdown = Get-MaxDrawdown -EquityCurve $equity

    if ($maxDrawdown -eq 0) { return 999 }

    # Calmar = Annualized Return / Max Drawdown
    $calmar = $annualizedReturn / $maxDrawdown

    return [Math]::Round($calmar, 3)
}

# ============================================================================
# ALPHA AND BETA
# ============================================================================

function Get-AlphaBeta {
    param(
        [Parameter(Mandatory)][array]$PortfolioReturns,
        [Parameter(Mandatory)][array]$BenchmarkReturns,
        [double]$RiskFreeRate = 0.04,
        [int]$PeriodsPerYear = 365
    )

    $n = [Math]::Min($PortfolioReturns.Count, $BenchmarkReturns.Count)

    if ($n -lt 2) { return @{ alpha = 0; beta = 0 } }

    # Calculate beta (covariance / variance)
    $portfolioMean = ($PortfolioReturns[0..($n-1)] | Measure-Object -Average).Average
    $benchmarkMean = ($BenchmarkReturns[0..($n-1)] | Measure-Object -Average).Average

    $covariance = 0
    $benchmarkVariance = 0

    for ($i = 0; $i -lt $n; $i++) {
        $portfolioDev = $PortfolioReturns[$i] - $portfolioMean
        $benchmarkDev = $BenchmarkReturns[$i] - $benchmarkMean

        $covariance += $portfolioDev * $benchmarkDev
        $benchmarkVariance += $benchmarkDev * $benchmarkDev
    }

    $covariance /= ($n - 1)
    $benchmarkVariance /= ($n - 1)

    $beta = if ($benchmarkVariance -ne 0) { $covariance / $benchmarkVariance } else { 0 }

    # Calculate alpha (Jensen's alpha)
    $annualizedPortfolioReturn = $portfolioMean * $PeriodsPerYear
    $annualizedBenchmarkReturn = $benchmarkMean * $PeriodsPerYear

    $alpha = $annualizedPortfolioReturn - ($RiskFreeRate + $beta * ($annualizedBenchmarkReturn - $RiskFreeRate))

    return @{
        alpha = [Math]::Round($alpha, 4)
        beta = [Math]::Round($beta, 3)
    }
}

function Get-InformationRatio {
    param(
        [Parameter(Mandatory)][array]$PortfolioReturns,
        [Parameter(Mandatory)][array]$BenchmarkReturns,
        [int]$PeriodsPerYear = 365
    )

    $n = [Math]::Min($PortfolioReturns.Count, $BenchmarkReturns.Count)

    if ($n -lt 2) { return 0 }

    # Active returns (portfolio - benchmark)
    $activeReturns = @()
    for ($i = 0; $i -lt $n; $i++) {
        $activeReturns += $PortfolioReturns[$i] - $BenchmarkReturns[$i]
    }

    # Annualized active return
    $avgActiveReturn = ($activeReturns | Measure-Object -Average).Average
    $annualizedActiveReturn = $avgActiveReturn * $PeriodsPerYear

    # Tracking error (std dev of active returns)
    $trackingError = [Math]::Sqrt((($activeReturns | ForEach-Object { [Math]::Pow($_ - $avgActiveReturn, 2) }) | Measure-Object -Average).Average)
    $annualizedTrackingError = $trackingError * [Math]::Sqrt($PeriodsPerYear)

    if ($annualizedTrackingError -eq 0) { return 999 }

    # Information Ratio = Active Return / Tracking Error
    $ir = $annualizedActiveReturn / $annualizedTrackingError

    return [Math]::Round($ir, 3)
}

# ============================================================================
# TRADING METRICS
# ============================================================================

function Get-TradingMetrics {
    param([Parameter(Mandatory)][array]$Trades)

    if ($Trades.Count -eq 0) {
        return @{
            totalTrades = 0
            winRate = 0
            profitFactor = 0
            avgWin = 0
            avgLoss = 0
            largestWin = 0
            largestLoss = 0
            expectancy = 0
        }
    }

    $wins = $Trades | Where-Object { $_ -gt 0 }
    $losses = $Trades | Where-Object { $_ -lt 0 }

    $winCount = $wins.Count
    $lossCount = $losses.Count
    $totalTrades = $Trades.Count

    $winRate = if ($totalTrades -gt 0) { $winCount / $totalTrades } else { 0 }

    $totalWin = if ($wins) { ($wins | Measure-Object -Sum).Sum } else { 0 }
    $totalLoss = if ($losses) { [Math]::Abs(($losses | Measure-Object -Sum).Sum) } else { 0 }

    $profitFactor = if ($totalLoss -gt 0) { $totalWin / $totalLoss } else { 999 }

    $avgWin = if ($winCount -gt 0) { $totalWin / $winCount } else { 0 }
    $avgLoss = if ($lossCount -gt 0) { $totalLoss / $lossCount } else { 0 }

    $largestWin = if ($wins) { ($wins | Measure-Object -Maximum).Maximum } else { 0 }
    $largestLoss = if ($losses) { ($losses | Measure-Object -Minimum).Minimum } else { 0 }

    # Expectancy = (Win% * AvgWin) - (Loss% * AvgLoss)
    $expectancy = ($winRate * $avgWin) - ((1 - $winRate) * $avgLoss)

    return @{
        totalTrades = $totalTrades
        winRate = [Math]::Round($winRate * 100, 2)
        profitFactor = [Math]::Round($profitFactor, 2)
        avgWin = [Math]::Round($avgWin, 2)
        avgLoss = [Math]::Round($avgLoss, 2)
        largestWin = [Math]::Round($largestWin, 2)
        largestLoss = [Math]::Round($largestLoss, 2)
        expectancy = [Math]::Round($expectancy, 2)
    }
}

function Get-MaxDrawdown {
    param([Parameter(Mandatory)][array]$EquityCurve)

    $peak = $EquityCurve[0]
    $maxDrawdown = 0

    foreach ($value in $EquityCurve) {
        if ($value -gt $peak) {
            $peak = $value
        }

        $drawdown = ($peak - $value) / $peak

        if ($drawdown -gt $maxDrawdown) {
            $maxDrawdown = $drawdown
        }
    }

    return $maxDrawdown
}

function Get-RMultiples {
    param(
        [Parameter(Mandatory)][array]$Trades,
        [Parameter(Mandatory)][double]$RiskPerTrade
    )

    # R-multiple = Profit / Risk
    $rMultiples = @()

    foreach ($trade in $Trades) {
        $rMultiple = $trade / $RiskPerTrade
        $rMultiples += $rMultiple
    }

    $avgR = ($rMultiples | Measure-Object -Average).Average

    return @{
        avgRMultiple = [Math]::Round($avgR, 2)
        rMultiples = $rMultiples
    }
}

# ============================================================================
# COMPREHENSIVE REPORT
# ============================================================================

function Get-PerformanceReport {
    param(
        [Parameter(Mandatory)][array]$Returns,
        [Parameter(Mandatory)][array]$Trades,
        [Parameter(Mandatory)][array]$EquityCurve,
        [array]$BenchmarkReturns = @(),
        [double]$InitialCapital = 10000
    )

    Write-Host "`n╔══════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║          📊 PERFORMANCE ANALYTICS REPORT             ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════╝`n" -ForegroundColor Green

    # Returns analysis
    $totalReturn = (($EquityCurve[-1] - $EquityCurve[0]) / $EquityCurve[0]) * 100
    $sharpe = Get-SharpeRatio -Returns $Returns
    $sortino = Get-SortinoRatio -Returns $Returns
    $calmar = Get-CalmarRatio -Returns $Returns

    Write-Host "📈 RETURNS:" -ForegroundColor Yellow
    Write-Host "   Total return: $([Math]::Round($totalReturn, 2))%" -ForegroundColor White
    Write-Host "   Sharpe ratio: $sharpe" -ForegroundColor White
    Write-Host "   Sortino ratio: $sortino" -ForegroundColor White
    Write-Host "   Calmar ratio: $calmar`n" -ForegroundColor White

    # Alpha & Beta (if benchmark provided)
    if ($BenchmarkReturns.Count -gt 0) {
        $alphaBeta = Get-AlphaBeta -PortfolioReturns $Returns -BenchmarkReturns $BenchmarkReturns
        $ir = Get-InformationRatio -PortfolioReturns $Returns -BenchmarkReturns $BenchmarkReturns

        Write-Host "🎯 ALPHA & BETA:" -ForegroundColor Yellow
        Write-Host "   Alpha: $($alphaBeta.alpha)" -ForegroundColor $(if ($alphaBeta.alpha -gt 0) { 'Green' } else { 'Red' })
        Write-Host "   Beta: $($alphaBeta.beta)" -ForegroundColor White
        Write-Host "   Information ratio: $ir`n" -ForegroundColor White
    }

    # Trading metrics
    $metrics = Get-TradingMetrics -Trades $Trades

    Write-Host "💼 TRADING METRICS:" -ForegroundColor Yellow
    Write-Host "   Total trades: $($metrics.totalTrades)" -ForegroundColor White
    Write-Host "   Win rate: $($metrics.winRate)%" -ForegroundColor $(if ($metrics.winRate -gt 50) { 'Green' } else { 'Red' })
    Write-Host "   Profit factor: $($metrics.profitFactor)" -ForegroundColor $(if ($metrics.profitFactor -gt 1.5) { 'Green' } else { 'Red' })
    Write-Host "   Avg win: `$$($metrics.avgWin) | Avg loss: `$$($metrics.avgLoss)" -ForegroundColor White
    Write-Host "   Largest win: `$$($metrics.largestWin) | Largest loss: `$$($metrics.largestLoss)" -ForegroundColor White
    Write-Host "   Expectancy: `$$($metrics.expectancy)`n" -ForegroundColor $(if ($metrics.expectancy -gt 0) { 'Green' } else { 'Red' })

    # Drawdown
    $maxDD = Get-MaxDrawdown -EquityCurve $EquityCurve

    Write-Host "📉 RISK METRICS:" -ForegroundColor Yellow
    Write-Host "   Max drawdown: $([Math]::Round($maxDD * 100, 2))%" -ForegroundColor $(if ($maxDD -lt 0.20) { 'Green' } else { 'Red' })
    Write-Host "   Final equity: `$$([Math]::Round($EquityCurve[-1], 2))`n" -ForegroundColor White

    # Rating
    $rating = if ($sharpe -gt 2 -and $metrics.winRate -gt 55 -and $metrics.profitFactor -gt 2) { "EXCELLENT ⭐⭐⭐⭐⭐" }
              elseif ($sharpe -gt 1 -and $metrics.winRate -gt 50 -and $metrics.profitFactor -gt 1.5) { "GOOD ⭐⭐⭐⭐" }
              elseif ($sharpe -gt 0.5 -and $metrics.profitFactor -gt 1.2) { "AVERAGE ⭐⭐⭐" }
              elseif ($totalReturn -gt 0) { "BELOW AVERAGE ⭐⭐" }
              else { "POOR ⭐" }

    Write-Host "🏆 OVERALL RATING: $rating`n" -ForegroundColor Cyan

    return @{
        totalReturn = $totalReturn
        sharpe = $sharpe
        sortino = $sortino
        calmar = $calmar
        alpha = if ($BenchmarkReturns.Count -gt 0) { $alphaBeta.alpha } else { 0 }
        beta = if ($BenchmarkReturns.Count -gt 0) { $alphaBeta.beta } else { 0 }
        tradingMetrics = $metrics
        maxDrawdown = $maxDD
        rating = $rating
    }
}

# ============================================================================
# EXPORT
# ============================================================================

Export-ModuleMember -Function Get-PerformanceReport, Get-SharpeRatio, Get-SortinoRatio, Get-CalmarRatio, Get-AlphaBeta, Get-InformationRatio, Get-TradingMetrics, Get-MaxDrawdown, Get-RMultiples

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Performance Analytics ready. Institutional-grade metrics (Sharpe, Sortino, Alpha, Beta)" -ForegroundColor Yellow
}
