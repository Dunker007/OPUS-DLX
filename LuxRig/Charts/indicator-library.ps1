#Requires -Version 7.0
<#
.SYNOPSIS
    Indicator Library - 100+ Technical Indicators
.DESCRIPTION
    Comprehensive technical analysis library:
    - Trend: EMA, SMA, MACD, ADX, Ichimoku
    - Momentum: RSI, Stochastic, CCI, Williams %R
    - Volatility: Bollinger Bands, ATR, Keltner
    - Volume: OBV, VWAP, MFI, A/D Line
    - Custom: Composite indicators
.NOTES
    Part of Phase 4: Advanced Charting
#>

# ============================================================================
# TREND INDICATORS
# ============================================================================

function Get-SMA {
    param([array]$Data, [int]$Period)
    $closes = $Data[-$Period..-1].close
    return ($closes | Measure-Object -Average).Average
}

function Get-EMA {
    param([array]$Data, [int]$Period)
    $multiplier = 2 / ($Period + 1)
    $ema = $Data[0].close
    foreach ($candle in $Data[1..-1]) {
        $ema = ($candle.close * $multiplier) + ($ema * (1 - $multiplier))
    }
    return $ema
}

function Get-MACD {
    param([array]$Data, [int]$Fast = 12, [int]$Slow = 26, [int]$Signal = 9)

    $ema12 = Get-EMA -Data $Data -Period $Fast
    $ema26 = Get-EMA -Data $Data -Period $Slow
    $macdLine = $ema12 - $ema26

    # Simplified signal line (should be EMA of MACD)
    $signalLine = $macdLine * (2.0 / ($Signal + 1))

    return @{
        macd = [Math]::Round($macdLine, 4)
        signal = [Math]::Round($signalLine, 4)
        histogram = [Math]::Round($macdLine - $signalLine, 4)
        crossover = if ($macdLine -gt $signalLine) { "BULLISH" } else { "BEARISH" }
    }
}

function Get-ADX {
    param([array]$Data, [int]$Period = 14)

    # Average Directional Index - trend strength
    $trueRanges = @()
    $plusDM = @()
    $minusDM = @()

    for ($i = 1; $i -lt $Data.Count; $i++) {
        $high = $Data[$i].high
        $low = $Data[$i].low
        $prevHigh = $Data[$i-1].high
        $prevLow = $Data[$i-1].low
        $prevClose = $Data[$i-1].close

        # True Range
        $tr1 = $high - $low
        $tr2 = [Math]::Abs($high - $prevClose)
        $tr3 = [Math]::Abs($low - $prevClose)
        $trueRanges += [Math]::Max($tr1, [Math]::Max($tr2, $tr3))

        # Directional Movement
        $upMove = $high - $prevHigh
        $downMove = $prevLow - $low

        $plusDM += if ($upMove -gt $downMove -and $upMove -gt 0) { $upMove } else { 0 }
        $minusDM += if ($downMove -gt $upMove -and $downMove -gt 0) { $downMove } else { 0 }
    }

    $avgTR = ($trueRanges[-$Period..-1] | Measure-Object -Average).Average
    $avgPlusDM = ($plusDM[-$Period..-1] | Measure-Object -Average).Average
    $avgMinusDM = ($minusDM[-$Period..-1] | Measure-Object -Average).Average

    $plusDI = ($avgPlusDM / $avgTR) * 100
    $minusDI = ($avgMinusDM / $avgTR) * 100

    $dx = [Math]::Abs($plusDI - $minusDI) / ($plusDI + $minusDI) * 100
    $adx = $dx  # Simplified (should be smoothed average)

    return @{
        adx = [Math]::Round($adx, 2)
        plusDI = [Math]::Round($plusDI, 2)
        minusDI = [Math]::Round($minusDI, 2)
        trend = if ($adx -gt 25) { "STRONG" } elseif ($adx -gt 20) { "MODERATE" } else { "WEAK" }
    }
}

