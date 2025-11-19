<#
.SYNOPSIS
    Task Router - Intelligent AI Orchestration System for LuxRig

.DESCRIPTION
    Routes tasks to optimal AI models based on:
    - Task complexity analysis (keywords, length, requirements)
    - Current budget allocation (remaining quota)
    - AI availability (rate limits, health status)
    - Fallback chains (Premium → Mid-tier → Local)

.EXAMPLE
    $result = Invoke-TaskRouter -Task "Generate a landing page for a SaaS product" -Priority "high"

.NOTES
    Part of LuxRig Phase 1 Foundation
    This is the brain of the AI orchestration system
#>

# Import all AI plugins
Import-Module "$PSScriptRoot\ai-plugins\claude-plugin.ps1" -Force
Import-Module "$PSScriptRoot\ai-plugins\gpt-plugin.ps1" -Force
Import-Module "$PSScriptRoot\ai-plugins\gemini-plugin.ps1" -Force
Import-Module "$PSScriptRoot\ai-plugins\grok-plugin.ps1" -Force
Import-Module "$PSScriptRoot\ai-plugins\local-plugin.ps1" -Force

# Import budget manager
. "$PSScriptRoot\budget-manager.ps1"

# Task complexity analyzer
function Get-TaskComplexity {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Task,

        [hashtable]$Metadata = @{}
    )

    $complexity = @{
        score = 0
        tier = 3  # Default to local models
        reasoning = @()
    }

    # High-complexity keywords (Tier 1 - Premium)
    $tier1Keywords = @(
        "strategy", "strategic", "creative", "design", "architecture",
        "ethical", "legal", "compliance", "review", "audit",
        "business plan", "marketing strategy", "brand voice",
        "complex analysis", "multi-step", "orchestrate"
    )

    # Mid-complexity keywords (Tier 2 - Mid-tier)
    $tier2Keywords = @(
        "code", "programming", "debug", "api", "integrate",
        "research", "analyze", "compare", "summarize",
        "documentation", "technical", "implementation",
        "generate content", "write article", "seo"
    )

    # Check for tier 1 keywords
    foreach ($keyword in $tier1Keywords) {
        if ($Task -match $keyword) {
            $complexity.score += 10
            $complexity.reasoning += "Contains tier-1 keyword: $keyword"
        }
    }

    # Check for tier 2 keywords
    foreach ($keyword in $tier2Keywords) {
        if ($Task -match $keyword) {
            $complexity.score += 5
            $complexity.reasoning += "Contains tier-2 keyword: $keyword"
        }
    }

    # Length-based complexity
    if ($Task.Length -gt 1000) {
        $complexity.score += 8
        $complexity.reasoning += "Long task description (>1000 chars)"
    }
    elseif ($Task.Length -gt 500) {
        $complexity.score += 4
        $complexity.reasoning += "Medium task description (>500 chars)"
    }

    # Check metadata for explicit priority
    if ($Metadata.priority -eq "high" -or $Metadata.priority -eq "critical") {
        $complexity.score += 15
        $complexity.reasoning += "Explicit high priority set"
    }
    elseif ($Metadata.priority -eq "medium") {
        $complexity.score += 5
        $complexity.reasoning += "Explicit medium priority set"
    }

    # Determine tier based on score
    if ($complexity.score -ge 15) {
        $complexity.tier = 1  # Premium AI
    }
    elseif ($complexity.score -ge 5) {
        $complexity.tier = 2  # Mid-tier AI
    }
    else {
        $complexity.tier = 3  # Local models
    }

    return $complexity
}

# AI selection based on complexity and availability
function Select-OptimalAI {
    param(
        [int]$RequiredTier,
        [string]$TaskType = "general",
        [hashtable]$BudgetStatus
    )

    # Define AI preferences by tier and task type
    $aiPreferences = @{
        1 = @{  # Premium tier
            strategy = @("claude", "grok", "gpt4")
            code = @("gpt4", "claude", "gemini")
            creative = @("claude", "grok", "gpt4")
            analysis = @("claude", "gpt4", "gemini")
            general = @("claude", "gpt4", "gemini", "grok")
        }
        2 = @{  # Mid-tier
            general = @("gemini", "gpt4")
        }
        3 = @{  # Local models
            general = @("local")
        }
    }

    # Get preferred AIs for this tier and task type
    $preferredAIs = $aiPreferences[$RequiredTier][$TaskType]
    if (-not $preferredAIs) {
        $preferredAIs = $aiPreferences[$RequiredTier]["general"]
    }

    # Check each preferred AI for budget availability
    foreach ($aiName in $preferredAIs) {
        $budgetKey = $aiName -replace '\d', ''  # Remove numbers from name

        if ($BudgetStatus.models.$budgetKey.remaining_budget -gt 0) {
            return $aiName
        }
    }

    # If no AI available at this tier, try fallback to next tier
    if ($RequiredTier -eq 1) {
        Write-Warning "Tier 1 budget exhausted, falling back to Tier 2"
        return Select-OptimalAI -RequiredTier 2 -TaskType $TaskType -BudgetStatus $BudgetStatus
    }
    elseif ($RequiredTier -eq 2) {
        Write-Warning "Tier 2 budget exhausted, falling back to Tier 3 (local)"
        return "local"
    }
    else {
        return "local"  # Always fallback to local
    }
}

