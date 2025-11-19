#Requires -Version 7.0
<#
.SYNOPSIS
    Upsell Machine - Increase average order value
.DESCRIPTION
    Complete upsell/cross-sell automation:
    - Order bump (add-on at checkout)
    - One-click upsell (after purchase, offer upgrade)
    - Cross-sell recommendations (related products)
    - Bundle builder (package deals)
    - Loyalty program (rewards for repeat customers)
    - VIP tier (premium support, early access)
.NOTES
    Part of Phase 3: Monetization Maximizer
    Increases revenue per customer by 30%+
#>

# ============================================================================
# CONFIGURATION
# ============================================================================

$script:Config = @{
    DataPath = "$PSScriptRoot/../../../Data/upsells"
    MinOrderBumpValue = 9
    MaxOrderBumpValue = 49
    UpsellMaxPriceMultiplier = 3
}

# ============================================================================
# ORDER BUMP GENERATOR
# ============================================================================

function New-OrderBump {
    param(
        [Parameter(Mandatory)]
        [hashtable]$MainProduct,
        [string]$BumpType = "Complementary"
    )

    Write-Host "💎 Creating order bump for $($MainProduct.name)..." -ForegroundColor Cyan

    # Generate relevant bumps based on main product
    $bumps = @(
        @{
            name = "Premium Support Package"
            description = "Get priority email support + monthly check-ins"
            price = [Math]::Round($MainProduct.price * 0.3, 0)
            discount = 0
            conversionRate = 25  # Expected %
        },
        @{
            name = "Video Training Course"
            description = "Master $($MainProduct.name) with our step-by-step video course"
            price = 29
            discount = 50  # 50% off if added at checkout
            conversionRate = 35
        },
        @{
            name = "Template Pack"
            description = "10 ready-to-use templates to get started faster"
            price = 19
            discount = 0
            conversionRate = 40
        },
        @{
            name = "Extended License"
            description = "Use on unlimited projects + resell rights"
            price = [Math]::Round($MainProduct.price * 0.5, 0)
            discount = 0
            conversionRate = 15
        }
    )

    # Select best bump (highest expected value)
    $bump = $bumps | ForEach-Object {
        $expectedValue = $_.price * ($_.conversionRate / 100)
        $_ | Add-Member -NotePropertyName 'expectedValue' -NotePropertyValue $expectedValue -PassThru
    } | Sort-Object expectedValue -Descending | Select-Object -First 1

    Write-Host "   Selected: $($bump.name) at `$$($bump.price) (exp. $($bump.expectedValue) per order)" -ForegroundColor Green

    return $bump
}

# ============================================================================
# ONE-CLICK UPSELL
# ============================================================================

function New-PostPurchaseUpsell {
    param(
        [Parameter(Mandatory)]
        [hashtable]$PurchasedProduct,
        [ValidateSet('Upgrade', 'AddOn', 'Bundle')]
        [string]$Type = 'Upgrade'
    )

    Write-Host "🚀 Creating post-purchase upsell..." -ForegroundColor Cyan

    $upsell = switch ($Type) {
        'Upgrade' {
            @{
                type = 'Upgrade'
                name = "$($PurchasedProduct.name) Pro"
                headline = "Upgrade to Pro for just `$$([Math]::Round($PurchasedProduct.price * 0.5, 0)) more!"
                benefits = @(
                    "Unlock all premium features",
                    "Priority support",
                    "Unlimited usage",
                    "Early access to new features"
                )
                price = [Math]::Round($PurchasedProduct.price * 0.5, 0)
                originalPrice = $PurchasedProduct.price
                urgency = "One-time offer - available for next 10 minutes only"
                cta = "Yes, Upgrade Me!"
            }
        }
        'AddOn' {
            @{
                type = 'AddOn'
                name = "Complementary Product"
                headline = "Perfect pairing: Add [Product] for 30% off"
                price = 29
                discount = 30
                cta = "Add to My Order"
            }
        }
        'Bundle' {
            @{
                type = 'Bundle'
                name = "Complete Bundle"
                headline = "Get everything - Save 40%"
                includedProducts = @("Product 1", "Product 2", "Product 3")
                bundlePrice = [Math]::Round($PurchasedProduct.price * 2, 0)
                savings = [Math]::Round($PurchasedProduct.price * 0.8, 0)
                cta = "Get the Bundle"
            }
        }
    }

    Write-Host "   Created: $($upsell.name)" -ForegroundColor Green

    return $upsell
}

# ============================================================================
# CROSS-SELL RECOMMENDATIONS
# ============================================================================

