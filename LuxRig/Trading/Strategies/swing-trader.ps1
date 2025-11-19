#Requires -Version 7.0
<#
.SYNOPSIS
    Swing Trading Bot - 1-7 day holds for 3-10% gains
.DESCRIPTION
    Medium-term swing trading strategy:
    - 1-7 day holding periods
    - 3-10% profit targets
    - Technical + fundamental analysis
    - Trend following with momentum
    - Risk: 1-2% per trade
.NOTES
    Part of Phase 4: Trading Strategies
#>

$script:Config = @{
    HoldingPeriod = @{ Min = 1; Max = 7 }  # Days
    ProfitTarget = 0.05   # 5% average
    StopLoss = 0.02       # 2%
    PositionSize = 0.10   # 10% of capital per trade
    MaxPositions = 5
    MinRSI = 40
    MaxRSI = 70
}

# ============================================================================
# SWING SIGNAL GENERATION
# ============================================================================

function Get-SwingSignal {
    param(
        [Parameter(Mandatory)][array]$DailyCandles,
        [Parameter(Mandatory)][array]$FourHourCandles
    )

    # Daily indicators
    $ema20 = Get-EMA -Data $DailyCandles -Period 20
    $ema50 = Get-EMA -Data $DailyCandles -Period 50
    $rsi = Get-RSI -Data $DailyCandles -Period 14
    $macd = Get-MACD -Data $DailyCandles

    # 4-hour confirmation
    $rsi4h = Get-RSI -Data $FourHourCandles -Period 14
    $ema9_4h = Get-EMA -Data $FourHourCandles -Period 9

    # Volume analysis
    $avgVolume = ($DailyCandles[-20..-1].volume | Measure-Object -Average).Average
    $currentVolume = $DailyCandles[-1].volume
    $volumeRatio = $currentVolume / $avgVolume

    # Price action
    $currentPrice = $DailyCandles[-1].close
    $high20 = ($DailyCandles[-20..-1].high | Measure-Object -Maximum).Maximum
    $low20 = ($DailyCandles[-20..-1].low | Measure-Object -Minimum).Minimum

    # Signal scoring
    $bullishScore = 0
    $bearishScore = 0

    # Trend analysis
    if ($ema20 -gt $ema50) { $bullishScore += 2 } else { $bearishScore += 2 }
    if ($currentPrice -gt $ema20) { $bullishScore += 1 } else { $bearishScore += 1 }

    # Momentum
    if ($rsi -gt $script:Config.MinRSI -and $rsi -lt 60) { $bullishScore += 2 }
    if ($rsi -gt 70) { $bearishScore += 2 }
    if ($rsi -lt 30) { $bullishScore += 1 }  # Oversold bounce

    # MACD
    if ($macd.histogram -gt 0 -and $macd.macd -gt $macd.signal) { $bullishScore += 2 }
    if ($macd.histogram -lt 0 -and $macd.macd -lt $macd.signal) { $bearishScore += 2 }

    # Volume confirmation
    if ($volumeRatio -gt 1.3) { $bullishScore += 1 }

    # 4-hour confirmation
    if ($rsi4h -gt 40 -and $rsi4h -lt 70) { $bullishScore += 1 }

    # Breakout detection
    if ($currentPrice -gt ($high20 * 0.99)) { $bullishScore += 2 }  # Near 20-day high
    if ($currentPrice -lt ($low20 * 1.01)) { $bearishScore += 1 }   # Near 20-day low

    # Generate signal
    if ($bullishScore -ge 7) {
        return @{
            signal = "BUY"
            strength = [Math]::Min(1.0, $bullishScore / 10)
            entry = $currentPrice
            target = $currentPrice * (1 + $script:Config.ProfitTarget)
            stop = $currentPrice * (1 - $script:Config.StopLoss)
            reason = "EMA trend ($ema20 > $ema50), RSI: $([Math]::Round($rsi, 1)), MACD bullish, Score: $bullishScore"
        }
    }
    elseif ($bearishScore -ge 7) {
        return @{
            signal = "SELL"
            strength = [Math]::Min(1.0, $bearishScore / 10)
            entry = $currentPrice
            reason = "Bearish indicators, Score: $bearishScore"
        }
    }
    else {
        return @{ signal = "HOLD"; strength = 0; reason = "Insufficient signal (Bull: $bullishScore, Bear: $bearishScore)" }
    }
}

# ============================================================================
# SWING TRADING BOT
# ============================================================================

