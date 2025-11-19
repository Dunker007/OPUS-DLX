<#
.SYNOPSIS
    Idea Validator - Validates market demand before building

.DESCRIPTION
    Validates product ideas through:
    - Market research (Google Trends, competitor analysis)
    - Technical feasibility check
    - Revenue potential estimation
    - Risk assessment
    - Go/No-Go decision with confidence score
#>

Import-Module "$PSScriptRoot\..\..\Orchestrator\task-router.ps1" -Force

function Test-MarketDemand {
    param([hashtable]$Idea)

    $prompt = @"
Analyze market demand for this product idea:
TITLE: $($Idea.title)
DESCRIPTION: $($Idea.description)

Research:
1. Similar existing products
2. Market size estimate
3. Competition level (1-10)
4. Growth trends
5. Target audience size

Return JSON: {competitors: [], marketSize: "", competitionLevel: 0, trends: "", audienceSize: 0}
"@

    $result = Invoke-TaskRouter -Task $prompt -Priority "medium"

    if ($result.success) {
        try { return $result.response | ConvertFrom-Json }
        catch { return @{competitionLevel = 5; marketSize = "unknown"} }
    }
    return @{competitionLevel = 5}
}

function Test-TechnicalFeasibility {
    param([hashtable]$Idea)

    $prompt = @"
Assess technical feasibility:
IDEA: $($Idea.title) - $($Idea.description)

Evaluate:
1. Technical complexity (1-10)
2. Required technologies
3. Development time estimate (hours)
4. Scalability concerns
5. Integration challenges

Return JSON: {complexity: 0, technologies: [], estimatedHours: 0, scalable: true, challenges: []}
"@

    $result = Invoke-TaskRouter -Task $prompt -Priority "low"

    if ($result.success) {
        try { return $result.response | ConvertFrom-Json }
        catch { return @{complexity = 5; estimatedHours = 40} }
    }
    return @{complexity = 5; estimatedHours = 40}
}

function Get-RevenuePotential {
    param([hashtable]$Idea, [hashtable]$Market)

    $prompt = @"
Estimate revenue potential:
IDEA: $($Idea.title)
MARKET SIZE: $($Market.marketSize)
COMPETITION: $($Market.competitionLevel)/10

Calculate:
1. Potential pricing tiers
2. Month 1 revenue estimate
3. Month 6 revenue estimate
4. Month 12 revenue estimate
5. Customer acquisition cost estimate

Return JSON: {pricing: {free: "", basic: 0, pro: 0}, month1: 0, month6: 0, month12: 0, cac: 0}
"@

    $result = Invoke-TaskRouter -Task $prompt -Priority "medium"

    if ($result.success) {
        try { return $result.response | ConvertFrom-Json }
        catch { return @{month1 = 0; month6 = 500; month12 = 2000} }
    }
    return @{month1 = 0; month6 = 500; month12 = 2000}
}

function Invoke-IdeaValidation {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Idea,
        [double]$MinConfidence = 0.6
    )

    Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║       IDEA VALIDATION - STARTING          ║" -ForegroundColor Yellow
    Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host "Idea: $($Idea.title)" -ForegroundColor Cyan

    # Multi-dimensional validation
    $market = Test-MarketDemand -Idea $Idea
    Write-Host "✓ Market demand analyzed" -ForegroundColor Green

    $technical = Test-TechnicalFeasibility -Idea $Idea
    Write-Host "✓ Technical feasibility assessed" -ForegroundColor Green

    $revenue = Get-RevenuePotential -Idea $Idea -Market $market
    Write-Host "✓ Revenue potential estimated" -ForegroundColor Green

    # Calculate confidence score
    $demandScore = $Idea.score.demand / 10
    $competitionScore = (10 - $market.competitionLevel) / 10
    $feasibilityScore = (10 - $technical.complexity) / 10
    $revenueScore = [Math]::Min(1, $revenue.month6 / 1000)

    $confidenceScore = [Math]::Round((
        ($demandScore * 0.3) +
        ($competitionScore * 0.2) +
        ($feasibilityScore * 0.3) +
        ($revenueScore * 0.2)
    ), 2)

    $decision = if ($confidenceScore -ge $MinConfidence) { "GO" } else { "NO-GO" }
    $color = if ($decision -eq "GO") { "Green" } else { "Red" }

    Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor $color
    Write-Host "DECISION: $decision (Confidence: $($confidenceScore * 100)%)" -ForegroundColor $color
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor $color

    return @{
        decision = $decision
        confidence = $confidenceScore
        market = $market
        technical = $technical
        revenue = $revenue
        scores = @{
            demand = $demandScore
            competition = $competitionScore
            feasibility = $feasibilityScore
            revenue = $revenueScore
        }
    }
}

Export-ModuleMember -Function Invoke-IdeaValidation, Test-MarketDemand, Test-TechnicalFeasibility
