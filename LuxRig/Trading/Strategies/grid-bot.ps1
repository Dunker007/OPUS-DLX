#Requires -Version 7.0
<#
.SYNOPSIS
    Grid Trading Bot - Range automation
.DESCRIPTION
    Automated grid trading:
    - Buy low, sell high in sideways markets
    - Dynamic grid adjustment
    - Multiple simultaneous grids
    - Geometric vs arithmetic grids
.NOTES
    Part of Phase 4: Trading Strategies
#>

$script:Config = @{
    GridLevels = 10
    RangePercent = 0.05  # 5% range
    ProfitPerGrid = 0.01 # 1% per grid
}

function New-GridStrategy {
    param(
        [Parameter(Mandatory)][double]$LowerBound,
        [Parameter(Mandatory)][double]$UpperBound,
        [int]$Levels = 10,
        [double]$Capital = 1000,
        [ValidateSet('Arithmetic','Geometric')][string]$Type = 'Arithmetic'
    )

    Write-Host "📊 Creating grid: $$LowerBound - $$UpperBound ($Levels levels)" -ForegroundColor Cyan

    $grids = @()
    $step = ($UpperBound - $LowerBound) / $Levels

    for ($i = 0; $i -lt $Levels; $i++) {
        if ($Type -eq 'Arithmetic') {
            $buyPrice = $LowerBound + ($step * $i)
            $sellPrice = $LowerBound + ($step * ($i + 1))
        }
        else {
            # Geometric grid
            $ratio = [Math]::Pow(($UpperBound / $LowerBound), (1.0 / $Levels))
            $buyPrice = $LowerBound * [Math]::Pow($ratio, $i)
            $sellPrice = $buyPrice * $ratio
        }

        $grids += @{
            level = $i
            buyPrice = [Math]::Round($buyPrice, 2)
            sellPrice = [Math]::Round($sellPrice, 2)
            size = [Math]::Round(($Capital / $Levels) / $buyPrice, 6)
            buyOrderId = $null
            sellOrderId = $null
            status = 'pending'
        }
    }

    return $grids
}

function Start-GridBot {
    param(
        [Parameter(Mandatory)][string]$Exchange,
        [Parameter(Mandatory)][string]$Symbol,
        [double]$Capital = 1000,
        [double]$RangePercent = 0.05
    )

    Write-Host "🎯 Starting grid bot: $Symbol" -ForegroundColor Green

    # Get current price
    $currentPrice = (& "Get-${Exchange}Price" -Symbol $Symbol).price
    $lowerBound = $currentPrice * (1 - $RangePercent)
    $upperBound = $currentPrice * (1 + $RangePercent)

    # Create grid
    $grids = New-GridStrategy -LowerBound $lowerBound -UpperBound $upperBound -Capital $Capital -Levels $script:Config.GridLevels

    Write-Host "   Grid range: $$lowerBound - $$upperBound" -ForegroundColor Cyan
    Write-Host "   Levels: $($grids.Count)" -ForegroundColor Cyan

    # Place initial buy orders
    foreach ($grid in $grids) {
        try {
            $order = & "New-${Exchange}LimitOrder" -Symbol $Symbol -Side "BUY" -Size $grid.size -Price $grid.buyPrice -PostOnly

            $grid.buyOrderId = $order.orderId
            $grid.status = 'buy_placed'

            Write-Host "   📝 Buy order: $($grid.size) @ $$($grid.buyPrice)" -ForegroundColor Gray
        }
        catch {
            Write-Host "   ❌ Failed to place buy order at $$($grid.buyPrice)" -ForegroundColor Red
        }
    }

    # Monitor and manage grid
    while ($true) {
        Start-Sleep -Seconds 10

        foreach ($grid in $grids) {
            try {
                # Check buy order
                if ($grid.status -eq 'buy_placed' -and $grid.buyOrderId) {
                    $buyOrder = & "Get-${Exchange}Order" -OrderId $grid.buyOrderId

                    if ($buyOrder.status -eq 'FILLED') {
                        # Place sell order
                        $sellOrder = & "New-${Exchange}LimitOrder" -Symbol $Symbol -Side "SELL" -Size $grid.size -Price $grid.sellPrice -PostOnly

                        $grid.sellOrderId = $sellOrder.orderId
                        $grid.status = 'sell_placed'

                        Write-Host "   ✅ Buy filled @ $$($grid.buyPrice) | Sell placed @ $$($grid.sellPrice)" -ForegroundColor Green
                    }
                }

                # Check sell order
                if ($grid.status -eq 'sell_placed' -and $grid.sellOrderId) {
                    $sellOrder = & "Get-${Exchange}Order" -OrderId $grid.sellOrderId

                    if ($sellOrder.status -eq 'FILLED') {
                        # Replace buy order
                        $buyOrder = & "New-${Exchange}LimitOrder" -Symbol $Symbol -Side "BUY" -Size $grid.size -Price $grid.buyPrice -PostOnly

                        $grid.buyOrderId = $buyOrder.orderId
                        $grid.sellOrderId = $null
                        $grid.status = 'buy_placed'

                        Write-Host "   💰 Sell filled @ $$($grid.sellPrice) | Profit: $$([Math]::Round(($grid.sellPrice - $grid.buyPrice) * $grid.size, 2))" -ForegroundColor Green
                    }
                }
            }
            catch {
                Write-Host "   ⚠️  Error managing grid level $($grid.level): $_" -ForegroundColor Yellow
            }
        }
    }
}

Export-ModuleMember -Function Start-GridBot, New-GridStrategy

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Grid Bot ready. Use Start-GridBot -Exchange 'Coinbase' -Symbol 'BTC-USD'" -ForegroundColor Yellow
}
