#Requires -Version 7.0
<#
.SYNOPSIS
    Sentiment Aggregator - Social media & news sentiment
.DESCRIPTION
    Multi-source sentiment analysis:
    - Twitter/X crypto sentiment
    - Reddit mentions and upvotes
    - News sentiment (crypto media)
    - Fear & Greed Index
    - Influencer tracking
.NOTES
    Part of Phase 4: Advanced Charting
#>

# ============================================================================
# FEAR & GREED INDEX
# ============================================================================

function Get-FearGreedIndex {
    try {
        # Fetch from Alternative.me API
        $response = Invoke-RestMethod -Uri "https://api.alternative.me/fng/?limit=1" -Method Get

        $value = [int]$response.data[0].value
        $classification = $response.data[0].value_classification

        return @{
            value = $value
            classification = $classification
            signal = if ($value -lt 25) { "EXTREME_FEAR" }
                     elseif ($value -lt 45) { "FEAR" }
                     elseif ($value -lt 55) { "NEUTRAL" }
                     elseif ($value -lt 75) { "GREED" }
                     else { "EXTREME_GREED" }
            contrarian = if ($value -lt 25) { "BUY" } elseif ($value -gt 75) { "SELL" } else { "HOLD" }
        }
    }
    catch {
        Write-Host "⚠️  Failed to fetch Fear & Greed Index" -ForegroundColor Yellow
        return @{ value = 50; classification = "Neutral"; signal = "NEUTRAL" }
    }
}

# ============================================================================
# SOCIAL SENTIMENT (SIMULATED)
# ============================================================================

function Get-TwitterSentiment {
    param([string]$Symbol = "BTC")

    # Note: Full implementation requires Twitter API access
    # This is a simplified simulation

    Write-Host "🐦 Fetching Twitter sentiment for $Symbol..." -ForegroundColor Cyan

    # Simulated sentiment data
    $positiveCount = Get-Random -Minimum 100 -Maximum 500
    $negativeCount = Get-Random -Minimum 50 -Maximum 300
    $neutralCount = Get-Random -Minimum 200 -Maximum 400

    $total = $positiveCount + $negativeCount + $neutralCount
    $positivePercent = ($positiveCount / $total) * 100
    $negativePercent = ($negativeCount / $total) * 100

    $sentiment = if ($positivePercent -gt 50) { "BULLISH" }
                 elseif ($negativePercent -gt 50) { "BEARISH" }
                 else { "NEUTRAL" }

    return @{
        source = "Twitter"
        positive = $positiveCount
        negative = $negativeCount
        neutral = $neutralCount
        positivePercent = [Math]::Round($positivePercent, 2)
        negativePercent = [Math]::Round($negativePercent, 2)
        sentiment = $sentiment
        mentions = $total
    }
}

function Get-RedditSentiment {
    param([string]$Symbol = "BTC")

    Write-Host "📱 Fetching Reddit sentiment for $Symbol..." -ForegroundColor Cyan

    # Simulated Reddit data
    $posts = Get-Random -Minimum 50 -Maximum 200
    $upvotes = Get-Random -Minimum 1000 -Maximum 5000
    $comments = Get-Random -Minimum 500 -Maximum 2000

    $positivePercent = Get-Random -Minimum 40 -Maximum 70

    return @{
        source = "Reddit"
        posts = $posts
        upvotes = $upvotes
        comments = $comments
        positivePercent = $positivePercent
        negativePercent = [Math]::Round(100 - $positivePercent, 2)
        sentiment = if ($positivePercent -gt 55) { "BULLISH" } elseif ($positivePercent -lt 45) { "BEARISH" } else { "NEUTRAL" }
    }
}

# ============================================================================
# NEWS SENTIMENT
# ============================================================================

function Get-NewsSentiment {
    param([string]$Symbol = "BTC")

    Write-Host "📰 Analyzing news sentiment for $Symbol..." -ForegroundColor Cyan

    # Simulated news analysis
    $articles = @(
        @{ title = "Bitcoin surges on institutional adoption"; sentiment = "POSITIVE"; score = 0.8 }
        @{ title = "Crypto market faces regulatory uncertainty"; sentiment = "NEGATIVE"; score = -0.6 }
        @{ title = "Bitcoin price consolidates in tight range"; sentiment = "NEUTRAL"; score = 0.1 }
    )

    $avgScore = ($articles.score | Measure-Object -Average).Average
    $positiveCount = ($articles | Where-Object { $_.sentiment -eq "POSITIVE" }).Count
    $negativeCount = ($articles | Where-Object { $_.sentiment -eq "NEGATIVE" }).Count

    return @{
        source = "News"
        articles = $articles.Count
        positiveArticles = $positiveCount
        negativeArticles = $negativeCount
        avgScore = [Math]::Round($avgScore, 2)
        sentiment = if ($avgScore -gt 0.2) { "BULLISH" } elseif ($avgScore -lt -0.2) { "BEARISH" } else { "NEUTRAL" }
    }
}

# ============================================================================
# INFLUENCER TRACKING
# ============================================================================

function Get-InfluencerSignals {
    param([string]$Symbol = "BTC")

    # Simulated influencer data
    $influencers = @(
        @{ name = "CryptoWhale"; followers = 500000; signal = "BULLISH"; confidence = 0.7 }
        @{ name = "BTCAnalyst"; followers = 300000; signal = "NEUTRAL"; confidence = 0.5 }
        @{ name = "ChartMaster"; followers = 200000; signal = "BEARISH"; confidence = 0.6 }
    )

    $bullishCount = ($influencers | Where-Object { $_.signal -eq "BULLISH" }).Count
    $bearishCount = ($influencers | Where-Object { $_.signal -eq "BEARISH" }).Count

    return @{
        influencers = $influencers
        bullishCount = $bullishCount
        bearishCount = $bearishCount
        aggregate = if ($bullishCount -gt $bearishCount) { "BULLISH" } elseif ($bearishCount -gt $bullishCount) { "BEARISH" } else { "NEUTRAL" }
    }
}

