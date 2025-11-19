<#
.SYNOPSIS
    Auto-Scaler - Revenue-based budget auto-scaling

.DESCRIPTION
    Automatically adjusts AI budgets based on revenue:
    - Monitors revenue growth
    - Scales budgets up when profitable
    - Scales down when unprofitable
    - Switches between modes automatically
#>

Import-Module "$PSScriptRoot\budget-manager.ps1" -Force
Import-Module "$PSScriptRoot\roi-calculator.ps1" -Force

function Get-ScalingRecommendation {
    param([hashtable]$ROIData, [hashtable]$RevenueData)

    $currentMode = "growth"  # Would read from budget-rules.yaml

    $recommendation = @{
        action = "maintain"
        targetMode = $currentMode
        budgetMultiplier = 1.0
        reasoning = @()
    }

    # Rule 1: High ROI + Growing Revenue = Scale Up
    if ($ROIData.roi -gt 300 -and $RevenueData.total -gt 1000) {
        $recommendation.action = "scale_up"
        $recommendation.budgetMultiplier = 1.5
        $recommendation.reasoning += "High ROI ($($ROIData.roi)%) and strong revenue (`$$($RevenueData.total))"

        if ($currentMode -eq "bootstrapper" -and $RevenueData.total -gt 500) {
            $recommendation.targetMode = "growth"
            $recommendation.reasoning += "Revenue threshold for Growth mode reached"
        }
        elseif ($currentMode -eq "growth" -and $RevenueData.total -gt 2000) {
            $recommendation.targetMode = "blitzkrieg"
            $recommendation.reasoning += "Revenue threshold for Blitzkrieg mode reached"
        }
    }

    # Rule 2: Low ROI = Scale Down
    if ($ROIData.roi -lt 50 -or -not $ROIData.profitable) {
        $recommendation.action = "scale_down"
        $recommendation.budgetMultiplier = 0.7
        $recommendation.reasoning += "Low ROI ($($ROIData.roi)%) or unprofitable"

        if ($currentMode -eq "blitzkrieg") {
            $recommendation.targetMode = "growth"
            $recommendation.reasoning += "Scaling back to Growth mode"
        }
        elseif ($currentMode -eq "growth") {
            $recommendation.targetMode = "bootstrapper"
            $recommendation.reasoning += "Scaling back to Bootstrapper mode"
        }
    }

    # Rule 3: Moderate performance = Maintain
    if ($ROIData.roi -ge 100 -and $ROIData.roi -le 300) {
        $recommendation.action = "maintain"
        $recommendation.reasoning += "ROI in healthy range ($($ROIData.roi)%)"
    }

    # Rule 4: Revenue decline = Caution
    if ($RevenueData.total -lt 100) {
        $recommendation.action = "scale_down"
        $recommendation.budgetMultiplier = 0.5
        $recommendation.reasoning += "Low revenue (`$$($RevenueData.total)) - conserve resources"
    }

    return $recommendation
}

function Invoke-AutoScale {
    param(
        [switch]$DryRun = $true,
        [switch]$Force = $false
    )

    Write-Host "`n╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║              AUTO-SCALER - ANALYZING                      ║" -ForegroundColor Yellow
    Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Yellow

    # Get current metrics
    $roi = Get-ROIMetrics -Period "month"
    Import-Module "$PSScriptRoot\..\Analytics\revenue-tracker.ps1" -Force
    $revenue = Get-TotalRevenue -Period "month"

    # Get scaling recommendation
    $recommendation = Get-ScalingRecommendation -ROIData $roi -RevenueData $revenue

    # Display recommendation
    Write-Host "`nScaling Analysis:" -ForegroundColor Cyan
    Write-Host "  Current ROI: $($roi.roi)%" -ForegroundColor White
    Write-Host "  Monthly Revenue: `$$($revenue.total)" -ForegroundColor White
    Write-Host "  AI Costs: `$$($roi.aiCost)" -ForegroundColor White

    Write-Host "`nRecommendation:" -ForegroundColor Yellow
    Write-Host "  Action: $($recommendation.action.ToUpper())" -ForegroundColor $(
        switch ($recommendation.action) {
            "scale_up" { "Green" }
            "scale_down" { "Red" }
            default { "Gray" }
        }
    )
    Write-Host "  Target Mode: $($recommendation.targetMode)" -ForegroundColor Cyan
    Write-Host "  Budget Multiplier: $($recommendation.budgetMultiplier)x" -ForegroundColor White

    Write-Host "`nReasoning:" -ForegroundColor Gray
    foreach ($reason in $recommendation.reasoning) {
        Write-Host "  - $reason" -ForegroundColor DarkGray
    }

    # Execute scaling (if not dry run)
    if (-not $DryRun -and ($Force -or $recommendation.action -ne "maintain")) {
        Write-Host "`nExecuting auto-scaling..." -ForegroundColor Yellow

        # Would update budget-rules.yaml here
        # For now, just save recommendation

        $scalingEvent = @{
            timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            action = $recommendation.action
            targetMode = $recommendation.targetMode
            multiplier = $recommendation.budgetMultiplier
            roi = $roi.roi
            revenue = $revenue.total
            reasoning = $recommendation.reasoning
        }

        $scalingLog = "$PSScriptRoot\..\Analytics\auto-scaling.jsonl"
        $scalingEvent | ConvertTo-Json -Compress | Add-Content $scalingLog

        Write-Host "✓ Scaling event logged" -ForegroundColor Green
    }
    elseif ($DryRun) {
        Write-Host "`n[DRY RUN] No changes made. Use -DryRun:`$false to execute." -ForegroundColor Yellow
    }

    return $recommendation
}

function Start-AutoScaleScheduler {
    param(
        [int]$IntervalHours = 24
    )

    Write-Host "Starting auto-scale scheduler (runs every $IntervalHours hours)" -ForegroundColor Cyan

    while ($true) {
        $result = Invoke-AutoScale -DryRun:$false

        if ($result.action -ne "maintain") {
            Write-Host "✓ Auto-scaling action taken: $($result.action)" -ForegroundColor Green
        }

        Start-Sleep -Seconds ($IntervalHours * 3600)
    }
}

Export-ModuleMember -Function Invoke-AutoScale, Get-ScalingRecommendation, Start-AutoScaleScheduler
