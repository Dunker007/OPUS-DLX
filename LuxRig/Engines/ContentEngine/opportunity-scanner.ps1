<#
.SYNOPSIS
    Opportunity Scanner - Automated Problem Discovery for LuxRig

.DESCRIPTION
    Finds revenue opportunities by monitoring:
    - Reddit API for common complaints and pain points
    - GitHub issues for tool gaps
    - ProductHunt for market validation
    - Scores opportunities (demand, difficulty, monetization potential)
    - Outputs scored ideas to Products\ideas\

.EXAMPLE
    $opportunities = Find-Opportunities -Source "reddit" -Limit 10
    $scored = Score-Opportunity -Opportunity $opp

.NOTES
    Part of LuxRig Phase 1 Foundation
    This is the opportunity discovery engine
#>

# Find opportunities from Reddit
function Find-RedditOpportunities {
    param(
        [string[]]$Subreddits = @("SaaS", "Entrepreneur", "startups", "webdev", "sideproject"),
        [int]$Limit = 50,
        [int]$DaysBack = 7
    )

    Write-Host "`n=== Scanning Reddit for Opportunities ===" -ForegroundColor Cyan

    $opportunities = @()

    foreach ($subreddit in $Subreddits) {
        Write-Host "Searching r/$subreddit..." -ForegroundColor Gray

        try {
            # Reddit API endpoint (no auth needed for public posts)
            $url = "https://www.reddit.com/r/$subreddit/search.json?q=need+OR+wish+OR+problem+OR+frustrating&restrict_sr=1&sort=top&t=week&limit=$Limit"

            $response = Invoke-RestMethod -Uri $url -Headers @{
                "User-Agent" = "LuxRig/1.0 (Opportunity Scanner)"
            } -TimeoutSec 30

            foreach ($post in $response.data.children) {
                $data = $post.data

                # Extract problem indicators
                $title = $data.title
                $selftext = $data.selftext
                $upvotes = $data.ups
                $comments = $data.num_comments

                # Basic keyword matching for pain points
                $painKeywords = @("need", "wish", "can't find", "doesn't exist", "frustrated", "annoying", "hate that", "problem with")
                $hasPainPoint = $false

                foreach ($keyword in $painKeywords) {
                    if ($title -match $keyword -or $selftext -match $keyword) {
                        $hasPainPoint = $true
                        break
                    }
                }

                if ($hasPainPoint) {
                    $opportunities += @{
                        source = "reddit"
                        subreddit = $subreddit
                        title = $title
                        description = $selftext.Substring(0, [Math]::Min(500, $selftext.Length))
                        url = "https://reddit.com$($data.permalink)"
                        upvotes = $upvotes
                        comments = $comments
                        created = $data.created_utc
                        engagement_score = $upvotes + ($comments * 2)
                    }
                }
            }

            Start-Sleep -Milliseconds 1000  # Rate limiting
        }
        catch {
            Write-Warning "Failed to fetch from r/$subreddit: $_"
        }
    }

    Write-Host "Found $($opportunities.Count) potential opportunities from Reddit" -ForegroundColor Green

    return $opportunities
}

# Find opportunities from GitHub
function Find-GitHubOpportunities {
    param(
        [string[]]$Topics = @("productivity", "automation", "developer-tools", "chrome-extension"),
        [int]$Limit = 50
    )

    Write-Host "`n=== Scanning GitHub Issues for Opportunities ===" -ForegroundColor Cyan

    $opportunities = @()

    foreach ($topic in $Topics) {
        Write-Host "Searching topic: $topic..." -ForegroundColor Gray

        try {
            # GitHub search API
            $query = "label:enhancement+OR+label:feature-request+topic:$topic+state:open"
            $url = "https://api.github.com/search/issues?q=$query&sort=reactions&order=desc&per_page=$Limit"

            $response = Invoke-RestMethod -Uri $url -Headers @{
                "User-Agent" = "LuxRig/1.0"
                "Accept" = "application/vnd.github.v3+json"
            } -TimeoutSec 30

            foreach ($issue in $response.items) {
                $opportunities += @{
                    source = "github"
                    topic = $topic
                    title = $issue.title
                    description = $issue.body.Substring(0, [Math]::Min(500, $issue.body.Length))
                    url = $issue.html_url
                    repo = $issue.repository_url -replace '.*/repos/', ''
                    reactions = $issue.reactions.total_count
                    comments = $issue.comments
                    created = $issue.created_at
                    engagement_score = $issue.reactions.total_count + ($issue.comments * 2)
                }
            }

            Start-Sleep -Milliseconds 1000  # Rate limiting
        }
        catch {
            Write-Warning "Failed to fetch from GitHub topic $topic : $_"
        }
    }

    Write-Host "Found $($opportunities.Count) potential opportunities from GitHub" -ForegroundColor Green

    return $opportunities
}

# Find opportunities from ProductHunt (via scraping - no official API)
function Find-ProductHuntOpportunities {
    param(
        [int]$DaysBack = 7
    )

    Write-Host "`n=== Analyzing ProductHunt Trends ===" -ForegroundColor Cyan
    Write-Host "Note: ProductHunt scraping requires authenticated API access" -ForegroundColor Yellow
    Write-Host "Placeholder: Would analyze recent launches for gaps and patterns" -ForegroundColor Gray

    # Placeholder - would need ProductHunt API key
    $opportunities = @()

    return $opportunities
}