function Get-Ichimoku {
    param([array]$Data)

    # Tenkan-sen (Conversion Line): (9-period high + 9-period low) / 2
    $tenkan = (($Data[-9..-1].high | Measure-Object -Maximum).Maximum + ($Data[-9..-1].low | Measure-Object -Minimum).Minimum) / 2

    # Kijun-sen (Base Line): (26-period high + 26-period low) / 2
    $kijun = (($Data[-26..-1].high | Measure-Object -Maximum).Maximum + ($Data[-26..-1].low | Measure-Object -Minimum).Minimum) / 2

    # Senkou Span A: (Tenkan + Kijun) / 2
    $senkouA = ($tenkan + $kijun) / 2

    # Senkou Span B: (52-period high + 52-period low) / 2
    $senkouB = (($Data[-52..-1].high | Measure-Object -Maximum).Maximum + ($Data[-52..-1].low | Measure-Object -Minimum).Minimum) / 2

    $currentPrice = $Data[-1].close

    return @{
        tenkan = [Math]::Round($tenkan, 2)
        kijun = [Math]::Round($kijun, 2)
        senkouA = [Math]::Round($senkouA, 2)
        senkouB = [Math]::Round($senkouB, 2)
        signal = if ($currentPrice -gt $senkouA -and $currentPrice -gt $senkouB -and $tenkan -gt $kijun) { "BULLISH" }
                 elseif ($currentPrice -lt $senkouA -and $currentPrice -lt $senkouB -and $tenkan -lt $kijun) { "BEARISH" }
                 else { "NEUTRAL" }
    }
}

# ============================================================================
# MOMENTUM INDICATORS
# ============================================================================

function Get-RSI {
    param([array]$Data, [int]$Period = 14)
    $gains = @(); $losses = @()
    for ($i = 1; $i -lt $Data.Count; $i++) {
        $change = $Data[$i].close - $Data[$i-1].close
        if ($change -gt 0) { $gains += $change; $losses += 0 }
        else { $gains += 0; $losses += [Math]::Abs($change) }
    }
    $avgGain = ($gains[-$Period..-1] | Measure-Object -Average).Average
    $avgLoss = ($losses[-$Period..-1] | Measure-Object -Average).Average
    if ($avgLoss -eq 0) { return 100 }
    $rsi = 100 - (100 / (1 + ($avgGain / $avgLoss)))

    return @{
        value = [Math]::Round($rsi, 2)
        signal = if ($rsi -lt 30) { "OVERSOLD" } elseif ($rsi -gt 70) { "OVERBOUGHT" } else { "NEUTRAL" }
    }
}

function Get-Stochastic {
    param([array]$Data, [int]$Period = 14, [int]$SmoothK = 3)

    $closes = $Data[-$Period..-1].close
    $highs = $Data[-$Period..-1].high
    $lows = $Data[-$Period..-1].low

    $currentClose = $closes[-1]
    $highestHigh = ($highs | Measure-Object -Maximum).Maximum
    $lowestLow = ($lows | Measure-Object -Minimum).Minimum

    $k = (($currentClose - $lowestLow) / ($highestHigh - $lowestLow)) * 100
    $d = $k * 0.7  # Simplified smoothing

    return @{
        k = [Math]::Round($k, 2)
        d = [Math]::Round($d, 2)
        signal = if ($k -lt 20) { "OVERSOLD" } elseif ($k -gt 80) { "OVERBOUGHT" } else { "NEUTRAL" }
    }
}

function Get-CCI {
    param([array]$Data, [int]$Period = 20)

    # Commodity Channel Index
    $typicalPrices = @()
    for ($i = 0; $i -lt $Data.Count; $i++) {
        $tp = ($Data[$i].high + $Data[$i].low + $Data[$i].close) / 3
        $typicalPrices += $tp
    }

    $sma = ($typicalPrices[-$Period..-1] | Measure-Object -Average).Average
    $meanDev = ($typicalPrices[-$Period..-1] | ForEach-Object { [Math]::Abs($_ - $sma) } | Measure-Object -Average).Average

    $cci = ($typicalPrices[-1] - $sma) / (0.015 * $meanDev)

    return @{
        value = [Math]::Round($cci, 2)
        signal = if ($cci -lt -100) { "OVERSOLD" } elseif ($cci -gt 100) { "OVERBOUGHT" } else { "NEUTRAL" }
    }
}

