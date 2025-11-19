<#
.SYNOPSIS
    Analytics Collector - Comprehensive performance metrics

.DESCRIPTION
    Collects and analyzes:
    - Traffic data
    - Conversion rates
    - User behavior
    - Content performance
    - Revenue attribution
#>

function New-TrafficEvent {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Source,  # web, api, content

        [Parameter(Mandatory=$true)]
        [string]$Path,

        [string]$UserId = "anonymous",

        [hashtable]$Metadata = @{}
    )

    $event = @{
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        source = $Source
        path = $Path
        userId = $UserId
        userAgent = $Metadata.userAgent
        referrer = $Metadata.referrer
        ip = $Metadata.ip
        metadata = $Metadata
    }

    $trafficFile = "$PSScriptRoot\traffic\events-$(Get-Date -Format 'yyyy-MM').jsonl"
    $trafficDir = Split-Path $trafficFile -Parent

    if (-not (Test-Path $trafficDir)) {
        New-Item -ItemType Directory -Path $trafficDir -Force | Out-Null
    }

    $event | ConvertTo-Json -Compress | Add-Content $trafficFile
}

function Get-TrafficStats {
    param(
        [ValidateSet("today", "week", "month")]
        [string]$Period = "today",

        [string]$Source = ""
    )

    $trafficFile = "$PSScriptRoot\traffic\events-$(Get-Date -Format 'yyyy-MM').jsonl"

    if (-not (Test-Path $trafficFile)) {
        return @{pageviews = 0; uniqueVisitors = 0; sources = @{}}
    }

    $events = Get-Content $trafficFile | ForEach-Object { $_ | ConvertFrom-Json }

    # Filter by period
    $filteredEvents = switch ($Period) {
        "today" { $events | Where-Object { ([datetime]$_.timestamp).Date -eq (Get-Date).Date } }
        "week" { $events | Where-Object { ([datetime]$_.timestamp) -gt (Get-Date).AddDays(-7) } }
        "month" { $events }
    }

    # Filter by source if specified
    if ($Source) {
        $filteredEvents = $filteredEvents | Where-Object { $_.source -eq $Source }
    }

    $pageviews = $filteredEvents.Count
    $uniqueVisitors = ($filteredEvents | Select-Object -ExpandProperty userId -Unique).Count

    # Top pages
    $topPages = $filteredEvents | Group-Object path | Sort-Object Count -Descending | Select-Object -First 10

    # Traffic sources
    $sources = $filteredEvents | Group-Object source | ForEach-Object {
        @{source = $_.Name; count = $_.Count}
    }

    return @{
        pageviews = $pageviews
        uniqueVisitors = $uniqueVisitors
        topPages = $topPages
        sources = $sources
        period = $Period
    }
}

function Get-ConversionRate {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FunnelName,

        [ValidateSet("today", "week", "month")]
        [string]$Period = "month"
    )

    $conversionsFile = "$PSScriptRoot\conversions.jsonl"

    if (-not (Test-Path $conversionsFile)) {
        return @{rate = 0; conversions = 0; visitors = 0}
    }

    $conversions = Get-Content $conversionsFile | ForEach-Object { $_ | ConvertFrom-Json }

    $funnelData = $conversions | Where-Object { $_.funnel -eq $FunnelName }

    $periodData = switch ($Period) {
        "today" { $funnelData | Where-Object { ([datetime]$_.date).Date -eq (Get-Date).Date } }
        "week" { $funnelData | Where-Object { ([datetime]$_.date) -gt (Get-Date).AddDays(-7) } }
        "month" { $funnelData }
    }

    $conversions = $periodData.Count
    $visitors = ($periodData | Select-Object -ExpandProperty userId -Unique).Count

    $rate = if ($visitors -gt 0) {
        [Math]::Round(($conversions / $visitors) * 100, 2)
    } else { 0 }

    return @{
        funnel = $FunnelName
        rate = $rate
        conversions = $conversions
        visitors = $visitors
        period = $Period
    }
}

function New-ConversionEvent {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FunnelName,

        [Parameter(Mandatory=$true)]
        [string]$UserId,

        [double]$Value = 0,

        [hashtable]$Metadata = @{}
    )

    $event = @{
        date = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        funnel = $FunnelName
        userId = $UserId
        value = $Value
        metadata = $Metadata
    }

    $conversionsFile = "$PSScriptRoot\conversions.jsonl"
    $event | ConvertTo-Json -Compress | Add-Content $conversionsFile

    Write-Host "✓ Conversion tracked: $FunnelName ($Value)" -ForegroundColor Green
}

function Get-ContentPerformance {
    param([int]$Limit = 10)

    $contentDir = "$PSScriptRoot\..\Content\published"

    if (-not (Test-Path $contentDir)) {
        return @()
    }

    $contentFiles = Get-ChildItem -Path $contentDir -Filter "*.json"

    $performance = @()

    foreach ($file in $contentFiles) {
        $metadata = Get-Content $file.FullName | ConvertFrom-Json

        # Get traffic for this content
        $contentPath = $metadata.filepath -replace '\.md$', ''
        $stats = Get-TrafficStats -Period "month"
        $pageData = $stats.topPages | Where-Object { $_.Name -eq $contentPath }

        $performance += @{
            title = $metadata.title
            views = if ($pageData) { $pageData.Count } else { 0 }
            wordCount = $metadata.wordCount
            qualityScore = $metadata.qualityScore
            generated = $metadata.generated
        }
    }

    return $performance | Sort-Object views -Descending | Select-Object -First $Limit
}

function Get-AnalyticsDashboard {
    Write-Host "`n╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║              ANALYTICS DASHBOARD - 30 DAYS                ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

    # Traffic
    $traffic = Get-TrafficStats -Period "month"
    Write-Host "`nTraffic (30 days):" -ForegroundColor Yellow
    Write-Host "  Pageviews: $($traffic.pageviews)" -ForegroundColor White
    Write-Host "  Unique Visitors: $($traffic.uniqueVisitors)" -ForegroundColor White

    # Top Content
    $topContent = Get-ContentPerformance -Limit 5
    Write-Host "`nTop Performing Content:" -ForegroundColor Yellow
    $topContent | ForEach-Object {
        Write-Host "  - $($_.title): $($_.views) views" -ForegroundColor White
    }

    # Conversions
    $apiConversions = Get-ConversionRate -FunnelName "api-signup" -Period "month"
    Write-Host "`nAPI Signups:" -ForegroundColor Yellow
    Write-Host "  Conversion Rate: $($apiConversions.rate)%" -ForegroundColor White
    Write-Host "  Total Signups: $($apiConversions.conversions)" -ForegroundColor White

    return @{
        traffic = $traffic
        topContent = $topContent
        conversions = @{
            apiSignup = $apiConversions
        }
    }
}

Export-ModuleMember -Function New-TrafficEvent, Get-TrafficStats, Get-ConversionRate, New-ConversionEvent, Get-ContentPerformance, Get-AnalyticsDashboard
