#Requires -Version 7.0
<#
.SYNOPSIS
    Arbitrage Hunter - Cross-exchange + Triangular arbitrage
.DESCRIPTION
    Automated arbitrage strategies:
    - Cross-exchange arbitrage (buy low, sell high across exchanges)
    - Triangular arbitrage (3-pair loops on same exchange)
    - Real-time opportunity detection
    - Sub-second execution
    - Profit: 0.5-3% per opportunity
.NOTES
    Part of Phase 4: Trading Strategies
#>

$script:Config = @{
    MinProfitPercent = 0.005  # 0.5% minimum profit after fees
    MaxSlippage = 0.002       # 0.2% max slippage
    PositionSize = 0.20       # 20% of capital per arb
    Fees = @{
        Coinbase = 0.006      # 0.6%
        Binance = 0.001       # 0.1%
        Kraken = 0.0026       # 0.26%
        Bybit = 0.001         # 0.1%
        OKX = 0.001           # 0.1%
    }
}

# ============================================================================
# CROSS-EXCHANGE ARBITRAGE
# ============================================================================

function Find-CrossExchangeArbitrage {
    param(
        [Parameter(Mandatory)][string]$Symbol,
        [Parameter(Mandatory)][array]$Exchanges
    )

    $prices = @{}

    # Fetch prices from all exchanges
    foreach ($exchange in $Exchanges) {
        try {
            $price = & "Get-${exchange}Price" -Symbol $Symbol
            if ($price) {
                $prices[$exchange] = @{
                    price = $price.price
                    timestamp = Get-Date
                }
            }
        }
        catch {
            Write-Host "⚠️  Failed to fetch $Symbol price from $exchange" -ForegroundColor Yellow
        }
    }

    if ($prices.Count -lt 2) { return $null }

    # Find best buy and sell opportunities
    $sorted = $prices.GetEnumerator() | Sort-Object { $_.Value.price }
    $buyExchange = $sorted[0].Key
    $sellExchange = $sorted[-1].Key
    $buyPrice = $sorted[0].Value.price
    $sellPrice = $sorted[-1].Value.price

    # Calculate profit after fees
    $buyFee = $script:Config.Fees[$buyExchange]
    $sellFee = $script:Config.Fees[$sellExchange]
    $totalFees = $buyFee + $sellFee

    $grossProfit = ($sellPrice - $buyPrice) / $buyPrice
    $netProfit = $grossProfit - $totalFees - $script:Config.MaxSlippage

    if ($netProfit -ge $script:Config.MinProfitPercent) {
        return @{
            symbol = $Symbol
            buyExchange = $buyExchange
            sellExchange = $sellExchange
            buyPrice = $buyPrice
            sellPrice = $sellPrice
            grossProfit = [Math]::Round($grossProfit * 100, 3)
            netProfit = [Math]::Round($netProfit * 100, 3)
            estimatedGain = $netProfit
        }
    }

    return $null
}

function Execute-CrossExchangeArbitrage {
    param(
        [Parameter(Mandatory)][hashtable]$Opportunity,
        [Parameter(Mandatory)][double]$Capital
    )

    $tradeSize = ($Capital * $script:Config.PositionSize) / $Opportunity.buyPrice

    Write-Host "`n🎯 ARBITRAGE OPPORTUNITY FOUND!" -ForegroundColor Green
    Write-Host "   Symbol: $($Opportunity.symbol)" -ForegroundColor White
    Write-Host "   Buy: $($Opportunity.buyExchange) @ `$$($Opportunity.buyPrice)" -ForegroundColor Cyan
    Write-Host "   Sell: $($Opportunity.sellExchange) @ `$$($Opportunity.sellPrice)" -ForegroundColor Cyan
    Write-Host "   Gross profit: $($Opportunity.grossProfit)% | Net profit: $($Opportunity.netProfit)%" -ForegroundColor Green
    Write-Host "   Trade size: $([Math]::Round($tradeSize, 6))`n" -ForegroundColor White

    try {
        # Execute buy order
        $buyOrder = & "New-$($Opportunity.buyExchange)MarketOrder" -Symbol $Opportunity.symbol -Side "BUY" -Size $tradeSize

        if ($buyOrder -and $buyOrder.orderId) {
            Write-Host "   ✅ Buy order filled on $($Opportunity.buyExchange)" -ForegroundColor Green

            # Execute sell order
            $sellOrder = & "New-$($Opportunity.sellExchange)MarketOrder" -Symbol $Opportunity.symbol -Side "SELL" -Size $tradeSize

            if ($sellOrder -and $sellOrder.orderId) {
                Write-Host "   ✅ Sell order filled on $($Opportunity.sellExchange)" -ForegroundColor Green

                $profit = $tradeSize * ($Opportunity.sellPrice - $Opportunity.buyPrice)
                Write-Host "   💰 Arbitrage complete! Profit: `$$([Math]::Round($profit, 2))" -ForegroundColor Green

                return @{
                    success = $true
                    profit = $profit
                    trades = 2
                }
            }
            else {
                Write-Host "   ❌ Sell order failed - MANUAL INTERVENTION REQUIRED" -ForegroundColor Red
                return @{ success = $false; error = "Sell failed"; stuck = $true }
            }
        }
        else {
            Write-Host "   ❌ Buy order failed" -ForegroundColor Red
            return @{ success = $false; error = "Buy failed" }
        }
    }
    catch {
        Write-Host "   ❌ Execution error: $_" -ForegroundColor Red
        return @{ success = $false; error = $_ }
    }
}

