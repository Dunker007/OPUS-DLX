<#
.SYNOPSIS
    ROI Calculator - Calculate return on AI investment

.DESCRIPTION
    Calculates ROI metrics:
    - Cost per revenue dollar generated
    - AI cost vs revenue ratio
    - Per-model profitability
    - Optimization recommendations
#>

Import-Module "$PSScriptRoot\budget-manager.ps1" -Force

function Get-AISpend {
    param([string]$Period = "month")

    $budgetState = Get-BudgetState

    $totalSpend = 0

    foreach ($modelName in $budgetState.models.Keys) {
        $model = $budgetState.models[$modelName]

        $spend = switch ($Period) {
            "day" { $model.spent_today }
            "week" { $model.spent_week }
            "month" { $model.spent_month }
            "all" { $budgetState.total_spent_all_time }
        }

        $totalSpend += $spend
    }

    return $totalSpend
}

function Get-ROIMetrics {
    param(
        [ValidateSet("day", "week", "month", "all")]
        [string]$Period = "month"
    )

    Write-Host "`n[ROI Calculator] Calculating ROI for: $Period" -ForegroundColor Cyan

    # Get AI costs
    $aiCost = Get-AISpend -Period $Period

    # Get revenue
    Import-Module "$PSScriptRoot\..\Analytics\revenue-tracker.ps1" -Force
    $revenue = Get-TotalRevenue -Period $Period

    # Calculate ROI
    $netProfit = $revenue.total - $aiCost
    $roi = if ($aiCost -gt 0) {
        [Math]::Round((($netProfit) / $aiCost) * 100, 2)
    } else { 0 }

    $costPerDollar = if ($revenue.total -gt 0) {
        [Math]::Round($aiCost / $revenue.total, 4)
    } else { 0 }

    # Profitability assessment
    $profitable = $netProfit -gt 0
    $efficiency = if ($costPerDollar -le 0.2) { "Excellent" }
                  elseif ($costPerDollar -le 0.4) { "Good" }
                  elseif ($costPerDollar -le 0.6) { "Fair" }
                  else { "Poor" }

    Write-Host "`n╔═══════════════════════════════════════════════════════════╗" -ForegroundColor $(if ($profitable) { "Green" } else { "Red" })
    Write-Host "║               ROI REPORT - $($Period.ToUpper())".PadRight(60) + "║" -ForegroundColor $(if ($profitable) { "Green" } else { "Red" })
    Write-Host "╠═══════════════════════════════════════════════════════════╣" -ForegroundColor $(if ($profitable) { "Green" } else { "Red" })
    Write-Host "║ Revenue:          `$$($revenue.total)".PadRight(60) + "║" -ForegroundColor White
    Write-Host "║ AI Costs:         `$$aiCost".PadRight(60) + "║" -ForegroundColor White
    Write-Host "║ Net Profit:       `$$netProfit".PadRight(60) + "║" -ForegroundColor $(if ($profitable) { "Green" } else { "Red" })
    Write-Host "║".PadRight(60) + "║"
    Write-Host "║ ROI:              $roi%".PadRight(60) + "║" -ForegroundColor Cyan
    Write-Host "║ Cost per `$1:      `$$costPerDollar".PadRight(60) + "║" -ForegroundColor Cyan
    Write-Host "║ Efficiency:       $efficiency".PadRight(60) + "║" -ForegroundColor Yellow
    Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor $(if ($profitable) { "Green" } else { "Red" })

    return @{
        period = $Period
        revenue = $revenue.total
        aiCost = $aiCost
        netProfit = $netProfit
        roi = $roi
        costPerDollar = $costPerDollar
        profitable = $profitable
        efficiency = $efficiency
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
}

function Get-PerModelROI {
    param([string]$Period = "month")

    $budgetState = Get-BudgetState
    $revenue = Get-TotalRevenue -Period $Period

    # Assume revenue is distributed by model usage
    $totalTokens = 0
    foreach ($modelName in $budgetState.models.Keys) {
        $totalTokens += $budgetState.models[$modelName].tokens_month
    }

    $modelROI = @()

    foreach ($modelName in $budgetState.models.Keys) {
        $model = $budgetState.models[$modelName]

        if ($model.spent_month -eq 0) { continue }

        # Estimate revenue attribution based on token usage
        $attributedRevenue = if ($totalTokens -gt 0) {
            ($model.tokens_month / $totalTokens) * $revenue.total
        } else { 0 }

        $modelProfit = $attributedRevenue - $model.spent_month
        $modelROI = if ($model.spent_month -gt 0) {
            [Math]::Round(($modelProfit / $model.spent_month) * 100, 2)
        } else { 0 }

        $modelROI += @{
            model = $modelName
            cost = $model.spent_month
            revenue = $attributedRevenue
            profit = $modelProfit
            roi = $modelROI
            requests = $model.requests_month
        }
    }

    return $modelROI | Sort-Object roi -Descending
}

function Get-OptimizationRecommendations {
    param([hashtable]$ROIData)

    $recommendations = @()

    # Low ROI check
    if ($ROIData.roi -lt 100) {
        $recommendations += "⚠️ ROI below 100% - consider reducing AI costs or increasing revenue"
    }

    # High cost per dollar
    if ($ROIData.costPerDollar -gt 0.5) {
        $recommendations += "⚠️ High cost ratio - optimize AI usage or increase pricing"
    }

    # Profitability
    if (-not $ROIData.profitable) {
        $recommendations += "🔴 UNPROFITABLE - immediate action required"
        $recommendations += "  → Reduce budget allocation"
        $recommendations += "  → Use more local models"
        $recommendations += "  → Increase product pricing"
    }

    # Good performance
    if ($ROIData.roi -gt 500 -and $ROIData.profitable) {
        $recommendations += "✅ Excellent ROI - consider scaling up AI budget"
        $recommendations += "  → Increase to next spending tier"
        $recommendations += "  → Launch additional revenue streams"
    }

    # Per-model recommendations
    $modelROI = Get-PerModelROI

    $unprofitableModels = $modelROI | Where-Object { $_.roi -lt 0 }

    foreach ($model in $unprofitableModels) {
        $recommendations += "⚠️ Model '$($model.model)' is unprofitable (ROI: $($model.roi)%)"
        $recommendations += "  → Reduce usage or switch to cheaper alternative"
    }

    return $recommendations
}

function Save-ROISnapshot {
    param([hashtable]$ROIData)

    $snapshotFile = "$PSScriptRoot\..\Analytics\roi-snapshots.jsonl"
    $ROIData | ConvertTo-Json -Compress | Add-Content $snapshotFile

    Write-Host "✓ ROI snapshot saved" -ForegroundColor Green
}

Export-ModuleMember -Function Get-ROIMetrics, Get-PerModelROI, Get-OptimizationRecommendations, Save-ROISnapshot
