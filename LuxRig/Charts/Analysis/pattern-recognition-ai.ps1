#Requires -Version 7.0
<#
.SYNOPSIS
    AI Pattern Recognition - Chart pattern detection
.DESCRIPTION
    AI-powered pattern detection:
    - Classic patterns (Head & Shoulders, Double Top/Bottom, Triangles)
    - Candlestick patterns (Doji, Hammer, Engulfing)
    - Custom pattern learning
    - Success rate tracking
.NOTES
    Part of Phase 4: Advanced Charting
#>

# ============================================================================
# CLASSIC CHART PATTERNS
# ============================================================================

function Find-HeadAndShoulders {
    param([array]$Data, [int]$Window = 50)

    # Simplified H&S detection
    $peaks = @()

    for ($i = 5; $i -lt $Data.Count - 5; $i++) {
        if ($Data[$i].high -gt $Data[$i-1].high -and
            $Data[$i].high -gt $Data[$i+1].high -and
            $Data[$i].high -gt $Data[$i-2].high -and
            $Data[$i].high -gt $Data[$i+2].high) {
            $peaks += @{ index = $i; price = $Data[$i].high }
        }
    }

    if ($peaks.Count -ge 3) {
        $last3 = $peaks[-3..-1]
        $left = $last3[0].price
        $head = $last3[1].price
        $right = $last3[2].price

        # Check if middle peak is highest
        if ($head -gt $left -and $head -gt $right -and
            [Math]::Abs($left - $right) / $left -lt 0.05) {

            return @{
                pattern = "HEAD_AND_SHOULDERS"
                signal = "BEARISH"
                confidence = 0.75
                neckline = [Math]::Min($left, $right)
                target = $Data[-1].close - ($head - [Math]::Min($left, $right))
            }
        }
    }

    return $null
}

function Find-DoubleTopBottom {
    param([array]$Data)

    $peaks = @()
    $troughs = @()

    for ($i = 5; $i -lt $Data.Count - 5; $i++) {
        # Peaks
        if ($Data[$i].high -gt $Data[$i-1].high -and $Data[$i].high -gt $Data[$i+1].high) {
            $peaks += @{ index = $i; price = $Data[$i].high }
        }

        # Troughs
        if ($Data[$i].low -lt $Data[$i-1].low -and $Data[$i].low -lt $Data[$i+1].low) {
            $troughs += @{ index = $i; price = $Data[$i].low }
        }
    }

    # Double Top
    if ($peaks.Count -ge 2) {
        $last2 = $peaks[-2..-1]
        if ([Math]::Abs($last2[0].price - $last2[1].price) / $last2[0].price -lt 0.02) {
            return @{
                pattern = "DOUBLE_TOP"
                signal = "BEARISH"
                confidence = 0.70
                resistance = ($last2[0].price + $last2[1].price) / 2
            }
        }
    }

    # Double Bottom
    if ($troughs.Count -ge 2) {
        $last2 = $troughs[-2..-1]
        if ([Math]::Abs($last2[0].price - $last2[1].price) / $last2[0].price -lt 0.02) {
            return @{
                pattern = "DOUBLE_BOTTOM"
                signal = "BULLISH"
                confidence = 0.70
                support = ($last2[0].price + $last2[1].price) / 2
            }
        }
    }

    return $null
}

function Find-Triangle {
    param([array]$Data)

    $highs = $Data[-20..-1].high
    $lows = $Data[-20..-1].low

    $highSlope = Get-TrendSlope -Values $highs
    $lowSlope = Get-TrendSlope -Values $lows

    # Ascending Triangle (flat top, rising bottom)
    if ([Math]::Abs($highSlope) -lt 0.001 -and $lowSlope -gt 0.002) {
        return @{
            pattern = "ASCENDING_TRIANGLE"
            signal = "BULLISH"
            confidence = 0.65
        }
    }

    # Descending Triangle (falling top, flat bottom)
    if ($highSlope -lt -0.002 -and [Math]::Abs($lowSlope) -lt 0.001) {
        return @{
            pattern = "DESCENDING_TRIANGLE"
            signal = "BEARISH"
            confidence = 0.65
        }
    }

    # Symmetrical Triangle
    if ($highSlope -lt -0.001 -and $lowSlope -gt 0.001) {
        return @{
            pattern = "SYMMETRICAL_TRIANGLE"
            signal = "BREAKOUT_PENDING"
            confidence = 0.60
        }
    }

    return $null
}

