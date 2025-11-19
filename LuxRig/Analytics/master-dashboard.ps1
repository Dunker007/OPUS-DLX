#Requires -Version 7.0
<#
.SYNOPSIS
    Master Control Dashboard - Single pane of glass for entire empire
.DESCRIPTION
    Real-time metrics dashboard displaying:
    - Revenue (today, week, month, all-time)
    - Active Products (deployed count, top performers)
    - Traffic (visitors across all properties)
    - Conversions (trials → paid, free → premium)
    - AI Costs (spend by model, ROI per model)
    - Opportunities (new ideas, validation in progress)
    - Tasks (what's running right now)
    - Alerts (issues requiring attention)

    Visualizations: Revenue graphs, product performance tables, AI usage heatmaps, marketing funnels, geographic maps
.NOTES
    Part of Phase 3: Intelligence Dashboard
    Command center for the entire LuxRig empire
#>

# ============================================================================
# CONFIGURATION
# ============================================================================

$script:Config = @{
    RefreshInterval = 10  # seconds
    RevenueTracker = "$PSScriptRoot/revenue-tracker.ps1"
    ROICalculator = "$PSScriptRoot/../Orchestrator/roi-calculator.ps1"
}

# ============================================================================
# REVENUE METRICS
# ============================================================================

function Get-RevenueDashboard {
    $now = Get-Date

    # Simulate revenue data (would fetch from actual sources)
    $revenue = @{
        today = [Math]::Round((Get-Random -Minimum 50 -Maximum 500), 2)
        week = [Math]::Round((Get-Random -Minimum 500 -Maximum 2000), 2)
        month = [Math]::Round((Get-Random -Minimum 2000 -Maximum 10000), 2)
        allTime = [Math]::Round((Get-Random -Minimum 10000 -Maximum 50000), 2)
        growth = @{
            todayVsYesterday = [Math]::Round((Get-Random -Minimum -20 -Maximum 50), 1)
            weekVsLastWeek = [Math]::Round((Get-Random -Minimum -10 -Maximum 40), 1)
            monthVsLastMonth = [Math]::Round((Get-Random -Minimum 5 -Maximum 80), 1)
        }
        sources = @{
            stripe = [Math]::Round((Get-Random -Minimum 1000 -Maximum 5000), 2)
            affiliates = [Math]::Round((Get-Random -Minimum 200 -Maximum 2000), 2)
            products = [Math]::Round((Get-Random -Minimum 500 -Maximum 3000), 2)
        }
    }

    return $revenue
}

# ============================================================================
# PRODUCT METRICS
# ============================================================================

function Get-ProductDashboard {
    # Simulate product data
    $products = @(
        @{name = "Product A"; status = "active"; revenue = 1500; customers = 45; mrr = 1500},
        @{name = "Product B"; status = "active"; revenue = 800; customers = 28; mrr = 800},
        @{name = "Product C"; status = "active"; revenue = 450; customers = 15; mrr = 450},
        @{name = "Product D"; status = "beta"; revenue = 120; customers = 8; mrr = 120},
        @{name = "Product E"; status = "development"; revenue = 0; customers = 0; mrr = 0}
    )

    $summary = @{
        total = $products.Count
        active = ($products | Where-Object { $_.status -eq "active" }).Count
        beta = ($products | Where-Object { $_.status -eq "beta" }).Count
        development = ($products | Where-Object { $_.status -eq "development" }).Count
        totalRevenue = ($products.revenue | Measure-Object -Sum).Sum
        totalCustomers = ($products.customers | Measure-Object -Sum).Sum
        topPerformers = $products | Sort-Object revenue -Descending | Select-Object -First 3
    }

    return @{
        products = $products
        summary = $summary
    }
}

# ============================================================================
# TRAFFIC METRICS
# ============================================================================

function Get-TrafficDashboard {
    $traffic = @{
        today = Get-Random -Minimum 500 -Maximum 5000
        week = Get-Random -Minimum 5000 -Maximum 30000
        month = Get-Random -Minimum 20000 -Maximum 150000
        sources = @{
            organic = 45
            direct = 25
            social = 15
            referral = 10
            paid = 5
        }
        topPages = @(
            @{page = "/products/tool-a"; views = 2500; conversions = 125},
            @{page = "/blog/tutorial-guide"; views = 1800; conversions = 54},
            @{page = "/pricing"; views = 1500; conversions = 90}
        )
        countries = @(
            @{country = "United States"; percentage = 42},
            @{country = "United Kingdom"; percentage = 18},
            @{country = "Canada"; percentage = 12},
            @{country = "Germany"; percentage = 8},
            @{country = "Other"; percentage = 20}
        )
    }

    return $traffic
}

# ============================================================================
# CONVERSION METRICS
# ============================================================================

function Get-ConversionDashboard {
    $conversions = @{
        trialToPaid = @{
            rate = [Math]::Round((Get-Random -Minimum 15 -Maximum 35), 1)
            thisMonth = Get-Random -Minimum 20 -Maximum 100
            lastMonth = Get-Random -Minimum 15 -Maximum 90
        }
        freeToPremium = @{
            rate = [Math]::Round((Get-Random -Minimum 5 -Maximum 15), 1)
            thisMonth = Get-Random -Minimum 10 -Maximum 50
            lastMonth = Get-Random -Minimum 8 -Maximum 45
        }
        funnel = @{
            visitors = 10000
            signups = 500
            trials = 150
            paid = 45
        }
    }

    # Calculate funnel percentages
    $conversions.funnel.signupRate = [Math]::Round(($conversions.funnel.signups / $conversions.funnel.visitors) * 100, 1)
    $conversions.funnel.trialRate = [Math]::Round(($conversions.funnel.trials / $conversions.funnel.signups) * 100, 1)
    $conversions.funnel.paidRate = [Math]::Round(($conversions.funnel.paid / $conversions.funnel.trials) * 100, 1)

    return $conversions
}

# ============================================================================
# AI COST METRICS
# ============================================================================

function Get-AICostDashboard {
    $aiCosts = @{
        today = [Math]::Round((Get-Random -Minimum 5 -Maximum 50), 2)
        month = [Math]::Round((Get-Random -Minimum 150 -Maximum 500), 2)
        byModel = @(
            @{model = "Claude Opus"; cost = 120.50; requests = 450; avgCost = 0.268},
            @{model = "GPT-4"; cost = 85.30; requests = 320; avgCost = 0.266},
            @{model = "Gemini Pro"; cost = 32.10; requests = 890; avgCost = 0.036},
            @{model = "Local (Ollama)"; cost = 0; requests = 2340; avgCost = 0}
        )
        roi = @{
            revenueGenerated = 2870
            aiCostTotal = 237.90
            roi = [Math]::Round((2870 / 237.90), 1)
        }
    }

    return $aiCosts
}

# ============================================================================
# OPPORTUNITIES TRACKER
# ============================================================================

function Get-OpportunitiesDashboard {
    $opportunities = @{
        discovered = Get-Random -Minimum 50 -Maximum 200
        validated = Get-Random -Minimum 10 -Maximum 50
        inDevelopment = Get-Random -Minimum 3 -Maximum 15
        launched = Get-Random -Minimum 1 -Maximum 5
        topOpportunities = @(
            @{title = "Opp A"; score = 8.5; status = "validated"},
            @{title = "Opp B"; score = 7.8; status = "validation"},
            @{title = "Opp C"; score = 7.2; status = "development"}
        )
    }

    return $opportunities
}

# ============================================================================
# ACTIVE TASKS
# ============================================================================

function Get-ActiveTasks {
    $tasks = @(
        @{name = "Content generation"; status = "running"; progress = 65},
        @{name = "SEO audit"; status = "running"; progress = 40},
        @{name = "Email campaign"; status = "scheduled"; startTime = (Get-Date).AddHours(2)},
        @{name = "Competitor analysis"; status = "running"; progress = 80},
        @{name = "Product deployment"; status = "queued"}
    )

    $summary = @{
        running = ($tasks | Where-Object { $_.status -eq "running" }).Count
        scheduled = ($tasks | Where-Object { $_.status -eq "scheduled" }).Count
        queued = ($tasks | Where-Object { $_.status -eq "queued" }).Count
    }

    return @{
        tasks = $tasks
        summary = $summary
    }
}

# ============================================================================
# ALERTS & NOTIFICATIONS
# ============================================================================

function Get-SystemAlerts {
    $alerts = @(
        @{level = "warning"; message = "AI budget at 85% for this month"; action = "Review usage"},
        @{level = "info"; message = "New high-value opportunity detected"; action = "Review"},
        @{level = "success"; message = "Product deployment successful"; action = "None"}
    )

    $summary = @{
        critical = ($alerts | Where-Object { $_.level -eq "critical" }).Count
        warning = ($alerts | Where-Object { $_.level -eq "warning" }).Count
        info = ($alerts | Where-Object { $_.level -eq "info" }).Count
    }

    return @{
        alerts = $alerts
        summary = $summary
    }
}

# ============================================================================
# MAIN DASHBOARD
# ============================================================================

function Show-MasterDashboard {
    param(
        [switch]$Continuous = $false,
        [int]$RefreshInterval = $script:Config.RefreshInterval
    )

    do {
        Clear-Host

        Write-Host "╔═══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║                      🎯 LUXRIG MASTER CONTROL DASHBOARD                       ║" -ForegroundColor Cyan
        Write-Host "╚═══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "📅 $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
        Write-Host ""

        # Revenue Section
        $revenue = Get-RevenueDashboard
        Write-Host "💰 REVENUE" -ForegroundColor Green
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
        Write-Host "   Today:     `$$($revenue.today)    $(if ($revenue.growth.todayVsYesterday -gt 0) { "📈 +$($revenue.growth.todayVsYesterday)%" } else { "📉 $($revenue.growth.todayVsYesterday)%" })" -ForegroundColor White
        Write-Host "   This Week: `$$($revenue.week)   $(if ($revenue.growth.weekVsLastWeek -gt 0) { "📈 +$($revenue.growth.weekVsLastWeek)%" } else { "📉 $($revenue.growth.weekVsLastWeek)%" })" -ForegroundColor White
        Write-Host "   This Month:`$$($revenue.month)  $(if ($revenue.growth.monthVsLastMonth -gt 0) { "📈 +$($revenue.growth.monthVsLastMonth)%" } else { "📉 $($revenue.growth.monthVsLastMonth)%" })" -ForegroundColor White
        Write-Host "   All-Time:  `$$($revenue.allTime)" -ForegroundColor White
        Write-Host ""

        # Products Section
        $products = Get-ProductDashboard
        Write-Host "🚀 PRODUCTS" -ForegroundColor Magenta
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
        Write-Host "   Active: $($products.summary.active) | Beta: $($products.summary.beta) | Development: $($products.summary.development)" -ForegroundColor White
        Write-Host "   Total Revenue: `$$($products.summary.totalRevenue) | Customers: $($products.summary.totalCustomers)" -ForegroundColor White
        Write-Host ""
        Write-Host "   Top Performers:" -ForegroundColor Yellow
        foreach ($product in $products.summary.topPerformers) {
            Write-Host "   • $($product.name): `$$($product.revenue) ($($product.customers) customers)" -ForegroundColor Gray
        }
        Write-Host ""

        # Traffic Section
        $traffic = Get-TrafficDashboard
        Write-Host "📊 TRAFFIC" -ForegroundColor Blue
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
        Write-Host "   Today: $($traffic.today) | Week: $($traffic.week) | Month: $($traffic.month)" -ForegroundColor White
        Write-Host "   Sources: Organic $($traffic.sources.organic)% | Direct $($traffic.sources.direct)% | Social $($traffic.sources.social)%" -ForegroundColor White
        Write-Host ""

        # Conversions Section
        $conversions = Get-ConversionDashboard
        Write-Host "🎯 CONVERSIONS" -ForegroundColor Yellow
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
        Write-Host "   Trial → Paid: $($conversions.trialToPaid.rate)% | Free → Premium: $($conversions.freeToPremium.rate)%" -ForegroundColor White
        Write-Host "   Funnel: $($conversions.funnel.visitors) visitors → $($conversions.funnel.signups) signups → $($conversions.funnel.trials) trials → $($conversions.funnel.paid) paid" -ForegroundColor White
        Write-Host ""

        # AI Costs Section
        $aiCosts = Get-AICostDashboard
        Write-Host "🤖 AI COSTS & ROI" -ForegroundColor Cyan
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
        Write-Host "   Today: `$$($aiCosts.today) | Month: `$$($aiCosts.month)" -ForegroundColor White
        Write-Host "   ROI: $($aiCosts.roi.roi)x (Revenue: `$$($aiCosts.roi.revenueGenerated) / Cost: `$$($aiCosts.roi.aiCostTotal))" -ForegroundColor Green
        Write-Host ""

        # Active Tasks Section
        $tasks = Get-ActiveTasks
        Write-Host "⚙️  ACTIVE TASKS" -ForegroundColor Magenta
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
        Write-Host "   Running: $($tasks.summary.running) | Scheduled: $($tasks.summary.scheduled) | Queued: $($tasks.summary.queued)" -ForegroundColor White
        Write-Host ""

        # Alerts Section
        $alerts = Get-SystemAlerts
        if ($alerts.alerts.Count -gt 0) {
            Write-Host "🔔 ALERTS" -ForegroundColor Red
            Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
            foreach ($alert in $alerts.alerts) {
                $color = switch ($alert.level) {
                    "critical" { "Red" }
                    "warning" { "Yellow" }
                    default { "White" }
                }
                Write-Host "   • $($alert.message)" -ForegroundColor $color
            }
            Write-Host ""
        }

        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray

        if ($Continuous) {
            Write-Host "`n🔄 Refreshing in $RefreshInterval seconds... (Press Ctrl+C to stop)" -ForegroundColor Gray
            Start-Sleep -Seconds $RefreshInterval
        }

    } while ($Continuous)
}

# ============================================================================
# EXPORT
# ============================================================================

Export-ModuleMember -Function Show-MasterDashboard, Get-RevenueDashboard, Get-ProductDashboard, Get-TrafficDashboard

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Master Dashboard ready. Use Show-MasterDashboard -Continuous for live view" -ForegroundColor Yellow
}
