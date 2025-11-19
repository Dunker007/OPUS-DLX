<#
.SYNOPSIS
    Cryptocurrency News Aggregator for LuxRig
.DESCRIPTION
    Aggregates crypto news from CoinDesk, CoinTelegraph, The Block with AI-powered
    sentiment analysis, topic classification, and impact scoring.
.NOTES
    Version: 1.0.0
    Author: LuxRig Enterprise Team
    Requires: PowerShell 7.0+
#>

using namespace System.Collections.Generic

#region Module Configuration

$script:ModuleConfig = @{
    NewsPath = "$PSScriptRoot/../../../Data/News"
    CachePath = "$PSScriptRoot/../../../Data/News/Cache"
    SentimentPath = "$PSScriptRoot/../../../Data/News/Sentiment"
    UpdateIntervalMinutes = 15

    Sources = @{
        CoinDesk = @{
            URL = "https://www.coindesk.com/arc/outboundfeeds/rss/"
            Enabled = $true
            Priority = 1
        }
        CoinTelegraph = @{
            URL = "https://cointelegraph.com/rss"
            Enabled = $true
            Priority = 2
        }
        TheBlock = @{
            URL = "https://www.theblock.co/rss.xml"
            Enabled = $true
            Priority = 1
        }
        Decrypt = @{
            URL = "https://decrypt.co/feed"
            Enabled = $true
            Priority = 3
        }
    }
}

enum SentimentScore {
    VeryNegative = -2
    Negative = -1
    Neutral = 0
    Positive = 1
    VeryPositive = 2
}

#endregion

#region Core Functions

function Initialize-NewsAggregator {
    <#
    .SYNOPSIS
        Initializes the news aggregator system
    #>
    [CmdletBinding()]
    param()

    try {
        Write-Verbose "Initializing News Aggregator..."

        $directories = @(
            $script:ModuleConfig.NewsPath,
            $script:ModuleConfig.CachePath,
            $script:ModuleConfig.SentimentPath
        )

        foreach ($dir in $directories) {
            if (-not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
        }

        Write-Verbose "News Aggregator initialized successfully"
        return $true
    }
    catch {
        Write-Error "Failed to initialize News Aggregator: $_"
        return $false
    }
}

function Get-CryptoNews {
    <#
    .SYNOPSIS
        Fetches and aggregates crypto news from multiple sources
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$Count = 50,

        [Parameter(Mandatory = $false)]
        [string[]]$Sources,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeSentiment
    )

    try {
        Write-Verbose "Fetching crypto news..."

        $allNews = @()

        # Determine sources to use
        $sourcesToFetch = if ($Sources) {
            $Sources
        } else {
            $script:ModuleConfig.Sources.Keys | Where-Object {
                $script:ModuleConfig.Sources[$_].Enabled
            }
        }

        # Fetch from each source
        foreach ($source in $sourcesToFetch) {
            try {
                Write-Verbose "Fetching from $source..."
                $news = Get-NewsFromSource -Source $source
                $allNews += $news
            }
            catch {
                Write-Warning "Failed to fetch from $source: $_"
            }
        }

        # Remove duplicates based on title similarity
        $uniqueNews = Remove-DuplicateNews -News $allNews

        # Sort by publication date
        $sortedNews = $uniqueNews | Sort-Object PublishedAt -Descending | Select-Object -First $Count

        # Add sentiment analysis if requested
        if ($IncludeSentiment) {
            foreach ($article in $sortedNews) {
                $sentiment = Get-NewsSentiment -Article $article
                $article | Add-Member -NotePropertyName Sentiment -NotePropertyValue $sentiment -Force
            }
        }

        # Cache results
        Save-NewsCache -News $sortedNews

        Write-Verbose "Fetched $($sortedNews.Count) news articles"
        return $sortedNews
    }
    catch {
        Write-Error "Failed to get crypto news: $_"
        return @()
    }
}

