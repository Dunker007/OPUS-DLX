<#
.SYNOPSIS
    SEO Optimizer - Advanced on-page SEO optimization

.DESCRIPTION
    Optimizes content for search engines:
    - Keyword density analysis
    - Heading structure optimization
    - Schema markup generation
    - Meta tag optimization
    - Readability scoring
#>

Import-Module "$PSScriptRoot\..\..\Orchestrator\task-router.ps1" -Force

function Get-KeywordDensity {
    param([string]$Content, [string]$Keyword)

    $words = ($Content -split '\s+').Count
    $keywordMatches = ([regex]::Matches($Content, $Keyword, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)).Count

    $density = if ($words -gt 0) { ($keywordMatches / $words) * 100 } else { 0 }

    return @{
        keyword = $Keyword
        occurrences = $keywordMatches
        totalWords = $words
        density = [Math]::Round($density, 2)
        optimal = ($density -ge 1.0 -and $density -le 3.0)
    }
}

function Get-HeadingStructure {
    param([string]$Content)

    $h1Count = ([regex]::Matches($Content, '^#\s+', [System.Text.RegularExpressions.RegexOptions]::Multiline)).Count
    $h2Count = ([regex]::Matches($Content, '^##\s+', [System.Text.RegularExpressions.RegexOptions]::Multiline)).Count
    $h3Count = ([regex]::Matches($Content, '^###\s+', [System.Text.RegularExpressions.RegexOptions]::Multiline)).Count

    return @{
        h1Count = $h1Count
        h2Count = $h2Count
        h3Count = $h3Count
        hasProperStructure = ($h1Count -eq 1 -and $h2Count -ge 3)
        issues = @(
            if ($h1Count -eq 0) { "Missing H1" }
            if ($h1Count -gt 1) { "Multiple H1s (should be 1)" }
            if ($h2Count -lt 3) { "Too few H2s (need 3+)" }
        )
    }
}

function New-SchemaMarkup {
    param(
        [string]$Title,
        [string]$Description,
        [string]$Author = "LuxRig",
        [string]$PublishDate = "",
        [string]$ImageUrl = ""
    )

    if (-not $PublishDate) {
        $PublishDate = (Get-Date).ToString("yyyy-MM-dd")
    }

    $schema = @{
        '@context' = 'https://schema.org'
        '@type' = 'Article'
        headline = $Title
        description = $Description
        author = @{
            '@type' = 'Person'
            name = $Author
        }
        datePublished = $PublishDate
        dateModified = $PublishDate
    }

    if ($ImageUrl) {
        $schema.image = $ImageUrl
    }

    return $schema | ConvertTo-Json -Depth 10
}

function Optimize-MetaTags {
    param(
        [string]$Title,
        [string]$Description,
        [string]$Keyword
    )

    $prompt = @"
Optimize these SEO meta tags:

TITLE: $Title
DESCRIPTION: $Description
KEYWORD: $Keyword

Create:
1. Optimized title tag (50-60 chars, include keyword at start)
2. Meta description (150-160 chars, compelling, include keyword)
3. 5 relevant meta keywords
4. Open Graph title
5. Open Graph description

Return JSON: {title, description, keywords, ogTitle, ogDescription}
"@

    $result = Invoke-TaskRouter -Task $prompt -Priority "low"

    if ($result.success) {
        try { return $result.response | ConvertFrom-Json }
        catch {
            return @{
                title = $Title
                description = $Description
                keywords = @($Keyword)
            }
        }
    }

    return @{title = $Title; description = $Description}
}

