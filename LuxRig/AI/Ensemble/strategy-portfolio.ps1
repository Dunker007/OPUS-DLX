#Requires -Version 7.0
<#
.SYNOPSIS
    Multi-Strategy Portfolio Manager
.DESCRIPTION
    Manages portfolio of trading strategies:
    - Diversified strategy allocation
    - Performance-based rebalancing
    - Risk-adjusted position sizing
.NOTES
    Part of Phase 4: Advanced AI Systems
#>

function New-StrategyPortfolio {
    param([Parameter(Mandatory)][array]$Strategies)

    return @{
        strategies = $Strategies
        allocations = @{}
        performance = @{}
    }
}

function Start-StrategyPortfolio {
    param(
        [Parameter(Mandatory)][hashtable]$Portfolio,
        [double]$TotalCapital = 100000
    )

    Write-Host "`n💼 MULTI-STRATEGY PORTFOLIO MANAGER" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════`n" -ForegroundColor Cyan

    # Initialize equal allocations
    $strategyCount = $Portfolio.strategies.Count
    foreach ($strategy in $Portfolio.strategies) {
        $Portfolio.allocations[$strategy.name] = 1.0 / $strategyCount
        $Portfolio.performance[$strategy.name] = @{
            return = 0
            sharpe = 0
            trades = 0
        }
    }

    Write-Host "Strategies:" -ForegroundColor Yellow
    foreach ($strategy in $Portfolio.strategies) {
        $allocation = [Math]::Round($Portfolio.allocations[$strategy.name] * 100, 1)
        $capital = [Math]::Round($TotalCapital * $Portfolio.allocations[$strategy.name], 2)

        Write-Host "   $($strategy.name): $allocation% (``$$capital)" -ForegroundColor White
    }

    Write-Host ""

    return $Portfolio
}

function Rebalance-StrategyPortfolio {
    param(
        [Parameter(Mandatory)][hashtable]$Portfolio,
        [ValidateSet("Equal","Performance","Sharpe","Kelly")][string]$Method = "Sharpe"
    )

    Write-Host "`n📊 REBALANCING STRATEGY PORTFOLIO" -ForegroundColor Cyan
    Write-Host "Method: $Method`n" -ForegroundColor White

    switch ($Method) {
        "Equal" {
            # Equal weight
            $count = $Portfolio.strategies.Count
            foreach ($strategy in $Portfolio.strategies) {
                $Portfolio.allocations[$strategy.name] = 1.0 / $count
            }
        }

        "Performance" {
            # Weight by returns
            $totalReturn = 0
            foreach ($strategy in $Portfolio.strategies) {
                $ret = [Math]::Max(0, $Portfolio.performance[$strategy.name].return)
                $totalReturn += $ret
            }

            foreach ($strategy in $Portfolio.strategies) {
                $ret = [Math]::Max(0, $Portfolio.performance[$strategy.name].return)
                $Portfolio.allocations[$strategy.name] = if ($totalReturn -gt 0) { $ret / $totalReturn } else { 1.0 / $Portfolio.strategies.Count }
            }
        }

        "Sharpe" {
            # Weight by Sharpe ratio
            $totalSharpe = 0
            foreach ($strategy in $Portfolio.strategies) {
                $sharpe = [Math]::Max(0, $Portfolio.performance[$strategy.name].sharpe)
                $totalSharpe += $sharpe
            }

            foreach ($strategy in $Portfolio.strategies) {
                $sharpe = [Math]::Max(0, $Portfolio.performance[$strategy.name].sharpe)
                $Portfolio.allocations[$strategy.name] = if ($totalSharpe -gt 0) { $sharpe / $totalSharpe } else { 1.0 / $Portfolio.strategies.Count }
            }
        }

        "Kelly" {
            # Kelly Criterion allocation
            foreach ($strategy in $Portfolio.strategies) {
                $perf = $Portfolio.performance[$strategy.name]
                $winRate = if ($perf.trades -gt 0) { 0.6 } else { 0.5 }  # Simplified
                $avgWin = 1.05; $avgLoss = 0.98

                $kelly = ($winRate * $avgWin - (1 - $winRate) * $avgLoss) / $avgWin
                $Portfolio.allocations[$strategy.name] = [Math]::Max(0, [Math]::Min(0.5, $kelly * 0.25))
            }

            # Normalize
            $total = ($Portfolio.allocations.Values | Measure-Object -Sum).Sum
            foreach ($name in $Portfolio.allocations.Keys) {
                $Portfolio.allocations[$name] /= $total
            }
        }
    }

    Write-Host "New allocations:" -ForegroundColor Yellow
    foreach ($strategy in $Portfolio.strategies) {
        Write-Host "   $($strategy.name): $([Math]::Round($Portfolio.allocations[$strategy.name] * 100, 1))%" -ForegroundColor Cyan
    }
    Write-Host ""
}

Export-ModuleMember -Function New-StrategyPortfolio, Start-StrategyPortfolio, Rebalance-StrategyPortfolio

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Strategy Portfolio ready. Multi-strategy diversification and rebalancing" -ForegroundColor Yellow
}
