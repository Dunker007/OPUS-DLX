<#
.SYNOPSIS
    Strategy Marketplace for LuxRig
.DESCRIPTION
    User-generated strategy store with revenue sharing, ratings, reviews,
    and automated testing/validation of trading strategies.
.NOTES
    Version: 1.0.0
    Author: LuxRig Enterprise Team
    Requires: PowerShell 7.0+
#>

using namespace System.Collections.Generic

#region Module Configuration

$script:ModuleConfig = @{
    StrategiesPath = "$PSScriptRoot/../../../Data/Marketplace/Strategies"
    ReviewsPath = "$PSScriptRoot/../../../Data/Marketplace/Reviews"
    SalesPath = "$PSScriptRoot/../../../Data/Marketplace/Sales"
    RevenueSharePercent = 70  # Creator gets 70%, platform gets 30%
}

enum StrategyStatus {
    Draft
    UnderReview
    Approved
    Rejected
    Active
    Suspended
}

#endregion

#region Core Functions

function Initialize-StrategyMarketplace {
    <#
    .SYNOPSIS
        Initializes the strategy marketplace
    #>
    [CmdletBinding()]
    param()

    try {
        Write-Verbose "Initializing Strategy Marketplace..."

        $directories = @(
            $script:ModuleConfig.StrategiesPath,
            $script:ModuleConfig.ReviewsPath,
            $script:ModuleConfig.SalesPath
        )

        foreach ($dir in $directories) {
            if (-not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
        }

        Write-Verbose "Strategy Marketplace initialized successfully"
        return $true
    }
    catch {
        Write-Error "Failed to initialize Strategy Marketplace: $_"
        return $false
    }
}

function Publish-Strategy {
    <#
    .SYNOPSIS
        Publishes a trading strategy to the marketplace
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CreatorId,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Description,

        [Parameter(Mandatory = $true)]
        [hashtable]$StrategyCode,

        [Parameter(Mandatory = $false)]
        [decimal]$Price = 49.99,

        [Parameter(Mandatory = $false)]
        [string[]]$Tags = @(),

        [Parameter(Mandatory = $false)]
        [string]$Category = "General"
    )

    try {
        Write-Verbose "Publishing strategy: $Name"

        $strategyId = [guid]::NewGuid().ToString()

        $strategy = @{
            StrategyId = $strategyId
            CreatorId = $CreatorId
            Name = $Name
            Description = $Description
            StrategyCode = $StrategyCode
            Price = $Price
            Tags = $Tags
            Category = $Category
            Status = "UnderReview"
            CreatedAt = (Get-Date).ToString('o')
            PublishedAt = $null
            TotalSales = 0
            TotalRevenue = 0
            AverageRating = 0
            TotalReviews = 0
            BacktestResults = @{}
        }

        # Validate and backtest strategy
        Write-Verbose "Validating strategy..."
        $validation = Test-StrategyValidation -Strategy $strategy

        if ($validation.IsValid) {
            Write-Verbose "Running backtest..."
            $strategy.BacktestResults = Start-StrategyBacktest -Strategy $strategy

            # Auto-approve if backtest results are good
            if ($strategy.BacktestResults.WinRate -gt 55) {
                $strategy.Status = "Approved"
                $strategy.PublishedAt = (Get-Date).ToString('o')
            }
        } else {
            $strategy.Status = "Rejected"
            $strategy.RejectionReason = $validation.Reason
        }

        # Save strategy
        $strategyFile = Join-Path $script:ModuleConfig.StrategiesPath "$strategyId.json"
        $strategy | ConvertTo-Json -Depth 10 | Set-Content $strategyFile

        Write-Verbose "Strategy published: $strategyId (Status: $($strategy.Status))"
        return $strategy
    }
    catch {
        Write-Error "Failed to publish strategy: $_"
        return $null
    }
}

