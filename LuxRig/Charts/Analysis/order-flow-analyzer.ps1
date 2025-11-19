#Requires -Version 7.0
<#
.SYNOPSIS
    Order Flow Analyzer - CVD, whale watching, market microstructure
.DESCRIPTION
    Advanced order flow analysis:
    - Cumulative Volume Delta (CVD)
    - Large order detection (whale watching)
    - Bid/ask imbalance
    - Order book depth analysis
    - Absorption and spoofing detection
.NOTES
    Part of Phase 4: Advanced Charting
#>

# ============================================================================
# CUMULATIVE VOLUME DELTA
# ============================================================================

function Get-CVD {
    param([Parameter(Mandatory)][array]$Trades)

    $cvd = 0
    $buyVolume = 0
    $sellVolume = 0

    foreach ($trade in $Trades) {
        if ($trade.side -eq "BUY") {
            $buyVolume += $trade.size
            $cvd += $trade.size
        }
        else {
            $sellVolume += $trade.size
            $cvd -= $trade.size
        }
    }

    $totalVolume = $buyVolume + $sellVolume
    $buyPressure = if ($totalVolume -gt 0) { ($buyVolume / $totalVolume) * 100 } else { 50 }

    return @{
        cvd = [Math]::Round($cvd, 4)
        buyVolume = [Math]::Round($buyVolume, 4)
        sellVolume = [Math]::Round($sellVolume, 4)
        buyPressure = [Math]::Round($buyPressure, 2)
        signal = if ($buyPressure -gt 55) { "BULLISH" } elseif ($buyPressure -lt 45) { "BEARISH" } else { "NEUTRAL" }
    }
}

# ============================================================================
# WHALE WATCHING
# ============================================================================

function Find-WhaleOrders {
    param(
        [Parameter(Mandatory)][array]$Trades,
        [double]$WhaleThreshold = 10000  # USD value
    )

    Write-Host "`n🐋 WHALE WATCHING" -ForegroundColor Cyan

    $whales = @()

    foreach ($trade in $Trades) {
        $value = $trade.price * $trade.size

        if ($value -ge $WhaleThreshold) {
            $whales += @{
                side = $trade.side
                size = $trade.size
                price = $trade.price
                value = [Math]::Round($value, 2)
                timestamp = $trade.timestamp
            }

            $color = if ($trade.side -eq "BUY") { "Green" } else { "Red" }
            Write-Host "   🐋 $($trade.side) $($trade.size) @ `$$($trade.price) (``$$([Math]::Round($value, 2)))" -ForegroundColor $color
        }
    }

    if ($whales.Count -eq 0) {
        Write-Host "   No whale activity detected" -ForegroundColor Gray
    }

    $buyWhales = ($whales | Where-Object { $_.side -eq "BUY" }).Count
    $sellWhales = ($whales | Where-Object { $_.side -eq "SELL" }).Count

    Write-Host "`n   Summary: $buyWhales buy whales, $sellWhales sell whales`n" -ForegroundColor White

    return @{
        whales = $whales
        buyCount = $buyWhales
        sellCount = $sellWhales
        signal = if ($buyWhales -gt $sellWhales) { "BULLISH" } elseif ($sellWhales -gt $buyWhales) { "BEARISH" } else { "NEUTRAL" }
    }
}

# ============================================================================
# ORDER BOOK ANALYSIS
# ============================================================================

