<#
.SYNOPSIS
    AI Content Generator - Creates SEO-optimized articles at scale

.DESCRIPTION
    Generates high-quality content:
    - Blog posts, articles, guides
    - SEO keyword optimization
    - Automatic image suggestions
    - Internal linking strategy
    - Multi-AI quality verification
#>

Import-Module "$PSScriptRoot\..\..\Orchestrator\task-router.ps1" -Force
Import-Module "$PSScriptRoot\..\..\Orchestrator\quality-gates.ps1" -Force

function New-ContentBrief {
    param(
        [string]$Topic,
        [string]$Keyword,
        [int]$WordCount = 1500,
        [string]$Tone = "professional"
    )

    $prompt = @"
Create a detailed content brief for:
TOPIC: $Topic
PRIMARY KEYWORD: $Keyword
TARGET WORD COUNT: $WordCount
TONE: $Tone

Generate:
1. SEO-optimized title (include keyword)
2. Meta description (155 chars max)
3. Outline with H2/H3 headings
4. LSI keywords to include
5. Content angle/hook
6. Call-to-action

Return as JSON: {title, metaDescription, outline, lsiKeywords, angle, cta}
"@

    $result = Invoke-TaskRouter -Task $prompt -Priority "medium" -TaskType "creative"

    if ($result.success) {
        try { return $result.response | ConvertFrom-Json }
        catch {
            return @{
                title = $Topic
                outline = @("Introduction", "Main Content", "Conclusion")
            }
        }
    }
    return @{title = $Topic}
}

function New-Article {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Brief,
        [int]$WordCount = 1500
    )

    Write-Host "[Content Generator] Writing article: $($Brief.title)" -ForegroundColor Cyan

    $prompt = @"
Write a complete, SEO-optimized article:

TITLE: $($Brief.title)
OUTLINE: $($Brief.outline -join ' | ')
KEYWORDS: $($Brief.lsiKeywords -join ', ')
WORD COUNT: $WordCount
TONE: Professional, engaging, informative

Requirements:
- Use markdown formatting (H2, H3, lists, bold)
- Include keyword naturally (2-3% density)
- Add actionable insights
- Include statistics/examples
- End with strong CTA
- Write for humans, optimize for SEO

Output complete markdown article ready to publish.
"@

    $result = Invoke-TaskRouter -Task $prompt -Priority "high" -TaskType "creative"

    if ($result.success) {
        return @{
            content = $result.response
            wordCount = ($result.response -split '\s+').Count
            success = $true
        }
    }
    return @{success = $false}
}

function Add-InternalLinks {
    param(
        [string]$Content,
        [string[]]$RelatedUrls = @()
    )

    if ($RelatedUrls.Count -eq 0) { return $Content }

    $prompt = @"
Add 2-3 natural internal links to this content:

CONTENT: $Content

AVAILABLE LINKS:
$($RelatedUrls -join "`n")

Return the full content with markdown links added contextually.
Only link where it makes sense naturally.
"@

    $result = Invoke-TaskRouter -Task $prompt -Priority "low"

    if ($result.success) { return $result.response }
    return $Content
}

function New-ImageSuggestions {
    param([string]$Title, [string]$Content)

    $prompt = @"
Suggest 3-5 images for this article:
TITLE: $Title

For each image suggest:
1. Description
2. Alt text (SEO optimized)
3. Placement (where in article)
4. Unsplash search query

Return JSON array: [{description, altText, placement, unsplashQuery}]
"@

    $result = Invoke-TaskRouter -Task $prompt -Priority "low"

    if ($result.success) {
        try { return $result.response | ConvertFrom-Json }
        catch { return @() }
    }
    return @()
}

function Invoke-ContentGeneration {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Topic,

        [string]$Keyword = "",

        [int]$WordCount = 1500,

        [string]$OutputPath = "$PSScriptRoot\..\..\Content\raw",

        [switch]$QualityCheck = $true,

        [string[]]$RelatedUrls = @()
    )

    Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║     CONTENT GENERATION - STARTING         ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Cyan

    try {
        # Step 1: Create content brief
        $brief = New-ContentBrief -Topic $Topic -Keyword $Keyword -WordCount $WordCount
        Write-Host "✓ Content brief created" -ForegroundColor Green

        # Step 2: Generate article
        $article = New-Article -Brief $brief -WordCount $WordCount

        if (-not $article.success) {
            throw "Article generation failed"
        }

        Write-Host "✓ Article written ($($article.wordCount) words)" -ForegroundColor Green

        # Step 3: Add internal links
        if ($RelatedUrls.Count -gt 0) {
            $article.content = Add-InternalLinks -Content $article.content -RelatedUrls $RelatedUrls
            Write-Host "✓ Internal links added" -ForegroundColor Green
        }

        # Step 4: Quality check
        if ($QualityCheck) {
            $quality = Test-ContentQuality -Content $article.content -Type "article"

            if (-not $quality.passed) {
                Write-Warning "Quality check failed: $($quality.issues -join ', ')"
                Write-Host "Continuing anyway (review recommended)..." -ForegroundColor Yellow
            }
            else {
                Write-Host "✓ Quality check passed (Score: $($quality.score)/100)" -ForegroundColor Green
            }
        }

        # Step 5: Generate image suggestions
        $images = New-ImageSuggestions -Title $brief.title -Content $article.content
        Write-Host "✓ Image suggestions generated ($($images.Count) images)" -ForegroundColor Green

        # Step 6: Save content
        $filename = $brief.title -replace '[^a-zA-Z0-9]', '-' -replace '-+', '-'
        $filename = $filename.ToLower() + ".md"
        $filepath = Join-Path $OutputPath $filename

        if (-not (Test-Path $OutputPath)) {
            New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        }

        # Create frontmatter
        $frontmatter = @"
---
title: $($brief.title)
description: $($brief.metaDescription)
keywords: $($brief.lsiKeywords -join ', ')
wordCount: $($article.wordCount)
generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
status: draft
---

$($article.content)
"@

        $frontmatter | Set-Content $filepath

        # Save metadata
        @{
            title = $brief.title
            brief = $brief
            filepath = $filepath
            wordCount = $article.wordCount
            images = $images
            qualityScore = if ($QualityCheck) { $quality.score } else { 0 }
            generated = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        } | ConvertTo-Json -Depth 10 | Set-Content ($filepath -replace '\.md$', '.json')

        Write-Host "`n✓ Content saved to: $filepath" -ForegroundColor Green

        return @{
            success = $true
            filepath = $filepath
            title = $brief.title
            wordCount = $article.wordCount
        }
    }
    catch {
        Write-Host "✗ Content generation failed: $_" -ForegroundColor Red
        return @{success = $false; error = $_.Exception.Message}
    }
}

Export-ModuleMember -Function Invoke-ContentGeneration, New-ContentBrief, New-Article