function Purchase-Strategy {
    <#
    .SYNOPSIS
        Purchases a strategy from the marketplace
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BuyerId,

        [Parameter(Mandatory = $true)]
        [string]$StrategyId,

        [Parameter(Mandatory = $false)]
        [string]$PaymentMethod = "Credit Card"
    )

    try {
        Write-Verbose "Processing strategy purchase: $StrategyId"

        # Get strategy
        $strategy = Get-Strategy -StrategyId $StrategyId
        if (-not $strategy) {
            throw "Strategy not found"
        }

        if ($strategy.Status -ne "Approved") {
            throw "Strategy not available for purchase"
        }

        $saleId = [guid]::NewGuid().ToString()

        # Calculate revenue share
        $creatorShare = $strategy.Price * ($script:ModuleConfig.RevenueSharePercent / 100)
        $platformShare = $strategy.Price * ((100 - $script:ModuleConfig.RevenueSharePercent) / 100)

        $sale = @{
            SaleId = $saleId
            StrategyId = $StrategyId
            CreatorId = $strategy.CreatorId
            BuyerId = $BuyerId
            Price = $strategy.Price
            CreatorShare = $creatorShare
            PlatformShare = $platformShare
            PaymentMethod = $PaymentMethod
            PurchasedAt = (Get-Date).ToString('o')
            Status = "Completed"
        }

        # Save sale
        $saleFile = Join-Path $script:ModuleConfig.SalesPath "$saleId.json"
        $sale | ConvertTo-Json -Depth 10 | Set-Content $saleFile

        # Update strategy stats
        $strategy.TotalSales++
        $strategy.TotalRevenue += $strategy.Price

        $strategyFile = Join-Path $script:ModuleConfig.StrategiesPath "$StrategyId.json"
        $strategy | ConvertTo-Json -Depth 10 | Set-Content $strategyFile

        Write-Verbose "Strategy purchased: $saleId"
        return $sale
    }
    catch {
        Write-Error "Failed to purchase strategy: $_"
        return $null
    }
}

function Add-StrategyReview {
    <#
    .SYNOPSIS
        Adds a review for a strategy
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$StrategyId,

        [Parameter(Mandatory = $true)]
        [string]$UserId,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 5)]
        [int]$Rating,

        [Parameter(Mandatory = $false)]
        [string]$Comment = ""
    )

    try {
        Write-Verbose "Adding review for strategy: $StrategyId"

        $reviewId = [guid]::NewGuid().ToString()

        $review = @{
            ReviewId = $reviewId
            StrategyId = $StrategyId
            UserId = $UserId
            Rating = $Rating
            Comment = $Comment
            CreatedAt = (Get-Date).ToString('o')
            Helpful = 0
        }

        # Save review
        $reviewFile = Join-Path $script:ModuleConfig.ReviewsPath "$reviewId.json"
        $review | ConvertTo-Json -Depth 10 | Set-Content $reviewFile

        # Update strategy rating
        Update-StrategyRating -StrategyId $StrategyId

        Write-Verbose "Review added: $reviewId"
        return $review
    }
    catch {
        Write-Error "Failed to add review: $_"
        return $null
    }
}

function Get-MarketplaceStrategies {
    <#
    .SYNOPSIS
        Gets strategies from the marketplace
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Category,

        [Parameter(Mandatory = $false)]
        [string[]]$Tags,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Rating', 'Sales', 'Price', 'Newest')]
        [string]$SortBy = 'Rating',

        [Parameter(Mandatory = $false)]
        [int]$Count = 50
    )

    try {
        $strategyFiles = Get-ChildItem -Path $script:ModuleConfig.StrategiesPath -Filter "*.json"

        $strategies = @()
        foreach ($file in $strategyFiles) {
            $strategy = Get-Content $file.FullName -Raw | ConvertFrom-Json

            # Only show approved strategies
            if ($strategy.Status -ne "Approved") { continue }

            # Apply filters
            if ($Category -and $strategy.Category -ne $Category) { continue }

            if ($Tags) {
                $hasTag = $false
                foreach ($tag in $Tags) {
                    if ($strategy.Tags -contains $tag) {
                        $hasTag = $true
                        break
                    }
                }
                if (-not $hasTag) { continue }
            }

            $strategies += $strategy
        }

        # Sort strategies
        $sorted = $strategies | Sort-Object -Property @{
            Expression = switch ($SortBy) {
                'Rating' { { $_.AverageRating } }
                'Sales' { { $_.TotalSales } }
                'Price' { { $_.Price } }
                'Newest' { { $_.PublishedAt } }
            }
        } -Descending | Select-Object -First $Count

        return $sorted
    }
    catch {
        Write-Error "Failed to get marketplace strategies: $_"
        return @()
    }
}

