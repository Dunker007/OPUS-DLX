<#
.SYNOPSIS
    Copy Trading Platform for LuxRig
.DESCRIPTION
    Allows users to copy successful traders' strategies with profit sharing,
    performance tracking, and automated trade replication.
.NOTES
    Version: 1.0.0
    Author: LuxRig Enterprise Team
    Requires: PowerShell 7.0+
#>

using namespace System.Collections.Generic

#region Module Configuration

$script:ModuleConfig = @{
    TradersPath = "$PSScriptRoot/../../../Data/CopyTrading/Traders"
    FollowersPath = "$PSScriptRoot/../../../Data/CopyTrading/Followers"
    TradesPath = "$PSScriptRoot/../../../Data/CopyTrading/Trades"
    ProfitSharePath = "$PSScriptRoot/../../../Data/CopyTrading/ProfitShare"
}

#endregion

#region Core Functions

function Initialize-CopyTradingPlatform {
    <#
    .SYNOPSIS
        Initializes the copy trading platform
    #>
    [CmdletBinding()]
    param()

    try {
        Write-Verbose "Initializing Copy Trading Platform..."

        $directories = @(
            $script:ModuleConfig.TradersPath,
            $script:ModuleConfig.FollowersPath,
            $script:ModuleConfig.TradesPath,
            $script:ModuleConfig.ProfitSharePath
        )

        foreach ($dir in $directories) {
            if (-not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
        }

        Write-Verbose "Copy Trading Platform initialized successfully"
        return $true
    }
    catch {
        Write-Error "Failed to initialize Copy Trading Platform: $_"
        return $false
    }
}

function Register-Trader {
    <#
    .SYNOPSIS
        Registers a trader for copy trading
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserId,

        [Parameter(Mandatory = $true)]
        [string]$DisplayName,

        [Parameter(Mandatory = $false)]
        [decimal]$MinimumInvestment = 100,

        [Parameter(Mandatory = $false)]
        [int]$ProfitSharePercent = 20,

        [Parameter(Mandatory = $false)]
        [string]$Strategy = "",

        [Parameter(Mandatory = $false)]
        [string]$Description = ""
    )

    try {
        Write-Verbose "Registering trader: $DisplayName"

        $traderId = [guid]::NewGuid().ToString()

        $trader = @{
            TraderId = $traderId
            UserId = $UserId
            DisplayName = $DisplayName
            MinimumInvestment = $MinimumInvestment
            ProfitSharePercent = $ProfitSharePercent
            Strategy = $Strategy
            Description = $Description
            RegisteredAt = (Get-Date).ToString('o')
            Status = "Active"
            TotalFollowers = 0
            TotalAUM = 0  # Assets Under Management
            TotalTrades = 0
            WinRate = 0
            TotalProfitLoss = 0
            MonthlyROI = 0
        }

        $traderFile = Join-Path $script:ModuleConfig.TradersPath "$traderId.json"
        $trader | ConvertTo-Json -Depth 10 | Set-Content $traderFile

        Write-Verbose "Trader registered: $traderId"
        return $trader
    }
    catch {
        Write-Error "Failed to register trader: $_"
        return $null
    }
}

