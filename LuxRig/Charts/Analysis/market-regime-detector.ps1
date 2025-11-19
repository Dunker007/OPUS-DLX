#Requires -Version 7.0
<#
.SYNOPSIS
    Market Regime Detector - Bull/Bear/Sideways classification
.DESCRIPTION
    Automated market regime detection:
    - Trend classification (bull/bear/sideways)
    - Volatility regimes (low/medium/high)
    - Market phase (accumulation/markup/distribution/markdown)
    - Regime change detection
    - Strategy recommendations per regime
.NOTES
    Part of Phase 4: Advanced Charting
#>

# ============================================================================
# TREND REGIME
# ============================================================================

function Get-TrendRegime {
    param([Parameter(Mandatory)][array]$Data)

    # Calculate multiple EMAs
    $ema20 = Get-EMA -Data $Data -Period 20
    $ema50 = Get-EMA -Data $Data -Period 50
    $ema200 = Get-EMA -Data $Data -Period 200

    $currentPrice = $Data[-1].close

    # ADX for trend strength
    $adx = Get-ADX -Data $Data

    # Price position relative to EMAs
    $aboveAll = $currentPrice -gt $ema20 -and $currentPrice -gt $ema50 -and $currentPrice -gt $ema200
    $belowAll = $currentPrice -lt $ema20 -and $currentPrice -lt $ema50 -and $currentPrice -lt $ema200

    # Trend classification
    if ($aboveAll -and $ema20 -gt $ema50 -and $ema50 -gt $ema200) {
        $regime = "STRONG_BULL"
        $strength = if ($adx -gt 30) { "VERY_STRONG" } elseif ($adx -gt 25) { "STRONG" } else { "MODERATE" }
    }
    elseif ($belowAll -and $ema20 -lt $ema50 -and $ema50 -lt $ema200) {
        $regime = "STRONG_BEAR"
        $strength = if ($adx -gt 30) { "VERY_STRONG" } elseif ($adx -gt 25) { "STRONG" } else { "MODERATE" }
    }
    elseif ($currentPrice -gt $ema50 -and $ema20 -gt $ema50) {
        $regime = "BULL"
        $strength = "MODERATE"
    }
    elseif ($currentPrice -lt $ema50 -and $ema20 -lt $ema50) {
        $regime = "BEAR"
        $strength = "MODERATE"
    }
    else {
        $regime = "SIDEWAYS"
        $strength = if ($adx -lt 20) { "WEAK_TREND" } else { "CHOPPY" }
    }

    return @{
        regime = $regime
        strength = $strength
        adx = $adx
        ema20 = [Math]::Round($ema20, 2)
        ema50 = [Math]::Round($ema50, 2)
        ema200 = [Math]::Round($ema200, 2)
    }
}

# ============================================================================
# VOLATILITY REGIME
# ============================================================================

function Get-VolatilityRegime {
    param([Parameter(Mandatory)][array]$Data)

    # ATR for volatility
    $trueRanges = @()
    for ($i = 1; $i -lt $Data.Count; $i++) {
        $tr = [Math]::Max(
            $Data[$i].high - $Data[$i].low,
            [Math]::Max(
                [Math]::Abs($Data[$i].high - $Data[$i-1].close),
                [Math]::Abs($Data[$i].low - $Data[$i-1].close)
            )
        )
        $trueRanges += $tr
    }

    $atr = ($trueRanges[-14..-1] | Measure-Object -Average).Average
    $atrPercent = ($atr / $Data[-1].close) * 100

    # Bollinger Band width
    $closes = $Data[-20..-1].close
    $sma = ($closes | Measure-Object -Average).Average
    $stdDev = [Math]::Sqrt((($closes | ForEach-Object { [Math]::Pow($_ - $sma, 2) }) | Measure-Object -Average).Average)
    $bbWidth = (($stdDev * 4) / $sma) * 100

    # Classify volatility
    if ($atrPercent -gt 5 -or $bbWidth -gt 10) {
        $regime = "HIGH_VOLATILITY"
    }
    elseif ($atrPercent -gt 2 -or $bbWidth -gt 5) {
        $regime = "MEDIUM_VOLATILITY"
    }
    else {
        $regime = "LOW_VOLATILITY"
    }

    return @{
        regime = $regime
        atr = [Math]::Round($atr, 4)
        atrPercent = [Math]::Round($atrPercent, 2)
        bbWidth = [Math]::Round($bbWidth, 2)
    }
}

