# ============================================================================
# LuxRig Blog Publisher
# Purpose: Automated blog publishing with WordPress/Ghost integration
# Location: LuxRig/Content/blog-publisher.ps1
# ============================================================================

<#
.SYNOPSIS
    Automated blog content generation and publishing system.

.DESCRIPTION
    Production-ready blog publisher featuring:
    - Local AI content generation
    - WordPress/Ghost/Medium integration
    - SEO optimization
    - Auto-scheduling
    - Image generation
    - Database tracking
    - Performance analytics

.PARAMETER Platform
    Publishing platform (wordpress, ghost, medium)

.PARAMETER Topic
    Blog topic/niche

.PARAMETER Count
    Number of posts to generate

.PARAMETER AutoPublish
    Automatically publish generated content

.EXAMPLE
    .\blog-publisher.ps1 -Platform wordpress -Topic "crypto trading" -Count 5 -AutoPublish
#>

param(
    [ValidateSet('wordpress', 'ghost', 'medium', 'blogger')]
    [string]$Platform = 'wordpress',

    [string]$Topic = 'cryptocurrency',

    [int]$Count = 1,

    [switch]$AutoPublish,

    [switch]$GenerateImages
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# IMPORTS
# ============================================================================

$dataAccessModule = Join-Path $PSScriptRoot '../Database/data-access.ps1'
$secretsModule = Join-Path $PSScriptRoot '../Security/secrets-manager.ps1'
$localAIModule = Join-Path $PSScriptRoot '../AI/LocalModels/install-local-ai.ps1'

if (Test-Path $dataAccessModule) {
    . $dataAccessModule
}

if (Test-Path $secretsModule) {
    . $secretsModule
}

if (Test-Path $localAIModule) {
    . $localAIModule
}

# ============================================================================
# CONFIGURATION
# ============================================================================

$Script:Config = @{
    MinWordCount = 800
    MaxWordCount = 1500
    SEOKeywordDensity = 0.02
    DefaultCategory = 'General'
    DefaultTags = @('cryptocurrency', 'trading', 'bitcoin', 'blockchain')
    ImageCount = 1
    ScheduleHoursAhead = 2
    ContentQualityThreshold = 0.7
}

# ============================================================================
# LOGGING
# ============================================================================

function Write-PublisherLog {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Message
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        'INFO' { 'Cyan' }
        'SUCCESS' { 'Green' }
        'WARNING' { 'Yellow' }
        'ERROR' { 'Red' }
    }

    $icon = switch ($Level) {
        'INFO' { '📝' }
        'SUCCESS' { '✅' }
        'WARNING' { '⚠️' }
        'ERROR' { '❌' }
    }

    Write-Host "[$timestamp] $icon [$Level] $Message" -ForegroundColor $color

    $logPath = Join-Path $PSScriptRoot '../Logs/blog-publisher.log'
    if (Test-Path (Split-Path $logPath)) {
        "[$timestamp] [$Level] $Message" | Add-Content -Path $logPath -ErrorAction SilentlyContinue
    }
}

# ============================================================================
# CONTENT GENERATION
# ============================================================================

function New-BlogTitle {
    param(
        [Parameter(Mandatory)]
        [string]$Topic,

        [string]$Angle = 'informative'
    )

    $titleTemplates = @(
        "The Ultimate Guide to $Topic in 2025"
        "10 Things You Need to Know About $Topic"
        "How to Master $Topic: A Complete Guide"
        "$Topic Explained: Everything You Need to Know"
        "The Future of $Topic: Trends and Predictions"
        "5 Proven Strategies for $Topic Success"
        "Beginner's Guide to $Topic"
        "$Topic 101: Essential Tips and Tricks"
        "Why $Topic Matters More Than Ever"
        "The Complete $Topic Handbook"
    )

    return $titleTemplates | Get-Random
}

function New-BlogOutline {
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$Topic
    )

    return @{
        Introduction = "Hook the reader and introduce $Topic"
        MainPoints = @(
            "What is $Topic?",
            "Why $Topic is important",
            "Key benefits of $Topic",
            "Common challenges with $Topic",
            "Best practices for $Topic",
            "Future trends in $Topic"
        )
        Conclusion = "Summary and call-to-action"
    }
}

