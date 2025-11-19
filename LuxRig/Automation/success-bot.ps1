#Requires -Version 7.0
<#
.SYNOPSIS
    Customer Success Bot - Proactive customer support using AI
.DESCRIPTION
    Automated customer success management:
    - Monitor customer behavior (identify struggling users)
    - Send helpful tips (before they ask)
    - Predict churn risk (offer incentive to stay)
    - Upsell opportunities (identify power users)
    - Collect feedback (NPS surveys, feature requests)
    - Generate case studies (success stories)
.NOTES
    Part of Phase 3: Automation Amplifier
    Reduces churn and increases lifetime value
#>

# ============================================================================
# CONFIGURATION
# ============================================================================

$script:Config = @{
    DataPath = "$PSScriptRoot/../../Data/customer-success"
    ChurnRiskThreshold = 0.7
    PowerUserThreshold = 0.8
}

# ============================================================================
# CUSTOMER HEALTH SCORING
# ============================================================================

function Get-CustomerHealthScore {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Customer
    )

    $score = 100

    # Activity recency (last login)
    $daysSinceLogin = ((Get-Date) - [datetime]::Parse($Customer.lastLogin)).Days
    if ($daysSinceLogin -gt 30) { $score -= 30 }
    elseif ($daysSinceLogin -gt 14) { $score -= 15 }
    elseif ($daysSinceLogin -gt 7) { $score -= 5 }

    # Feature usage
    $featuresUsed = $Customer.featuresUsed ?? 0
    $totalFeatures = 10
    $usageRate = $featuresUsed / $totalFeatures
    if ($usageRate -lt 0.2) { $score -= 20 }

    # Support tickets
    $openTickets = $Customer.openTickets ?? 0
    if ($openTickets -gt 2) { $score -= 15 }

    # Payment history
    if ($Customer.paymentFailures -gt 0) { $score -= 25 }

    # Engagement
    if (-not $Customer.hasCompletedOnboarding) { $score -= 10 }

    $healthScore = [Math]::Max(0, $score) / 100

    $status = if ($healthScore -ge 0.8) { 'Healthy' }
              elseif ($healthScore -ge 0.5) { 'At Risk' }
              else { 'Critical' }

    return @{
        score = $healthScore
        status = $status
        factors = @{
            daysSinceLogin = $daysSinceLogin
            usageRate = [Math]::Round($usageRate * 100, 0)
            openTickets = $openTickets
            paymentIssues = $Customer.paymentFailures -gt 0
        }
    }
}

# ============================================================================
# CHURN PREDICTION
# ============================================================================

function Get-ChurnRisk {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Customer
    )

    $health = Get-CustomerHealthScore -Customer $Customer

    # Additional churn signals
    $signals = @{
        lowActivity = $health.factors.daysSinceLogin -gt 14
        lowUsage = $health.factors.usageRate -lt 30
        supportIssues = $health.factors.openTickets -gt 1
        paymentIssues = $health.factors.paymentIssues
        shortTenure = $Customer.daysSinceSignup -lt 30
    }

    # Count risk signals
    $riskSignals = ($signals.Values | Where-Object { $_ -eq $true }).Count
    $churnProbability = [Math]::Min(1.0, $riskSignals / 5)

    $riskLevel = if ($churnProbability -ge 0.7) { 'High' }
                  elseif ($churnProbability -ge 0.4) { 'Medium' }
                  else { 'Low' }

    return @{
        probability = $churnProbability
        level = $riskLevel
        signals = $signals
        recommendation = Get-ChurnPreventionAction -RiskLevel $riskLevel -Signals $signals
    }
}

function Get-ChurnPreventionAction {
    param(
        [string]$RiskLevel,
        [hashtable]$Signals
    )

    $actions = @()

    if ($Signals.lowActivity) {
        $actions += "Send re-engagement email with value reminder"
    }

    if ($Signals.lowUsage) {
        $actions += "Offer personalized onboarding call"
    }

    if ($Signals.supportIssues) {
        $actions += "Escalate to senior support, offer premium help"
    }

    if ($Signals.paymentIssues) {
        $actions += "Reach out about billing, offer payment plan"
    }

    if ($RiskLevel -eq 'High') {
        $actions += "Offer discount/credit to retain"
        $actions += "Schedule executive call"
    }

    return $actions
}