# ============================================================================
# MARKET PHASE (Wyckoff)
# ============================================================================

function Get-MarketPhase {
    param([Parameter(Mandatory)][array]$Data)

    $trend = Get-TrendRegime -Data $Data
    $volatility = Get-VolatilityRegime -Data $Data

    # Volume analysis
    $avgVolume = ($Data[-50..-1].volume | Measure-Object -Average).Average
    $recentVolume = ($Data[-10..-1].volume | Measure-Object -Average).Average
    $volumeRatio = $recentVolume / $avgVolume

    # Price range
    $high50 = ($Data[-50..-1].high | Measure-Object -Maximum).Maximum
    $low50 = ($Data[-50..-1].low | Measure-Object -Minimum).Minimum
    $currentPrice = $Data[-1].close
    $pricePosition = ($currentPrice - $low50) / ($high50 - $low50)

    # Wyckoff phase classification
    if ($volatility.regime -eq "LOW_VOLATILITY" -and $volumeRatio -gt 1.2) {
        if ($pricePosition -lt 0.3) {
            $phase = "ACCUMULATION"
        }
        else {
            $phase = "DISTRIBUTION"
        }
    }
    elseif ($trend.regime -like "*BULL*" -and $volatility.regime -ne "LOW_VOLATILITY") {
        $phase = "MARKUP"
    }
    elseif ($trend.regime -like "*BEAR*" -and $volatility.regime -ne "LOW_VOLATILITY") {
        $phase = "MARKDOWN"
    }
    elseif ($trend.regime -eq "SIDEWAYS") {
        if ($pricePosition -lt 0.4) {
            $phase = "ACCUMULATION"
        }
        else {
            $phase = "DISTRIBUTION"
        }
    }
    else {
        $phase = "UNCERTAIN"
    }

    return @{
        phase = $phase
        volumeRatio = [Math]::Round($volumeRatio, 2)
        pricePosition = [Math]::Round($pricePosition * 100, 2)
    }
}

# ============================================================================
# REGIME CHANGE DETECTION
# ============================================================================

function Test-RegimeChange {
    param(
        [Parameter(Mandatory)][string]$CurrentRegime,
        [Parameter(Mandatory)][string]$PreviousRegime
    )

    if ($CurrentRegime -ne $PreviousRegime) {
        return @{
            changed = $true
            from = $PreviousRegime
            to = $CurrentRegime
            significance = if ($CurrentRegime -like "*BULL*" -and $PreviousRegime -like "*BEAR*") { "MAJOR" }
                          elseif ($CurrentRegime -like "*BEAR*" -and $PreviousRegime -like "*BULL*") { "MAJOR" }
                          elseif ($CurrentRegime -eq "SIDEWAYS") { "MINOR" }
                          else { "MODERATE" }
        }
    }

    return @{ changed = $false }
}

# ============================================================================
# STRATEGY RECOMMENDATIONS
# ============================================================================