function Get-SEOScore {
    param(
        [string]$Content,
        [string]$Title,
        [string]$Description,
        [string]$Keyword
    )

    Write-Host "`n[SEO Optimizer] Analyzing content..." -ForegroundColor Cyan

    $score = 100
    $issues = @()
    $recommendations = @()

    # 1. Keyword density
    $density = Get-KeywordDensity -Content $Content -Keyword $Keyword

    if (-not $density.optimal) {
        $score -= 15
        $issues += "Keyword density $($density.density)% (target: 1-3%)"
        $recommendations += "Adjust keyword usage to 1-3% density"
    }

    # 2. Heading structure
    $headings = Get-HeadingStructure -Content $Content

    if (-not $headings.hasProperStructure) {
        $score -= 20
        $issues += $headings.issues
        $recommendations += "Fix heading structure (1 H1, 3+ H2s)"
    }

    # 3. Content length
    $wordCount = ($Content -split '\s+').Count

    if ($wordCount -lt 800) {
        $score -= 15
        $issues += "Content too short ($wordCount words, target: 800+)"
        $recommendations += "Expand content to at least 800 words"
    }

    # 4. Title length
    if ($Title.Length -lt 30 -or $Title.Length -gt 60) {
        $score -= 10
        $issues += "Title length not optimal ($($Title.Length) chars, target: 30-60)"
    }

    # 5. Description length
    if ($Description.Length -lt 120 -or $Description.Length -gt 160) {
        $score -= 10
        $issues += "Description length not optimal ($($Description.Length) chars, target: 120-160)"
    }

    # 6. Keyword in title
    if ($Title -notmatch [regex]::Escape($Keyword)) {
        $score -= 10
        $issues += "Primary keyword not in title"
        $recommendations += "Include '$Keyword' in the title"
    }

    # 7. Internal/external links
    $links = ([regex]::Matches($Content, '\[.*?\]\(.*?\)')).Count

    if ($links -lt 3) {
        $score -= 10
        $issues += "Too few links ($links, target: 3+)"
        $recommendations += "Add internal and external links"
    }

    # 8. Images
    $images = ([regex]::Matches($Content, '!\[.*?\]\(.*?\)')).Count

    if ($images -eq 0) {
        $score -= 10
        $issues += "No images found"
        $recommendations += "Add relevant images with alt text"
    }

    $grade = switch ($score) {
        {$_ -ge 90} { "A" }
        {$_ -ge 80} { "B" }
        {$_ -ge 70} { "C" }
        {$_ -ge 60} { "D" }
        default { "F" }
    }

    Write-Host "`nSEO Score: $score/100 (Grade: $grade)" -ForegroundColor $(
        if ($score -ge 80) { "Green" }
        elseif ($score -ge 60) { "Yellow" }
        else { "Red" }
    )

    return @{
        score = $score
        grade = $grade
        issues = $issues
        recommendations = $recommendations
        metrics = @{
            keywordDensity = $density
            headings = $headings
            wordCount = $wordCount
            linkCount = $links
            imageCount = $images
        }
    }
}

function Invoke-SEOOptimization {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )

    Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║        SEO OPTIMIZATION - STARTING        ║" -ForegroundColor Yellow
    Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Yellow

    # Read file
    $content = Get-Content $FilePath -Raw

    # Parse frontmatter
    if ($content -match '---\s*([\s\S]*?)\s*---\s*([\s\S]*)') {
        $frontmatter = $Matches[1]
        $body = $Matches[2]

        # Extract metadata
        $title = if ($frontmatter -match 'title:\s*(.+)') { $Matches[1].Trim() } else { "" }
        $description = if ($frontmatter -match 'description:\s*(.+)') { $Matches[1].Trim() } else { "" }
        $keywords = if ($frontmatter -match 'keywords:\s*(.+)') { $Matches[1].Trim() } else { "" }
        $primaryKeyword = ($keywords -split ',')[0].Trim()

        # Analyze SEO
        $seoScore = Get-SEOScore -Content $body -Title $title -Description $description -Keyword $primaryKeyword

        # Generate schema
        $schema = New-SchemaMarkup -Title $title -Description $description

        # Optimize meta tags
        $optimizedMeta = Optimize-MetaTags -Title $title -Description $description -Keyword $primaryKeyword

        # Update frontmatter
        $updatedFrontmatter = @"
---
title: $($optimizedMeta.title)
description: $($optimizedMeta.description)
keywords: $($optimizedMeta.keywords -join ', ')
seoScore: $($seoScore.score)
seoGrade: $($seoScore.grade)
optimized: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
schema: $($schema -replace "`n", " ")
---

$body
"@

        # Save optimized version
        $optimizedPath = $FilePath -replace '\.md$', '-optimized.md'
        $updatedFrontmatter | Set-Content $optimizedPath

        Write-Host "`n✓ SEO optimized version saved: $optimizedPath" -ForegroundColor Green

        return @{
            success = $true
            score = $seoScore.score
            grade = $seoScore.grade
            filepath = $optimizedPath
            recommendations = $seoScore.recommendations
        }
    }
    else {
        Write-Warning "No frontmatter found in file"
        return @{success = $false}
    }
}

Export-ModuleMember -Function Invoke-SEOOptimization, Get-SEOScore, Get-KeywordDensity, New-SchemaMarkup
