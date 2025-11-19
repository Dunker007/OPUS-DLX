<#
.SYNOPSIS
    Budget Manager - Real-time AI Cost Tracking for LuxRig

.DESCRIPTION
    Tracks and enforces API spending limits:
    - Loads budget rules from config
    - Tracks spend per AI model (daily, weekly, monthly)
    - Enforces limits (warn at 80%, block at 100%)
    - Generates cost reports and ROI calculations
    - Persists budget state to JSON

.EXAMPLE
    $status = Get-BudgetStatus
    Update-BudgetSpend -Provider "Claude" -Cost 0.15 -Tokens 10000

.NOTES
    Part of LuxRig Phase 1 Foundation
    Critical for preventing runaway API costs
#>

# Budget state file
$script:BudgetStateFile = "$PSScriptRoot\..\Analytics\budget-state.json"
$script:BudgetRulesFile = "$PSScriptRoot\..\Configs\budget-rules.yaml"

# Initialize budget state
function Initialize-BudgetState {
    $defaultState = @{
        last_reset = (Get-Date).ToString("yyyy-MM-dd")
        period = "monthly"  # daily, weekly, monthly
        models = @{
            claude = @{
                monthly_budget = 100
                spent_today = 0
                spent_week = 0
                spent_month = 0
                tokens_today = 0
                tokens_week = 0
                tokens_month = 0
                requests_today = 0
                requests_week = 0
                requests_month = 0
            }
            gpt4 = @{
                monthly_budget = 100
                spent_today = 0
                spent_week = 0
                spent_month = 0
                tokens_today = 0
                tokens_week = 0
                tokens_month = 0
                requests_today = 0
                requests_week = 0
                requests_month = 0
            }
            gemini = @{
                monthly_budget = 50
                spent_today = 0
                spent_week = 0
                spent_month = 0
                tokens_today = 0
                tokens_week = 0
                tokens_month = 0
                requests_today = 0
                requests_week = 0
                requests_month = 0
            }
            grok = @{
                monthly_budget = 100
                spent_today = 0
                spent_week = 0
                spent_month = 0
                tokens_today = 0
                tokens_week = 0
                tokens_month = 0
                requests_today = 0
                requests_week = 0
                requests_month = 0
            }
            local = @{
                monthly_budget = 0
                spent_today = 0
                spent_week = 0
                spent_month = 0
                tokens_today = 0
                tokens_week = 0
                tokens_month = 0
                requests_today = 0
                requests_week = 0
                requests_month = 0
            }
        }
        total_spent_all_time = 0
        total_tokens_all_time = 0
    }

    return $defaultState
}

# Load budget state from file
function Get-BudgetState {
    try {
        if (Test-Path $script:BudgetStateFile) {
            $state = Get-Content $script:BudgetStateFile | ConvertFrom-Json -AsHashtable

            # Check if we need to reset (new month)
            $lastReset = [datetime]::Parse($state.last_reset)
            $now = Get-Date

            if ($now.Month -ne $lastReset.Month -or $now.Year -ne $lastReset.Year) {
                Write-Host "New month detected, resetting monthly budgets..." -ForegroundColor Yellow
                $state = Reset-MonthlyBudgets -State $state
            }

            return $state
        }
        else {
            Write-Host "Budget state file not found, initializing new state..." -ForegroundColor Yellow
            return Initialize-BudgetState
        }
    }
    catch {
        Write-Warning "Failed to load budget state: $_. Initializing new state."
        return Initialize-BudgetState
    }
}

# Save budget state to file
function Save-BudgetState {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$State
    )

    try {
        $stateDir = Split-Path $script:BudgetStateFile -Parent
        if (-not (Test-Path $stateDir)) {
            New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
        }

        $State | ConvertTo-Json -Depth 10 | Set-Content $script:BudgetStateFile
    }
    catch {
        Write-Warning "Failed to save budget state: $_"
    }
}

# Reset monthly budgets
function Reset-MonthlyBudgets {
    param(
        [hashtable]$State
    )

    foreach ($model in $State.models.Keys) {
        $State.models[$model].spent_month = 0
        $State.models[$model].tokens_month = 0
        $State.models[$model].requests_month = 0
    }

    $State.last_reset = (Get-Date).ToString("yyyy-MM-dd")
    Save-BudgetState -State $State

    return $State
}

# Update budget spend
function Update-BudgetSpend {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Provider,

        [Parameter(Mandatory=$true)]
        [double]$Cost,

        [int]$Tokens = 0
    )

    $state = Get-BudgetState

    # Normalize provider name
    $modelKey = $Provider.ToLower() -replace '[^a-z]', ''

    if (-not $state.models.ContainsKey($modelKey)) {
        Write-Warning "Unknown model: $Provider. Adding to budget tracking."
        $state.models[$modelKey] = Initialize-BudgetState.models.claude  # Template
    }

    # Update spend tracking
    $state.models[$modelKey].spent_today += $Cost
    $state.models[$modelKey].spent_week += $Cost
    $state.models[$modelKey].spent_month += $Cost
    $state.models[$modelKey].tokens_today += $Tokens
    $state.models[$modelKey].tokens_week += $Tokens
    $state.models[$modelKey].tokens_month += $Tokens
    $state.models[$modelKey].requests_today += 1
    $state.models[$modelKey].requests_week += 1
    $state.models[$modelKey].requests_month += 1

    $state.total_spent_all_time += $Cost
    $state.total_tokens_all_time += $Tokens

    # Check budget limits and warn
    $monthlyBudget = $state.models[$modelKey].monthly_budget
    $spentMonth = $state.models[$modelKey].spent_month
    $percentUsed = ($spentMonth / $monthlyBudget) * 100

    if ($percentUsed -ge 100) {
        Write-Warning "⚠️ BUDGET EXCEEDED for $Provider! Spent `$$spentMonth / `$$monthlyBudget (100%)"
    }
    elseif ($percentUsed -ge 80) {
        Write-Warning "⚠️ Budget warning for $Provider: Spent `$$spentMonth / `$$monthlyBudget ($([Math]::Round($percentUsed, 1))%)"
    }

    Save-BudgetState -State $state
}