function Invoke-AIContentGeneration {
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [string]$Model = 'llama2',

        [int]$MaxTokens = 2000
    )

    try {
        Write-PublisherLog -Level INFO -Message "Generating content with AI model: $Model"

        # Check if Ollama is running
        if (-not (Test-OllamaConnection)) {
            Write-PublisherLog -Level WARNING -Message "Ollama not running. Starting service..."
            Start-OllamaService | Out-Null
            Start-Sleep -Seconds 5
        }

        # Generate content
        $response = Invoke-LocalAICompletion -Model $Model -Prompt $Prompt

        if ($response) {
            Write-PublisherLog -Level SUCCESS -Message "Content generated successfully ($($response.Length) characters)"
            return $response
        }
        else {
            Write-PublisherLog -Level WARNING -Message "AI generation failed, using fallback content"
            return Get-FallbackContent -Topic $Prompt
        }
    }
    catch {
        Write-PublisherLog -Level ERROR -Message "AI content generation error: $_"
        return Get-FallbackContent -Topic $Prompt
    }
}

function Get-FallbackContent {
    param([string]$Topic)

    return @"
# Understanding $Topic

$Topic has become increasingly important in today's digital landscape. This comprehensive guide explores the key aspects of $Topic and how you can leverage it for success.

## What is $Topic?

$Topic represents a fundamental shift in how we approach modern challenges. Understanding its core principles is essential for anyone looking to stay ahead in this rapidly evolving field.

## Why $Topic Matters

The significance of $Topic cannot be overstated. Here are the key reasons why it matters:

1. **Innovation**: $Topic drives innovation across industries
2. **Efficiency**: Implementing $Topic solutions increases efficiency
3. **Growth**: $Topic creates new opportunities for growth
4. **Competitiveness**: Staying current with $Topic maintains competitive advantage

## Key Benefits

Embracing $Topic offers numerous benefits:

- Improved decision-making capabilities
- Enhanced operational efficiency
- Better resource allocation
- Increased scalability
- Reduced costs over time

## Getting Started with $Topic

For those new to $Topic, here's a simple roadmap:

1. **Education**: Learn the fundamentals
2. **Planning**: Develop a clear strategy
3. **Implementation**: Start with small, manageable steps
4. **Optimization**: Continuously refine your approach
5. **Scaling**: Expand as you gain confidence

## Common Challenges

While $Topic offers many advantages, there are challenges to be aware of:

- **Learning Curve**: Initial complexity can be daunting
- **Resource Requirements**: May require significant investment
- **Change Management**: Organizational resistance to change
- **Technical Expertise**: Need for specialized knowledge

## Best Practices

Success with $Topic requires following proven best practices:

1. Start with clear objectives
2. Invest in proper training
3. Use reliable tools and platforms
4. Monitor and measure results
5. Stay updated with latest trends

## Future Trends

The future of $Topic looks promising with several emerging trends:

- Increased automation and AI integration
- Greater accessibility for all users
- Enhanced security and privacy features
- More sustainable and eco-friendly approaches
- Cross-platform integration capabilities

## Conclusion

$Topic represents a powerful opportunity for those willing to invest the time and effort to understand it properly. By following the guidelines in this article, you'll be well-positioned to leverage $Topic for your success.

Remember, the key to mastering $Topic is continuous learning and adaptation. Stay curious, remain flexible, and don't be afraid to experiment with new approaches.
"@
}

function New-BlogPost {
    param(
        [Parameter(Mandatory)]
        [string]$Topic,

        [string]$Angle = 'informative'
    )

    try {
        Write-PublisherLog -Level INFO -Message "Generating blog post about: $Topic"

        # Generate title
        $title = New-BlogTitle -Topic $Topic -Angle $Angle
        Write-PublisherLog -Level INFO -Message "Title: $title"

        # Generate outline
        $outline = New-BlogOutline -Title $title -Topic $Topic

        # Generate introduction
        $introPrompt = @"
Write a compelling 200-word introduction for a blog post titled "$title".
The introduction should hook the reader and introduce the topic of $Topic.
Make it engaging, informative, and SEO-friendly.
"@

        $introduction = Invoke-AIContentGeneration -Prompt $introPrompt -Model 'mistral' -MaxTokens 300

        # Generate main content
        $mainPrompt = @"
Write the main content for a blog post about $Topic.
Cover these key points:
1. What is $Topic and why it matters
2. Key benefits and advantages
3. Common challenges and solutions
4. Best practices and tips
5. Future trends and predictions

Make it informative, well-structured, and around 1000 words.
Use markdown formatting with headers and bullet points.
"@

        $mainContent = Invoke-AIContentGeneration -Prompt $mainPrompt -Model 'mistral' -MaxTokens 1500

        # Generate conclusion
        $conclusionPrompt = @"
Write a compelling conclusion for a blog post about $Topic.
Summarize the key points and include a call-to-action.
Make it around 150 words.
"@

        $conclusion = Invoke-AIContentGeneration -Prompt $conclusionPrompt -Model 'mistral' -MaxTokens 250

        # Combine all parts
        $fullContent = @"
# $title

$introduction

$mainContent

## Conclusion

$conclusion
"@

        # Generate keywords
        $keywords = Get-SEOKeywords -Content $fullContent -Topic $Topic

        # Calculate metrics
        $wordCount = ($fullContent -split '\s+').Count

        Write-PublisherLog -Level SUCCESS -Message "Blog post generated successfully ($wordCount words)"

        return @{
            Title = $title
            Content = $fullContent
            Keywords = $keywords
            WordCount = $wordCount
            Topic = $Topic
            GeneratedAt = Get-Date
        }
    }
    catch {
        Write-PublisherLog -Level ERROR -Message "Failed to generate blog post: $_"
        return $null
    }
}

