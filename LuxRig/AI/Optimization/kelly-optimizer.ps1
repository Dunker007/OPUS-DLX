#Requires -Version 7.0
<#
.SYNOPSIS
    Kelly Criterion Optimizer
.DESCRIPTION
    Optimal position sizing using Kelly Criterion:
    - Full Kelly calculation
    - Fractional Kelly (risk reduction)
    - Multi-asset Kelly optimization
    - Dynamic Kelly adjustment
.NOTES
    Part of Phase 4: Advanced AI Systems
#>

function Get-OptimalKelly {
    param(
        [Parameter(Mandatory)][double]$WinRate,
        [Parameter(Mandatory)][double]$AvgWin,
        [Parameter(Mandatory)][double]$AvgLoss,
        [double]$FractionalKelly = 0.25
    )

    if ($AvgLoss -eq 0) { return 0 }

    $b = $AvgWin / $AvgLoss
    $p = $WinRate
    $q = 1 - $p

    $fullKelly = ($b * $p - $q) / $b
    $fractional = $fullKelly * $FractionalKelly

    return @{
        fullKelly = [Math]::Round([Math]::Max(0, $fullKelly), 4)
        fractionalKelly = [Math]::Round([Math]::Max(0, $fractional), 4)
        recommended = [Math]::Round([Math]::Max(0, [Math]::Min(0.10, $fractional)), 4)
    }
}

function Optimize-MultiAssetKelly {
    param(
        [Parameter(Mandatory)][hashtable]$Assets,
        [double]$TotalCapital = 100000
    )

    Write-Host "`n📐 MULTI-ASSET KELLY OPTIMIZATION" -ForegroundColor Cyan
    Write-Host "══════════════════════════════════════`n" -ForegroundColor Cyan

    $allocations = @{}

    foreach ($asset in $Assets.Keys) {
        $stats = $Assets[$asset]

        $kelly = Get-OptimalKelly -WinRate $stats.winRate -AvgWin $stats.avgWin -AvgLoss $stats.avgLoss

        $allocations[$asset] = @{
            kelly = $kelly.recommended
            capital = [Math]::Round($TotalCapital * $kelly.recommended, 2)
        }

        Write-Host "$asset`:" -ForegroundColor Yellow
        Write-Host "   Win rate: $([Math]::Round($stats.winRate * 100, 1))%" -ForegroundColor White
        Write-Host "   Avg win: `$$([Math]::Round($stats.avgWin, 2)) | Avg loss: `$$([Math]::Round($stats.avgLoss, 2))" -ForegroundColor White
        Write-Host "   Full Kelly: $([Math]::Round($kelly.fullKelly * 100, 2))%" -ForegroundColor Gray
        Write-Host "   Recommended: $([Math]::Round($kelly.recommended * 100, 2))% (``$$($allocations[$asset].capital))" -ForegroundColor Green
        Write-Host ""
    }

    return $allocations
}

function Update-KellyDynamically {
    param(
        [Parameter(Mandatory)][array]$RecentTrades,
        [int]$WindowSize = 50
    )

    $recent = $Trades[-[Math]::Min($WindowSize, $Trades.Count)..-1]

    $wins = ($recent | Where-Object { $_.pnl -gt 0 })
    $losses = ($recent | Where-Object { $_.pnl -lt 0 })

    $winRate = $wins.Count / $recent.Count
    $avgWin = if ($wins.Count -gt 0) { ($wins.pnl | Measure-Object -Average).Average } else { 0 }
    $avgLoss = if ($losses.Count -gt 0) { [Math]::Abs(($losses.pnl | Measure-Object -Average).Average) } else { 0 }

    $kelly = Get-OptimalKelly -WinRate $winRate -AvgWin $avgWin -AvgLoss $avgLoss

    return $kelly.recommended
}

Export-ModuleMember -Function Get-OptimalKelly, Optimize-MultiAssetKelly, Update-KellyDynamically

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Kelly Optimizer ready. Optimal position sizing for maximum growth" -ForegroundColor Yellow
}