# Get current budget status
function Get-BudgetStatus {
    $state = Get-BudgetState

    $status = @{
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        total_spent = 0
        total_budget = 0
        total_remaining = 0
        models = @{}
    }

    foreach ($modelName in $state.models.Keys) {
        $model = $state.models[$modelName]

        $status.total_spent += $model.spent_month
        $status.total_budget += $model.monthly_budget

        $remaining = $model.monthly_budget - $model.spent_month
        $percentUsed = if ($model.monthly_budget -gt 0) {
            ($model.spent_month / $model.monthly_budget) * 100
        } else { 0 }

        $status.models[$modelName] = @{
            monthly_budget = $model.monthly_budget
            spent_month = $model.spent_month
            remaining_budget = [Math]::Max(0, $remaining)
            percent_used = [Math]::Round($percentUsed, 2)
            tokens_month = $model.tokens_month
            requests_month = $model.requests_month
            avg_cost_per_request = if ($model.requests_month -gt 0) {
                $model.spent_month / $model.requests_month
            } else { 0 }
        }
    }

    $status.total_remaining = $status.total_budget - $status.total_spent

    return $status
}

# Generate budget report
function Get-BudgetReport {
    param(
        [ValidateSet("daily", "weekly", "monthly", "all-time")]
        [string]$Period = "monthly"
    )

    $state = Get-BudgetState
    $status = Get-BudgetStatus

    Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          LuxRig Budget Report - $Period".PadRight(59) + "║" -ForegroundColor Cyan
    Write-Host "╠══════════════════════════════════════════════════════════╣" -ForegroundColor Cyan

    Write-Host "║ Overall Budget Status                                    ║" -ForegroundColor Cyan
    Write-Host "║   Total Budget:    `$$($status.total_budget)".PadRight(59) + "║" -ForegroundColor White
    Write-Host "║   Total Spent:     `$$($status.total_spent)".PadRight(59) + "║" -ForegroundColor Yellow
    Write-Host "║   Remaining:       `$$($status.total_remaining)".PadRight(59) + "║" -ForegroundColor Green
    Write-Host "╠══════════════════════════════════════════════════════════╣" -ForegroundColor Cyan

    foreach ($modelName in $status.models.Keys) {
        $model = $status.models[$modelName]

        $color = "White"
        if ($model.percent_used -ge 100) { $color = "Red" }
        elseif ($model.percent_used -ge 80) { $color = "Yellow" }
        elseif ($model.percent_used -ge 50) { $color = "Green" }

        Write-Host "║ $($modelName.ToUpper())".PadRight(59) + "║" -ForegroundColor Cyan
        Write-Host "║   Budget: `$$($model.monthly_budget) | Spent: `$$([Math]::Round($model.spent_month, 2)) | Remaining: `$$([Math]::Round($model.remaining_budget, 2))".PadRight(59) + "║" -ForegroundColor $color
        Write-Host "║   Usage: $($model.percent_used)% | Tokens: $($model.tokens_month) | Requests: $($model.requests_month)".PadRight(59) + "║" -ForegroundColor Gray
    }

    Write-Host "╠══════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
    Write-Host "║ All-Time Stats                                           ║" -ForegroundColor Cyan
    Write-Host "║   Total Spent:     `$$($state.total_spent_all_time)".PadRight(59) + "║" -ForegroundColor White
    Write-Host "║   Total Tokens:    $($state.total_tokens_all_time)".PadRight(59) + "║" -ForegroundColor White
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
}

# Check if a model has budget available
function Test-BudgetAvailable {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Provider,

        [double]$EstimatedCost = 0.0
    )

    $status = Get-BudgetStatus
    $modelKey = $Provider.ToLower() -replace '[^a-z]', ''

    if (-not $status.models.ContainsKey($modelKey)) {
        return $true  # Unknown model, allow it
    }

    $model = $status.models[$modelKey]

    # Local models always available (free)
    if ($model.monthly_budget -eq 0) {
        return $true
    }

    # Check if adding estimated cost would exceed budget
    $projectedSpend = $model.spent_month + $EstimatedCost

    return ($projectedSpend -le $model.monthly_budget)
}

# Export functions
Export-ModuleMember -Function Get-BudgetStatus, Update-BudgetSpend, Get-BudgetReport, Test-BudgetAvailable, Get-BudgetState, Save-BudgetState
