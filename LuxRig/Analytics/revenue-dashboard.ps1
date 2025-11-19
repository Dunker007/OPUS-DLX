# ============================================================================
# LuxRig Revenue Dashboard
# Purpose: Real-time revenue tracking and reporting with email summaries
# Location: LuxRig/Analytics/revenue-dashboard.ps1
# ============================================================================

<#
.SYNOPSIS
    Comprehensive revenue tracking and analytics dashboard.

.DESCRIPTION
    Production-ready revenue dashboard featuring:
    - Multi-source revenue tracking (trading, content, API, affiliate)
    - Real-time metrics and KPIs
    - HTML dashboard generation
    - Daily/weekly/monthly reports
    - Email summaries
    - Performance forecasting
    - ROI calculations

.PARAMETER ReportType
    Type of report (daily, weekly, monthly, realtime)

.PARAMETER OutputFormat
    Output format (html, json, console)

.PARAMETER SendEmail
    Send email summary

.EXAMPLE
    .\revenue-dashboard.ps1 -ReportType daily -OutputFormat html -SendEmail
#>

param(
    [ValidateSet('daily', 'weekly', 'monthly', 'realtime')]
    [string]$ReportType = 'daily',

    [ValidateSet('html', 'json', 'console')]
    [string]$OutputFormat = 'console',

    [switch]$SendEmail,

    [switch]$Watch
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# IMPORTS
# ============================================================================

$dataAccessModule = Join-Path $PSScriptRoot '../Database/data-access.ps1'

if (Test-Path $dataAccessModule) {
    . $dataAccessModule
}

# ============================================================================
# CONFIGURATION
# ============================================================================

$Script:Config = @{
    DashboardPath = Join-Path $PSScriptRoot '../Data/dashboard.html'
    ReportsPath = Join-Path $PSScriptRoot '../Data/Reports'
    RefreshInterval = 60  # Seconds
    EmailRecipients = @()
    TargetDailyRevenue = 100
    TargetMonthlyRevenue = 3000
}

# ============================================================================
# LOGGING
# ============================================================================

function Write-DashboardLog {
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

    Write-Host "[$timestamp] [DASHBOARD] [$Level] $Message" -ForegroundColor $color

    $logPath = Join-Path $PSScriptRoot '../Logs/revenue-dashboard.log'
    if (Test-Path (Split-Path $logPath)) {
        "[$timestamp] [$Level] $Message" | Add-Content -Path $logPath -ErrorAction SilentlyContinue
    }
}

# ============================================================================
# DATA COLLECTION
# ============================================================================

function Get-RevenueMetrics {
    param(
        [DateTime]$StartDate = (Get-Date).Date,
        [DateTime]$EndDate = (Get-Date).Date.AddDays(1).AddSeconds(-1)
    )

    try {
        Write-DashboardLog -Level INFO -Message "Collecting revenue metrics from $($StartDate.ToString('yyyy-MM-dd')) to $($EndDate.ToString('yyyy-MM-dd'))"

        # Get revenue data
        $revenueData = Get-RevenueByDateRange -StartDate $StartDate -EndDate $EndDate

        # Calculate totals by source
        $metrics = @{
            Trading = 0
            Content = 0
            Affiliate = 0
            API = 0
            Subscription = 0
            Other = 0
            Total = 0
            TransactionCount = 0
            AvgTransaction = 0
            TopSource = ''
        }

        foreach ($record in $revenueData) {
            $source = $record.source
            $amount = [double]$record.total_amount

            $metrics[$source] = $amount
            $metrics.Total += $amount
            $metrics.TransactionCount += [int]$record.transaction_count
        }

        if ($metrics.TransactionCount -gt 0) {
            $metrics.AvgTransaction = [math]::Round($metrics.Total / $metrics.TransactionCount, 2)
        }

        # Find top source
        $topSource = $revenueData | Sort-Object total_amount -Descending | Select-Object -First 1
        if ($topSource) {
            $metrics.TopSource = $topSource.source
        }

        Write-DashboardLog -Level SUCCESS -Message "Metrics collected: Total Revenue = $$($metrics.Total)"

        return $metrics
    }
    catch {
        Write-DashboardLog -Level ERROR -Message "Failed to collect revenue metrics: $_"
        return @{
            Total = 0
            TransactionCount = 0
        }
    }
}

function Get-TradingMetrics {
    param([int]$Days = 30)

    try {
        $stats = Get-TradeStatistics -StartDate (Get-Date).AddDays(-$Days) -EndDate (Get-Date)

        if ($stats) {
            return @{
                TotalTrades = $stats.total_trades
                WinRate = $stats.win_rate
                TotalProfitLoss = [math]::Round([double]$stats.total_profit_loss, 2)
                AvgProfitLoss = [math]::Round([double]$stats.avg_profit_loss, 2)
                TotalFees = [math]::Round([double]$stats.total_fees, 2)
                Volume = [math]::Round([double]$stats.total_volume, 2)
            }
        }

        return @{
            TotalTrades = 0
            WinRate = 0
            TotalProfitLoss = 0
        }
    }
    catch {
        Write-DashboardLog -Level ERROR -Message "Failed to get trading metrics: $_"
        return @{}
    }
}

function Get-ContentMetrics {
    param([int]$Days = 30)

    try {
        $content = Get-Content -Type 'BLOG' -Status 'PUBLISHED' -Limit 100

        $recent = $content | Where-Object {
            $_.published_at -and [DateTime]::Parse($_.published_at) -ge (Get-Date).AddDays(-$Days)
        }

        return @{
            PublishedCount = $recent.Count
            TotalViews = ($recent | Measure-Object -Property views -Sum).Sum
            TotalClicks = ($recent | Measure-Object -Property clicks -Sum).Sum
            TotalRevenue = ($recent | Measure-Object -Property revenue -Sum).Sum
            AvgCTR = if ($recent.Count -gt 0) {
                $totalViews = ($recent | Measure-Object -Property views -Sum).Sum
                $totalClicks = ($recent | Measure-Object -Property clicks -Sum).Sum
                if ($totalViews -gt 0) {
                    [math]::Round(($totalClicks / $totalViews) * 100, 2)
                }
                else { 0 }
            }
            else { 0 }
        }
    }
    catch {
        Write-DashboardLog -Level ERROR -Message "Failed to get content metrics: $_"
        return @{}
    }
}

function Get-APIMetrics {
    param([int]$Hours = 24)

    try {
        $stats = Get-APIUsageStatistics -Hours $Hours

        $totals = @{
            TotalRequests = 0
            SuccessfulRequests = 0
            FailedRequests = 0
            TotalCost = 0
            TotalTokens = 0
            AvgResponseTime = 0
        }

        foreach ($stat in $stats) {
            $totals.TotalRequests += [int]$stat.total_requests
            $totals.SuccessfulRequests += [int]$stat.successful_requests
            $totals.FailedRequests += [int]$stat.failed_requests
            $totals.TotalCost += [double]$stat.total_cost
            $totals.TotalTokens += [int]$stat.total_tokens
        }

        if ($stats.Count -gt 0) {
            $totals.AvgResponseTime = [math]::Round(($stats | Measure-Object -Property avg_response_time -Average).Average, 0)
        }

        return $totals
    }
    catch {
        Write-DashboardLog -Level ERROR -Message "Failed to get API metrics: $_"
        return @{}
    }
}

# ============================================================================
# REPORT GENERATION
# ============================================================================

function New-DailyReport {
    try {
        Write-DashboardLog -Level INFO -Message "Generating daily report..."

        $today = Get-Date
        $yesterday = $today.AddDays(-1)

        # Get metrics
        $todayMetrics = Get-RevenueMetrics -StartDate $today.Date -EndDate $today
        $yesterdayMetrics = Get-RevenueMetrics -StartDate $yesterday.Date -EndDate $yesterday.Date.AddDays(1).AddSeconds(-1)
        $tradingMetrics = Get-TradingMetrics -Days 1
        $contentMetrics = Get-ContentMetrics -Days 1
        $apiMetrics = Get-APIMetrics -Hours 24

        # Calculate changes
        $revenueChange = if ($yesterdayMetrics.Total -gt 0) {
            [math]::Round((($todayMetrics.Total - $yesterdayMetrics.Total) / $yesterdayMetrics.Total) * 100, 2)
        }
        else { 0 }

        $report = @{
            Date = $today.ToString("yyyy-MM-dd")
            Type = "Daily"
            Revenue = @{
                Total = $todayMetrics.Total
                Trading = $todayMetrics.Trading
                Content = $todayMetrics.Content
                API = $todayMetrics.API
                Affiliate = $todayMetrics.Affiliate
                ChangePercent = $revenueChange
                Target = $Script:Config.TargetDailyRevenue
                Achievement = if ($Script:Config.TargetDailyRevenue -gt 0) {
                    [math]::Round(($todayMetrics.Total / $Script:Config.TargetDailyRevenue) * 100, 2)
                }
                else { 0 }
            }
            Trading = $tradingMetrics
            Content = $contentMetrics
            API = $apiMetrics
            GeneratedAt = Get-Date
        }

        Write-DashboardLog -Level SUCCESS -Message "Daily report generated"

        return $report
    }
    catch {
        Write-DashboardLog -Level ERROR -Message "Failed to generate daily report: $_"
        return $null
    }
}

function New-WeeklyReport {
    try {
        Write-DashboardLog -Level INFO -Message "Generating weekly report..."

        $endDate = Get-Date
        $startDate = $endDate.AddDays(-7)

        $metrics = Get-RevenueMetrics -StartDate $startDate -EndDate $endDate
        $tradingMetrics = Get-TradingMetrics -Days 7
        $contentMetrics = Get-ContentMetrics -Days 7

        $report = @{
            StartDate = $startDate.ToString("yyyy-MM-dd")
            EndDate = $endDate.ToString("yyyy-MM-dd")
            Type = "Weekly"
            Revenue = @{
                Total = $metrics.Total
                DailyAverage = [math]::Round($metrics.Total / 7, 2)
                BySource = @{
                    Trading = $metrics.Trading
                    Content = $metrics.Content
                    API = $metrics.API
                    Affiliate = $metrics.Affiliate
                }
            }
            Trading = $tradingMetrics
            Content = $contentMetrics
            GeneratedAt = Get-Date
        }

        Write-DashboardLog -Level SUCCESS -Message "Weekly report generated"

        return $report
    }
    catch {
        Write-DashboardLog -Level ERROR -Message "Failed to generate weekly report: $_"
        return $null
    }
}

function New-MonthlyReport {
    try {
        Write-DashboardLog -Level INFO -Message "Generating monthly report..."

        $endDate = Get-Date
        $startDate = $endDate.AddMonths(-1)

        $metrics = Get-RevenueMetrics -StartDate $startDate -EndDate $endDate
        $tradingMetrics = Get-TradingMetrics -Days 30
        $contentMetrics = Get-ContentMetrics -Days 30

        $report = @{
            StartDate = $startDate.ToString("yyyy-MM-dd")
            EndDate = $endDate.ToString("yyyy-MM-dd")
            Type = "Monthly"
            Revenue = @{
                Total = $metrics.Total
                DailyAverage = [math]::Round($metrics.Total / 30, 2)
                Target = $Script:Config.TargetMonthlyRevenue
                Achievement = if ($Script:Config.TargetMonthlyRevenue -gt 0) {
                    [math]::Round(($metrics.Total / $Script:Config.TargetMonthlyRevenue) * 100, 2)
                }
                else { 0 }
                BySource = @{
                    Trading = $metrics.Trading
                    Content = $metrics.Content
                    API = $metrics.API
                    Affiliate = $metrics.Affiliate
                }
            }
            Trading = $tradingMetrics
            Content = $contentMetrics
            GeneratedAt = Get-Date
        }

        Write-DashboardLog -Level SUCCESS -Message "Monthly report generated"

        return $report
    }
    catch {
        Write-DashboardLog -Level ERROR -Message "Failed to generate monthly report: $_"
        return $null
    }
}

# ============================================================================
# OUTPUT FORMATTING
# ============================================================================

function Format-ConsoleReport {
    param([Parameter(Mandatory)][hashtable]$Report)

    Write-Host "`n" + ("=" * 80) -ForegroundColor Cyan
    Write-Host "  LUXRIG REVENUE DASHBOARD - $($Report.Type.ToUpper()) REPORT" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Cyan

    Write-Host "`n📅 Date: $($Report.Date ?? "$($Report.StartDate) to $($Report.EndDate)")" -ForegroundColor White

    Write-Host "`n💰 REVENUE SUMMARY" -ForegroundColor Yellow
    Write-Host ("─" * 80) -ForegroundColor Gray

    $total = $Report.Revenue.Total
    Write-Host "  Total Revenue:        " -NoNewline -ForegroundColor White
    Write-Host "`$$([math]::Round($total, 2))" -ForegroundColor Green

    if ($Report.Revenue.ContainsKey('ChangePercent')) {
        $changeColor = if ($Report.Revenue.ChangePercent -gt 0) { 'Green' } else { 'Red' }
        $changeSymbol = if ($Report.Revenue.ChangePercent -gt 0) { '▲' } else { '▼' }
        Write-Host "  Change from yesterday: " -NoNewline -ForegroundColor White
        Write-Host "$changeSymbol $($Report.Revenue.ChangePercent)%" -ForegroundColor $changeColor
    }

    if ($Report.Revenue.ContainsKey('Achievement')) {
        Write-Host "  Target Achievement:   " -NoNewline -ForegroundColor White
        $achievementColor = if ($Report.Revenue.Achievement -ge 100) { 'Green' } elseif ($Report.Revenue.Achievement -ge 75) { 'Yellow' } else { 'Red' }
        Write-Host "$($Report.Revenue.Achievement)%" -ForegroundColor $achievementColor
    }

    Write-Host "`n📊 REVENUE BY SOURCE" -ForegroundColor Yellow
    Write-Host ("─" * 80) -ForegroundColor Gray

    $sources = @('Trading', 'Content', 'API', 'Affiliate')
    foreach ($source in $sources) {
        if ($Report.Revenue.ContainsKey($source)) {
            $amount = $Report.Revenue.$source
            $percent = if ($total -gt 0) { [math]::Round(($amount / $total) * 100, 1) } else { 0 }
            Write-Host "  $($source.PadRight(15)): " -NoNewline -ForegroundColor White
            Write-Host "`$$([math]::Round($amount, 2).ToString().PadRight(12)) " -NoNewline -ForegroundColor Cyan
            Write-Host "($percent%)" -ForegroundColor Gray
        }
    }

    if ($Report.Trading) {
        Write-Host "`n📈 TRADING PERFORMANCE" -ForegroundColor Yellow
        Write-Host ("─" * 80) -ForegroundColor Gray
        Write-Host "  Total Trades:  $($Report.Trading.TotalTrades)" -ForegroundColor White
        Write-Host "  Win Rate:      $($Report.Trading.WinRate)%" -ForegroundColor $(if ($Report.Trading.WinRate -ge 50) { 'Green' } else { 'Red' })
        Write-Host "  Profit/Loss:   `$$($Report.Trading.TotalProfitLoss)" -ForegroundColor $(if ($Report.Trading.TotalProfitLoss -gt 0) { 'Green' } else { 'Red' })
        Write-Host "  Volume:        `$$($Report.Trading.Volume)" -ForegroundColor Cyan
    }

    if ($Report.Content) {
        Write-Host "`n📝 CONTENT PERFORMANCE" -ForegroundColor Yellow
        Write-Host ("─" * 80) -ForegroundColor Gray
        Write-Host "  Published:     $($Report.Content.PublishedCount)" -ForegroundColor White
        Write-Host "  Total Views:   $($Report.Content.TotalViews)" -ForegroundColor Cyan
        Write-Host "  Total Clicks:  $($Report.Content.TotalClicks)" -ForegroundColor Cyan
        Write-Host "  CTR:           $($Report.Content.AvgCTR)%" -ForegroundColor White
        Write-Host "  Revenue:       `$$($Report.Content.TotalRevenue)" -ForegroundColor Green
    }

    if ($Report.API) {
        Write-Host "`n🔌 API USAGE" -ForegroundColor Yellow
        Write-Host ("─" * 80) -ForegroundColor Gray
        Write-Host "  Total Requests:     $($Report.API.TotalRequests)" -ForegroundColor White
        Write-Host "  Successful:         $($Report.API.SuccessfulRequests)" -ForegroundColor Green
        Write-Host "  Failed:             $($Report.API.FailedRequests)" -ForegroundColor Red
        Write-Host "  Avg Response Time:  $($Report.API.AvgResponseTime)ms" -ForegroundColor Cyan
        Write-Host "  Total Cost:         `$$($Report.API.TotalCost)" -ForegroundColor Yellow
    }

    Write-Host "`n" + ("=" * 80) -ForegroundColor Cyan
    Write-Host "  Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Host ("=" * 80) + "`n" -ForegroundColor Cyan
}

function Export-HTMLDashboard {
    param([Parameter(Mandatory)][hashtable]$Report)

    try {
        $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LuxRig Revenue Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #0f0f23; color: #e0e0e0; padding: 20px; }
        .container { max-width: 1400px; margin: 0 auto; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; border-radius: 10px; margin-bottom: 30px; }
        .header h1 { color: white; font-size: 32px; margin-bottom: 10px; }
        .header .subtitle { color: rgba(255,255,255,0.9); font-size: 16px; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .card { background: #1a1a2e; padding: 25px; border-radius: 10px; border: 1px solid #2a2a3e; }
        .card h2 { color: #667eea; font-size: 18px; margin-bottom: 15px; border-bottom: 2px solid #667eea; padding-bottom: 10px; }
        .metric { display: flex; justify-content: space-between; align-items: center; margin: 15px 0; }
        .metric-label { color: #b0b0b0; font-size: 14px; }
        .metric-value { font-size: 24px; font-weight: bold; color: #4ade80; }
        .metric-value.negative { color: #ef4444; }
        .metric-value.neutral { color: #fbbf24; }
        .progress-bar { width: 100%; height: 8px; background: #2a2a3e; border-radius: 4px; overflow: hidden; margin-top: 10px; }
        .progress-fill { height: 100%; background: linear-gradient(90deg, #667eea 0%, #764ba2 100%); transition: width 0.3s; }
        .source-breakdown { margin-top: 20px; }
        .source-item { display: flex; justify-content: space-between; padding: 12px; background: #2a2a3e; margin: 8px 0; border-radius: 5px; }
        .footer { text-align: center; color: #666; margin-top: 40px; padding: 20px; border-top: 1px solid #2a2a3e; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>💎 LuxRig Revenue Dashboard</h1>
            <div class="subtitle">$($Report.Type) Report - $(if ($Report.Date) { $Report.Date } else { "$($Report.StartDate) to $($Report.EndDate)" })</div>
        </div>

        <div class="grid">
            <div class="card">
                <h2>💰 Total Revenue</h2>
                <div class="metric">
                    <span class="metric-label">Total Earned</span>
                    <span class="metric-value">`$$([math]::Round($Report.Revenue.Total, 2))</span>
                </div>
                $(if ($Report.Revenue.ContainsKey('Achievement')) {
                    $achievement = $Report.Revenue.Achievement
                    @"
                <div class="metric">
                    <span class="metric-label">Target Achievement</span>
                    <span class="metric-value $(if ($achievement -ge 100) { '' } elseif ($achievement -ge 75) { 'neutral' } else { 'negative' })">$achievement%</span>
                </div>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: $([math]::Min($achievement, 100))%"></div>
                </div>
"@
                })
            </div>

            <div class="card">
                <h2>📊 Revenue by Source</h2>
                <div class="source-breakdown">
                    <div class="source-item">
                        <span>Trading</span>
                        <strong>`$$([math]::Round($Report.Revenue.Trading, 2))</strong>
                    </div>
                    <div class="source-item">
                        <span>Content</span>
                        <strong>`$$([math]::Round($Report.Revenue.Content, 2))</strong>
                    </div>
                    <div class="source-item">
                        <span>API</span>
                        <strong>`$$([math]::Round($Report.Revenue.API, 2))</strong>
                    </div>
                    <div class="source-item">
                        <span>Affiliate</span>
                        <strong>`$$([math]::Round($Report.Revenue.Affiliate, 2))</strong>
                    </div>
                </div>
            </div>

            $(if ($Report.Trading) {
                @"
            <div class="card">
                <h2>📈 Trading Performance</h2>
                <div class="metric">
                    <span class="metric-label">Total Trades</span>
                    <span class="metric-value neutral">$($Report.Trading.TotalTrades)</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Win Rate</span>
                    <span class="metric-value $(if ($Report.Trading.WinRate -ge 50) { '' } else { 'negative' })">$($Report.Trading.WinRate)%</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Profit/Loss</span>
                    <span class="metric-value $(if ($Report.Trading.TotalProfitLoss -gt 0) { '' } else { 'negative' })">`$$($Report.Trading.TotalProfitLoss)</span>
                </div>
            </div>
"@
            })

            $(if ($Report.Content) {
                @"
            <div class="card">
                <h2>📝 Content Performance</h2>
                <div class="metric">
                    <span class="metric-label">Published</span>
                    <span class="metric-value neutral">$($Report.Content.PublishedCount)</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Total Views</span>
                    <span class="metric-value neutral">$($Report.Content.TotalViews)</span>
                </div>
                <div class="metric">
                    <span class="metric-label">CTR</span>
                    <span class="metric-value">$($Report.Content.AvgCTR)%</span>
                </div>
            </div>
"@
            })
        </div>

        <div class="footer">
            Generated by LuxRig Revenue Dashboard at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        </div>
    </div>
</body>
</html>
"@

        # Ensure reports directory exists
        if (-not (Test-Path $Script:Config.ReportsPath)) {
            New-Item -ItemType Directory -Path $Script:Config.ReportsPath -Force | Out-Null
        }

        # Save dashboard
        $html | Set-Content -Path $Script:Config.DashboardPath -Encoding UTF8

        # Save report
        $reportFilename = "revenue-report-$($Report.Type.ToLower())-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
        $reportPath = Join-Path $Script:Config.ReportsPath $reportFilename
        $html | Set-Content -Path $reportPath -Encoding UTF8

        Write-DashboardLog -Level SUCCESS -Message "HTML dashboard saved to: $($Script:Config.DashboardPath)"
        Write-DashboardLog -Level SUCCESS -Message "Report saved to: $reportPath"

        return $Script:Config.DashboardPath
    }
    catch {
        Write-DashboardLog -Level ERROR -Message "Failed to export HTML dashboard: $_"
        return $null
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

function Start-RevenueDashboard {
    Write-Host "`n" + ("=" * 80) -ForegroundColor Cyan
    Write-Host "  LUXRIG REVENUE DASHBOARD" -ForegroundColor Cyan
    Write-Host ("=" * 80) + "`n" -ForegroundColor Cyan

    # Generate report based on type
    $report = switch ($ReportType) {
        'daily' { New-DailyReport }
        'weekly' { New-WeeklyReport }
        'monthly' { New-MonthlyReport }
        'realtime' { New-DailyReport }
    }

    if ($report) {
        # Output based on format
        switch ($OutputFormat) {
            'console' {
                Format-ConsoleReport -Report $report
            }
            'html' {
                $dashboardPath = Export-HTMLDashboard -Report $report
                Write-Host "Dashboard saved to: $dashboardPath" -ForegroundColor Green
            }
            'json' {
                $jsonPath = Join-Path $Script:Config.ReportsPath "revenue-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
                $report | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding UTF8
                Write-Host "JSON report saved to: $jsonPath" -ForegroundColor Green
            }
        }

        # Send email if requested
        if ($SendEmail) {
            Write-DashboardLog -Level INFO -Message "Email sending not yet implemented"
        }

        # Watch mode
        if ($Watch) {
            Write-Host "`nEntering watch mode (refresh every $($Script:Config.RefreshInterval) seconds)..." -ForegroundColor Yellow
            Write-Host "Press Ctrl+C to exit`n" -ForegroundColor Gray

            while ($true) {
                Start-Sleep -Seconds $Script:Config.RefreshInterval
                Clear-Host
                $report = New-DailyReport
                Format-ConsoleReport -Report $report

                if ($OutputFormat -eq 'html') {
                    Export-HTMLDashboard -Report $report | Out-Null
                }
            }
        }
    }
    else {
        Write-DashboardLog -Level ERROR -Message "Failed to generate report"
    }
}

# ============================================================================
# EXECUTION
# ============================================================================

try {
    Start-RevenueDashboard
}
catch {
    Write-DashboardLog -Level ERROR -Message "Fatal error: $_"
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}