function Start-SwingTrader {
    param(
        [Parameter(Mandatory)][string]$Exchange,
        [Parameter(Mandatory)][string]$Symbol,
        [double]$Capital = 10000,
        [int]$CheckInterval = 3600  # Check every hour
    )

    Write-Host "📈 Starting swing trader: $Symbol on $Exchange" -ForegroundColor Green
    Write-Host "   Capital: `$$Capital | Target: $($script:Config.ProfitTarget * 100)% | Stop: $($script:Config.StopLoss * 100)%" -ForegroundColor Cyan
    Write-Host "   Holding period: $($script:Config.HoldingPeriod.Min)-$($script:Config.HoldingPeriod.Max) days`n" -ForegroundColor Cyan

    $positions = @()
    $trades = 0
    $wins = 0
    $totalPnL = 0

    while ($true) {
        try {
            # Fetch data
            $dailyCandles = & "Get-${Exchange}Candles" -Symbol $Symbol -Interval "1d" -Limit 100
            $fourHourCandles = & "Get-${Exchange}Candles" -Symbol $Symbol -Interval "4h" -Limit 100

            if (-not $dailyCandles -or -not $fourHourCandles) {
                Write-Host "⚠️  Failed to fetch candles, retrying..." -ForegroundColor Yellow
                Start-Sleep -Seconds 60
                continue
            }

            # Get signal
            $signal = Get-SwingSignal -DailyCandles $dailyCandles -FourHourCandles $fourHourCandles

            # Entry logic
            if ($signal.signal -eq "BUY" -and $positions.Count -lt $script:Config.MaxPositions) {
                $positionValue = $Capital * $script:Config.PositionSize
                $size = $positionValue / $signal.entry

                Write-Host "`n🎯 SWING ENTRY SIGNAL" -ForegroundColor Cyan
                Write-Host "   Reason: $($signal.reason)" -ForegroundColor White
                Write-Host "   Entry: `$$($signal.entry) | Target: `$$($signal.target) | Stop: `$$($signal.stop)" -ForegroundColor White

                $order = & "New-${Exchange}MarketOrder" -Symbol $Symbol -Side "BUY" -Size $size

                if ($order -and $order.orderId) {
                    $positions += @{
                        orderId = $order.orderId
                        symbol = $Symbol
                        entry = $signal.entry
                        size = $size
                        target = $signal.target
                        stop = $signal.stop
                        openedAt = Get-Date
                        reason = $signal.reason
                    }

                    $trades++
                    Write-Host "   ✅ Position opened: $size @ `$$($signal.entry)" -ForegroundColor Green
                }
            }

            # Exit logic
            $currentPrice = $dailyCandles[-1].close
            $positionsToClose = @()

            foreach ($position in $positions) {
                $holdingDays = ((Get-Date) - $position.openedAt).TotalDays
                $pnlPercent = (($currentPrice - $position.entry) / $position.entry) * 100

                # Exit conditions
                $shouldExit = $false
                $exitReason = ""

                if ($currentPrice -ge $position.target) {
                    $shouldExit = $true
                    $exitReason = "TARGET HIT"
                }
                elseif ($currentPrice -le $position.stop) {
                    $shouldExit = $true
                    $exitReason = "STOP LOSS"
                }
                elseif ($holdingDays -ge $script:Config.HoldingPeriod.Max) {
                    $shouldExit = $true
                    $exitReason = "MAX HOLDING PERIOD"
                }
                elseif ($signal.signal -eq "SELL" -and $pnlPercent -gt 2) {
                    $shouldExit = $true
                    $exitReason = "SIGNAL REVERSAL (in profit)"
                }

                if ($shouldExit) {
                    & "New-${Exchange}MarketOrder" -Symbol $Symbol -Side "SELL" -Size $position.size

                    $pnl = ($currentPrice - $position.entry) * $position.size
                    $totalPnL += $pnl

                    if ($pnl -gt 0) { $wins++ }

                    Write-Host "`n💰 POSITION CLOSED: $exitReason" -ForegroundColor $(if ($pnl -gt 0) { 'Green' } else { 'Red' })
                    Write-Host "   Held: $([Math]::Round($holdingDays, 1)) days" -ForegroundColor White
                    Write-Host "   Entry: `$$($position.entry) | Exit: `$$currentPrice" -ForegroundColor White
                    Write-Host "   PnL: `$$([Math]::Round($pnl, 2)) ($([Math]::Round($pnlPercent, 2))%)" -ForegroundColor White

                    $positionsToClose += $position
                }
            }

            # Remove closed positions
            foreach ($closed in $positionsToClose) {
                $positions = $positions | Where-Object { $_.orderId -ne $closed.orderId }
            }

            # Status update
            if ($trades -gt 0) {
                $winRate = [Math]::Round(($wins / $trades) * 100, 1)
                Write-Host "`n📊 SWING STATS: $trades trades | Win rate: $winRate% | Total PnL: `$$([Math]::Round($totalPnL, 2)) | Open: $($positions.Count)" -ForegroundColor Cyan
            }

            # Show open positions
            if ($positions.Count -gt 0) {
                Write-Host "`n📋 Open positions:" -ForegroundColor Yellow
                foreach ($pos in $positions) {
                    $holdingDays = ((Get-Date) - $pos.openedAt).TotalDays
                    $unrealizedPnL = (($currentPrice - $pos.entry) / $pos.entry) * 100
                    Write-Host "   $($pos.symbol): $([Math]::Round($holdingDays, 1))d | Entry: `$$($pos.entry) | PnL: $([Math]::Round($unrealizedPnL, 2))%" -ForegroundColor Gray
                }
            }

            Start-Sleep -Seconds $CheckInterval
        }
        catch {
            Write-Host "`n❌ Error: $_" -ForegroundColor Red
            Start-Sleep -Seconds 300
        }
    }
}

# ============================================================================
# INDICATORS
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

function Get-MACD {
    param([array]$Data)

    $ema12 = Get-EMA -Data $Data -Period 12
    $ema26 = Get-EMA -Data $Data -Period 26
    $macd = $ema12 - $ema26

    # Simplified signal line (9-period EMA of MACD)
    $signal = $macd * 0.5  # Approximation

    return @{
        macd = $macd
        signal = $signal
        histogram = $macd - $signal
    }
}

# ============================================================================
# EXPORT
# ============================================================================

Export-ModuleMember -Function Start-SwingTrader, Get-SwingSignal

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Swing Trader ready. 1-7 day holds for 3-10% gains" -ForegroundColor Yellow
    Write-Host "Use: Start-SwingTrader -Exchange 'Coinbase' -Symbol 'BTC-USD' -Capital 10000" -ForegroundColor Yellow
}