# Score an opportunity
function Score-Opportunity {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Opportunity
    )

    $score = @{
        demand = 0        # 0-10: How many people want this
        difficulty = 0    # 0-10: How hard to build (inverse - lower is better)
        monetization = 0  # 0-10: Revenue potential
        competition = 0   # 0-10: Market saturation (inverse - lower is better)
        total = 0
        tier = "unknown"
    }

    # Demand score (based on engagement)
    $engagement = $Opportunity.engagement_score
    if ($engagement -gt 100) { $score.demand = 10 }
    elseif ($engagement -gt 50) { $score.demand = 8 }
    elseif ($engagement -gt 25) { $score.demand = 6 }
    elseif ($engagement -gt 10) { $score.demand = 4 }
    else { $score.demand = 2 }

    # Difficulty score (keyword-based estimation)
    $easyKeywords = @("calculator", "converter", "checker", "tracker", "list")
    $hardKeywords = @("ai", "machine learning", "blockchain", "real-time", "distributed")

    $description = "$($Opportunity.title) $($Opportunity.description)"

    $isEasy = $false
    $isHard = $false

    foreach ($keyword in $easyKeywords) {
        if ($description -match $keyword) { $isEasy = $true; break }
    }

    foreach ($keyword in $hardKeywords) {
        if ($description -match $keyword) { $isHard = $true; break }
    }

    if ($isEasy) { $score.difficulty = 8 }      # Easy to build = high score
    elseif ($isHard) { $score.difficulty = 3 }   # Hard to build = low score
    else { $score.difficulty = 5 }               # Medium

    # Monetization score (keyword-based)
    $moneyKeywords = @("business", "enterprise", "professional", "agency", "saas", "paid", "subscription")

    $hasMoney = $false
    foreach ($keyword in $moneyKeywords) {
        if ($description -match $keyword) { $hasMoney = $true; break }
    }

    if ($hasMoney) { $score.monetization = 8 }
    else { $score.monetization = 5 }

    # Competition score (placeholder - would check existing solutions)
    $score.competition = 5  # Assume moderate competition

    # Calculate total score
    $score.total = [Math]::Round((
        ($score.demand * 0.4) +          # 40% weight on demand
        ($score.difficulty * 0.25) +     # 25% weight on ease of build
        ($score.monetization * 0.25) +   # 25% weight on revenue potential
        ($score.competition * 0.1)       # 10% weight on competition
    ), 2)

    # Categorize tier
    if ($score.total -ge 8) { $score.tier = "HIGH" }
    elseif ($score.total -ge 6) { $score.tier = "MEDIUM" }
    else { $score.tier = "LOW" }

    return $score
}

# Main function: Find and score all opportunities
function Find-Opportunities {
    param(
        [ValidateSet("all", "reddit", "github", "producthunt")]
        [string]$Source = "all",

        [int]$Limit = 50,

        [switch]$SaveToFile
    )

    $allOpportunities = @()

    # Gather from sources
    if ($Source -eq "all" -or $Source -eq "reddit") {
        $redditOpps = Find-RedditOpportunities -Limit $Limit
        $allOpportunities += $redditOpps
    }

    if ($Source -eq "all" -or $Source -eq "github") {
        $githubOpps = Find-GitHubOpportunities -Limit $Limit
        $allOpportunities += $githubOpps
    }

    if ($Source -eq "all" -or $Source -eq "producthunt") {
        $phOpps = Find-ProductHuntOpportunities
        $allOpportunities += $phOpps
    }

    # Score each opportunity
    Write-Host "`n=== Scoring Opportunities ===" -ForegroundColor Cyan

    $scoredOpportunities = @()
    foreach ($opp in $allOpportunities) {
        $score = Score-Opportunity -Opportunity $opp
        $opp.score = $score
        $scoredOpportunities += $opp
    }

    # Sort by total score (descending)
    $scoredOpportunities = $scoredOpportunities | Sort-Object { $_.score.total } -Descending

    # Display top opportunities
    Write-Host "`n╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║          TOP OPPORTUNITIES DISCOVERED                     ║" -ForegroundColor Green
    Write-Host "╠═══════════════════════════════════════════════════════════╣" -ForegroundColor Green

    $topOpps = $scoredOpportunities | Select-Object -First 10
    $index = 1

    foreach ($opp in $topOpps) {
        $score = $opp.score
        $color = switch ($score.tier) {
            "HIGH" { "Green" }
            "MEDIUM" { "Yellow" }
            "LOW" { "Gray" }
        }

        Write-Host "`n#$index - $($opp.title.Substring(0, [Math]::Min(50, $opp.title.Length)))" -ForegroundColor $color
        Write-Host "  Source: $($opp.source) | Engagement: $($opp.engagement_score)" -ForegroundColor Gray
        Write-Host "  Score: $($score.total)/10 [$($score.tier)] | Demand:$($score.demand) Difficulty:$($score.difficulty) Money:$($score.monetization)" -ForegroundColor Gray
        Write-Host "  URL: $($opp.url)" -ForegroundColor DarkGray

        $index++
    }

    Write-Host "`n╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Green

    # Save to file if requested
    if ($SaveToFile) {
        $outputDir = "$PSScriptRoot\..\..\Products\ideas"
        $outputFile = "$outputDir\opportunities-$(Get-Date -Format 'yyyy-MM-dd-HHmm').json"

        if (-not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }

        $scoredOpportunities | ConvertTo-Json -Depth 10 | Set-Content $outputFile
        Write-Host "`nSaved $($scoredOpportunities.Count) opportunities to: $outputFile" -ForegroundColor Cyan
    }

    return $scoredOpportunities
}

# Export functions
Export-ModuleMember -Function Find-Opportunities, Score-Opportunity, Find-RedditOpportunities, Find-GitHubOpportunities