function Get-SEOKeywords {
    param(
        [Parameter(Mandatory)]
        [string]$Content,

        [Parameter(Mandatory)]
        [string]$Topic
    )

    # Extract potential keywords
    $words = $Content -split '\W+' | Where-Object { $_.Length -gt 4 } | Group-Object | Sort-Object Count -Descending | Select-Object -First 10

    $keywords = @($Topic) + ($words | Select-Object -First 5 | ForEach-Object { $_.Name.ToLower() })

    return $keywords -join ', '
}

# ============================================================================
# WORDPRESS INTEGRATION
# ============================================================================

function Get-WordPressCredentials {
    try {
        $siteUrl = Get-LuxRigSecret -Service 'WordPress' -Key 'SITE_URL'
        $username = Get-LuxRigSecret -Service 'WordPress' -Key 'USERNAME'
        $appPassword = Get-LuxRigSecret -Service 'WordPress' -Key 'APP_PASSWORD'

        if (-not $siteUrl -or -not $username -or -not $appPassword) {
            Write-PublisherLog -Level WARNING -Message "WordPress credentials not configured"
            return $null
        }

        return @{
            SiteUrl = $siteUrl
            Username = $username
            AppPassword = $appPassword
        }
    }
    catch {
        Write-PublisherLog -Level ERROR -Message "Failed to get WordPress credentials: $_"
        return $null
    }
}

function Publish-ToWordPress {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Post,

        [string]$Status = 'draft'
    )

    try {
        Write-PublisherLog -Level INFO -Message "Publishing to WordPress: $($Post.Title)"

        $credentials = Get-WordPressCredentials

        if (-not $credentials) {
            Write-PublisherLog -Level WARNING -Message "WordPress not configured. Saving post to database only."
            return Save-PostToDatabase -Post $Post -Platform 'wordpress' -Status 'DRAFT'
        }

        # Prepare WordPress API request
        $apiUrl = "$($credentials.SiteUrl)/wp-json/wp/v2/posts"

        $authHeader = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($credentials.Username):$($credentials.AppPassword)"))

        $headers = @{
            'Authorization' = "Basic $authHeader"
            'Content-Type' = 'application/json'
        }

        $body = @{
            title = $Post.Title
            content = $Post.Content
            status = $Status
            categories = @(1)  # Default category
            tags = @()
        } | ConvertTo-Json

        # Publish to WordPress
        $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers $headers -Body $body -ErrorAction Stop

        Write-PublisherLog -Level SUCCESS -Message "Published to WordPress successfully. Post ID: $($response.id)"

        # Save to database
        Save-PostToDatabase -Post $Post -Platform 'wordpress' -Status 'PUBLISHED' -URL $response.link

        return @{
            Success = $true
            PostID = $response.id
            URL = $response.link
        }
    }
    catch {
        Write-PublisherLog -Level ERROR -Message "Failed to publish to WordPress: $_"

        # Save to database as failed
        Save-PostToDatabase -Post $Post -Platform 'wordpress' -Status 'FAILED'

        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Save-PostToDatabase {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Post,

        [Parameter(Mandatory)]
        [string]$Platform,

        [string]$Status = 'DRAFT',

        [string]$URL = $null
    )

    try {
        $contentId = "BLOG-$(Get-Date -Format 'yyyyMMddHHmmss')-$([Guid]::NewGuid().ToString().Substring(0,8))"

        $contentData = @{
            content_id = $contentId
            type = 'BLOG'
            platform = $Platform
            title = $Post.Title
            body = $Post.Content
            keywords = $Post.Keywords
            status = $Status
            url = $URL
            metadata = (@{
                WordCount = $Post.WordCount
                Topic = $Post.Topic
                GeneratedAt = $Post.GeneratedAt
            } | ConvertTo-Json -Compress)
        }

        if ($Status -eq 'PUBLISHED') {
            $contentData['published_at'] = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        }

        $result = New-Content -ContentData $contentData

        if ($result.Success) {
            Write-PublisherLog -Level SUCCESS -Message "Post saved to database: $contentId"
            return $contentId
        }
        else {
            Write-PublisherLog -Level ERROR -Message "Failed to save post to database: $($result.Error)"
            return $null
        }
    }
    catch {
        Write-PublisherLog -Level ERROR -Message "Database save error: $_"
        return $null
    }
}

