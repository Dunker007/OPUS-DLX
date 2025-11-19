#Requires -Version 7.0
<#
.SYNOPSIS
    Advanced DCA Bot - Smart dollar-cost averaging with dip buying
.DESCRIPTION
    Intelligent DCA strategy:
    - Regular scheduled buys
    - Accelerated buying on dips
    - RSI-based position sizing
    - Trend-aware DCA
    - Auto-compounding
    - Take-profit ladders
.NOTES
    Part of Phase 4: Trading Strategies
#>

$script:Config = @{
    BaseAmount = 100          # Base buy amount ($)
    Schedule = "Daily"        # Daily, Weekly, BiWeekly, Monthly
    DipThreshold = -0.05      # Buy more on 5%+ dips
    DipMultiplier = 2.0       # 2x on dips
    MaxBuyAmount = 500        # Max single purchase
    TakeProfitLevels = @(0.20, 0.50, 1.00)  # 20%, 50%, 100% gains
    TakeProfitPercent = @(0.25, 0.25, 0.50)  # Sell 25%, 25%, 50%
}

# ============================================================================
# DCA STRATEGY
# ============================================================================

function Get-DCABuyAmount {
    param(
        [Parameter(Mandatory)][double]$CurrentPrice,
        [Parameter(Mandatory)][double]$AveragePrice,
        [Parameter(Mandatory)][double]$RSI,
        [double]$BaseAmount = 100
    )

    $priceChange = ($CurrentPrice - $AveragePrice) / $AveragePrice
    $buyAmount = $BaseAmount

    # Dip buying: increase amount on price drops
    if ($priceChange -le $script:Config.DipThreshold) {
        $buyAmount *= $script:Config.DipMultiplier
        Write-Host "   🎯 DIP DETECTED: $([Math]::Round($priceChange * 100, 1))% | Buying ${buyAmount}x" -ForegroundColor Yellow
    }

    # RSI-based adjustment
    if ($RSI -lt 30) {
        # Oversold - buy more
        $buyAmount *= 1.5
        Write-Host "   📉 RSI OVERSOLD ($([Math]::Round($RSI, 1))): Increased buy amount" -ForegroundColor Cyan
    }
    elseif ($RSI -gt 70) {
        # Overbought - buy less
        $buyAmount *= 0.5
        Write-Host "   📈 RSI OVERBOUGHT ($([Math]::Round($RSI, 1))): Reduced buy amount" -ForegroundColor Magenta
    }

    # Cap at max buy amount
    $buyAmount = [Math]::Min($buyAmount, $script:Config.MaxBuyAmount)

    return [Math]::Round($buyAmount, 2)
}

function Get-NextDCATime {
    param([string]$Schedule)

    $now = Get-Date

    switch ($Schedule) {
        "Daily" { return $now.AddDays(1).Date.AddHours(9) }  # 9 AM next day
        "Weekly" {
            $daysUntilMonday = (8 - [int]$now.DayOfWeek) % 7
            if ($daysUntilMonday -eq 0) { $daysUntilMonday = 7 }
            return $now.AddDays($daysUntilMonday).Date.AddHours(9)
        }
        "BiWeekly" { return $now.AddDays(14).Date.AddHours(9) }
        "Monthly" {
            $nextMonth = $now.AddMonths(1)
            return (Get-Date -Year $nextMonth.Year -Month $nextMonth.Month -Day 1).AddHours(9)
        }
        default { return $now.AddDays(1).Date.AddHours(9) }
    }
}

# ============================================================================
# DCA BOT
# ============================================================================