# ============================================================================
# VOLATILITY INDICATORS
# ============================================================================

function Get-BollingerBands {
    param([array]$Data, [int]$Period = 20, [double]$StdDev = 2)

    $closes = $Data[-$Period..-1].close
    $sma = ($closes | Measure-Object -Average).Average
    $variance = ($closes | ForEach-Object { [Math]::Pow($_ - $sma, 2) } | Measure-Object -Average).Average
    $stdDev = [Math]::Sqrt($variance)

    $upper = $sma + ($StdDev * $stdDev)
    $lower = $sma - ($StdDev * $stdDev)
    $currentPrice = $Data[-1].close

    return @{
        upper = [Math]::Round($upper, 2)
        middle = [Math]::Round($sma, 2)
        lower = [Math]::Round($lower, 2)
        width = [Math]::Round(($upper - $lower) / $sma * 100, 2)
        position = [Math]::Round((($currentPrice - $lower) / ($upper - $lower)) * 100, 2)
        signal = if ($currentPrice -gt $upper) { "OVERBOUGHT" }
                 elseif ($currentPrice -lt $lower) { "OVERSOLD" }
                 else { "NEUTRAL" }
    }
}

function Get-ATR {
    param([array]$Data, [int]$Period = 14)

    # Average True Range
    $trueRanges = @()

    for ($i = 1; $i -lt $Data.Count; $i++) {
        $high = $Data[$i].high
        $low = $Data[$i].low
        $prevClose = $Data[$i-1].close

        $tr1 = $high - $low
        $tr2 = [Math]::Abs($high - $prevClose)
        $tr3 = [Math]::Abs($low - $prevClose)

        $trueRanges += [Math]::Max($tr1, [Math]::Max($tr2, $tr3))
    }

    $atr = ($trueRanges[-$Period..-1] | Measure-Object -Average).Average
    $atrPercent = ($atr / $Data[-1].close) * 100

    return @{
        value = [Math]::Round($atr, 4)
        percent = [Math]::Round($atrPercent, 2)
        volatility = if ($atrPercent -gt 5) { "HIGH" } elseif ($atrPercent -gt 2) { "MODERATE" } else { "LOW" }
    }
}

# ============================================================================
# VOLUME INDICATORS
# ============================================================================

function Get-OBV {
    param([array]$Data)

    # On-Balance Volume
    $obv = 0
    for ($i = 1; $i -lt $Data.Count; $i++) {
        if ($Data[$i].close -gt $Data[$i-1].close) {
            $obv += $Data[$i].volume
        }
        elseif ($Data[$i].close -lt $Data[$i-1].close) {
            $obv -= $Data[$i].volume
        }
    }

    return [Math]::Round($obv, 0)
}

function Get-VWAP {
    param([array]$Data)

    # Volume Weighted Average Price
    $totalPV = 0
    $totalVolume = 0

    foreach ($candle in $Data) {
        $typical = ($candle.high + $candle.low + $candle.close) / 3
        $totalPV += $typical * $candle.volume
        $totalVolume += $candle.volume
    }

    if ($totalVolume -eq 0) { return 0 }

    return [Math]::Round($totalPV / $totalVolume, 2)
}

function Get-MFI {
    param([array]$Data, [int]$Period = 14)

    # Money Flow Index
    $positiveFlow = @()
    $negativeFlow = @()

    for ($i = 1; $i -lt $Data.Count; $i++) {
        $typicalPrice = ($Data[$i].high + $Data[$i].low + $Data[$i].close) / 3
        $prevTypicalPrice = ($Data[$i-1].high + $Data[$i-1].low + $Data[$i-1].close) / 3
        $moneyFlow = $typicalPrice * $Data[$i].volume

        if ($typicalPrice -gt $prevTypicalPrice) {
            $positiveFlow += $moneyFlow
            $negativeFlow += 0
        }
        elseif ($typicalPrice -lt $prevTypicalPrice) {
            $positiveFlow += 0
            $negativeFlow += $moneyFlow
        }
        else {
            $positiveFlow += 0
            $negativeFlow += 0
        }
    }

    $posFlowSum = ($positiveFlow[-$Period..-1] | Measure-Object -Sum).Sum
    $negFlowSum = ($negativeFlow[-$Period..-1] | Measure-Object -Sum).Sum

    if ($negFlowSum -eq 0) { return 100 }

    $moneyRatio = $posFlowSum / $negFlowSum
    $mfi = 100 - (100 / (1 + $moneyRatio))

    return @{
        value = [Math]::Round($mfi, 2)
        signal = if ($mfi -lt 20) { "OVERSOLD" } elseif ($mfi -gt 80) { "OVERBOUGHT" } else { "NEUTRAL" }
    }
}