function New-CopyTrade {
    <#
    .SYNOPSIS
        Creates a trade and replicates to followers
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TraderId,

        [Parameter(Mandatory = $true)]
        [string]$Asset,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Buy', 'Sell')]
        [string]$Action,

        [Parameter(Mandatory = $true)]
        [decimal]$Price,

        [Parameter(Mandatory = $true)]
        [decimal]$Quantity
    )

    try {
        Write-Verbose "Creating copy trade: $Asset $Action"

        $tradeId = [guid]::NewGuid().ToString()

        $trade = @{
            TradeId = $tradeId
            TraderId = $TraderId
            Asset = $Asset
            Action = $Action
            Price = $Price
            Quantity = $Quantity
            CreatedAt = (Get-Date).ToString('o')
            ReplicatedTrades = @()
        }

        # Get followers
        $followers = Get-Followers -TraderId $TraderId | Where-Object { $_.Status -eq "Active" }

        Write-Verbose "Replicating to $($followers.Count) followers"

        foreach ($follower in $followers) {
            try {
                # Calculate follower's trade size based on allocation
                $followerQuantity = ($follower.AllocationAmount / $Price) * ($Quantity / 100)

                $replicatedTrade = @{
                    FollowerId = $follower.FollowerId
                    UserId = $follower.UserId
                    Asset = $Asset
                    Action = $Action
                    Price = $Price
                    Quantity = $followerQuantity
                    ExecutedAt = (Get-Date).ToString('o')
                    Status = "Executed"
                }

                $trade.ReplicatedTrades += $replicatedTrade

                Write-Verbose "Replicated to follower: $($follower.UserId)"
            }
            catch {
                Write-Warning "Failed to replicate to follower $($follower.UserId): $_"
            }
        }

        # Save trade
        $tradeFile = Join-Path $script:ModuleConfig.TradesPath "$tradeId.json"
        $trade | ConvertTo-Json -Depth 10 | Set-Content $tradeFile

        # Update trader stats
        Update-TraderStats -TraderId $TraderId

        Write-Verbose "Copy trade created: $tradeId"
        return $trade
    }
    catch {
        Write-Error "Failed to create copy trade: $_"
        return $null
    }
}

function Follow-Trader {
    <#
    .SYNOPSIS
        Allows a user to follow and copy a trader
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserId,

        [Parameter(Mandatory = $true)]
        [string]$TraderId,

        [Parameter(Mandatory = $true)]
        [decimal]$AllocationAmount,

        [Parameter(Mandatory = $false)]
        [bool]$AutoCopy = $true
    )

    try {
        Write-Verbose "User $UserId following trader $TraderId"

        # Validate trader
        $trader = Get-Trader -TraderId $TraderId
        if (-not $trader) {
            throw "Trader not found: $TraderId"
        }

        # Check minimum investment
        if ($AllocationAmount -lt $trader.MinimumInvestment) {
            throw "Minimum investment is $($trader.MinimumInvestment)"
        }

        $followerId = [guid]::NewGuid().ToString()

        $follower = @{
            FollowerId = $followerId
            UserId = $UserId
            TraderId = $TraderId
            AllocationAmount = $AllocationAmount
            AutoCopy = $AutoCopy
            StartedAt = (Get-Date).ToString('o')
            Status = "Active"
            TotalTrades = 0
            TotalProfitLoss = 0
            ROI = 0
        }

        $followerFile = Join-Path $script:ModuleConfig.FollowersPath "$followerId.json"
        $follower | ConvertTo-Json -Depth 10 | Set-Content $followerFile

        # Update trader follower count
        $trader.TotalFollowers++
        $trader.TotalAUM += $AllocationAmount

        $traderFile = Join-Path $script:ModuleConfig.TradersPath "$TraderId.json"
        $trader | ConvertTo-Json -Depth 10 | Set-Content $traderFile

        Write-Verbose "Follower created: $followerId"
        return $follower
    }
    catch {
        Write-Error "Failed to follow trader: $_"
        return $null
    }
}

function Get-TopTraders {
    <#
    .SYNOPSIS
        Gets top performing traders
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$Count = 10,

        [Parameter(Mandatory = $false)]
        [ValidateSet('ROI', 'WinRate', 'Followers', 'AUM')]
        [string]$SortBy = 'ROI'
    )

    try {
        $traderFiles = Get-ChildItem -Path $script:ModuleConfig.TradersPath -Filter "*.json"

        $traders = @()
        foreach ($file in $traderFiles) {
            $trader = Get-Content $file.FullName -Raw | ConvertFrom-Json
            if ($trader.Status -eq "Active") {
                $traders += $trader
            }
        }

        # Sort traders
        $sorted = $traders | Sort-Object -Property @{
            Expression = switch ($SortBy) {
                'ROI' { { $_.MonthlyROI } }
                'WinRate' { { $_.WinRate } }
                'Followers' { { $_.TotalFollowers } }
                'AUM' { { $_.TotalAUM } }
            }
        } -Descending | Select-Object -First $Count

        return $sorted
    }
    catch {
        Write-Error "Failed to get top traders: $_"
        return @()
    }
}