# Main routing function
function Invoke-TaskRouter {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Task,

        [string]$SystemPrompt = "",

        [string]$Priority = "medium",

        [string]$TaskType = "general",

        [hashtable]$Options = @{}
    )

    Write-Host "`n=== LuxRig Task Router ===" -ForegroundColor Cyan
    Write-Host "Task: $($Task.Substring(0, [Math]::Min(100, $Task.Length)))..." -ForegroundColor Gray

    # Analyze task complexity
    $metadata = @{ priority = $Priority; task_type = $TaskType }
    $complexity = Get-TaskComplexity -Task $Task -Metadata $metadata

    Write-Host "Complexity Analysis:" -ForegroundColor Yellow
    Write-Host "  Score: $($complexity.score)" -ForegroundColor Gray
    Write-Host "  Tier: $($complexity.tier)" -ForegroundColor Gray
    foreach ($reason in $complexity.reasoning) {
        Write-Host "  - $reason" -ForegroundColor DarkGray
    }

    # Get current budget status
    $budgetStatus = Get-BudgetStatus

    Write-Host "`nBudget Status:" -ForegroundColor Yellow
    Write-Host "  Total Spent: `$$($budgetStatus.total_spent)" -ForegroundColor Gray
    Write-Host "  Total Remaining: `$$($budgetStatus.total_remaining)" -ForegroundColor Gray

    # Select optimal AI
    $selectedAI = Select-OptimalAI -RequiredTier $complexity.tier -TaskType $TaskType -BudgetStatus $budgetStatus

    Write-Host "`nSelected AI: $selectedAI" -ForegroundColor Green

    # Route to selected AI
    $result = $null
    $startTime = Get-Date

    try {
        switch -Regex ($selectedAI) {
            "claude" {
                Write-Host "Routing to Claude (Anthropic)..." -ForegroundColor Cyan
                $result = Invoke-ClaudeAPI -Prompt $Task -SystemPrompt $SystemPrompt -Metadata $metadata
            }
            "gpt4" {
                Write-Host "Routing to GPT-4 (OpenAI)..." -ForegroundColor Cyan
                $result = Invoke-GPTAPI -Prompt $Task -SystemPrompt $SystemPrompt -Metadata $metadata
            }
            "gemini" {
                Write-Host "Routing to Gemini (Google)..." -ForegroundColor Cyan
                $result = Invoke-GeminiAPI -Prompt $Task -SystemPrompt $SystemPrompt -Metadata $metadata
            }
            "grok" {
                Write-Host "Routing to Grok (X.AI)..." -ForegroundColor Cyan
                $result = Invoke-GrokAPI -Prompt $Task -SystemPrompt $SystemPrompt -Metadata $metadata
            }
            "local" {
                Write-Host "Routing to Local Models (Ollama/LM Studio)..." -ForegroundColor Cyan
                $result = Invoke-LocalAPI -Prompt $Task -SystemPrompt $SystemPrompt -Metadata $metadata
            }
            default {
                throw "Unknown AI provider: $selectedAI"
            }
        }

        $endTime = Get-Date
        $totalDuration = ($endTime - $startTime).TotalSeconds

        # Update budget tracking
        if ($result.success -and $result.usage.cost -gt 0) {
            Update-BudgetSpend -Provider $result.provider -Cost $result.usage.cost -Tokens $result.usage.total_tokens
        }

        # Display result summary
        if ($result.success) {
            Write-Host "`n✓ Task completed successfully!" -ForegroundColor Green
            Write-Host "  Model: $($result.model)" -ForegroundColor Gray
            Write-Host "  Tokens: $($result.usage.total_tokens)" -ForegroundColor Gray
            Write-Host "  Cost: `$$([Math]::Round($result.usage.cost, 4))" -ForegroundColor Gray
            Write-Host "  Duration: $([Math]::Round($totalDuration, 2))s" -ForegroundColor Gray
        }
        else {
            Write-Host "`n✗ Task failed!" -ForegroundColor Red
            Write-Host "  Error: $($result.error)" -ForegroundColor Red
        }

        return $result
    }
    catch {
        Write-Host "`n✗ Routing failed: $_" -ForegroundColor Red

        return @{
            success = $false
            provider = $selectedAI
            error = $_.Exception.Message
            duration = ((Get-Date) - $startTime).TotalSeconds
        }
    }
}

# Export main function
Export-ModuleMember -Function Invoke-TaskRouter, Get-TaskComplexity, Select-OptimalAI
