#Requires -Version 7.0
<#
.SYNOPSIS
    Q-Learning Trading Agent
.DESCRIPTION
    Reinforcement Learning trader using Q-Learning:
    - Learns optimal trading policy from experience
    - State: price, indicators, position
    - Actions: buy, sell, hold
    - Rewards: profit/loss
.NOTES
    Part of Phase 4: Advanced AI Systems
#>

# ============================================================================
# Q-LEARNING AGENT
# ============================================================================

class QLearningAgent {
    [hashtable]$QTable
    [double]$LearningRate
    [double]$DiscountFactor
    [double]$Epsilon  # Exploration rate
    [int]$EpisodeCount

    QLearningAgent([double]$alpha, [double]$gamma, [double]$epsilon) {
        $this.QTable = @{}
        $this.LearningRate = $alpha
        $this.DiscountFactor = $gamma
        $this.Epsilon = $epsilon
        $this.EpisodeCount = 0
    }

    [string] GetStateKey([hashtable]$State) {
        # Discretize state for Q-table lookup
        $priceChange = [Math]::Round($State.priceChange, 1)
        $rsi = [Math]::Round($State.rsi / 10) * 10  # Bucket RSI by 10s
        $macd = if ($State.macd -gt 0) { 1 } else { -1 }
        $position = $State.position

        return "$priceChange|$rsi|$macd|$position"
    }

    [string] SelectAction([hashtable]$State) {
        $stateKey = $this.GetStateKey($State)

        # Epsilon-greedy exploration
        if ((Get-Random -Min 0.0 -Max 1.0) -lt $this.Epsilon) {
            # Explore: random action
            $actions = @("BUY", "SELL", "HOLD")
            return $actions[(Get-Random -Max $actions.Count)]
        }

        # Exploit: best known action
        if (-not $this.QTable.ContainsKey($stateKey)) {
            $this.QTable[$stateKey] = @{ BUY = 0; SELL = 0; HOLD = 0 }
        }

        $qValues = $this.QTable[$stateKey]
        $bestAction = "HOLD"
        $bestValue = $qValues.HOLD

        foreach ($action in $qValues.Keys) {
            if ($qValues[$action] -gt $bestValue) {
                $bestValue = $qValues[$action]
                $bestAction = $action
            }
        }

        return $bestAction
    }

    [void] UpdateQValue([hashtable]$State, [string]$Action, [double]$Reward, [hashtable]$NextState) {
        $stateKey = $this.GetStateKey($State)
        $nextStateKey = $this.GetStateKey($NextState)

        # Initialize Q-values if not exist
        if (-not $this.QTable.ContainsKey($stateKey)) {
            $this.QTable[$stateKey] = @{ BUY = 0; SELL = 0; HOLD = 0 }
        }

        if (-not $this.QTable.ContainsKey($nextStateKey)) {
            $this.QTable[$nextStateKey] = @{ BUY = 0; SELL = 0; HOLD = 0 }
        }

        # Find max Q-value for next state
        $maxNextQ = ($this.QTable[$nextStateKey].Values | Measure-Object -Maximum).Maximum

        # Q-Learning update formula
        $currentQ = $this.QTable[$stateKey][$Action]
        $newQ = $currentQ + $this.LearningRate * ($Reward + $this.DiscountFactor * $maxNextQ - $currentQ)

        $this.QTable[$stateKey][$Action] = $newQ
    }

    [void] DecayEpsilon([double]$DecayRate) {
        $this.Epsilon = [Math]::Max(0.01, $this.Epsilon * $DecayRate)
    }
}

# ============================================================================
# TRAINING
# ============================================================================