function Get-CrossSellRecommendations {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Product,
        [int]$Count = 3
    )

    Write-Host "🎯 Finding cross-sell recommendations..." -ForegroundColor Cyan

    # Would use collaborative filtering / AI in production
    $recommendations = @(
        @{
            name = "Related Product A"
            price = Get-Random -Minimum 19 -Maximum 99
            relevanceScore = 0.85
            reason = "Customers who bought $($Product.name) also bought this"
        },
        @{
            name = "Related Product B"
            price = Get-Random -Minimum 19 -Maximum 99
            relevanceScore = 0.78
            reason = "Pairs perfectly with $($Product.name)"
        },
        @{
            name = "Related Product C"
            price = Get-Random -Minimum 19 -Maximum 99
            relevanceScore = 0.72
            reason = "Complete your toolkit"
        }
    )

    $recommendations = $recommendations |
        Sort-Object relevanceScore -Descending |
        Select-Object -First $Count

    Write-Host "   Found $($recommendations.Count) recommendations" -ForegroundColor Green

    return $recommendations
}

# ============================================================================
# BUNDLE BUILDER
# ============================================================================

function New-ProductBundle {
    param(
        [Parameter(Mandatory)]
        [array]$Products,
        [double]$DiscountPercent = 25,
        [string]$BundleName
    )

    Write-Host "📦 Creating product bundle..." -ForegroundColor Cyan

    $totalPrice = ($Products.price | Measure-Object -Sum).Sum
    $bundlePrice = [Math]::Round($totalPrice * (1 - ($DiscountPercent / 100)), 0)
    $savings = $totalPrice - $bundlePrice

    $bundle = @{
        name = $BundleName ?? "Complete Bundle"
        products = $Products
        individualTotal = $totalPrice
        bundlePrice = $bundlePrice
        discount = $DiscountPercent
        savings = $savings
        value Proposition = "Save `$$savings ($DiscountPercent% off)"
        cta = "Get the Bundle"
    }

    Write-Host "   Bundle: `$$bundlePrice (save `$$savings)" -ForegroundColor Green

    return $bundle
}

# ============================================================================
# LOYALTY PROGRAM
# ============================================================================

function New-LoyaltyProgram {
    param(
        [string]$ProgramName = "Rewards Program",
        [int]$PointsPerDollar = 10,
        [int]$PointsForRedemption = 1000,
        [double]$RedemptionValue = 10
    )

    Write-Host "🌟 Creating loyalty program..." -ForegroundColor Cyan

    $program = @{
        name = $ProgramName
        pointsPerDollar = $PointsPerDollar
        redemption = @{
            pointsRequired = $PointsForRedemption
            value = $RedemptionValue
        }
        tiers = @{
            bronze = @{
                minSpend = 0
                benefits = @("Earn points", "Birthday discount")
                pointsMultiplier = 1
            }
            silver = @{
                minSpend = 250
                benefits = @("2x points", "Early access", "Free shipping")
                pointsMultiplier = 2
            }
            gold = @{
                minSpend = 1000
                benefits = @("3x points", "Priority support", "Exclusive deals", "Beta access")
                pointsMultiplier = 3
            }
        }
        referralBonus = @{
            referrer = 500  # Points
            referred = 250  # Points or % discount
        }
    }

    Write-Host "   Program created: $ProgramName" -ForegroundColor Green

    return $program
}

# ============================================================================
# VIP TIER
# ============================================================================

function New-VIPTier {
    param(
        [Parameter(Mandatory)]
        [hashtable]$BaseProduct,
        [double]$PriceMultiplier = 3
    )

    Write-Host "👑 Creating VIP tier..." -ForegroundColor Cyan

    $vipPrice = [Math]::Round($BaseProduct.price * $PriceMultiplier, 0)

    $vip = @{
        name = "$($BaseProduct.name) VIP"
        price = $vipPrice
        basePrice = $BaseProduct.price
        benefits = @(
            "Everything in $($BaseProduct.name)",
            "Dedicated account manager",
            "Priority support (24/7)",
            "Monthly strategy calls",
            "Custom integrations",
            "White-label option",
            "Early access to all features",
            "Lifetime updates",
            "Exclusive community access"
        )
        targetAudience = "Agencies, Enterprise, Power Users"
        positioning = "For professionals who need the best"
        cta = "Go VIP"
    }

    Write-Host "   VIP tier: `$$vipPrice ($($PriceMultiplier)x base)" -ForegroundColor Green

    return $vip
}

# ============================================================================
# UPSELL FUNNEL ANALYZER
# ============================================================================

