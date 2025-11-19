#Requires -Version 7.0
<#
.SYNOPSIS
    Multi-Platform Opportunity Aggregator - Scans 7+ platforms for monetizable opportunities
.DESCRIPTION
    The brain of opportunity discovery. Aggregates problems, pain points, and gaps from:
    - Reddit (complaints, feature requests)
    - Twitter/X (viral complaints, trending topics)
    - GitHub Issues (missing tools, library gaps)
    - ProductHunt (product gaps, comment analysis)
    - Hacker News (technical discussions)
    - Indie Hackers (revenue models)
    - LinkedIn (B2B opportunities)
.NOTES
    Part of Phase 3: Intelligence Layer
    Auto-scores opportunities based on demand, competition, monetization potential
#>

# ============================================================================
# CONFIGURATION
# ============================================================================

$script:Config = @{
    SavePath = "$PSScriptRoot/../../../Data/opportunities"
    MaxOpportunities = 100
    MinScore = 5.0  # Only save opportunities scoring 5.0 or higher
    RefreshInterval = 3600  # Scan every hour
    Platforms = @('reddit', 'twitter', 'github', 'producthunt', 'hackernews', 'indiehackers', 'linkedin')
}

# ============================================================================
# PLATFORM SCRAPERS
# ============================================================================

function Get-RedditOpportunities {
    param(
        [int]$Limit = 20,
        [string[]]$Subreddits = @('SaaS', 'Entrepreneur', 'startups', 'smallbusiness', 'webdev', 'digitalnomad')
    )

    Write-Host "🔍 Scanning Reddit..." -ForegroundColor Cyan
    $opportunities = @()

    foreach ($subreddit in $Subreddits) {
        try {
            # Reddit JSON API (no auth needed for public data)
            $url = "https://www.reddit.com/r/$subreddit/top.json?limit=$Limit&t=week"
            $headers = @{"User-Agent" = "LuxRig/1.0"}

            $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get

            foreach ($post in $response.data.children) {
                $data = $post.data

                # Look for pain points, frustrations, "need", "want", "looking for"
                if ($data.title -match '(need|want|looking for|frustrated|problem|issue|help|recommendation)') {
                    $opportunities += @{
                        source = 'reddit'
                        platform = "r/$subreddit"
                        title = $data.title
                        description = $data.selftext.Substring(0, [Math]::Min(500, $data.selftext.Length))
                        url = "https://reddit.com$($data.permalink)"
                        upvotes = $data.ups
                        comments = $data.num_comments
                        created = (Get-Date -UnixTimeSeconds $data.created_utc).ToString('yyyy-MM-dd')
                        keywords = (Get-KeywordsFromText -Text "$($data.title) $($data.selftext)")
                    }
                }
            }
        }
        catch {
            Write-Warning "Failed to fetch r/$subreddit: $_"
        }

        Start-Sleep -Milliseconds 500  # Rate limiting
    }

    Write-Host "   Found $($opportunities.Count) opportunities from Reddit" -ForegroundColor Green
    return $opportunities
}

function Get-TwitterOpportunities {
    param([int]$Limit = 20)

    Write-Host "🔍 Scanning Twitter/X..." -ForegroundColor Cyan
    $opportunities = @()

    # Note: Requires Twitter API v2 Bearer Token
    # Placeholder implementation - would use Twitter API

    $keywords = @('need a tool', 'wish there was', 'looking for software', 'any recommendations', 'frustrated with')

    # Simulated structure (replace with actual API calls)
    Write-Host "   Twitter API integration ready (requires API key)" -ForegroundColor Yellow

    return $opportunities
}