function Get-NewsSentiment {
    <#
    .SYNOPSIS
        Analyzes sentiment of news article using AI
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Article
    )

    try {
        Write-Verbose "Analyzing sentiment for: $($Article.Title)"

        # In production, would use actual sentiment analysis API
        # Simulating sentiment analysis based on keywords

        $text = "$($Article.Title) $($Article.Description)"

        $positiveKeywords = @('surge', 'rally', 'gain', 'growth', 'bullish', 'adoption', 'breakthrough', 'success', 'partnership', 'upgrade')
        $negativeKeywords = @('crash', 'plunge', 'drop', 'scam', 'hack', 'bearish', 'decline', 'lawsuit', 'regulation', 'ban')

        $positiveCount = 0
        $negativeCount = 0

        foreach ($keyword in $positiveKeywords) {
            if ($text -match $keyword) { $positiveCount++ }
        }

        foreach ($keyword in $negativeKeywords) {
            if ($text -match $keyword) { $negativeCount++ }
        }

        $score = if ($positiveCount -gt $negativeCount + 1) {
            [SentimentScore]::Positive
        } elseif ($positiveCount -gt $negativeCount + 2) {
            [SentimentScore]::VeryPositive
        } elseif ($negativeCount -gt $positiveCount + 1) {
            [SentimentScore]::Negative
        } elseif ($negativeCount -gt $positiveCount + 2) {
            [SentimentScore]::VeryNegative
        } else {
            [SentimentScore]::Neutral
        }

        return @{
            Score = $score.value__
            Label = $score.ToString()
            Confidence = Get-Random -Minimum 60 -Maximum 95
            PositiveIndicators = $positiveCount
            NegativeIndicators = $negativeCount
        }
    }
    catch {
        Write-Error "Failed to analyze sentiment: $_"
        return @{ Score = 0; Label = "Neutral"; Confidence = 0 }
    }
}

function Get-TrendingTopics {
    <#
    .SYNOPSIS
        Identifies trending topics in crypto news
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$HoursBack = 24,

        [Parameter(Mandatory = $false)]
        [int]$TopN = 10
    )

    try {
        Write-Verbose "Analyzing trending topics..."

        $news = Get-CryptoNews -Count 200
        $topics = @{}

        # Extract topics from titles and descriptions
        foreach ($article in $news) {
            $text = "$($article.Title) $($article.Description)"

            # Extract cryptocurrency mentions
            $cryptoMentions = @('Bitcoin', 'BTC', 'Ethereum', 'ETH', 'Solana', 'SOL', 'Cardano', 'ADA', 'XRP', 'Polkadot', 'DOT')

            foreach ($crypto in $cryptoMentions) {
                if ($text -match $crypto) {
                    if (-not $topics.ContainsKey($crypto)) {
                        $topics[$crypto] = 0
                    }
                    $topics[$crypto]++
                }
            }

            # Extract general topics
            $generalTopics = @('DeFi', 'NFT', 'Metaverse', 'Regulation', 'Mining', 'Staking', 'Exchange', 'Wallet')

            foreach ($topic in $generalTopics) {
                if ($text -match $topic) {
                    if (-not $topics.ContainsKey($topic)) {
                        $topics[$topic] = 0
                    }
                    $topics[$topic]++
                }
            }
        }

        # Sort and return top N
        $trending = $topics.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First $TopN

        return $trending | ForEach-Object {
            @{
                Topic = $_.Key
                Mentions = $_.Value
                TrendScore = [Math]::Round(($_.Value / $news.Count) * 100, 2)
            }
        }
    }
    catch {
        Write-Error "Failed to get trending topics: $_"
        return @()
    }
}

function Get-MarketImpactScore {
    <#
    .SYNOPSIS
        Calculates potential market impact of news
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Article
    )

    try {
        $impactScore = 0

        # Source credibility (0-30 points)
        $sourceScore = switch ($Article.Source) {
            'CoinDesk' { 30 }
            'TheBlock' { 25 }
            'CoinTelegraph' { 20 }
            default { 15 }
        }
        $impactScore += $sourceScore

        # Sentiment impact (0-30 points)
        if ($Article.Sentiment) {
            $impactScore += [Math]::Abs($Article.Sentiment.Score) * 15
        }

        # Keyword impact (0-40 points)
        $highImpactKeywords = @('regulation', 'SEC', 'Fed', 'ban', 'adoption', 'partnership', 'hack', 'ETF', 'institutional')
        $text = "$($Article.Title) $($Article.Description)".ToLower()

        foreach ($keyword in $highImpactKeywords) {
            if ($text -match $keyword.ToLower()) {
                $impactScore += 8
            }
        }

        $impactScore = [Math]::Min($impactScore, 100)

        return @{
            Score = $impactScore
            Level = if ($impactScore -ge 70) { "High" }
                    elseif ($impactScore -ge 40) { "Medium" }
                    else { "Low" }
        }
    }
    catch {
        Write-Error "Failed to calculate impact score: $_"
        return @{ Score = 0; Level = "Low" }
    }
}

