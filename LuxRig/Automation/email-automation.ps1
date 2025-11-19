<#
.SYNOPSIS
    Email Automation - Customer lifecycle emails

.DESCRIPTION
    Automated email campaigns:
    - Welcome sequences
    - Onboarding drips
    - Re-engagement campaigns
    - Revenue notifications
    - Product updates
#>

function Send-Email {
    param(
        [Parameter(Mandatory=$true)]
        [string]$To,

        [Parameter(Mandatory=$true)]
        [string]$Subject,

        [Parameter(Mandatory=$true)]
        [string]$Body,

        [string]$From = "noreply@luxrig.com",

        [string]$Provider = "resend"  # resend, ses, sendgrid
    )

    $apiKey = $env:RESEND_API_KEY

    if (-not $apiKey) {
        Write-Warning "Email API key not configured"
        return @{success = $false; error = "API key missing"}
    }

    $endpoint = "https://api.resend.com/emails"

    $emailData = @{
        from = $From
        to = @($To)
        subject = $Subject
        html = $Body
    }

    try {
        $response = Invoke-RestMethod -Uri $endpoint -Method Post `
            -Headers @{
                "Authorization" = "Bearer $apiKey"
                "Content-Type" = "application/json"
            } `
            -Body ($emailData | ConvertTo-Json)

        Write-Host "✓ Email sent to $To" -ForegroundColor Green

        return @{
            success = $true
            id = $response.id
        }
    }
    catch {
        Write-Warning "Email send failed: $_"
        return @{success = $false; error = $_.Exception.Message}
    }
}

function Get-EmailTemplate {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("welcome", "trial_ending", "upgrade", "churn_prevention", "revenue_milestone")]
        [string]$TemplateName,

        [hashtable]$Variables = @{}
    )

    $templates = @{
        welcome = @"
<!DOCTYPE html>
<html>
<head><style>body{font-family:Arial,sans-serif;max-width:600px;margin:0 auto;padding:20px}</style></head>
<body>
    <h1>Welcome to {{PRODUCT_NAME}}! 🎉</h1>
    <p>Hi {{NAME}},</p>
    <p>Thanks for signing up! We're excited to have you on board.</p>
    <p>Here's what you can do next:</p>
    <ul>
        <li>Complete your profile</li>
        <li>Try our key features</li>
        <li>Join our community</li>
    </ul>
    <a href="{{DASHBOARD_URL}}" style="display:inline-block;background:#6366f1;color:white;padding:12px 24px;text-decoration:none;border-radius:6px;margin-top:20px">
        Get Started
    </a>
    <p style="margin-top:30px;color:#666;font-size:14px">
        Need help? Reply to this email or visit our <a href="{{SUPPORT_URL}}">Help Center</a>.
    </p>
</body>
</html>
"@

        trial_ending = @"
<!DOCTYPE html>
<html>
<head><style>body{font-family:Arial,sans-serif;max-width:600px;margin:0 auto;padding:20px}</style></head>
<body>
    <h1>Your trial ends in {{DAYS_LEFT}} days</h1>
    <p>Hi {{NAME}},</p>
    <p>Your free trial of {{PRODUCT_NAME}} is ending soon. Don't lose access to:</p>
    <ul>
        <li>{{FEATURE_1}}</li>
        <li>{{FEATURE_2}}</li>
        <li>{{FEATURE_3}}</li>
    </ul>
    <p><strong>Upgrade now and get 20% off your first month!</strong></p>
    <a href="{{UPGRADE_URL}}" style="display:inline-block;background:#10b981;color:white;padding:12px 24px;text-decoration:none;border-radius:6px;margin-top:20px">
        Upgrade Now
    </a>
</body>
</html>
"@

        upgrade = @"
<!DOCTYPE html>
<html>
<head><style>body{font-family:Arial,sans-serif;max-width:600px;margin:0 auto;padding:20px}</style></head>
<body>
    <h1>Ready to unlock more? 🚀</h1>
    <p>Hi {{NAME}},</p>
    <p>You've been crushing it with {{PRODUCT_NAME}}! Based on your usage, we think you'd love our Pro plan:</p>
    <ul>
        <li>10x more requests</li>
        <li>Priority support</li>
        <li>Advanced features</li>
        <li>Custom integrations</li>
    </ul>
    <p><strong>Special offer: Upgrade today and save 30%</strong></p>
    <a href="{{UPGRADE_URL}}" style="display:inline-block;background:#8b5cf6;color:white;padding:12px 24px;text-decoration:none;border-radius:6px;margin-top:20px">
        See Pro Features
    </a>
</body>
</html>
"@

        revenue_milestone = @"
<!DOCTYPE html>
<html>
<head><style>body{font-family:Arial,sans-serif;max-width:600px;margin:0 auto;padding:20px}</style></head>
<body>
    <h1>🎉 Milestone Reached: ${{REVENUE}} in Revenue!</h1>
    <p>Congratulations!</p>
    <p>Your LuxRig system just hit ${{REVENUE}} in total revenue. Here's the breakdown:</p>
    <ul>
        <li>API Subscriptions: ${{API_REVENUE}}</li>
        <li>Product Sales: ${{PRODUCT_REVENUE}}</li>
        <li>Affiliate: ${{AFFILIATE_REVENUE}}</li>
    </ul>
    <p>ROI: {{ROI}}% | AI Costs: ${{AI_COST}}</p>
    <p>Keep crushing it! 🚀</p>
    <a href="{{DASHBOARD_URL}}" style="display:inline-block;background:#6366f1;color:white;padding:12px 24px;text-decoration:none;border-radius:6px;margin-top:20px">
        View Dashboard
    </a>
</body>
</html>
"@
    }

    $template = $templates[$TemplateName]

    # Replace variables
    foreach ($key in $Variables.Keys) {
        $template = $template -replace "{{$key}}", $Variables[$key]
    }

    return $template
}