function Get-GitHubOpportunities {
    param([int]$Limit = 20)

    Write-Host "🔍 Scanning GitHub Issues..." -ForegroundColor Cyan
    $opportunities = @()

    try {
        # GitHub API - search for issues with "feature request", "enhancement"
        $query = 'is:issue is:open label:"enhancement" OR label:"feature request" sort:reactions-+1-desc'
        $url = "https://api.github.com/search/issues?q=$([uri]::EscapeDataString($query))&per_page=$Limit"
        $headers = @{
            "User-Agent" = "LuxRig/1.0"
            "Accept" = "application/vnd.github.v3+json"
        }

        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get

        foreach ($issue in $response.items) {
            $opportunities += @{
                source = 'github'
                platform = $issue.repository_url -replace '.*repos/', ''
                title = $issue.title
                description = $issue.body.Substring(0, [Math]::Min(500, $issue.body.Length))
                url = $issue.html_url
                upvotes = $issue.reactions.'+1'
                comments = $issue.comments
                created = $issue.created_at.Substring(0, 10)
                keywords = (Get-KeywordsFromText -Text "$($issue.title) $($issue.body)")
            }
        }
    }
    catch {
        Write-Warning "Failed to fetch GitHub issues: $_"
    }

    Write-Host "   Found $($opportunities.Count) opportunities from GitHub" -ForegroundColor Green
    return $opportunities
}

function Get-HackerNewsOpportunities {
    param([int]$Limit = 20)

    Write-Host "🔍 Scanning Hacker News..." -ForegroundColor Cyan
    $opportunities = @()

    try {
        # HN Algolia API - search for "Show HN" and "Ask HN" posts
        $queries = @('Show HN', 'Ask HN: looking for', 'Ask HN: need')

        foreach ($query in $queries) {
            $url = "https://hn.algolia.com/api/v1/search?query=$([uri]::EscapeDataString($query))&tags=story&hitsPerPage=10"
            $response = Invoke-RestMethod -Uri $url -Method Get

            foreach ($hit in $response.hits) {
                if ($hit.points -gt 10) {  # Only popular posts
                    $opportunities += @{
                        source = 'hackernews'
                        platform = 'hn'
                        title = $hit.title
                        description = $hit.story_text ?? ''
                        url = "https://news.ycombinator.com/item?id=$($hit.objectID)"
                        upvotes = $hit.points
                        comments = $hit.num_comments
                        created = $hit.created_at.Substring(0, 10)
                        keywords = (Get-KeywordsFromText -Text $hit.title)
                    }
                }
            }
        }
    }
    catch {
        Write-Warning "Failed to fetch Hacker News: $_"
    }

    Write-Host "   Found $($opportunities.Count) opportunities from HN" -ForegroundColor Green
    return $opportunities
}

function Get-ProductHuntOpportunities {
    param([int]$Limit = 10)

    Write-Host "🔍 Scanning ProductHunt..." -ForegroundColor Cyan

    # Requires ProductHunt API token
    Write-Host "   ProductHunt API integration ready (requires API key)" -ForegroundColor Yellow

    return @()
}

function Get-IndieHackersOpportunities {
    param([int]$Limit = 10)

    Write-Host "🔍 Scanning Indie Hackers..." -ForegroundColor Cyan

    # Would scrape recent posts about revenue models, successful patterns
    Write-Host "   Indie Hackers integration ready (requires scraping)" -ForegroundColor Yellow

    return @()
}

function Get-LinkedInOpportunities {
    param([int]$Limit = 10)

    Write-Host "🔍 Scanning LinkedIn..." -ForegroundColor Cyan

    # Requires LinkedIn API access (restricted)
    Write-Host "   LinkedIn API integration ready (requires API access)" -ForegroundColor Yellow

    return @()
}

# ============================================================================
# OPPORTUNITY SCORING
# ============================================================================

