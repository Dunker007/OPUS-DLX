#Requires -Version 7.0
<#
.SYNOPSIS
    Advanced Risk Management System
.DESCRIPTION
    Institutional-grade risk management:
    - Kelly Criterion position sizing
    - Value at Risk (VaR) calculations
    - Maximum drawdown limits
    - Correlation analysis
    - Circuit breakers
.NOTES
    Part of Phase 4: Risk Management
#>

$script:Config = @{
    MaxDrawdown = 0.20        # 20% max drawdown
    MaxPositionSize = 0.10    # 10% max per position
    MaxCorrelation = 0.70     # Max correlation between positions
    VaRConfidence = 0.95      # 95% confidence VaR
    CircuitBreakerLoss = 0.05 # 5% daily loss triggers halt
}

# ============================================================================
# KELLY CRITERION
# ============================================================================

function Get-KellyPositionSize {
    param(
        [Parameter(Mandatory)][double]$WinRate,
        [Parameter(Mandatory)][double]$AvgWin,
        [Parameter(Mandatory)][double]$AvgLoss,
        [double]$Capital = 10000,
        [double]$FractionalKelly = 0.25  # Use 25% of full Kelly
    )

    # Kelly formula: f = (bp - q) / b
    # where: b = avg win / avg loss, p = win rate, q = 1 - p

    if ($AvgLoss -eq 0) { return 0 }

    $b = $AvgWin / $AvgLoss
    $p = $WinRate
    $q = 1 - $p

    $kelly = ($b * $p - $q) / $b

    # Apply fractional Kelly (reduces risk)
    $fractionalKelly = $kelly * $FractionalKelly

    # Position size in dollars
    $positionSize = [Math]::Max(0, [Math]::Min($fractionalKelly * $Capital, $Capital * $script:Config.MaxPositionSize))

    return @{
        fullKelly = [Math]::Round($kelly, 4)
        fractionalKelly = [Math]::Round($fractionalKelly, 4)
        positionSize = [Math]::Round($positionSize, 2)
        percentOfCapital = [Math]::Round(($positionSize / $Capital) * 100, 2)
    }
}

# ============================================================================
# VALUE AT RISK (VaR)
# ============================================================================

function Get-ValueAtRisk {
    param(
        [Parameter(Mandatory)][array]$Returns,
        [double]$Confidence = 0.95,
        [double]$PortfolioValue = 10000
    )

    # Sort returns
    $sortedReturns = $Returns | Sort-Object

    # Find VaR at confidence level
    $index = [Math]::Floor((1 - $Confidence) * $Returns.Count)
    $varReturn = $sortedReturns[$index]

    $var = [Math]::Abs($varReturn * $PortfolioValue)

    # Conditional VaR (CVaR) - average of losses beyond VaR
    $tailReturns = $sortedReturns[0..$index]
    $cvar = [Math]::Abs(($tailReturns | Measure-Object -Average).Average * $PortfolioValue)

    return @{
        var = [Math]::Round($var, 2)
        cvar = [Math]::Round($cvar, 2)
        varPercent = [Math]::Round(($var / $PortfolioValue) * 100, 2)
        confidence = $Confidence * 100
    }
}

# ============================================================================
# DRAWDOWN MONITORING
# ============================================================================

function Get-DrawdownMetrics {
    param([Parameter(Mandatory)][array]$EquityCurve)

    $peak = $EquityCurve[0]
    $maxDrawdown = 0
    $currentDrawdown = 0
    $drawdownPeriods = @()

    for ($i = 0; $i -lt $EquityCurve.Count; $i++) {
        $value = $EquityCurve[$i]

        if ($value -gt $peak) {
            $peak = $value
        }

        $currentDrawdown = ($peak - $value) / $peak

        if ($currentDrawdown -gt $maxDrawdown) {
            $maxDrawdown = $currentDrawdown
        }

        if ($currentDrawdown -gt $script:Config.MaxDrawdown) {
            $drawdownPeriods += @{
                index = $i
                drawdown = $currentDrawdown
                peak = $peak
                current = $value
            }
        }
    }

    return @{
        maxDrawdown = [Math]::Round($maxDrawdown * 100, 2)
        currentDrawdown = [Math]::Round($currentDrawdown * 100, 2)
        breachCount = $drawdownPeriods.Count
        breaches = $drawdownPeriods
        status = if ($currentDrawdown -gt $script:Config.MaxDrawdown) { 'EXCEEDED' } else { 'OK' }
    }
}

# ============================================================================
# CORRELATION ANALYSIS
# ============================================================================

function Get-PositionCorrelation {
    param(
        [Parameter(Mandatory)][array]$Position1Returns,
        [Parameter(Mandatory)][array]$Position2Returns
    )

    $n = [Math]::Min($Position1Returns.Count, $Position2Returns.Count)

    if ($n -lt 2) { return 0 }

    $mean1 = ($Position1Returns | Measure-Object -Average).Average
    $mean2 = ($Position2Returns | Measure-Object -Average).Average

    $numerator = 0
    $sum1Sq = 0
    $sum2Sq = 0

    for ($i = 0; $i -lt $n; $i++) {
        $diff1 = $Position1Returns[$i] - $mean1
        $diff2 = $Position2Returns[$i] - $mean2

        $numerator += $diff1 * $diff2
        $sum1Sq += $diff1 * $diff1
        $sum2Sq += $diff2 * $diff2
    }

    $denominator = [Math]::Sqrt($sum1Sq * $sum2Sq)

    if ($denominator -eq 0) { return 0 }

    return [Math]::Round($numerator / $denominator, 3)
}

