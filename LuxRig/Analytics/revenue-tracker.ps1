<#
.SYNOPSIS
    Revenue Tracker - Real-time revenue monitoring

.DESCRIPTION
    Tracks revenue from all sources:
    - API subscriptions (Stripe)
    - Affiliate commissions
    - Product sales
    - Ad revenue
    - Real-time dashboard
#>

function Get-StripeRevenue {
    param(
        [ValidateSet("today", "week", "month", "year", "all")]
        [string]$Period = "month",

        [string]$StripeSecretKey = $env:STRIPE_SECRET_KEY
    )

    if (-not $StripeSecretKey) {
        Write-Warning "Stripe key not configured"
        return @{amount = 0; transactions = 0}
    }

    $endpoint = "https://api.stripe.com/v1/charges"

    $created = switch ($Period) {
        "today" { @{gte = [int][double]::Parse((Get-Date).Date.ToString("o") | Get-Date -UFormat %s)} }
        "week" { @{gte = [int][double]::Parse(((Get-Date).AddDays(-7).ToString("o")) | Get-Date -UFormat %s)} }
        "month" { @{gte = [int][double]::Parse(((Get-Date).AddMonths(-1).ToString("o")) | Get-Date -UFormat %s)} }
        "year" { @{gte = [int][double]::Parse(((Get-Date).AddYears(-1).ToString("o")) | Get-Date -UFormat %s)} }
        default { @{} }
    }

    try {
        $response = Invoke-RestMethod -Uri $endpoint -Method Get `
            -Headers @{"Authorization" = "Bearer $StripeSecretKey"} `
            -Body @{created = $created; limit = 100}

        $totalRevenue = ($response.data | Where-Object {$_.paid} | Measure-Object -Property amount -Sum).Sum / 100
        $transactions = $response.data.Count

        return @{
            amount = $totalRevenue
            transactions = $transactions
            charges = $response.data
        }
    }
    catch {
        Write-Warning "Stripe revenue fetch failed: $_"
        return @{amount = 0; transactions = 0}
    }
}

function Get-AffiliateRevenue {
    param([string]$Period = "month")

    # Mock - would integrate with actual affiliate networks
    $affiliateFile = "$PSScriptRoot\affiliate-commissions.jsonl"

    if (-not (Test-Path $affiliateFile)) {
        return @{amount = 0; clicks = 0; conversions = 0}
    }

    $data = Get-Content $affiliateFile | ForEach-Object { $_ | ConvertFrom-Json }

    $periodData = switch ($Period) {
        "today" { $data | Where-Object { ([datetime]$_.date).Date -eq (Get-Date).Date } }
        "week" { $data | Where-Object { ([datetime]$_.date) -gt (Get-Date).AddDays(-7) } }
        "month" { $data | Where-Object { ([datetime]$_.date) -gt (Get-Date).AddMonths(-1) } }
        default { $data }
    }

    return @{
        amount = ($periodData | Measure-Object -Property commission -Sum).Sum
        clicks = ($periodData | Measure-Object -Property clicks -Sum).Sum
        conversions = $periodData.Count
    }
}

function Get-ProductRevenue {
    param([string]$Period = "month")

    $salesFile = "$PSScriptRoot\product-sales.jsonl"

    if (-not (Test-Path $salesFile)) {
        return @{amount = 0; sales = 0}
    }

    $sales = Get-Content $salesFile | ForEach-Object { $_ | ConvertFrom-Json }

    $periodSales = switch ($Period) {
        "today" { $sales | Where-Object { ([datetime]$_.date).Date -eq (Get-Date).Date } }
        "week" { $sales | Where-Object { ([datetime]$_.date) -gt (Get-Date).AddDays(-7) } }
        "month" { $sales | Where-Object { ([datetime]$_.date) -gt (Get-Date).AddMonths(-1) } }
        default { $sales }
    }

    return @{
        amount = ($periodSales | Measure-Object -Property amount -Sum).Sum
        sales = $periodSales.Count
        products = ($periodSales | Select-Object -ExpandProperty product -Unique).Count
    }
}

function Get-TotalRevenue {
    param(
        [ValidateSet("today", "week", "month", "year", "all")]
        [string]$Period = "month"
    )

    Write-Host "`n[Revenue Tracker] Calculating revenue for: $Period" -ForegroundColor Cyan

    $stripe = Get-StripeRevenue -Period $Period
    $affiliate = Get-AffiliateRevenue -Period $Period
    $products = Get-ProductRevenue -Period $Period

    $total = $stripe.amount + $affiliate.amount + $products.amount

    Write-Host "╔═══════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║        REVENUE REPORT - $($Period.ToUpper())".PadRight(44) + "║" -ForegroundColor Green
    Write-Host "╠═══════════════════════════════════════════╣" -ForegroundColor Green
    Write-Host "║ API Subscriptions: `$$($stripe.amount)".PadRight(44) + "║" -ForegroundColor White
    Write-Host "║ Affiliate: `$$($affiliate.amount)".PadRight(44) + "║" -ForegroundColor White
    Write-Host "║ Product Sales: `$$($products.amount)".PadRight(44) + "║" -ForegroundColor White
    Write-Host "║".PadRight(44) + "║"
    Write-Host "║ TOTAL REVENUE: `$$total".PadRight(44) + "║" -ForegroundColor Green
    Write-Host "╚═══════════════════════════════════════════╝" -ForegroundColor Green

    return @{
        total = $total
        stripe = $stripe
        affiliate = $affiliate
        products = $products
        period = $Period
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
}

function Save-RevenueSnapshot {
    param([hashtable]$RevenueData)

    $snapshotFile = "$PSScriptRoot\revenue-snapshots.jsonl"
    $RevenueData | ConvertTo-Json -Compress | Add-Content $snapshotFile

    Write-Host "✓ Revenue snapshot saved" -ForegroundColor Green
}

function Get-RevenueGrowth {
    param([string]$Period = "month")

    $currentRevenue = Get-TotalRevenue -Period $Period
    $previousRevenue = Get-TotalRevenue -Period "all"  # Simplified - would calculate previous period

    $growth = if ($previousRevenue.total -gt 0) {
        (($currentRevenue.total - $previousRevenue.total) / $previousRevenue.total) * 100
    } else { 0 }

    return @{
        current = $currentRevenue.total
        previous = $previousRevenue.total
        growth = [Math]::Round($growth, 2)
        direction = if ($growth -gt 0) { "up" } else { "down" }
    }
}

Export-ModuleMember -Function Get-TotalRevenue, Save-RevenueSnapshot, Get-RevenueGrowth, Get-StripeRevenue