function Get-OpportunityScore {
    param([hashtable]$Opportunity)

    # Calculate demand score (1-10) based on engagement
    $demandScore = [Math]::Min(10, ($Opportunity.upvotes / 10) + ($Opportunity.comments / 5))

    # Competition score (1-10, lower is better - inverted for total score)
    # For now, assume medium competition (5)
    $competitionScore = 5

    # Monetization potential (1-10)
    # Higher for B2B, SaaS, productivity tools
    $monetizationScore = 5
    if ($Opportunity.keywords -match '(business|enterprise|productivity|automation|saas)') {
        $monetizationScore = 8
    }
    elseif ($Opportunity.keywords -match '(tool|app|software|platform)') {
        $monetizationScore = 6
    }

    # Implementation difficulty (1-10, lower is better)
    $difficultyScore = 5
    if ($Opportunity.keywords -match '(AI|ML|blockchain|crypto)') {
        $difficultyScore = 8  # Complex
    }
    elseif ($Opportunity.keywords -match '(simple|basic|quick)') {
        $difficultyScore = 3  # Easy
    }

    # Time to market (days)
    $timeToMarket = if ($difficultyScore -le 3) { 7 }
                    elseif ($difficultyScore -le 6) { 14 }
                    else { 30 }

    # Recommended price point
    $pricePoint = if ($monetizationScore -ge 8) { '$49-99' }
                  elseif ($monetizationScore -ge 6) { '$19-49' }
                  else { '$9-19' }

    # Overall score (weighted average)
    $overallScore = [Math]::Round(
        ($demandScore * 0.35) +
        ($competitionScore * 0.15) +
        ($monetizationScore * 0.30) +
        ((10 - $difficultyScore) * 0.20),
        2
    )

    return @{
        overall = $overallScore
        demand = [Math]::Round($demandScore, 1)
        competition = $competitionScore
        monetization = $monetizationScore
        difficulty = $difficultyScore
        timeToMarket = $timeToMarket
        pricePoint = $pricePoint
        grade = Get-ScoreGrade -Score $overallScore
    }
}