function Start-QLearningTraining {
    param(
        [Parameter(Mandatory)][array]$HistoricalData,
        [int]$Episodes = 100,
        [double]$InitialCapital = 10000
    )

    Write-Host "`n🤖 Q-LEARNING TRADER - TRAINING" -ForegroundColor Cyan
    Write-Host "════════════════════════════════════`n" -ForegroundColor Cyan

    $agent = [QLearningAgent]::new(0.1, 0.95, 0.3)  # alpha, gamma, epsilon

    $trainingResults = @()

    for ($episode = 1; $episode -le $Episodes; $episode++) {
        $capital = $InitialCapital
        $position = $null
        $totalReward = 0

        for ($i = 50; $i -lt ($HistoricalData.Count - 1); $i++) {
            # Get state
            $state = Get-TradingState -Data $HistoricalData[0..$i] -Position $position

            # Select action
            $action = $agent.SelectAction($state)

            # Execute action and get reward
            $result = Invoke-TradingAction -Action $action -CurrentPrice $HistoricalData[$i].close -Position ([ref]$position) -Capital ([ref]$capital)
            $reward = $result.reward

            # Get next state
            $nextState = Get-TradingState -Data $HistoricalData[0..($i+1)] -Position $position

            # Update Q-table
            $agent.UpdateQValue($state, $action, $reward, $nextState)

            $totalReward += $reward
        }

        # Decay exploration
        $agent.DecayEpsilon(0.995)

        $finalReturn = (($capital - $InitialCapital) / $InitialCapital) * 100

        if ($episode % 10 -eq 0) {
            Write-Host "Episode $episode/$Episodes | Return: $([Math]::Round($finalReturn, 2))% | Epsilon: $([Math]::Round($agent.Epsilon, 3))" -ForegroundColor $(if ($finalReturn -gt 0) { 'Green' } else { 'Red' })
        }

        $trainingResults += @{
            episode = $episode
            return = $finalReturn
            totalReward = $totalReward
        }
    }

    Write-Host "`n✅ Training complete!" -ForegroundColor Green
    Write-Host "   Q-Table size: $($agent.QTable.Count) states" -ForegroundColor White
    Write-Host "   Final epsilon: $([Math]::Round($agent.Epsilon, 3))`n" -ForegroundColor White

    return @{
        agent = $agent
        results = $trainingResults
    }
}

function Get-TradingState {
    param([array]$Data, $Position)

    $current = $Data[-1]
    $prev = $Data[-2]

    # Price change
    $priceChange = (($current.close - $prev.close) / $prev.close) * 100

    # RSI
    $rsi = Get-RSI -Data $Data -Period 14

    # MACD
    $ema12 = Get-EMA -Data $Data -Period 12
    $ema26 = Get-EMA -Data $Data -Period 26
    $macd = $ema12 - $ema26

    return @{
        priceChange = $priceChange
        rsi = $rsi
        macd = $macd
        position = if ($Position) { "LONG" } else { "NONE" }
    }
}

function Invoke-TradingAction {
    param([string]$Action, [double]$CurrentPrice, [ref]$Position, [ref]$Capital)

    $reward = 0

    if ($Action -eq "BUY" -and -not $Position.Value) {
        # Open position
        $Position.Value = @{
            entry = $CurrentPrice
            size = ($Capital.Value * 0.1) / $CurrentPrice
        }
        $Capital.Value *= 0.9  # Use 10% of capital
    }
    elseif ($Action -eq "SELL" -and $Position.Value) {
        # Close position
        $pnl = ($CurrentPrice - $Position.Value.entry) * $Position.Value.size
        $Capital.Value += $Position.Value.size * $CurrentPrice
        $Position.Value = $null

        $reward = $pnl / 100  # Normalize reward
    }

    return @{ reward = $reward }
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
    $gains = @(); $losses = @()
    for ($i = 1; $i -lt $Data.Count; $i++) {
        $change = $Data[$i].close - $Data[$i-1].close
        if ($change -gt 0) { $gains += $change; $losses += 0 }
        else { $gains += 0; $losses += [Math]::Abs($change) }
    }
    $avgGain = ($gains[-$Period..-1] | Measure-Object -Average).Average
    $avgLoss = ($losses[-$Period..-1] | Measure-Object -Average).Average
    if ($avgLoss -eq 0) { return 100 }
    return 100 - (100 / (1 + ($avgGain / $avgLoss)))
}

# ============================================================================
# EXPORT
# ============================================================================

Export-ModuleMember -Function Start-QLearningTraining

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Q-Learning Trader ready. Reinforcement learning for automated trading" -ForegroundColor Yellow
}