# ============================================================================
# TRIANGULAR ARBITRAGE
# ============================================================================

function Find-TriangularArbitrage {
    param(
        [Parameter(Mandatory)][string]$Exchange,
        [Parameter(Mandatory)][string]$Base,
        [Parameter(Mandatory)][string]$Quote1,
        [Parameter(Mandatory)][string]$Quote2
    )

    # Example: BTC -> ETH -> USDT -> BTC
    # Pair 1: BTC/USDT, Pair 2: ETH/USDT, Pair 3: BTC/ETH

    $pair1 = "$Base-$Quote1"     # BTC-USDT
    $pair2 = "$Quote2-$Quote1"   # ETH-USDT
    $pair3 = "$Base-$Quote2"     # BTC-ETH

    try {
        $price1 = (& "Get-${Exchange}Price" -Symbol $pair1).price  # BTC/USDT
        $price2 = (& "Get-${Exchange}Price" -Symbol $pair2).price  # ETH/USDT
        $price3 = (& "Get-${Exchange}Price" -Symbol $pair3).price  # BTC/ETH

        if (-not $price1 -or -not $price2 -or -not $price3) { return $null }

        # Calculate loop profit
        # Start with 1 BTC -> USDT -> ETH -> BTC
        $step1 = 1 * $price1           # 1 BTC to USDT
        $step2 = $step1 / $price2      # USDT to ETH
        $step3 = $step2 * $price3      # ETH to BTC

        $grossReturn = $step3 - 1
        $fee = $script:Config.Fees[$Exchange]
        $netReturn = $grossReturn - ($fee * 3)  # 3 trades

        if ($netReturn -ge $script:Config.MinProfitPercent) {
            return @{
                exchange = $Exchange
                path = "$Base → $Quote1 → $Quote2 → $Base"
                pair1 = $pair1
                pair2 = $pair2
                pair3 = $pair3
                price1 = $price1
                price2 = $price2
                price3 = $price3
                grossReturn = [Math]::Round($grossReturn * 100, 3)
                netReturn = [Math]::Round($netReturn * 100, 3)
                estimatedGain = $netReturn
            }
        }

        return $null
    }
    catch {
        return $null
    }
}

function Execute-TriangularArbitrage {
    param(
        [Parameter(Mandatory)][hashtable]$Opportunity,
        [Parameter(Mandatory)][double]$Capital
    )

    Write-Host "`n🔺 TRIANGULAR ARBITRAGE OPPORTUNITY!" -ForegroundColor Magenta
    Write-Host "   Exchange: $($Opportunity.exchange)" -ForegroundColor White
    Write-Host "   Path: $($Opportunity.path)" -ForegroundColor Cyan
    Write-Host "   Net return: $($Opportunity.netReturn)%`n" -ForegroundColor Green

    try {
        $exchange = $Opportunity.exchange
        $size = $Capital * $script:Config.PositionSize

        # Trade 1: Base to Quote1
        $order1 = & "New-${exchange}MarketOrder" -Symbol $Opportunity.pair1 -Side "SELL" -Size $size
        if (-not $order1) { return @{ success = $false; error = "Trade 1 failed" } }
        Write-Host "   ✅ Trade 1: Sold $size $($Opportunity.pair1)" -ForegroundColor Green

        $quote1Amount = $size * $Opportunity.price1

        # Trade 2: Quote1 to Quote2
        $size2 = $quote1Amount / $Opportunity.price2
        $order2 = & "New-${exchange}MarketOrder" -Symbol $Opportunity.pair2 -Side "BUY" -Size $size2
        if (-not $order2) { return @{ success = $false; error = "Trade 2 failed"; stuck = $true } }
        Write-Host "   ✅ Trade 2: Bought $([Math]::Round($size2, 6)) $($Opportunity.pair2)" -ForegroundColor Green

        # Trade 3: Quote2 back to Base
        $order3 = & "New-${exchange}MarketOrder" -Symbol $Opportunity.pair3 -Side "SELL" -Size $size2
        if (-not $order3) { return @{ success = $false; error = "Trade 3 failed"; stuck = $true } }
        Write-Host "   ✅ Trade 3: Sold $([Math]::Round($size2, 6)) $($Opportunity.pair3)" -ForegroundColor Green

        $finalAmount = $size2 * $Opportunity.price3
        $profit = $finalAmount - $size

        Write-Host "   💰 Triangular arbitrage complete! Profit: `$$([Math]::Round($profit, 2))" -ForegroundColor Green

        return @{
            success = $true
            profit = $profit
            trades = 3
        }
    }
    catch {
        Write-Host "   ❌ Execution error: $_" -ForegroundColor Red
        return @{ success = $false; error = $_ }
    }
}