function Send-WelcomeEmail {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Email,

        [string]$Name = "there",

        [string]$ProductName = "LuxRig"
    )

    $body = Get-EmailTemplate -TemplateName "welcome" -Variables @{
        NAME = $Name
        PRODUCT_NAME = $ProductName
        DASHBOARD_URL = "https://app.luxrig.com/dashboard"
        SUPPORT_URL = "https://help.luxrig.com"
    }

    return Send-Email -To $Email -Subject "Welcome to $ProductName!" -Body $body
}

function Send-RevenueNotification {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Email,

        [Parameter(Mandatory=$true)]
        [double]$TotalRevenue,

        [hashtable]$RevenueBreakdown = @{}
    )

    $body = Get-EmailTemplate -TemplateName "revenue_milestone" -Variables @{
        REVENUE = $TotalRevenue
        API_REVENUE = $RevenueBreakdown.api
        PRODUCT_REVENUE = $RevenueBreakdown.products
        AFFILIATE_REVENUE = $RevenueBreakdown.affiliate
        ROI = $RevenueBreakdown.roi
        AI_COST = $RevenueBreakdown.aiCost
        DASHBOARD_URL = "https://app.luxrig.com/revenue"
    }

    return Send-Email -To $Email -Subject "🎉 Revenue Milestone: `$$TotalRevenue" -Body $body
}

function Start-EmailCampaign {
    param(
        [Parameter(Mandatory=$true)]
        [string]$CampaignName,

        [Parameter(Mandatory=$true)]
        [string[]]$Recipients,

        [string]$TemplateName,

        [hashtable]$Variables = @{},

        [int]$DelaySeconds = 60
    )

    Write-Host "`n[Email Campaign] Starting: $CampaignName" -ForegroundColor Cyan
    Write-Host "Recipients: $($Recipients.Count)" -ForegroundColor Gray

    $sent = 0
    $failed = 0

    foreach ($recipient in $Recipients) {
        $result = Send-Email -To $recipient `
            -Subject $CampaignName `
            -Body (Get-EmailTemplate -TemplateName $TemplateName -Variables $Variables)

        if ($result.success) {
            $sent++
        }
        else {
            $failed++
        }

        Start-Sleep -Seconds $DelaySeconds
    }

    Write-Host "✓ Campaign complete: $sent sent, $failed failed" -ForegroundColor Green

    return @{
        campaign = $CampaignName
        sent = $sent
        failed = $failed
        total = $Recipients.Count
    }
}

Export-ModuleMember -Function Send-Email, Send-WelcomeEmail, Send-RevenueNotification, Start-EmailCampaign, Get-EmailTemplate