function Start-DCABot {
    param(
        [Parameter(Mandatory)][string]$Exchange,
        [Parameter(Mandatory)][string]$Symbol,
        [double]$BaseAmount = 100,
        [ValidateSet("Daily","Weekly","BiWeekly","Monthly")][string]$Schedule = "Daily",
        [switch]$AutoCompound
    )

    Write-Host "💎 Starting DCA bot: $Symbol on $Exchange" -ForegroundColor Green
    Write-Host "   Schedule: $Schedule | Base amount: `$$BaseAmount | Dip buying: ENABLED" -ForegroundColor Cyan
    Write-Host "   Auto-compound: $(if ($AutoCompound) { 'ON' } else { 'OFF' })`n" -ForegroundColor Cyan

    $script:Config.BaseAmount = $BaseAmount
    $script:Config.Schedule = $Schedule

    $holdings = @{
        totalInvested = 0
        totalAmount = 0
        averagePrice = 0
        purchases = @()
        sells = @()
    }

    $nextBuyTime = Get-NextDCATime -Schedule $Schedule

    while ($true) {
        try {
            $now = Get-Date

            # Fetch market data
            $price = & "Get-${Exchange}Price" -Symbol $Symbol
            $candles = & "Get-${Exchange}Candles" -Symbol $Symbol -Interval "1d" -Limit 30

            if (-not $price -or -not $candles) {
                Write-Host "⚠️  Failed to fetch data, retrying..." -ForegroundColor Yellow
                Start-Sleep -Seconds 60
                continue
            }

            $currentPrice = $price.price
            $rsi = Get-RSI -Data $candles -Period 14

            # Check for scheduled buy
            if ($now -ge $nextBuyTime) {
                # Calculate buy amount
                $avgPrice = if ($holdings.averagePrice -gt 0) { $holdings.averagePrice } else { $currentPrice }
                $buyAmount = Get-DCABuyAmount -CurrentPrice $currentPrice -AveragePrice $avgPrice -RSI $rsi -BaseAmount $script:Config.BaseAmount

                $size = $buyAmount / $currentPrice

                Write-Host "`n🔔 SCHEDULED DCA BUY" -ForegroundColor Cyan
                Write-Host "   Amount: `$$buyAmount | Size: $([Math]::Round($size, 8)) | Price: `$$currentPrice" -ForegroundColor White
                Write-Host "   RSI: $([Math]::Round($rsi, 1)) | Avg entry: `$$([Math]::Round($avgPrice, 2))" -ForegroundColor White

                # Execute buy
                $order = & "New-${Exchange}MarketOrder" -Symbol $Symbol -Side "BUY" -Size $size

                if ($order -and $order.orderId) {
                    # Update holdings
                    $holdings.totalInvested += $buyAmount
                    $holdings.totalAmount += $size
                    $holdings.averagePrice = $holdings.totalInvested / $holdings.totalAmount

                    $holdings.purchases += @{
                        timestamp = $now
                        price = $currentPrice
                        amount = $buyAmount
                        size = $size
                    }

                    Write-Host "   ✅ Purchase complete | Total invested: `$$([Math]::Round($holdings.totalInvested, 2))" -ForegroundColor Green
                    Write-Host "   Average price: `$$([Math]::Round($holdings.averagePrice, 2)) | Total holdings: $([Math]::Round($holdings.totalAmount, 6))" -ForegroundColor Green
                }

                # Schedule next buy
                $nextBuyTime = Get-NextDCATime -Schedule $Schedule
                Write-Host "   Next buy: $($nextBuyTime.ToString('yyyy-MM-dd HH:mm'))" -ForegroundColor Gray
            }

            # Check take-profit levels
            if ($holdings.averagePrice -gt 0 -and $holdings.totalAmount -gt 0) {
                $currentValue = $holdings.totalAmount * $currentPrice
                $pnlPercent = (($currentPrice - $holdings.averagePrice) / $holdings.averagePrice) * 100

                for ($i = 0; $i -lt $script:Config.TakeProfitLevels.Count; $i++) {
                    $tpLevel = $script:Config.TakeProfitLevels[$i] * 100
                    $tpPercent = $script:Config.TakeProfitPercent[$i]

                    if ($pnlPercent -ge $tpLevel) {
                        $sellSize = $holdings.totalAmount * $tpPercent

                        Write-Host "`n💰 TAKE PROFIT TRIGGERED: $tpLevel%" -ForegroundColor Green
                        Write-Host "   Selling $([Math]::Round($tpPercent * 100, 0))% of position ($([Math]::Round($sellSize, 6)))" -ForegroundColor White

                        $sellOrder = & "New-${Exchange}MarketOrder" -Symbol $Symbol -Side "SELL" -Size $sellSize

                        if ($sellOrder -and $sellOrder.orderId) {
                            $sellValue = $sellSize * $currentPrice
                            $profit = $sellValue - ($sellSize * $holdings.averagePrice)

                            $holdings.totalAmount -= $sellSize
                            $holdings.sells += @{
                                timestamp = $now
                                price = $currentPrice
                                size = $sellSize
                                profit = $profit
                            }

                            Write-Host "   ✅ Sold for `$$([Math]::Round($sellValue, 2)) | Profit: `$$([Math]::Round($profit, 2))" -ForegroundColor Green

                            # Remove this TP level
                            $script:Config.TakeProfitLevels = $script:Config.TakeProfitLevels | Where-Object { $_ -ne ($tpLevel / 100) }
                            $script:Config.TakeProfitPercent = $script:Config.TakeProfitPercent[0..($i-1)] + $script:Config.TakeProfitPercent[($i+1)..($script:Config.TakeProfitPercent.Count-1)]

                            # Auto-compound: use profit for next buy
                            if ($AutoCompound) {
                                $script:Config.BaseAmount += ($profit * 0.5)  # Add 50% of profit to base amount
                                Write-Host "   📈 Auto-compound: New base amount = `$$([Math]::Round($script:Config.BaseAmount, 2))" -ForegroundColor Cyan
                            }
                        }

                        break
                    }
                }

                # Portfolio status
                Write-Host "`n📊 DCA PORTFOLIO STATUS:" -ForegroundColor Cyan
                Write-Host "   Holdings: $([Math]::Round($holdings.totalAmount, 6)) $Symbol" -ForegroundColor White
                Write-Host "   Invested: `$$([Math]::Round($holdings.totalInvested, 2)) | Current value: `$$([Math]::Round($currentValue, 2))" -ForegroundColor White
                Write-Host "   Average price: `$$([Math]::Round($holdings.averagePrice, 2)) | Current price: `$$currentPrice" -ForegroundColor White
                Write-Host "   PnL: `$$([Math]::Round($currentValue - $holdings.totalInvested, 2)) ($([Math]::Round($pnlPercent, 2))%)" -ForegroundColor $(if ($pnlPercent -gt 0) { 'Green' } else { 'Red' })
                Write-Host "   Total purchases: $($holdings.purchases.Count) | Total sells: $($holdings.sells.Count)" -ForegroundColor White
                Write-Host "   Next buy: $($nextBuyTime.ToString('yyyy-MM-dd HH:mm'))`n" -ForegroundColor Gray
            }

            # Sleep until next check (every 5 minutes)
            Start-Sleep -Seconds 300
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

# ============================================================================
# EXPORT
# ============================================================================

Export-ModuleMember -Function Start-DCABot

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Advanced DCA Bot ready. Smart dollar-cost averaging with dip buying" -ForegroundColor Yellow
    Write-Host "Use: Start-DCABot -Exchange 'Coinbase' -Symbol 'BTC-USD' -BaseAmount 100 -Schedule 'Daily' -AutoCompound" -ForegroundColor Yellow
}