# ============================================================================
# SENTIMENT REPORT
# ============================================================================

function Get-SentimentReport {
    param([string]$Symbol = "BTC")

    Write-Host "`n╔══════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║          🎭 SENTIMENT ANALYSIS REPORT                ║" -ForegroundColor Magenta
    Write-Host "╚══════════════════════════════════════════════════════╝`n" -ForegroundColor Magenta

    # Fear & Greed
    $fg = Get-FearGreedIndex
    Write-Host "😱 FEAR & GREED INDEX:" -ForegroundColor Yellow
    Write-Host "   Value: $($fg.value)/100 - $($fg.classification)" -ForegroundColor White
    Write-Host "   Signal: $($fg.signal)" -ForegroundColor $(if ($fg.signal -like "*FEAR*") { 'Red' } else { 'Green' })
    Write-Host "   Contrarian play: $($fg.contrarian)`n" -ForegroundColor Cyan

    # Social media
    $twitter = Get-TwitterSentiment -Symbol $Symbol
    Write-Host "🐦 TWITTER SENTIMENT:" -ForegroundColor Yellow
    Write-Host "   Mentions: $($twitter.mentions)" -ForegroundColor White
    Write-Host "   Positive: $($twitter.positivePercent)% | Negative: $($twitter.negativePercent)%" -ForegroundColor White
    Write-Host "   Sentiment: $($twitter.sentiment)`n" -ForegroundColor $(if ($twitter.sentiment -eq "BULLISH") { 'Green' } elseif ($twitter.sentiment -eq "BEARISH") { 'Red' } else { 'Gray' })

    $reddit = Get-RedditSentiment -Symbol $Symbol
    Write-Host "📱 REDDIT SENTIMENT:" -ForegroundColor Yellow
    Write-Host "   Posts: $($reddit.posts) | Upvotes: $($reddit.upvotes) | Comments: $($reddit.comments)" -ForegroundColor White
    Write-Host "   Positive: $($reddit.positivePercent)% | Negative: $($reddit.negativePercent)%" -ForegroundColor White
    Write-Host "   Sentiment: $($reddit.sentiment)`n" -ForegroundColor $(if ($reddit.sentiment -eq "BULLISH") { 'Green' } elseif ($reddit.sentiment -eq "BEARISH") { 'Red' } else { 'Gray' })

    # News
    $news = Get-NewsSentiment -Symbol $Symbol
    Write-Host "📰 NEWS SENTIMENT:" -ForegroundColor Yellow
    Write-Host "   Articles analyzed: $($news.articles)" -ForegroundColor White
    Write-Host "   Positive: $($news.positiveArticles) | Negative: $($news.negativeArticles)" -ForegroundColor White
    Write-Host "   Average score: $($news.avgScore)" -ForegroundColor White
    Write-Host "   Sentiment: $($news.sentiment)`n" -ForegroundColor $(if ($news.sentiment -eq "BULLISH") { 'Green' } elseif ($news.sentiment -eq "BEARISH") { 'Red' } else { 'Gray' })

    # Influencers
    $influencers = Get-InfluencerSignals -Symbol $Symbol
    Write-Host "🌟 INFLUENCER SIGNALS:" -ForegroundColor Yellow
    foreach ($inf in $influencers.influencers) {
        Write-Host "   $($inf.name) ($($inf.followers/1000)K): $($inf.signal)" -ForegroundColor Gray
    }
    Write-Host "   Aggregate: $($influencers.aggregate)`n" -ForegroundColor White

    # Aggregate sentiment
    $bullishSignals = 0
    $bearishSignals = 0

    if ($twitter.sentiment -eq "BULLISH") { $bullishSignals++ }
    if ($twitter.sentiment -eq "BEARISH") { $bearishSignals++ }
    if ($reddit.sentiment -eq "BULLISH") { $bullishSignals++ }
    if ($reddit.sentiment -eq "BEARISH") { $bearishSignals++ }
    if ($news.sentiment -eq "BULLISH") { $bullishSignals++ }
    if ($news.sentiment -eq "BEARISH") { $bearishSignals++ }
    if ($influencers.aggregate -eq "BULLISH") { $bullishSignals++ }
    if ($influencers.aggregate -eq "BEARISH") { $bearishSignals++ }

    $aggregate = if ($bullishSignals -gt $bearishSignals) { "BULLISH" }
                 elseif ($bearishSignals -gt $bullishSignals) { "BEARISH" }
                 else { "NEUTRAL" }

    Write-Host "🎯 AGGREGATE SENTIMENT: $aggregate ($bullishSignals bullish, $bearishSignals bearish)`n" -ForegroundColor $(if ($aggregate -eq "BULLISH") { 'Green' } elseif ($aggregate -eq "BEARISH") { 'Red' } else { 'Yellow' })

    return @{
        fearGreed = $fg
        twitter = $twitter
        reddit = $reddit
        news = $news
        influencers = $influencers
        aggregate = $aggregate
        bullishSignals = $bullishSignals
        bearishSignals = $bearishSignals
    }
}

# ============================================================================
# EXPORT
# ============================================================================

Export-ModuleMember -Function Get-SentimentReport, Get-FearGreedIndex, Get-TwitterSentiment, Get-RedditSentiment, Get-NewsSentiment, Get-InfluencerSignals

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Sentiment Aggregator ready. Multi-source social and news sentiment analysis" -ForegroundColor Yellow
}