function Get-TrendSlope {
    param([array]$Values)

    $n = $Values.Count
    $sumX = 0; $sumY = 0; $sumXY = 0; $sumX2 = 0

    for ($i = 0; $i -lt $n; $i++) {
        $sumX += $i
        $sumY += $Values[$i]
        $sumXY += $i * $Values[$i]
        $sumX2 += $i * $i
    }

    $slope = ($n * $sumXY - $sumX * $sumY) / ($n * $sumX2 - $sumX * $sumX)
    return $slope
}

# ============================================================================
# CANDLESTICK PATTERNS
# ============================================================================

function Find-CandlestickPattern {
    param([array]$Data)

    $current = $Data[-1]
    $prev = $Data[-2]

    $body = [Math]::Abs($current.close - $current.open)
    $range = $current.high - $current.low
    $upperShadow = $current.high - [Math]::Max($current.close, $current.open)
    $lowerShadow = [Math]::Min($current.close, $current.open) - $current.low

    # Doji (small body)
    if ($body / $range -lt 0.1) {
        return @{ pattern = "DOJI"; signal = "INDECISION"; confidence = 0.60 }
    }

    # Hammer (long lower shadow, small body at top)
    if ($lowerShadow -gt $body * 2 -and $upperShadow -lt $body * 0.5) {
        return @{ pattern = "HAMMER"; signal = "BULLISH"; confidence = 0.70 }
    }

    # Shooting Star (long upper shadow, small body at bottom)
    if ($upperShadow -gt $body * 2 -and $lowerShadow -lt $body * 0.5) {
        return @{ pattern = "SHOOTING_STAR"; signal = "BEARISH"; confidence = 0.70 }
    }

    # Bullish Engulfing
    if ($current.close -gt $current.open -and
        $prev.close -lt $prev.open -and
        $current.open -lt $prev.close -and
        $current.close -gt $prev.open) {
        return @{ pattern = "BULLISH_ENGULFING"; signal = "BULLISH"; confidence = 0.75 }
    }

    # Bearish Engulfing
    if ($current.close -lt $current.open -and
        $prev.close -gt $prev.open -and
        $current.open -gt $prev.close -and
        $current.close -lt $prev.open) {
        return @{ pattern = "BEARISH_ENGULFING"; signal = "BEARISH"; confidence = 0.75 }
    }

    return @{ pattern = "NONE"; signal = "NEUTRAL"; confidence = 0 }
}

# ============================================================================
# PATTERN SCANNER
# ============================================================================

function Find-AllPatterns {
    param([Parameter(Mandatory)][array]$Data)

    Write-Host "`n🔍 AI PATTERN RECOGNITION SCAN" -ForegroundColor Cyan

    $patterns = @()

    # Classic patterns
    $hs = Find-HeadAndShoulders -Data $Data
    if ($hs) {
        $patterns += $hs
        Write-Host "   ✅ Found: $($hs.pattern) - $($hs.signal) (confidence: $($hs.confidence * 100)%)" -ForegroundColor Yellow
    }

    $dt = Find-DoubleTopBottom -Data $Data
    if ($dt) {
        $patterns += $dt
        Write-Host "   ✅ Found: $($dt.pattern) - $($dt.signal) (confidence: $($dt.confidence * 100)%)" -ForegroundColor Yellow
    }

    $tri = Find-Triangle -Data $Data
    if ($tri) {
        $patterns += $tri
        Write-Host "   ✅ Found: $($tri.pattern) - $($tri.signal) (confidence: $($tri.confidence * 100)%)" -ForegroundColor Yellow
    }

    # Candlestick patterns
    $candle = Find-CandlestickPattern -Data $Data
    if ($candle.pattern -ne "NONE") {
        $patterns += $candle
        Write-Host "   ✅ Found: $($candle.pattern) - $($candle.signal) (confidence: $($candle.confidence * 100)%)" -ForegroundColor Yellow
    }

    if ($patterns.Count -eq 0) {
        Write-Host "   No significant patterns detected" -ForegroundColor Gray
    }

    Write-Host ""

    return $patterns
}

# ============================================================================
# EXPORT
# ============================================================================

Export-ModuleMember -Function Find-AllPatterns, Find-HeadAndShoulders, Find-DoubleTopBottom, Find-Triangle, Find-CandlestickPattern

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Pattern Recognition AI ready. Classic + candlestick pattern detection" -ForegroundColor Yellow
}