function Get-CreatorRevenue {
    <#
    .SYNOPSIS
        Calculates revenue for a strategy creator
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CreatorId,

        [Parameter(Mandatory = $false)]
        [DateTime]$PeriodStart = (Get-Date).AddMonths(-1),

        [Parameter(Mandatory = $false)]
        [DateTime]$PeriodEnd = (Get-Date)
    )

    try {
        Write-Verbose "Calculating revenue for creator: $CreatorId"

        $saleFiles = Get-ChildItem -Path $script:ModuleConfig.SalesPath -Filter "*.json"

        $totalRevenue = 0
        $totalSales = 0

        foreach ($file in $saleFiles) {
            $sale = Get-Content $file.FullName -Raw | ConvertFrom-Json

            if ($sale.CreatorId -ne $CreatorId) { continue }

            $purchasedAt = [DateTime]::Parse($sale.PurchasedAt)
            if ($purchasedAt -lt $PeriodStart -or $purchasedAt -gt $PeriodEnd) { continue }

            $totalRevenue += $sale.CreatorShare
            $totalSales++
        }

        return @{
            CreatorId = $CreatorId
            PeriodStart = $PeriodStart.ToString('o')
            PeriodEnd = $PeriodEnd.ToString('o')
            TotalSales = $totalSales
            TotalRevenue = $totalRevenue
            AveragePerSale = if ($totalSales -gt 0) { $totalRevenue / $totalSales } else { 0 }
        }
    }
    catch {
        Write-Error "Failed to calculate creator revenue: $_"
        return @{}
    }
}

function Get-TopStrategies {
    <#
    .SYNOPSIS
        Gets top performing strategies
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$Count = 10
    )

    try {
        return Get-MarketplaceStrategies -SortBy 'Rating' -Count $Count
    }
    catch {
        Write-Error "Failed to get top strategies: $_"
        return @()
    }
}

#endregion

#region Helper Functions

function Get-Strategy {
    param($StrategyId)

    $strategyFile = Join-Path $script:ModuleConfig.StrategiesPath "$StrategyId.json"
    if (Test-Path $strategyFile) {
        return Get-Content $strategyFile -Raw | ConvertFrom-Json
    }
    return $null
}

function Test-StrategyValidation {
    param($Strategy)

    # Simulate strategy validation
    # In production, would validate code syntax, safety, etc.

    $isValid = (Get-Random -Minimum 1 -Maximum 100) -gt 10  # 90% validation rate

    return @{
        IsValid = $isValid
        Reason = if (-not $isValid) { "Strategy contains invalid code" } else { "" }
    }
}

function Start-StrategyBacktest {
    param($Strategy)

    # Simulate backtest results
    # In production, would run actual backtest

    return @{
        TotalTrades = Get-Random -Minimum 100 -Maximum 500
        WinRate = Get-Random -Minimum 50 -Maximum 85
        ProfitFactor = Get-Random -Minimum 1.1 -Maximum 3.5
        MaxDrawdown = Get-Random -Minimum 5 -Maximum 25
        AnnualizedReturn = Get-Random -Minimum 10 -Maximum 150
        SharpeRatio = Get-Random -Minimum 0.5 -Maximum 3.0
    }
}

function Update-StrategyRating {
    param($StrategyId)

    $reviewFiles = Get-ChildItem -Path $script:ModuleConfig.ReviewsPath -Filter "*.json"

    $reviews = @()
    foreach ($file in $reviewFiles) {
        $review = Get-Content $file.FullName -Raw | ConvertFrom-Json
        if ($review.StrategyId -eq $StrategyId) {
            $reviews += $review
        }
    }

    if ($reviews.Count -gt 0) {
        $averageRating = ($reviews | Measure-Object -Property Rating -Average).Average

        $strategy = Get-Strategy -StrategyId $StrategyId
        if ($strategy) {
            $strategy.AverageRating = [Math]::Round($averageRating, 2)
            $strategy.TotalReviews = $reviews.Count

            $strategyFile = Join-Path $script:ModuleConfig.StrategiesPath "$StrategyId.json"
            $strategy | ConvertTo-Json -Depth 10 | Set-Content $strategyFile
        }
    }
}

#endregion

# Initialize on module load
Initialize-StrategyMarketplace | Out-Null

# Export public functions
Export-ModuleMember -Function @(
    'Initialize-StrategyMarketplace',
    'Publish-Strategy',
    'Purchase-Strategy',
    'Add-StrategyReview',
    'Get-MarketplaceStrategies',
    'Get-CreatorRevenue',
    'Get-TopStrategies'
)