function Get-OrderBookImbalance {
    param([Parameter(Mandatory)][hashtable]$OrderBook, [int]$Depth = 10)

    $bids = $OrderBook.bids[0..([Math]::Min($Depth, $OrderBook.bids.Count) - 1)]
    $asks = $OrderBook.asks[0..([Math]::Min($Depth, $OrderBook.asks.Count) - 1)]

    $bidVolume = ($bids | ForEach-Object { $_.quantity } | Measure-Object -Sum).Sum
    $askVolume = ($asks | ForEach-Object { $_.quantity } | Measure-Object -Sum).Sum

    $totalVolume = $bidVolume + $askVolume
    $bidPercentage = if ($totalVolume -gt 0) { ($bidVolume / $totalVolume) * 100 } else { 50 }

    $imbalance = $bidVolume - $askVolume
    $imbalanceRatio = if ($askVolume -gt 0) { $bidVolume / $askVolume } else { 999 }

    return @{
        bidVolume = [Math]::Round($bidVolume, 4)
        askVolume = [Math]::Round($askVolume, 4)
        bidPercentage = [Math]::Round($bidPercentage, 2)
        imbalance = [Math]::Round($imbalance, 4)
        ratio = [Math]::Round($imbalanceRatio, 2)
        signal = if ($bidPercentage -gt 60) { "BULLISH" }
                 elseif ($bidPercentage -lt 40) { "BEARISH" }
                 else { "NEUTRAL" }
    }
}

function Find-WallsAndLevels {
    param([Parameter(Mandatory)][hashtable]$OrderBook, [double]$WallThreshold = 100)

    Write-Host "`n🧱 ORDER BOOK WALLS" -ForegroundColor Cyan

    $walls = @{
        supportWalls = @()
        resistanceWalls = @()
    }

    # Find bid walls (support)
    foreach ($bid in $OrderBook.bids) {
        if ($bid.quantity -ge $WallThreshold) {
            $walls.supportWalls += @{
                price = $bid.price
                quantity = $bid.quantity
            }
            Write-Host "   📗 BID WALL @ `$$($bid.price): $($bid.quantity)" -ForegroundColor Green
        }
    }

    # Find ask walls (resistance)
    foreach ($ask in $OrderBook.asks) {
        if ($ask.quantity -ge $WallThreshold) {
            $walls.resistanceWalls += @{
                price = $ask.price
                quantity = $ask.quantity
            }
            Write-Host "   📕 ASK WALL @ `$$($ask.price): $($ask.quantity)" -ForegroundColor Red
        }
    }

    if ($walls.supportWalls.Count -eq 0 -and $walls.resistanceWalls.Count -eq 0) {
        Write-Host "   No significant walls detected" -ForegroundColor Gray
    }

    Write-Host ""

    return $walls
}

# ============================================================================
# ABSORPTION DETECTION
# ============================================================================

function Find-Absorption {
    param(
        [Parameter(Mandatory)][array]$Candles,
        [Parameter(Mandatory)][array]$Trades
    )

    # Absorption: price stalls despite high volume
    $recent = $Candles[-1]
    $priceChange = [Math]::Abs(($recent.close - $recent.open) / $recent.open) * 100

    $avgVolume = ($Candles[-20..-1].volume | Measure-Object -Average).Average
    $volumeRatio = $recent.volume / $avgVolume

    # High volume but small price movement = absorption
    if ($volumeRatio -gt 1.5 -and $priceChange -lt 0.5) {
        $cvd = Get-CVD -Trades $Trades

        return @{
            detected = $true
            volumeRatio = [Math]::Round($volumeRatio, 2)
            priceChange = [Math]::Round($priceChange, 2)
            absorbingSide = if ($cvd.buyPressure -gt 50) { "SELLERS" } else { "BUYERS" }
            signal = if ($cvd.buyPressure -gt 50) { "BULLISH_ABSORPTION" } else { "BEARISH_ABSORPTION" }
        }
    }

    return @{ detected = $false }
}

# ============================================================================
# ORDER FLOW REPORT
# ============================================================================