function Calculate-ProfitShare {
    <#
    .SYNOPSIS
        Calculates profit sharing for traders
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TraderId,

        [Parameter(Mandatory = $false)]
        [DateTime]$PeriodStart = (Get-Date).AddMonths(-1),

        [Parameter(Mandatory = $false)]
        [DateTime]$PeriodEnd = (Get-Date)
    )

    try {
        Write-Verbose "Calculating profit share for trader: $TraderId"

        $trader = Get-Trader -TraderId $TraderId
        if (-not $trader) {
            throw "Trader not found"
        }

        # Get all trades in period
        $tradeFiles = Get-ChildItem -Path $script:ModuleConfig.TradesPath -Filter "*.json"

        $totalProfit = 0
        $tradeCount = 0

        foreach ($file in $tradeFiles) {
            $trade = Get-Content $file.FullName -Raw | ConvertFrom-Json

            if ($trade.TraderId -ne $TraderId) { continue }

            $createdAt = [DateTime]::Parse($trade.CreatedAt)
            if ($createdAt -lt $PeriodStart -or $createdAt -gt $PeriodEnd) { continue }

            # Calculate profit from replicated trades
            foreach ($replicatedTrade in $trade.ReplicatedTrades) {
                if ($replicatedTrade.Action -eq 'Sell') {
                    # Simulate profit (in production, calculate actual P/L)
                    $profit = $replicatedTrade.Quantity * $replicatedTrade.Price * 0.05  # 5% profit simulation
                    $totalProfit += $profit
                }
            }

            $tradeCount++
        }

        # Calculate trader's share
        $traderShare = $totalProfit * ($trader.ProfitSharePercent / 100)

        $profitShare = @{
            TraderId = $TraderId
            PeriodStart = $PeriodStart.ToString('o')
            PeriodEnd = $PeriodEnd.ToString('o')
            TotalProfit = $totalProfit
            TraderSharePercent = $trader.ProfitSharePercent
            TraderShare = $traderShare
            TotalTrades = $tradeCount
        }

        # Save profit share record
        $shareFile = Join-Path $script:ModuleConfig.ProfitSharePath "$TraderId-$(Get-Date -Format 'yyyyMM').json"
        $profitShare | ConvertTo-Json -Depth 10 | Set-Content $shareFile

        Write-Verbose "Profit share calculated: Trader gets $$traderShare"
        return $profitShare
    }
    catch {
        Write-Error "Failed to calculate profit share: $_"
        return $null
    }
}

#endregion

#region Helper Functions

function Get-Trader {
    param($TraderId)

    $traderFile = Join-Path $script:ModuleConfig.TradersPath "$TraderId.json"
    if (Test-Path $traderFile) {
        return Get-Content $traderFile -Raw | ConvertFrom-Json
    }
    return $null
}

function Get-Followers {
    param($TraderId)

    $followerFiles = Get-ChildItem -Path $script:ModuleConfig.FollowersPath -Filter "*.json"

    $followers = @()
    foreach ($file in $followerFiles) {
        $follower = Get-Content $file.FullName -Raw | ConvertFrom-Json
        if ($follower.TraderId -eq $TraderId) {
            $followers += $follower
        }
    }

    return $followers
}

function Update-TraderStats {
    param($TraderId)

    $trader = Get-Trader -TraderId $TraderId
    if ($trader) {
        $trader.TotalTrades++

        # Simulate stats update (in production, calculate from actual trades)
        $trader.WinRate = Get-Random -Minimum 55 -Maximum 85
        $trader.MonthlyROI = Get-Random -Minimum 5 -Maximum 30

        $traderFile = Join-Path $script:ModuleConfig.TradersPath "$TraderId.json"
        $trader | ConvertTo-Json -Depth 10 | Set-Content $traderFile
    }
}

#endregion

# Initialize on module load
Initialize-CopyTradingPlatform | Out-Null

# Export public functions
Export-ModuleMember -Function @(
    'Initialize-CopyTradingPlatform',
    'Register-Trader',
    'New-CopyTrade',
    'Follow-Trader',
    'Get-TopTraders',
    'Calculate-ProfitShare'
)