# ============================================================================
# PROACTIVE SUPPORT
# ============================================================================

function Send-ProactiveTip {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Customer,
        [string]$TipType
    )

    $tips = @{
        'getting_started' = @{
            subject = "Quick tip to get more from [Product]"
            body = "Hey $($Customer.firstName), noticed you just signed up! Here's a tip to get the most value..."
        }
        'feature_discovery' = @{
            subject = "You might have missed this feature..."
            body = "Hi $($Customer.firstName), did you know [Product] can do [advanced feature]? Here's how..."
        }
        'best_practices' = @{
            subject = "How top users are using [Product]"
            body = "Hey $($Customer.firstName), our most successful users do these 3 things..."
        }
        're_engagement' = @{
            subject = "We miss you! Here's what's new"
            body = "Hi $($Customer.firstName), haven't seen you in a while. We've added some great features..."
        }
    }

    $tip = $tips[$TipType]

    Write-Host "📧 Sending proactive tip ($TipType) to $($Customer.email)" -ForegroundColor Cyan

    return @{
        sent = $true
        to = $Customer.email
        subject = $tip.subject
        type = $TipType
    }
}

# ============================================================================
# POWER USER IDENTIFICATION
# ============================================================================

function Find-PowerUsers {
    param([array]$Customers)

    Write-Host "🔍 Identifying power users..." -ForegroundColor Cyan

    $powerUsers = @()

    foreach ($customer in $Customers) {
        $score = 0

        # High usage
        if ($customer.loginCount -gt 100) { $score += 30 }
        elseif ($customer.loginCount -gt 50) { $score += 15 }

        # Feature adoption
        if ($customer.featuresUsed -gt 8) { $score += 25 }

        # Engagement
        if ($customer.referrals -gt 0) { $score += 20 }

        # Tenure
        if ($customer.daysSinceSignup -gt 90) { $score += 15 }

        # No support issues
        if ($customer.openTickets -eq 0) { $score += 10 }

        $powerScore = $score / 100

        if ($powerScore -ge $script:Config.PowerUserThreshold) {
            $powerUsers += @{
                customer = $customer
                powerScore = $powerScore
                upsellOpportunity = $true
                actions = @(
                    "Reach out for testimonial/case study",
                    "Offer VIP upgrade",
                    "Ask for referrals",
                    "Invite to advisory board"
                )
            }
        }
    }

    Write-Host "   Found $($powerUsers.Count) power users" -ForegroundColor Green

    return $powerUsers
}

# ============================================================================
# FEEDBACK COLLECTION
# ============================================================================

function Send-NPSSurvey {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Customer
    )

    Write-Host "📊 Sending NPS survey to $($Customer.email)..." -ForegroundColor Cyan

    $survey = @{
        type = "NPS"
        question = "On a scale of 0-10, how likely are you to recommend [Product] to a friend or colleague?"
        followUp = "What's the main reason for your score?"
        sentTo = $Customer.email
        sentAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    }

    return $survey
}

function Get-NPSScore {
    param([array]$Responses)

    $promoters = ($Responses | Where-Object { $_.score -ge 9 }).Count
    $detractors = ($Responses | Where-Object { $_.score -le 6 }).Count
    $total = $Responses.Count

    if ($total -eq 0) { return 0 }

    $nps = [Math]::Round((($promoters / $total) - ($detractors / $total)) * 100, 0)

    $category = if ($nps -ge 50) { 'Excellent' }
                 elseif ($nps -ge 20) { 'Good' }
                 elseif ($nps -ge 0) { 'Needs Improvement' }
                 else { 'Critical' }

    return @{
        score = $nps
        category = $category
        promoters = $promoters
        passives = ($Responses | Where-Object { $_.score -ge 7 -and $_.score -le 8 }).Count
        detractors = $detractors
        total = $total
    }
}

# ============================================================================
# CASE STUDY GENERATION
# ============================================================================

function New-CaseStudy {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Customer
    )

    Write-Host "📝 Generating case study for $($Customer.company)..." -ForegroundColor Cyan

    $caseStudy = @{
        customer = @{
            name = $Customer.firstName
            company = $Customer.company
            role = $Customer.role
        }
        challenge = "What problem were they facing?"
        solution = "How did [Product] solve it?"
        results = @(
            "Metric 1: X% improvement"
            "Metric 2: Saved Y hours per week"
            "Metric 3: Increased Z by N%"
        )
        quote = "\"[Product] has been a game-changer for us...\" - $($Customer.firstName), $($Customer.role)"
        status = 'draft'
        createdAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    }

    Write-Host "   ✓ Case study draft created" -ForegroundColor Green

    return $caseStudy
}