function Test-PortfolioCorrelation {
    param([Parameter(Mandatory)][hashtable]$Positions)

    $correlations = @()

    $symbols = $Positions.Keys | ForEach-Object { $_ }

    for ($i = 0; $i -lt $symbols.Count; $i++) {
        for ($j = $i + 1; $j -lt $symbols.Count; $j++) {
            $symbol1 = $symbols[$i]
            $symbol2 = $symbols[$j]

            $corr = Get-PositionCorrelation -Position1Returns $Positions[$symbol1].returns -Position2Returns $Positions[$symbol2].returns

            if ([Math]::Abs($corr) -gt $script:Config.MaxCorrelation) {
                $correlations += @{
                    pair = "$symbol1 / $symbol2"
                    correlation = $corr
                    warning = $true
                }
            }
        }
    }

    return @{
        highCorrelations = $correlations
        count = $correlations.Count
        status = if ($correlations.Count -gt 0) { 'WARNING' } else { 'OK' }
    }
}

# ============================================================================
# CIRCUIT BREAKERS
# ============================================================================

function Test-CircuitBreaker {
    param(
        [Parameter(Mandatory)][double]$StartingCapital,
        [Parameter(Mandatory)][double]$CurrentCapital
    )

    $dailyReturn = ($CurrentCapital - $StartingCapital) / $StartingCapital
    $loss = [Math]::Abs([Math]::Min(0, $dailyReturn))

    $breaker = @{
        triggered = $loss -gt $script:Config.CircuitBreakerLoss
        dailyLoss = [Math]::Round($loss * 100, 2)
        threshold = [Math]::Round($script:Config.CircuitBreakerLoss * 100, 2)
        action = if ($loss -gt $script:Config.CircuitBreakerLoss) { 'HALT_TRADING' } else { 'CONTINUE' }
    }

    if ($breaker.triggered) {
        Write-Host "🔴 CIRCUIT BREAKER TRIGGERED!" -ForegroundColor Red
        Write-Host "   Daily loss: $($breaker.dailyLoss)% (Threshold: $($breaker.threshold)%)" -ForegroundColor Red
        Write-Host "   Action: HALT ALL TRADING" -ForegroundColor Red
    }

    return $breaker
}

# ============================================================================
# COMPREHENSIVE RISK REPORT
# ============================================================================

function Get-RiskReport {
    param(
        [Parameter(Mandatory)][hashtable]$Portfolio,
        [Parameter(Mandatory)][array]$EquityCurve,
        [Parameter(Mandatory)][array]$Returns
    )

    Write-Host "`n╔══════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║            🛡️  RISK MANAGEMENT REPORT                ║" -ForegroundColor Red
    Write-Host "╚══════════════════════════════════════════════════════╝`n" -ForegroundColor Red

    # VaR
    $var = Get-ValueAtRisk -Returns $Returns -PortfolioValue $Portfolio.totalValue

    # Drawdown
    $drawdown = Get-DrawdownMetrics -EquityCurve $EquityCurve

    # Correlation
    $correlation = Test-PortfolioCorrelation -Positions $Portfolio.positions

    # Circuit breaker
    $breaker = Test-CircuitBreaker -StartingCapital $EquityCurve[0] -CurrentCapital $EquityCurve[-1]

    # Display
    Write-Host "💰 Portfolio Value: `$$($Portfolio.totalValue)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📊 Value at Risk (95%):" -ForegroundColor Yellow
    Write-Host "   VaR: `$$($var.var) ($($var.varPercent)%)" -ForegroundColor White
    Write-Host "   CVaR: `$$($var.cvar)" -ForegroundColor White
    Write-Host ""
    Write-Host "📉 Drawdown:" -ForegroundColor Yellow
    Write-Host "   Max: $($drawdown.maxDrawdown)%" -ForegroundColor White
    Write-Host "   Current: $($drawdown.currentDrawdown)%" -ForegroundColor White
    Write-Host "   Status: $($drawdown.status)" -ForegroundColor $(if ($drawdown.status -eq 'OK') { 'Green' } else { 'Red' })
    Write-Host ""
    Write-Host "🔗 Correlation:" -ForegroundColor Yellow
    Write-Host "   High correlations: $($correlation.count)" -ForegroundColor White
    Write-Host "   Status: $($correlation.status)" -ForegroundColor $(if ($correlation.status -eq 'OK') { 'Green' } else { 'Yellow' })
    Write-Host ""
    Write-Host "🔴 Circuit Breaker:" -ForegroundColor Yellow
    Write-Host "   Status: $($breaker.action)" -ForegroundColor $(if ($breaker.triggered) { 'Red' } else { 'Green' })
    Write-Host "   Daily loss: $($breaker.dailyLoss)%" -ForegroundColor White
    Write-Host ""

    return @{
        var = $var
        drawdown = $drawdown
        correlation = $correlation
        circuitBreaker = $breaker
    }
}

# ============================================================================
# EXPORT
# ============================================================================

Export-ModuleMember -Function Get-KellyPositionSize, Get-ValueAtRisk, Get-DrawdownMetrics, Test-CircuitBreaker, Get-RiskReport

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Advanced Risk Manager ready. Institutional-grade risk management activated" -ForegroundColor Yellow
}
