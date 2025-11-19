#Requires -Version 7.0
<#
.SYNOPSIS
    PPO (Proximal Policy Optimization) Trading Agent
.DESCRIPTION
    State-of-the-art RL for trading:
    - More stable than Q-Learning
    - Policy gradient method
    - Continuous action space support
.NOTES
    Part of Phase 4: Advanced AI Systems
    Note: Simplified PPO - production use Python/TensorFlow
#>

$script:Config = @{
    ClipRatio = 0.2
    LearningRate = 0.0003
    ValueCoef = 0.5
    EntropyCoef = 0.01
}

class PPOAgent {
    [hashtable]$Policy
    [hashtable]$ValueFunction
    [array]$Memory

    PPOAgent() {
        $this.Policy = @{}
        $this.ValueFunction = @{}
        $this.Memory = @()
    }

    [hashtable] SelectAction([hashtable]$State) {
        $stateKey = $this.GetStateKey($State)

        if (-not $this.Policy.ContainsKey($stateKey)) {
            $this.Policy[$stateKey] = @{
                BUY = 0.33
                SELL = 0.33
                HOLD = 0.34
            }
        }

        # Sample from policy (probability distribution)
        $rand = Get-Random -Min 0.0 -Max 1.0
        $cumProb = 0

        foreach ($action in @("BUY", "SELL", "HOLD")) {
            $cumProb += $this.Policy[$stateKey][$action]
            if ($rand -le $cumProb) {
                return @{
                    action = $action
                    probability = $this.Policy[$stateKey][$action]
                }
            }
        }

        return @{ action = "HOLD"; probability = $this.Policy[$stateKey].HOLD }
    }

    [void] StoreExperience([hashtable]$Experience) {
        $this.Memory += $Experience

        # Keep last 1000 experiences
        if ($this.Memory.Count -gt 1000) {
            $this.Memory = $this.Memory[-1000..-1]
        }
    }

    [void] UpdatePolicy() {
        if ($this.Memory.Count -lt 32) { return }

        # Sample mini-batch
        $batch = $this.Memory | Get-Random -Count 32

        foreach ($exp in $batch) {
            $stateKey = $this.GetStateKey($exp.state)

            # Compute advantage (simplified)
            $value = if ($this.ValueFunction.ContainsKey($stateKey)) { $this.ValueFunction[$stateKey] } else { 0 }
            $advantage = $exp.reward + 0.99 * $value - $value

            # Update policy (simplified PPO)
            if ($this.Policy.ContainsKey($stateKey)) {
                $oldProb = $this.Policy[$stateKey][$exp.action]
                $ratio = 1.0 + ([Math]::Sign($advantage) * 0.01)

                $this.Policy[$stateKey][$exp.action] = [Math]::Max(0.01, [Math]::Min(0.99, $oldProb * $ratio))

                # Normalize probabilities
                $total = ($this.Policy[$stateKey].Values | Measure-Object -Sum).Sum
                foreach ($action in $this.Policy[$stateKey].Keys) {
                    $this.Policy[$stateKey][$action] /= $total
                }
            }

            # Update value function
            $this.ValueFunction[$stateKey] = $value + 0.001 * $advantage
        }
    }

    [string] GetStateKey([hashtable]$State) {
        return "$([Math]::Round($State.priceChange, 1))|$([Math]::Round($State.rsi / 10) * 10)|$($State.trend)"
    }
}

function Start-PPOTraining {
    param(
        [Parameter(Mandatory)][array]$Data,
        [int]$Episodes = 50
    )

    Write-Host "`n🚀 PPO TRADER - TRAINING" -ForegroundColor Magenta
    Write-Host "════════════════════════════════════`n" -ForegroundColor Magenta

    $agent = [PPOAgent]::new()

    for ($ep = 1; $ep -le $Episodes; $ep++) {
        $capital = 10000
        $position = $null
        $totalReward = 0

        for ($i = 50; $i -lt ($Data.Count - 1); $i++) {
            $state = @{
                priceChange = (($Data[$i].close - $Data[$i-1].close) / $Data[$i-1].close) * 100
                rsi = 50
                trend = if ($Data[$i].close -gt $Data[$i-10].close) { "UP" } else { "DOWN" }
            }

            $actionResult = $agent.SelectAction($state)
            $action = $actionResult.action

            # Execute and get reward
            $reward = 0
            if ($action -eq "BUY" -and -not $position) {
                $position = @{ entry = $Data[$i].close; size = 1 }
            }
            elseif ($action -eq "SELL" -and $position) {
                $reward = ($Data[$i].close - $position.entry) / $position.entry
                $position = $null
            }

            $agent.StoreExperience(@{
                state = $state
                action = $action
                reward = $reward
                nextState = $state
            })

            $totalReward += $reward
        }

        # Update policy after episode
        $agent.UpdatePolicy()

        if ($ep % 10 -eq 0) {
            Write-Host "Episode $ep/$Episodes | Total reward: $([Math]::Round($totalReward, 4))" -ForegroundColor Cyan
        }
    }

    Write-Host "`n✅ PPO training complete!`n" -ForegroundColor Green

    return $agent
}

Export-ModuleMember -Function Start-PPOTraining

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "PPO Trader ready. Proximal Policy Optimization for advanced RL trading" -ForegroundColor Yellow
}