# ============================================================================
# CUSTOMER SUCCESS DASHBOARD
# ============================================================================

function Get-SuccessMetrics {
    param([array]$Customers)

    $healthyCount = 0
    $atRiskCount = 0
    $criticalCount = 0
    $churnRiskHigh = 0

    foreach ($customer in $Customers) {
        $health = Get-CustomerHealthScore -Customer $customer

        switch ($health.status) {
            'Healthy' { $healthyCount++ }
            'At Risk' { $atRiskCount++ }
            'Critical' { $criticalCount++ }
        }

        $churn = Get-ChurnRisk -Customer $customer
        if ($churn.level -eq 'High') { $churnRiskHigh++ }
    }

    return @{
        totalCustomers = $Customers.Count
        healthy = $healthyCount
        atRisk = $atRiskCount
        critical = $criticalCount
        churnRiskHigh = $churnRiskHigh
        healthRate = [Math]::Round(($healthyCount / $Customers.Count) * 100, 1)
    }
}

# ============================================================================
# AUTOMATED SUCCESS MANAGEMENT
# ============================================================================

function Start-SuccessBot {
    param(
        [array]$Customers,
        [switch]$AutoIntervene = $true
    )

    Write-Host "`n╔══════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║        🤖 CUSTOMER SUCCESS BOT - MONITORING...       ║" -ForegroundColor Magenta
    Write-Host "╚══════════════════════════════════════════════════════╝`n" -ForegroundColor Magenta

    $interventions = @()

    foreach ($customer in $Customers) {
        # Check health
        $health = Get-CustomerHealthScore -Customer $customer
        $churn = Get-ChurnRisk -Customer $customer

        # Intervene if needed
        if ($AutoIntervene) {
            if ($churn.level -eq 'High') {
                Write-Host "⚠️  High churn risk: $($customer.email)" -ForegroundColor Red

                foreach ($action in $churn.recommendation) {
                    Write-Host "   → $action" -ForegroundColor Yellow
                }

                $interventions += @{
                    customer = $customer.email
                    reason = "High churn risk"
                    actions = $churn.recommendation
                }
            }
            elseif ($health.status -eq 'At Risk') {
                # Send proactive tip
                Send-ProactiveTip -Customer $customer -TipType 're_engagement'

                $interventions += @{
                    customer = $customer.email
                    reason = "At risk - low engagement"
                    actions = @("Re-engagement email sent")
                }
            }
        }
    }

    # Identify power users
    $powerUsers = Find-PowerUsers -Customers $Customers

    # Get overall metrics
    $metrics = Get-SuccessMetrics -Customers $Customers

    Write-Host "`n╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║          🤖 SUCCESS BOT - MONITORING COMPLETE             ║" -ForegroundColor Green
    Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 Customer Health:" -ForegroundColor Cyan
    Write-Host "   Total: $($metrics.totalCustomers)" -ForegroundColor Gray
    Write-Host "   Healthy: $($metrics.healthy) ($($metrics.healthRate)%)" -ForegroundColor Green
    Write-Host "   At Risk: $($metrics.atRisk)" -ForegroundColor Yellow
    Write-Host "   Critical: $($metrics.critical)" -ForegroundColor Red
    Write-Host "   High Churn Risk: $($metrics.churnRiskHigh)" -ForegroundColor Red
    Write-Host ""
    Write-Host "🌟 Power Users: $($powerUsers.Count)" -ForegroundColor Cyan
    Write-Host "🔧 Interventions: $($interventions.Count)" -ForegroundColor Cyan
    Write-Host ""

    return @{
        metrics = $metrics
        interventions = $interventions
        powerUsers = $powerUsers
    }
}

# ============================================================================
# EXPORT
# ============================================================================

Export-ModuleMember -Function Start-SuccessBot, Get-CustomerHealthScore, Get-ChurnRisk, Find-PowerUsers, Send-NPSSurvey

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Customer Success Bot ready. Use Start-SuccessBot -Customers @()" -ForegroundColor Yellow
}