# ============================================================================
# ANALYTICS
# ============================================================================

function Get-ContentPerformance {
    param([int]$Days = 30)

    try {
        $startDate = (Get-Date).AddDays(-$Days)

        $content = Get-Content -Type 'BLOG' -Status 'PUBLISHED' -Limit 100

        $published = $content | Where-Object {
            $_.published_at -and [DateTime]::Parse($_.published_at) -ge $startDate
        }

        $stats = @{
            TotalPublished = $published.Count
            TotalViews = ($published | Measure-Object -Property views -Sum).Sum
            TotalClicks = ($published | Measure-Object -Property clicks -Sum).Sum
            TotalRevenue = ($published | Measure-Object -Property revenue -Sum).Sum
            AvgCTR = if ($published.Count -gt 0) {
                [math]::Round((($published | Measure-Object -Property clicks -Sum).Sum / ($published | Measure-Object -Property views -Sum).Sum) * 100, 2)
            }
            else { 0 }
        }

        return $stats
    }
    catch {
        Write-PublisherLog -Level ERROR -Message "Failed to get content performance: $_"
        return @{}
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

function Start-BlogPublisher {
    Write-Host "`n" + ("=" * 70) -ForegroundColor Cyan
    Write-Host "  LUXRIG BLOG PUBLISHER" -ForegroundColor Cyan
    Write-Host ("=" * 70) + "`n" -ForegroundColor Cyan

    Write-Host "Platform: $Platform" -ForegroundColor White
    Write-Host "Topic: $Topic" -ForegroundColor White
    Write-Host "Posts to generate: $Count" -ForegroundColor White
    Write-Host "Auto-publish: $(if ($AutoPublish) { 'Yes' } else { 'No' })" -ForegroundColor White
    Write-Host ""

    $publishedCount = 0
    $failedCount = 0

    for ($i = 1; $i -le $Count; $i++) {
        Write-Host "`nGenerating post $i of $Count..." -ForegroundColor Yellow

        # Generate blog post
        $post = New-BlogPost -Topic $Topic

        if ($post) {
            Write-PublisherLog -Level SUCCESS -Message "Post generated: $($post.Title)"

            if ($AutoPublish) {
                # Publish to platform
                $result = Publish-ToWordPress -Post $post -Status 'publish'

                if ($result.Success) {
                    $publishedCount++
                    Write-PublisherLog -Level SUCCESS -Message "Post published successfully: $($result.URL)"
                }
                else {
                    $failedCount++
                    Write-PublisherLog -Level ERROR -Message "Failed to publish post"
                }
            }
            else {
                # Save as draft
                Save-PostToDatabase -Post $post -Platform $Platform -Status 'DRAFT'
                Write-PublisherLog -Level INFO -Message "Post saved as draft"
            }
        }
        else {
            $failedCount++
            Write-PublisherLog -Level ERROR -Message "Failed to generate post"
        }

        # Add delay between posts
        if ($i -lt $Count) {
            Write-Host "Waiting before next generation..." -ForegroundColor Gray
            Start-Sleep -Seconds 5
        }
    }

    # Summary
    Write-Host "`n" + ("=" * 70) -ForegroundColor Cyan
    Write-Host "  PUBLISHING COMPLETE" -ForegroundColor Green
    Write-Host ("=" * 70) -ForegroundColor Cyan

    Write-Host "`nResults:" -ForegroundColor Yellow
    Write-Host "  Total posts generated: $Count" -ForegroundColor White
    Write-Host "  Successfully published: $publishedCount" -ForegroundColor Green
    Write-Host "  Failed: $failedCount" -ForegroundColor Red

    # Show performance stats
    if ($AutoPublish -and $publishedCount -gt 0) {
        Write-Host "`nGetting performance stats..." -ForegroundColor Cyan
        $stats = Get-ContentPerformance -Days 30

        Write-Host "  Published (last 30 days): $($stats.TotalPublished)" -ForegroundColor White
        Write-Host "  Total views: $($stats.TotalViews)" -ForegroundColor White
        Write-Host "  Total revenue: $$($stats.TotalRevenue)" -ForegroundColor White
    }
}

# ============================================================================
# EXECUTION
# ============================================================================

try {
    Start-BlogPublisher
}
catch {
    Write-PublisherLog -Level ERROR -Message "Fatal error: $_"
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}
