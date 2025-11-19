<#
.SYNOPSIS
    Master Orchestrator - Central control for entire LuxRig system

.DESCRIPTION
    Coordinates all LuxRig subsystems:
    - Automated opportunity scanning
    - Idea validation and product building
    - Content generation and publishing
    - API deployment and billing
    - Revenue tracking and optimization
    - Auto-scaling based on performance

.EXAMPLE
    .\master-orchestrator.ps1 -Mode "auto" -Interval 3600

.NOTES
    THIS IS THE BRAIN - Runs continuously, orchestrating entire passive income machine
#>

param(
    [ValidateSet("auto", "manual", "test")]
    [string]$Mode = "auto",

    [int]$Interval = 3600,  # Run cycle every hour

    [switch]$Continuous = $true
)

# Import all subsystems
Import-Module "$PSScriptRoot\task-router.ps1" -Force
Import-Module "$PSScriptRoot\budget-manager.ps1" -Force
Import-Module "$PSScriptRoot\roi-calculator.ps1" -Force
Import-Module "$PSScriptRoot\auto-scaler.ps1" -Force
Import-Module "$PSScriptRoot\..\Engines\ContentEngine\opportunity-scanner.ps1" -Force
Import-Module "$PSScriptRoot\..\Engines\ProductEngine\idea-validator.ps1" -Force
Import-Module "$PSScriptRoot\..\Engines\ProductEngine\tool-builder.ps1" -Force
Import-Module "$PSScriptRoot\..\Engines\ContentEngine\content-generator.ps1" -Force
Import-Module "$PSScriptRoot\..\Analytics\revenue-tracker.ps1" -Force
Import-Module "$PSScriptRoot\..\Analytics\analytics-collector.ps1" -Force