function Get-UpsellFunnelMetrics {
    param(
        [int]$InitialPurchases = 100,
        [double]$OrderBumpRate = 25,
        [double]$UpsellRate = 15,
        [double]$CrossSellRate = 10,
        [hashtable]$Pricing
    )

    # Calculate funnel metrics
    $orderBumps = [Math]::Round($InitialPurchases * ($OrderBumpRate / 100), 0)
    $upsells = [Math]::Round($InitialPurchases * ($UpsellRate / 100), 0)
    $crossSells = [Math]::Round($InitialPurchases * ($CrossSellRate / 100), 0)

    $baseRevenue = $InitialPurchases * $Pricing.basePrice
    $bumpRevenue = $orderBumps * $Pricing.bumpPrice
    $upsellRevenue = $upsells * $Pricing.upsellPrice
    $crossSellRevenue = $crossSells * $Pricing.crossSellPrice

    $totalRevenue = $baseRevenue + $bumpRevenue + $upsellRevenue + $crossSellRevenue
    $revenueIncrease = $totalRevenue - $baseRevenue
    $increasePercent = [Math]::Round(($revenueIncrease / $baseRevenue) * 100, 1)

    $metrics = @{
        initialPurchases = $InitialPurchases
        conversions = @{
            orderBumps = $orderBumps
            upsells = $upsells
            crossSells = $crossSells
        }
        revenue = @{
            base = $baseRevenue
            orderBumps = $bumpRevenue
            upsells = $upsellRevenue
            crossSells = $crossSellRevenue
            total = $totalRevenue
        }
        improvement = @{
            additionalRevenue = $revenueIncrease
            percentIncrease = $increasePercent
        }
        avgOrderValue = @{
            without = $Pricing.basePrice
            with = [Math]::Round($totalRevenue / $InitialPurchases, 2)
        }
    }

    return $metrics
}

# ============================================================================
# COMPREHENSIVE UPSELL MACHINE
# ============================================================================

function Start-UpsellMachine {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Product,
        [switch]$EnableAll = $true
    )

    Write-Host "`n╔══════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║         💎 UPSELL MACHINE - OPTIMIZING AOV...        ║" -ForegroundColor Magenta
    Write-Host "╚══════════════════════════════════════════════════════╝`n" -ForegroundColor Magenta

    # Generate all upsell components
    $orderBump = New-OrderBump -MainProduct $Product
    $upsell = New-PostPurchaseUpsell -PurchasedProduct $Product -Type 'Upgrade'
    $crossSells = Get-CrossSellRecommendations -Product $Product
    $vipTier = New-VIPTier -BaseProduct $Product
    $loyaltyProgram = New-LoyaltyProgram

    # Calculate impact
    $pricing = @{
        basePrice = $Product.price
        bumpPrice = $orderBump.price
        upsellPrice = $upsell.price
        crossSellPrice = ($crossSells.price | Measure-Object -Average).Average
    }

    $metrics = Get-UpsellFunnelMetrics -InitialPurchases 100 -Pricing $pricing

    # Display summary
    Write-Host "`n╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║            💎 UPSELL MACHINE ACTIVATED                    ║" -ForegroundColor Green
    Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 Revenue Impact (per 100 customers):" -ForegroundColor Cyan
    Write-Host "   Base Revenue: `$$($metrics.revenue.base)" -ForegroundColor Gray
    Write-Host "   + Order Bumps: `$$($metrics.revenue.orderBumps)" -ForegroundColor Gray
    Write-Host "   + Upsells: `$$($metrics.revenue.upsells)" -ForegroundColor Gray
    Write-Host "   + Cross-sells: `$$($metrics.revenue.crossSells)" -ForegroundColor Gray
    Write-Host "   = Total Revenue: `$$($metrics.revenue.total)" -ForegroundColor Green
    Write-Host ""
    Write-Host "📈 Improvement: +$($metrics.improvement.percentIncrease)% revenue" -ForegroundColor Green
    Write-Host "💰 Average Order Value: `$$($metrics.avgOrderValue.without) → `$$($metrics.avgOrderValue.with)" -ForegroundColor Green
    Write-Host ""

    return @{
        orderBump = $orderBump
        upsell = $upsell
        crossSells = $crossSells
        vipTier = $vipTier
        loyaltyProgram = $loyaltyProgram
        metrics = $metrics
    }
}

# ============================================================================
# EXPORT
# ============================================================================

Export-ModuleMember -Function Start-UpsellMachine, New-OrderBump, New-PostPurchaseUpsell, New-ProductBundle, New-LoyaltyProgram, New-VIPTier

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Upsell Machine ready. Use Start-UpsellMachine -Product @{name='Product'; price=29}" -ForegroundColor Yellow
}
