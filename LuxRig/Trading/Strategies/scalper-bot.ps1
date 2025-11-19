#Requires -Version 7.0
<#
.SYNOPSIS
    High-Frequency Scalping Bot - 100+ trades/day
.DESCRIPTION
    Automated scalping strategy:
    - 1-5 minute timeframe
    - 0.1-0.5% profit targets
    - Volume spike detection
    - Spread capture
    - Risk: 0.2% per trade
.NOTES
    Part of Phase 4: Trading Strategies
#>

$script:Config = @{
    Timeframe = "1m"
    ProfitTarget = 0.003  # 0.3%
    StopLoss = 0.002      # 0.2%
    MinVolume = 1.5       # 1.5x average volume
    MaxPositions = 5
    PositionSize = 0.02   # 2% of capital per trade
}

function Get-ScalpingSignal {
    param(
        [Parameter(Mandatory)][array]$Candles,
        [Parameter(Mandatory)][hashtable]$OrderBook
    )

    # Calculate indicators
    $ema9 = Get-EMA -Data $Candles -Period 9
    $ema21 = Get-EMA -Data $Candles -Period 21
    $rsi = Get-RSI -Data $Candles -Period 14
    $volume = $Candles[-1].volume
    $avgVolume = ($Candles[-20..-1].volume | Measure-Object -Average).Average

    # Volume spike detection
    $volumeSpike = $volume / $avgVolume

    # Spread analysis
    $spread = ($OrderBook.asks[0].price - $OrderBook.bids[0].price) / $OrderBook.bids[0].price

    # Signal generation
    if ($ema9 -gt $ema21 -and $rsi -lt 70 -and $volumeSpike -gt $script:Config.MinVolume -and $spread -lt 0.001) {
        return @{signal = "BUY"; confidence = 0.8; entry = $OrderBook.asks[0].price}
    }
    elseif ($ema9 -lt $ema21 -and $rsi -gt 30 -and $volumeSpike -gt $script:Config.MinVolume -and $spread -lt 0.001) {
        return @{signal = "SELL"; confidence = 0.8; entry = $OrderBook.bids[0].price}
    }

    return @{signal = "HOLD"; confidence = 0}
}

function Start-ScalpingBot {
    param(
        [Parameter(Mandatory)][string]$Exchange,
        [Parameter(Mandatory)][string]$Symbol,
        [double]$Capital = 1000
    )

    Write-Host "⚡ Starting scalping bot: $Symbol on $Exchange" -ForegroundColor Green
    Write-Host "   Capital: `$$Capital | Target: $($script:Config.ProfitTarget * 100)% | Stop: $($script:Config.StopLoss * 100)%" -ForegroundColor Cyan

    $positions = @()
    $trades = 0
    $wins = 0

    while ($true) {
        try {
            # Fetch data
            $candles = & "Get-${Exchange}Candles" -Symbol $Symbol -Granularity "60" -Limit 100
            $orderBook = & "Get-${Exchange}OrderBook" -Symbol $Symbol

            # Get signal
            $signal = Get-ScalpingSignal -Candles $candles -OrderBook $orderBook

            # Execute trades
            if ($signal.signal -eq "BUY" -and $positions.Count -lt $script:Config.MaxPositions) {
                $size = ($Capital * $script:Config.PositionSize) / $signal.entry

                $order = & "New-${Exchange}MarketOrder" -Symbol $Symbol -Side "BUY" -Size $size

                if ($order.orderId) {
                    $positions += @{
                        orderId = $order.orderId
                        entry = $signal.entry
                        size = $size
                        target = $signal.entry * (1 + $script:Config.ProfitTarget)
                        stop = $signal.entry * (1 - $script:Config.StopLoss)
                        openedAt = Get-Date
                    }

                    $trades++
                    Write-Host "   ✅ BUY: $size @ $$($signal.entry) | Target: $$($signal.entry * (1 + $script:Config.ProfitTarget))" -ForegroundColor Green
                }
            }

            # Manage positions
            foreach ($position in $positions) {
                $currentPrice = $candles[-1].close

                if ($currentPrice -ge $position.target) {
                    & "New-${Exchange}MarketOrder" -Symbol $Symbol -Side "SELL" -Size $position.size
                    $positions = $positions | Where-Object { $_.orderId -ne $position.orderId }
                    $wins++
                    Write-Host "   💰 PROFIT: Closed @ $$currentPrice (Target hit)" -ForegroundColor Green
                }
                elseif ($currentPrice -le $position.stop) {
                    & "New-${Exchange}MarketOrder" -Symbol $Symbol -Side "SELL" -Size $position.size
                    $positions = $positions | Where-Object { $_.orderId -ne $position.orderId }
                    Write-Host "   🛑 STOP: Closed @ $$currentPrice (Stop hit)" -ForegroundColor Red
                }
            }

            # Stats
            if ($trades -gt 0 -and $trades % 10 -eq 0) {
                $winRate = [Math]::Round(($wins / $trades) * 100, 1)
                Write-Host "`n📊 Stats: $trades trades | Win rate: $winRate% | Open positions: $($positions.Count)" -ForegroundColor Cyan
            }

            Start-Sleep -Seconds 5
        }
        catch {
            Write-Host "❌ Error: $_" -ForegroundColor Red
            Start-Sleep -Seconds 10
        }
    }
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

function Get-RSI {
    param([array]$Data, [int]$Period)
    $gains = @()
    $losses = @()
    for ($i = 1; $i -lt $Data.Count; $i++) {
        $change = $Data[$i].close - $Data[$i-1].close
        if ($change -gt 0) { $gains += $change; $losses += 0 }
        else { $gains += 0; $losses += [Math]::Abs($change) }
    }
    $avgGain = ($gains[-$Period..-1] | Measure-Object -Average).Average
    $avgLoss = ($losses[-$Period..-1] | Measure-Object -Average).Average
    if ($avgLoss -eq 0) { return 100 }
    $rs = $avgGain / $avgLoss
    return 100 - (100 / (1 + $rs))
}

Export-ModuleMember -Function Start-ScalpingBot

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Scalping Bot ready. Use Start-ScalpingBot -Exchange 'Coinbase' -Symbol 'BTC-USD'" -ForegroundColor Yellow
}