function Invoke-OrchestrationCycle {
    $cycleStart = Get-Date

    Write-Host "`n╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║                  LUXRIG ORCHESTRATION CYCLE                      ║" -ForegroundColor Magenta
    Write-Host "║                  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')                       ║" -ForegroundColor Magenta
    Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta

    $summary = @{
        opportunities = 0
        ideas_validated = 0
        products_built = 0
        content_created = 0
        revenue_generated = 0
        actions_taken = @()
    }

    # PHASE 1: Scan for opportunities
    Write-Host "`n[PHASE 1] Scanning for opportunities..." -ForegroundColor Cyan
    try {
        $opportunities = Find-Opportunities -Source "all" -Limit 20 -SaveToFile
        $summary.opportunities = $opportunities.Count
        $summary.actions_taken += "Scanned $($opportunities.Count) opportunities"
        Write-Host "✓ Found $($opportunities.Count) opportunities" -ForegroundColor Green
    }
    catch {
        Write-Warning "Opportunity scanning failed: $_"
    }

    # PHASE 2: Validate top ideas
    Write-Host "`n[PHASE 2] Validating top ideas..." -ForegroundColor Cyan
    $topOpportunities = $opportunities | Select-Object -First 3

    foreach ($opp in $topOpportunities) {
        try {
            $validation = Invoke-IdeaValidation -Idea $opp -MinConfidence 0.6

            if ($validation.decision -eq "GO") {
                $summary.ideas_validated++
                $summary.actions_taken += "Validated: $($opp.title) (Confidence: $($validation.confidence))"

                # PHASE 3: Build product if validated
                Write-Host "`n[PHASE 3] Building product: $($opp.title)..." -ForegroundColor Cyan

                $product = Build-MicroSaaS -Idea $opp -GenerateFrontend -GenerateLanding

                if ($product.success) {
                    $summary.products_built++
                    $summary.actions_taken += "Built product: $($product.project)"
                    Write-Host "✓ Product built: $($product.project)" -ForegroundColor Green
                }
            }
        }
        catch {
            Write-Warning "Product building failed for $($opp.title): $_"
        }
    }

    # PHASE 4: Generate content
    Write-Host "`n[PHASE 4] Generating content..." -ForegroundColor Cyan

    $contentTopics = @(
        "How to automate passive income with AI in 2024",
        "Best micro-SaaS ideas for solo developers",
        "AI-powered content creation: Complete guide"
    )

    foreach ($topic in $contentTopics | Select-Object -First 1) {
        try {
            $content = Invoke-ContentGeneration -Topic $topic -WordCount 1500 -QualityCheck

            if ($content.success) {
                $summary.content_created++
                $summary.actions_taken += "Created content: $($content.title)"
                Write-Host "✓ Content created: $($content.title)" -ForegroundColor Green
            }
        }
        catch {
            Write-Warning "Content generation failed for $topic: $_"
        }
    }

    # PHASE 5: Check revenue and optimize
    Write-Host "`n[PHASE 5] Revenue analysis and optimization..." -ForegroundColor Cyan

    try {
        $revenue = Get-TotalRevenue -Period "month"
        $summary.revenue_generated = $revenue.total

        $roi = Get-ROIMetrics -Period "month"

        # Auto-scale if needed
        $scaling = Invoke-AutoScale -DryRun:$false

        if ($scaling.action -ne "maintain") {
            $summary.actions_taken += "Auto-scaled: $($scaling.action) to $($scaling.targetMode) mode"
        }

        Write-Host "✓ Revenue: `$$($revenue.total) | ROI: $($roi.roi)%" -ForegroundColor Green
    }
    catch {
        Write-Warning "Revenue analysis failed: $_"
    }

    # PHASE 6: Analytics and reporting
    Write-Host "`n[PHASE 6] Collecting analytics..." -ForegroundColor Cyan

    try {
        $analytics = Get-AnalyticsDashboard
        Write-Host "✓ Analytics updated" -ForegroundColor Green
    }
    catch {
        Write-Warning "Analytics collection failed: $_"
    }

    # Summary
    $cycleEnd = Get-Date
    $cycleDuration = ($cycleEnd - $cycleStart).TotalSeconds

    Write-Host "`n╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                    CYCLE COMPLETE                                ║" -ForegroundColor Green
    Write-Host "╠══════════════════════════════════════════════════════════════════╣" -ForegroundColor Green
    Write-Host "║ Duration: $cycleDuration seconds".PadRight(67) + "║" -ForegroundColor White
    Write-Host "║ Opportunities Scanned: $($summary.opportunities)".PadRight(67) + "║" -ForegroundColor White
    Write-Host "║ Ideas Validated: $($summary.ideas_validated)".PadRight(67) + "║" -ForegroundColor White
    Write-Host "║ Products Built: $($summary.products_built)".PadRight(67) + "║" -ForegroundColor White
    Write-Host "║ Content Created: $($summary.content_created)".PadRight(67) + "║" -ForegroundColor White
    Write-Host "║ Revenue This Month: `$$($summary.revenue_generated)".PadRight(67) + "║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Green

    # Save cycle summary
    $summary.timestamp = $cycleStart.ToString("yyyy-MM-dd HH:mm:ss")
    $summary.duration = $cycleDuration

    $summaryFile = "$PSScriptRoot\..\Analytics\orchestration-cycles.jsonl"
    $summary | ConvertTo-Json -Compress | Add-Content $summaryFile

    return $summary
}

# Main execution
if ($Mode -eq "auto" -and $Continuous) {
    Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          LUXRIG MASTER ORCHESTRATOR - AUTO MODE                  ║" -ForegroundColor Cyan
    Write-Host "║          Running continuous cycles every $Interval seconds               ║" -ForegroundColor Cyan
    Write-Host "║          Press Ctrl+C to stop                                    ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

    while ($true) {
        Invoke-OrchestrationCycle
        Write-Host "`nNext cycle in $Interval seconds..." -ForegroundColor Gray
        Start-Sleep -Seconds $Interval
    }
}
elseif ($Mode -eq "test") {
    Write-Host "Running single test cycle..." -ForegroundColor Yellow
    Invoke-OrchestrationCycle
}
else {
    Write-Host "Manual mode - call Invoke-OrchestrationCycle to run a cycle" -ForegroundColor Yellow
}

Export-ModuleMember -Function Invoke-OrchestrationCycle