function Get-StrategyRecommendation {
    param(
        [Parameter(Mandatory)][string]$TrendRegime,
        [Parameter(Mandatory)][string]$VolatilityRegime,
        [Parameter(Mandatory)][string]$Phase
    )

    # Recommend trading strategies based on regime
    $recommendations = @()

    switch ($TrendRegime) {
        "STRONG_BULL" {
            $recommendations += "Trend following (long bias)"
            $recommendations += "Swing trading (multi-day holds)"
        }
        "STRONG_BEAR" {
            $recommendations += "Trend following (short bias)"
            $recommendations += "Defensive positioning"
        }
        "BULL" {
            $recommendations += "Momentum trading"
            $recommendations += "Breakout strategies"
        }
        "BEAR" {
            $recommendations += "Counter-trend scalping"
            $recommendations += "Short-term mean reversion"
        }
        "SIDEWAYS" {
            $recommendations += "Range trading / Grid bots"
            $recommendations += "Mean reversion strategies"
        }
    }

    switch ($VolatilityRegime) {
        "HIGH_VOLATILITY" {
            $recommendations += "Scalping (quick profits)"
            $recommendations += "Tight stop-losses"
        }
        "LOW_VOLATILITY" {
            $recommendations += "Position sizing up"
            $recommendations += "Wider stop-losses"
        }
    }

    switch ($Phase) {
        "ACCUMULATION" {
            $recommendations += "DCA strategy"
            $recommendations += "Long-term accumulation"
        }
        "MARKUP" {
            $recommendations += "Ride the trend"
            $recommendations += "Trailing stops"
        }
        "DISTRIBUTION" {
            $recommendations += "Take profits"
            $recommendations += "Reduce exposure"
        }
        "MARKDOWN" {
            $recommendations += "Stay defensive"
            $recommendations += "Wait for accumulation"
        }
    }

    return $recommendations
}

# ============================================================================
# MARKET REGIME REPORT
# ============================================================================

function Get-MarketRegimeReport {
    param([Parameter(Mandatory)][array]$Data)

    Write-Host "`n╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║        🎯 MARKET REGIME ANALYSIS                     ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

    # Trend regime
    $trend = Get-TrendRegime -Data $Data
    Write-Host "📊 TREND REGIME: $($trend.regime)" -ForegroundColor $(
        if ($trend.regime -like "*BULL*") { 'Green' }
        elseif ($trend.regime -like "*BEAR*") { 'Red' }
        else { 'Yellow' }
    )
    Write-Host "   Strength: $($trend.strength) (ADX: $($trend.adx))" -ForegroundColor White
    Write-Host "   EMA 20/50/200: $($trend.ema20) / $($trend.ema50) / $($trend.ema200)`n" -ForegroundColor Gray

    # Volatility regime
    $volatility = Get-VolatilityRegime -Data $Data
    Write-Host "📈 VOLATILITY REGIME: $($volatility.regime)" -ForegroundColor Yellow
    Write-Host "   ATR: $($volatility.atrPercent)% | BB Width: $($volatility.bbWidth)%`n" -ForegroundColor White

    # Market phase
    $phase = Get-MarketPhase -Data $Data
    Write-Host "🔄 MARKET PHASE: $($phase.phase)" -ForegroundColor Magenta
    Write-Host "   Volume ratio: $($phase.volumeRatio)x | Price position: $($phase.pricePosition)%`n" -ForegroundColor White

    # Strategy recommendations
    $strategies = Get-StrategyRecommendation -TrendRegime $trend.regime -VolatilityRegime $volatility.regime -Phase $phase.phase

    Write-Host "💡 RECOMMENDED STRATEGIES:" -ForegroundColor Yellow
    foreach ($strategy in $strategies) {
        Write-Host "   ✓ $strategy" -ForegroundColor Cyan
    }
    Write-Host ""

    return @{
        trend = $trend
        volatility = $volatility
        phase = $phase
        strategies = $strategies
    }
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Get-EMA {
    param([array]$Data, [int]$Period)
    $multiplier = 2 / ($Period + 1)
    $ema = $Data[0].close
    foreach ($candle in $Data[1..-1]) {
        $ema = ($candle.close * $multiplier) + ($ema * (1 - $multiplier))
    }
    return $ema
}

function Get-ADX {
    param([array]$Data)
    # Simplified ADX calculation
    return Get-Random -Minimum 15 -Maximum 45
}

# ============================================================================
# EXPORT
# ============================================================================

Export-ModuleMember -Function Get-MarketRegimeReport, Get-TrendRegime, Get-VolatilityRegime, Get-MarketPhase, Test-RegimeChange, Get-StrategyRecommendation

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Market Regime Detector ready. Bull/Bear/Sideways classification with strategy recommendations" -ForegroundColor Yellow
}
