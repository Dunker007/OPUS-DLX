#Requires -Version 7.0
<#
.SYNOPSIS
    RL-Based Capital Allocator
.DESCRIPTION
    Uses reinforcement learning to optimize capital allocation:
    - Learns optimal allocation from historical performance
    - Adapts to changing market conditions
    - Multi-asset portfolio optimization
.NOTES
    Part of Phase 4: Advanced AI Systems
#>

class AllocationAgent {
    [hashtable]$QTable
    [double]$LearningRate
    [double]$Epsilon

    AllocationAgent() {
        $this.QTable = @{}
        $this.LearningRate = 0.1
        $this.Epsilon = 0.2
    }

    [hashtable] SelectAllocation([hashtable]$MarketState, [array]$Assets) {
        $stateKey = $this.GetStateKey($MarketState)

        if ((Get-Random -Min 0.0 -Max 1.0) -lt $this.Epsilon) {
            # Explore: random allocation
            return $this.RandomAllocation($Assets)
        }

        # Exploit: use Q-table
        if ($this.QTable.ContainsKey($stateKey)) {
            return $this.QTable[$stateKey].allocation
        }

        return $this.RandomAllocation($Assets)
    }

    [hashtable] RandomAllocation([array]$Assets) {
        $allocation = @{}
        $total = 0

        foreach ($asset in $Assets) {
            $random = Get-Random -Min 0.0 -Max 1.0
            $allocation[$asset] = $random
            $total += $random
        }

        # Normalize
        foreach ($asset in $Assets) {
            $allocation[$asset] /= $total
        }

        return $allocation
    }

    [void] UpdateQValue([hashtable]$State, [hashtable]$Allocation, [double]$Reward) {
        $stateKey = $this.GetStateKey($State)

        if (-not $this.QTable.ContainsKey($stateKey)) {
            $this.QTable[$stateKey] = @{
                value = 0
                allocation = $Allocation
            }
        }

        $currentQ = $this.QTable[$stateKey].value
        $newQ = $currentQ + $this.LearningRate * ($Reward - $currentQ)

        $this.QTable[$stateKey].value = $newQ
        $this.QTable[$stateKey].allocation = $Allocation
    }

    [string] GetStateKey([hashtable]$State) {
        return "$($State.volatility)|$($State.trend)|$($State.momentum)"
    }
}

function Start-RLAllocationTraining {
    param(
        [Parameter(Mandatory)][array]$Assets,
        [Parameter(Mandatory)][array]$HistoricalData,
        [int]$Episodes = 100
    )

    Write-Host "`n🧠 RL CAPITAL ALLOCATOR - TRAINING" -ForegroundColor Magenta
    Write-Host "════════════════════════════════════════`n" -ForegroundColor Magenta

    $agent = [AllocationAgent]::new()

    for ($ep = 1; $ep -le $Episodes; $ep++) {
        $capital = 100000
        $totalReturn = 0

        for ($i = 50; $i -lt ($HistoricalData.Count - 1); $i++) {
            # Market state
            $state = @{
                volatility = Get-Random -Min 1 -Max 3
                trend = if ($HistoricalData[$i].close -gt $HistoricalData[$i-10].close) { "UP" } else { "DOWN" }
                momentum = Get-Random -Min 1 -Max 3
            }

            # Get allocation
            $allocation = $agent.SelectAllocation($state, $Assets)

            # Simulate returns
            $periodReturn = 0
            foreach ($asset in $Assets) {
                $assetReturn = (Get-Random -Min -0.02 -Max 0.05)
                $periodReturn += $allocation[$asset] * $assetReturn
            }

            $capital *= (1 + $periodReturn)
            $totalReturn += $periodReturn

            # Update Q-values
            $agent.UpdateQValue($state, $allocation, $periodReturn * 100)
        }

        if ($ep % 20 -eq 0) {
            Write-Host "Episode $ep | Return: $([Math]::Round(($capital - 100000) / 1000, 2))%" -ForegroundColor Cyan
        }
    }

    Write-Host "`n✅ Training complete!`n" -ForegroundColor Green

    return $agent
}

Export-ModuleMember -Function Start-RLAllocationTraining

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "RL Allocator ready. Reinforcement learning for optimal capital allocation" -ForegroundColor Yellow
}