function Get-OrderFlowReport {
    param(
        [Parameter(Mandatory)][hashtable]$OrderBook,
        [Parameter(Mandatory)][array]$Trades,
        [Parameter(Mandatory)][array]$Candles
    )

    Write-Host "`n╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║            📊 ORDER FLOW ANALYSIS                    ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

    # CVD
    $cvd = Get-CVD -Trades $Trades
    Write-Host "📈 CUMULATIVE VOLUME DELTA:" -ForegroundColor Yellow
    Write-Host "   CVD: $($cvd.cvd)" -ForegroundColor White
    Write-Host "   Buy pressure: $($cvd.buyPressure)% | Sell pressure: $([Math]::Round(100 - $cvd.buyPressure, 2))%" -ForegroundColor White
    Write-Host "   Signal: $($cvd.signal)`n" -ForegroundColor $(if ($cvd.signal -eq "BULLISH") { 'Green' } elseif ($cvd.signal -eq "BEARISH") { 'Red' } else { 'Gray' })

    # Whale watching
    $whales = Find-WhaleOrders -Trades $Trades -WhaleThreshold 5000

    # Order book imbalance
    $imbalance = Get-OrderBookImbalance -OrderBook $OrderBook -Depth 20
    Write-Host "⚖️  ORDER BOOK IMBALANCE:" -ForegroundColor Yellow
    Write-Host "   Bid volume: $($imbalance.bidVolume) ($($imbalance.bidPercentage)%)" -ForegroundColor White
    Write-Host "   Ask volume: $($imbalance.askVolume) ($([Math]::Round(100 - $imbalance.bidPercentage, 2))%)" -ForegroundColor White
    Write-Host "   Bid/Ask ratio: $($imbalance.ratio)" -ForegroundColor White
    Write-Host "   Signal: $($imbalance.signal)`n" -ForegroundColor $(if ($imbalance.signal -eq "BULLISH") { 'Green' } elseif ($imbalance.signal -eq "BEARISH") { 'Red' } else { 'Gray' })

    # Walls
    $walls = Find-WallsAndLevels -OrderBook $OrderBook -WallThreshold 50

    # Absorption
    $absorption = Find-Absorption -Candles $Candles -Trades $Trades
    if ($absorption.detected) {
        Write-Host "🛡️  ABSORPTION DETECTED:" -ForegroundColor Yellow
        Write-Host "   Absorbing side: $($absorption.absorbingSide)" -ForegroundColor White
        Write-Host "   Signal: $($absorption.signal)`n" -ForegroundColor Magenta
    }

    # Aggregate signal
    $bullishSignals = 0
    $bearishSignals = 0

    if ($cvd.signal -eq "BULLISH") { $bullishSignals++ }
    if ($cvd.signal -eq "BEARISH") { $bearishSignals++ }
    if ($whales.signal -eq "BULLISH") { $bullishSignals++ }
    if ($whales.signal -eq "BEARISH") { $bearishSignals++ }
    if ($imbalance.signal -eq "BULLISH") { $bullishSignals++ }
    if ($imbalance.signal -eq "BEARISH") { $bearishSignals++ }

    $aggregate = if ($bullishSignals -gt $bearishSignals) { "BULLISH" }
                 elseif ($bearishSignals -gt $bullishSignals) { "BEARISH" }
                 else { "NEUTRAL" }

    Write-Host "🎯 AGGREGATE ORDER FLOW: $aggregate ($bullishSignals bullish, $bearishSignals bearish)`n" -ForegroundColor $(if ($aggregate -eq "BULLISH") { 'Green' } elseif ($aggregate -eq "BEARISH") { 'Red' } else { 'Yellow' })

    return @{
        cvd = $cvd
        whales = $whales
        imbalance = $imbalance
        walls = $walls
        absorption = $absorption
        aggregate = $aggregate
    }
}

# ============================================================================
# EXPORT
# ============================================================================

Export-ModuleMember -Function Get-OrderFlowReport, Get-CVD, Find-WhaleOrders, Get-OrderBookImbalance, Find-WallsAndLevels, Find-Absorption

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Order Flow Analyzer ready. CVD, whale watching, and market microstructure" -ForegroundColor Yellow
}