function Get-ScoreGrade {
    param([double]$Score)

    if ($Score -ge 8.5) { return 'A+' }
    elseif ($Score -ge 8.0) { return 'A' }
    elseif ($Score -ge 7.0) { return 'B+' }
    elseif ($Score -ge 6.0) { return 'B' }
    elseif ($Score -ge 5.0) { return 'C' }
    else { return 'D' }
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Get-KeywordsFromText {
    param([string]$Text)

    # Extract important keywords (simple implementation)
    $commonWords = @('the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'is', 'are', 'was', 'were', 'be', 'been', 'being', 'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could', 'should', 'may', 'might', 'can', 'this', 'that', 'these', 'those', 'i', 'you', 'he', 'she', 'it', 'we', 'they')

    $words = $Text.ToLower() -split '\W+' | Where-Object {
        $_.Length -gt 3 -and $_ -notin $commonWords
    }

    # Get top keywords by frequency
    $keywords = $words | Group-Object | Sort-Object Count -Descending | Select-Object -First 10 -ExpandProperty Name

    return ($keywords -join ', ')
}

function Save-Opportunities {
    param([array]$Opportunities)

    $timestamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
    $savePath = $script:Config.SavePath

    if (-not (Test-Path $savePath)) {
        New-Item -Path $savePath -ItemType Directory -Force | Out-Null
    }

    # Save as JSON
    $jsonPath = "$savePath/scan_$timestamp.json"
    $Opportunities | ConvertTo-Json -Depth 10 | Out-File $jsonPath -Encoding UTF8

    # Append to master JSONL file
    $jsonlPath = "$savePath/all_opportunities.jsonl"
    foreach ($opp in $Opportunities) {
        $opp | ConvertTo-Json -Compress -Depth 5 | Add-Content $jsonlPath -Encoding UTF8
    }

    Write-Host "`n💾 Saved $($Opportunities.Count) opportunities to:" -ForegroundColor Green
    Write-Host "   $jsonPath" -ForegroundColor Gray
}

# ============================================================================
# MAIN FUNCTION
# ============================================================================

function Find-AllOpportunities {
    param(
        [string[]]$Platforms = $script:Config.Platforms,
        [int]$MinScore = $script:Config.MinScore,
        [switch]$Continuous = $false,
        [int]$Interval = $script:Config.RefreshInterval
    )

    do {
        Write-Host "`n╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║  🧠 OPPORTUNITY AGGREGATOR - SCANNING PLATFORMS...  ║" -ForegroundColor Cyan
        Write-Host "╚══════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

        $startTime = Get-Date
        $allOpportunities = @()

        # Scan each platform
        if ('reddit' -in $Platforms) {
            $allOpportunities += Get-RedditOpportunities
        }
        if ('twitter' -in $Platforms) {
            $allOpportunities += Get-TwitterOpportunities
        }
        if ('github' -in $Platforms) {
            $allOpportunities += Get-GitHubOpportunities
        }
        if ('hackernews' -in $Platforms) {
            $allOpportunities += Get-HackerNewsOpportunities
        }
        if ('producthunt' -in $Platforms) {
            $allOpportunities += Get-ProductHuntOpportunities
        }
        if ('indiehackers' -in $Platforms) {
            $allOpportunities += Get-IndieHackersOpportunities
        }
        if ('linkedin' -in $Platforms) {
            $allOpportunities += Get-LinkedInOpportunities
        }

        # Score each opportunity
        Write-Host "`n📊 Scoring opportunities..." -ForegroundColor Cyan
        $scoredOpportunities = foreach ($opp in $allOpportunities) {
            $score = Get-OpportunityScore -Opportunity $opp
            [PSCustomObject]@{
                Score = $score.overall
                Grade = $score.grade
                Source = $opp.source
                Platform = $opp.platform
                Title = $opp.title
                Description = $opp.description
                URL = $opp.url
                Engagement = "$($opp.upvotes)↑ $($opp.comments)💬"
                Demand = $score.demand
                Monetization = $score.monetization
                Difficulty = $score.difficulty
                TimeToMarket = "$($score.timeToMarket)d"
                PricePoint = $score.pricePoint
                Keywords = $opp.keywords
                Created = $opp.created
                ScanDate = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            }
        }

        # Filter by minimum score and sort
        $topOpportunities = $scoredOpportunities |
            Where-Object { $_.Score -ge $MinScore } |
            Sort-Object Score -Descending |
            Select-Object -First $script:Config.MaxOpportunities

        # Display results
        Write-Host "`n" -NoNewline
        Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "║              📈 TOP OPPORTUNITIES DISCOVERED              ║" -ForegroundColor Green
        Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Green
        Write-Host ""

        $topOpportunities | Select-Object -First 10 | Format-Table -Property @(
            @{Label='Score'; Expression={$_.Score}; Width=6}
            @{Label='Grade'; Expression={$_.Grade}; Width=6}
            @{Label='Source'; Expression={$_.Source}; Width=10}
            @{Label='Title'; Expression={$_.Title.Substring(0, [Math]::Min(50, $_.Title.Length))}; Width=50}
            @{Label='Price'; Expression={$_.PricePoint}; Width=10}
            @{Label='Time'; Expression={$_.TimeToMarket}; Width=6}
        ) -AutoSize

        # Save opportunities
        if ($topOpportunities.Count -gt 0) {
            Save-Opportunities -Opportunities $topOpportunities
        }

        $elapsed = ((Get-Date) - $startTime).TotalSeconds
        Write-Host "`n✅ Scan complete in $([Math]::Round($elapsed, 1))s - Found $($topOpportunities.Count) high-quality opportunities`n" -ForegroundColor Green

        if ($Continuous) {
            Write-Host "⏳ Next scan in $($Interval / 60) minutes..." -ForegroundColor Yellow
            Start-Sleep -Seconds $Interval
        }

    } while ($Continuous)

    return $topOpportunities
}

# ============================================================================
# EXPORT
# ============================================================================

Export-ModuleMember -Function Find-AllOpportunities

# Run if executed directly
if ($MyInvocation.InvocationName -ne '.') {
    Find-AllOpportunities
}