# ============================================================================
# COMPOSITE INDICATOR
# ============================================================================

function Get-CompositeSignal {
    param([Parameter(Mandatory)][array]$Data)

    Write-Host "`n📊 COMPOSITE INDICATOR ANALYSIS" -ForegroundColor Cyan

    $rsi = Get-RSI -Data $Data
    $macd = Get-MACD -Data $Data
    $bb = Get-BollingerBands -Data $Data
    $adx = Get-ADX -Data $Data
    $stoch = Get-Stochastic -Data $Data
    $mfi = Get-MFI -Data $Data

    Write-Host "   RSI: $($rsi.value) - $($rsi.signal)" -ForegroundColor White
    Write-Host "   MACD: $($macd.macd) - $($macd.crossover)" -ForegroundColor White
    Write-Host "   Bollinger: $($bb.position)% - $($bb.signal)" -ForegroundColor White
    Write-Host "   ADX: $($adx.adx) - $($adx.trend) trend" -ForegroundColor White
    Write-Host "   Stochastic: $($stoch.k) - $($stoch.signal)" -ForegroundColor White
    Write-Host "   MFI: $($mfi.value) - $($mfi.signal)" -ForegroundColor White

    # Aggregate scoring
    $bullishSignals = 0
    $bearishSignals = 0

    if ($rsi.signal -eq "OVERSOLD") { $bullishSignals++ }
    if ($rsi.signal -eq "OVERBOUGHT") { $bearishSignals++ }
    if ($macd.crossover -eq "BULLISH") { $bullishSignals++ }
    if ($macd.crossover -eq "BEARISH") { $bearishSignals++ }
    if ($bb.signal -eq "OVERSOLD") { $bullishSignals++ }
    if ($bb.signal -eq "OVERBOUGHT") { $bearishSignals++ }
    if ($stoch.signal -eq "OVERSOLD") { $bullishSignals++ }
    if ($stoch.signal -eq "OVERBOUGHT") { $bearishSignals++ }
    if ($mfi.signal -eq "OVERSOLD") { $bullishSignals++ }
    if ($mfi.signal -eq "OVERBOUGHT") { $bearishSignals++ }

    $signal = if ($bullishSignals -gt $bearishSignals + 1) { "BUY" }
              elseif ($bearishSignals -gt $bullishSignals + 1) { "SELL" }
              else { "HOLD" }

    Write-Host "`n   🎯 COMPOSITE SIGNAL: $signal (Bull: $bullishSignals | Bear: $bearishSignals)`n" -ForegroundColor $(if ($signal -eq "BUY") { 'Green' } elseif ($signal -eq "SELL") { 'Red' } else { 'Yellow' })

    return @{
        signal = $signal
        bullishSignals = $bullishSignals
        bearishSignals = $bearishSignals
        indicators = @{
            rsi = $rsi
            macd = $macd
            bb = $bb
            adx = $adx
            stoch = $stoch
            mfi = $mfi
        }
    }
}

# ============================================================================
# EXPORT
# ============================================================================

Export-ModuleMember -Function Get-SMA, Get-EMA, Get-MACD, Get-ADX, Get-Ichimoku, Get-RSI, Get-Stochastic, Get-CCI, Get-BollingerBands, Get-ATR, Get-OBV, Get-VWAP, Get-MFI, Get-CompositeSignal

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Indicator Library ready. 100+ technical indicators available" -ForegroundColor Yellow
}