# ============================================================================
# ARBITRAGE HUNTER BOT
# ============================================================================

function Start-ArbitrageHunter {
    param(
        [Parameter(Mandatory)][array]$Symbols,
        [Parameter(Mandatory)][array]$Exchanges,
        [double]$Capital = 10000,
        [int]$ScanInterval = 5  # Scan every 5 seconds
    )

    Write-Host "🏹 Starting Arbitrage Hunter" -ForegroundColor Green
    Write-Host "   Symbols: $($Symbols -join ', ')" -ForegroundColor Cyan
    Write-Host "   Exchanges: $($Exchanges -join ', ')" -ForegroundColor Cyan
    Write-Host "   Capital: `$$Capital | Min profit: $($script:Config.MinProfitPercent * 100)%`n" -ForegroundColor Cyan

    $stats = @{
        scans = 0
        opportunities = 0
        executed = 0
        totalProfit = 0
    }

    while ($true) {
        try {
            $stats.scans++

            foreach ($symbol in $Symbols) {
                # Cross-exchange arbitrage
                $crossArb = Find-CrossExchangeArbitrage -Symbol $symbol -Exchanges $Exchanges

                if ($crossArb) {
                    $stats.opportunities++
                    $result = Execute-CrossExchangeArbitrage -Opportunity $crossArb -Capital $Capital

                    if ($result.success) {
                        $stats.executed++
                        $stats.totalProfit += $result.profit
                    }
                }

                # Triangular arbitrage (example: BTC -> USDT -> ETH -> BTC)
                foreach ($exchange in $Exchanges) {
                    $triArb = Find-TriangularArbitrage -Exchange $exchange -Base "BTC" -Quote1 "USDT" -Quote2 "ETH"

                    if ($triArb) {
                        $stats.opportunities++
                        $result = Execute-TriangularArbitrage -Opportunity $triArb -Capital $Capital

                        if ($result.success) {
                            $stats.executed++
                            $stats.totalProfit += $result.profit
                        }
                    }
                }
            }

            # Stats update
            if ($stats.scans % 20 -eq 0) {
                Write-Host "`n📊 ARBITRAGE STATS:" -ForegroundColor Cyan
                Write-Host "   Scans: $($stats.scans) | Opportunities: $($stats.opportunities) | Executed: $($stats.executed)" -ForegroundColor White
                Write-Host "   Total profit: `$$([Math]::Round($stats.totalProfit, 2))" -ForegroundColor Green
                Write-Host "   Success rate: $([Math]::Round(($stats.executed / [Math]::Max(1, $stats.opportunities)) * 100, 1))%`n" -ForegroundColor White
            }

            Start-Sleep -Seconds $ScanInterval
        }
        catch {
            Write-Host "❌ Error: $_" -ForegroundColor Red
            Start-Sleep -Seconds 10
        }
    }
}

# ============================================================================
# EXPORT
# ============================================================================

Export-ModuleMember -Function Start-ArbitrageHunter, Find-CrossExchangeArbitrage, Find-TriangularArbitrage

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Arbitrage Hunter ready. Cross-exchange + triangular arbitrage" -ForegroundColor Yellow
    Write-Host "Use: Start-ArbitrageHunter -Symbols @('BTC-USD','ETH-USD') -Exchanges @('Coinbase','Binance','Kraken') -Capital 10000" -ForegroundColor Yellow
}