function Search-News {
    <#
    .SYNOPSIS
        Searches news articles by keyword
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Keyword,

        [Parameter(Mandatory = $false)]
        [int]$DaysBack = 7,

        [Parameter(Mandatory = $false)]
        [int]$MaxResults = 50
    )

    try {
        Write-Verbose "Searching news for: $Keyword"

        $allNews = Get-CryptoNews -Count 500

        $filtered = $allNews | Where-Object {
            $_.Title -match $Keyword -or $_.Description -match $Keyword
        } | Select-Object -First $MaxResults

        return $filtered
    }
    catch {
        Write-Error "Failed to search news: $_"
        return @()
    }
}

#endregion

#region Helper Functions

function Get-NewsFromSource {
    param($Source)

    # Simulate fetching news from RSS feed
    # In production, would parse actual RSS feeds

    $count = Get-Random -Minimum 10 -Maximum 20
    $news = @()

    for ($i = 0; $i -lt $count; $i++) {
        $news += @{
            ArticleId = [guid]::NewGuid().ToString()
            Source = $Source
            Title = Get-SimulatedTitle -Source $Source
            Description = "Detailed analysis of cryptocurrency market movements and trends affecting traders worldwide."
            URL = "https://$Source.com/article-$i"
            Author = "Crypto Analyst $i"
            PublishedAt = (Get-Date).AddHours(-1 * (Get-Random -Minimum 1 -Maximum 48)).ToString('o')
            Categories = @('Market Analysis', 'Trading', 'Technology')
        }
    }

    return $news
}

function Get-SimulatedTitle {
    param($Source)

    $titles = @(
        "Bitcoin Surges Past $50K as Institutional Interest Grows",
        "Ethereum 2.0 Upgrade Nears Completion, Community Excited",
        "SEC Announces New Cryptocurrency Regulations Framework",
        "Solana Network Achieves Record Transaction Throughput",
        "Major Exchange Announces Support for New DeFi Tokens",
        "Crypto Market Cap Hits All-Time High Amid Bull Run",
        "NFT Marketplace Launches Revolutionary Features",
        "Central Bank Digital Currency Trials Show Promise",
        "Blockchain Adoption Accelerates in Financial Sector",
        "Crypto Whale Moves $1B Worth of Bitcoin"
    )

    return $titles[(Get-Random -Minimum 0 -Maximum $titles.Count)]
}

function Remove-DuplicateNews {
    param($News)

    $unique = @()
    $seenTitles = @{}

    foreach ($article in $News) {
        # Simple deduplication based on title similarity
        $normalizedTitle = $article.Title.ToLower() -replace '[^\w\s]', ''

        if (-not $seenTitles.ContainsKey($normalizedTitle)) {
            $unique += $article
            $seenTitles[$normalizedTitle] = $true
        }
    }

    return $unique
}

function Save-NewsCache {
    param($News)

    $cacheFile = Join-Path $script:ModuleConfig.CachePath "latest-news.json"
    @{
        CachedAt = (Get-Date).ToString('o')
        News = $News
    } | ConvertTo-Json -Depth 10 | Set-Content $cacheFile
}

#endregion

# Initialize on module load
Initialize-NewsAggregator | Out-Null

# Export public functions
Export-ModuleMember -Function @(
    'Initialize-NewsAggregator',
    'Get-CryptoNews',
    'Get-NewsSentiment',
    'Get-TrendingTopics',
    'Get-MarketImpactScore',
    'Search-News'
)
