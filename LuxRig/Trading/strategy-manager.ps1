# ============================================================================
# LuxRig Strategy Manager
# Run and manage multiple trading strategies simultaneously
# ============================================================================

param(
    [string]$Action = 'list',
    [string]$Strategy,
    [double]$Allocation = 0
)

$dataAccessModule = Join-Path $PSScriptRoot '../Database/data-access.ps1'
if (Test-Path $dataAccessModule) { . $dataAccessModule }

$Script:AvailableStrategies = @{
    'DCA' = @{
        Name = 'Dollar Cost Averaging'
        Script = Join-Path $PSScriptRoot 'Strategies/dca-bot-live.ps1'
        MinAllocation = 100
        RiskLevel = 'LOW'
    }
    'GRID' = @{
        Name = 'Grid Trading'
        Script = Join-Path $PSScriptRoot 'Strategies/grid-bot.ps1'
        MinAllocation = 500
        RiskLevel = 'MEDIUM'
    }
    'SCALPER' = @{
        Name = 'Scalping Bot'
        Script = Join-Path $PSScriptRoot 'Strategies/scalper-bot.ps1'
        MinAllocation = 1000
        RiskLevel = 'HIGH'
    }
}

function Start-Strategy {
    param([string]$Name, [double]$Allocation)

    if (-not $Script:AvailableStrategies.ContainsKey($Name)) {
        Write-Host "❌ Unknown strategy: $Name" -ForegroundColor Red
        return
    }

    $strategy = $Script:AvailableStrategies[$Name]

    if ($Allocation -lt $strategy.MinAllocation) {
        Write-Host "❌ Minimum allocation for $Name is $$($strategy.MinAllocation)" -ForegroundColor Red
        return
    }

    Write-Host "🚀 Starting strategy: $($strategy.Name)" -ForegroundColor Green
    Write-Host "   Allocation: $$Allocation" -ForegroundColor Cyan
    Write-Host "   Risk Level: $($strategy.RiskLevel)" -ForegroundColor Yellow

    # Save to database
    $strategyId = "STRAT-$(Get-Date -Format 'yyyyMMddHHmmss')-$Name"

    $strategyData = @{
        strategy_id = $strategyId
        name = $strategy.Name
        type = $Name
        status = 'ACTIVE'
        capital_allocated = $Allocation
        parameters = (@{
            MinAllocation = $strategy.MinAllocation
            RiskLevel = $strategy.RiskLevel
        } | ConvertTo-Json -Compress)
    }

    New-DatabaseRecord -Table 'strategies' -Data $strategyData | Out-Null

    Write-Host "✅ Strategy registered: $strategyId" -ForegroundColor Green
}

function Get-ActiveStrategies {
    try {
        $strategies = Invoke-DatabaseQuery -Query "SELECT * FROM strategies WHERE status = 'ACTIVE';"

        if ($strategies) {
            Write-Host "`n=== Active Strategies ===" -ForegroundColor Cyan
            foreach ($s in $strategies) {
                Write-Host "`n$($s.name)" -ForegroundColor Yellow
                Write-Host "  ID: $($s.strategy_id)" -ForegroundColor Gray
                Write-Host "  Type: $($s.type)" -ForegroundColor White
                Write-Host "  Allocation: `$$($s.capital_allocated)" -ForegroundColor Cyan
                Write-Host "  Total Trades: $($s.total_trades)" -ForegroundColor White
                Write-Host "  Win Rate: $($s.win_rate)%" -ForegroundColor $(if($s.win_rate -ge 50){'Green'}else{'Red'})
                Write-Host "  P/L: `$$($s.total_profit_loss)" -ForegroundColor $(if($s.total_profit_loss -gt 0){'Green'}else{'Red'})
            }
        }
        else {
            Write-Host "No active strategies" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "❌ Failed to get strategies: $_" -ForegroundColor Red
    }
}

function Stop-Strategy {
    param([string]$StrategyId)

    Update-DatabaseRecord -Table 'strategies' -Data @{ status = 'INACTIVE' } -Where @{ strategy_id = $StrategyId } | Out-Null
    Write-Host "✅ Strategy stopped: $StrategyId" -ForegroundColor Green
}

# Main execution
switch ($Action) {
    'start' {
        if ($Strategy -and $Allocation -gt 0) {
            Start-Strategy -Name $Strategy -Allocation $Allocation
        }
        else {
            Write-Host "Usage: -Action start -Strategy DCA -Allocation 1000" -ForegroundColor Yellow
        }
    }
    'list' {
        Get-ActiveStrategies
    }
    'stop' {
        if ($Strategy) {
            Stop-Strategy -StrategyId $Strategy
        }
    }
    'available' {
        Write-Host "`n=== Available Strategies ===" -ForegroundColor Cyan
        foreach ($strat in $Script:AvailableStrategies.GetEnumerator()) {
            Write-Host "`n$($strat.Key)" -ForegroundColor Yellow
            Write-Host "  Name: $($strat.Value.Name)" -ForegroundColor White
            Write-Host "  Min Allocation: `$$($strat.Value.MinAllocation)" -ForegroundColor Cyan
            Write-Host "  Risk: $($strat.Value.RiskLevel)" -ForegroundColor Yellow
        }
        Write-Host ""
    }
}
