<#
.SYNOPSIS
    Cryptocurrency Tax Reporting System for LuxRig
.DESCRIPTION
    Cost basis tracking (FIFO/LIFO/HIFO), capital gains calculation, IRS Form 8949 generation,
    wash sale detection, and comprehensive tax reporting for crypto trading.
.NOTES
    Version: 1.0.0
    Author: LuxRig Enterprise Team
    Requires: PowerShell 7.0+
#>

using namespace System.Collections.Generic

#region Module Configuration

$script:ModuleConfig = @{
    TransactionsPath = "$PSScriptRoot/../../../Data/Tax/Transactions"
    TaxReportsPath = "$PSScriptRoot/../../../Data/Tax/Reports"
    CostBasisPath = "$PSScriptRoot/../../../Data/Tax/CostBasis"
    Form8949Path = "$PSScriptRoot/../../../Data/Tax/Forms"
    TaxYear = (Get-Date).Year
}

# Cost Basis Methods
enum CostBasisMethod {
    FIFO    # First In First Out
    LIFO    # Last In First Out
    HIFO    # Highest In First Out
    SpecID  # Specific Identification
}

# Transaction Types
enum TransactionType {
    Buy
    Sell
    Trade
    Income
    Mining
    Staking
    Airdrop
    Gift
    Transfer
}

#endregion

#region Core Functions

function Initialize-TaxReporter {
    <#
    .SYNOPSIS
        Initializes the tax reporting system
    #>
    [CmdletBinding()]
    param()

    try {
        Write-Verbose "Initializing Tax Reporter..."

        # Create required directories
        $directories = @(
            $script:ModuleConfig.TransactionsPath,
            $script:ModuleConfig.TaxReportsPath,
            $script:ModuleConfig.CostBasisPath,
            $script:ModuleConfig.Form8949Path
        )

        foreach ($dir in $directories) {
            if (-not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
        }

        Write-Verbose "Tax Reporter initialized successfully"
        return $true
    }
    catch {
        Write-Error "Failed to initialize Tax Reporter: $_"
        return $false
    }
}

function Import-TradingTransactions {
    <#
    .SYNOPSIS
        Imports trading transactions from various sources
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [int]$TaxYear,

        [Parameter(Mandatory = $false)]
        [string]$SourceFile,

        [Parameter(Mandatory = $false)]
        [array]$Transactions
    )

    try {
        Write-Verbose "Importing transactions for tax year $TaxYear..."

        $importedTransactions = @()

        # Import from file if provided
        if ($SourceFile -and (Test-Path $SourceFile)) {
            $fileContent = Get-Content $SourceFile -Raw | ConvertFrom-Json
            $importedTransactions = $fileContent
        }
        elseif ($Transactions) {
            $importedTransactions = $Transactions
        }

        # Normalize and validate transactions
        $normalizedTransactions = @()

        foreach ($tx in $importedTransactions) {
            $normalized = @{
                TransactionId = if ($tx.TransactionId) { $tx.TransactionId } else { [guid]::NewGuid().ToString() }
                Date = [DateTime]::Parse($tx.Date)
                Type = $tx.Type
                Asset = $tx.Asset
                Quantity = [decimal]$tx.Quantity
                Price = [decimal]$tx.Price
                Fee = if ($tx.Fee) { [decimal]$tx.Fee } else { 0 }
                Exchange = $tx.Exchange
                Notes = $tx.Notes
                TaxYear = $TaxYear
            }

            # Only include transactions in the specified tax year
            if ($normalized.Date.Year -eq $TaxYear) {
                $normalizedTransactions += $normalized
            }
        }

        # Save transactions
        $savePath = Join-Path $script:ModuleConfig.TransactionsPath "$TenantId-$TaxYear.json"
        $normalizedTransactions | ConvertTo-Json -Depth 10 | Set-Content $savePath

        Write-Verbose "Imported $($normalizedTransactions.Count) transactions"
        return $normalizedTransactions.Count
    }
    catch {
        Write-Error "Failed to import transactions: $_"
        return 0
    }
}

function Calculate-CostBasis {
    <#
    .SYNOPSIS
        Calculates cost basis using specified method
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [int]$TaxYear,

        [Parameter(Mandatory = $true)]
        [CostBasisMethod]$Method
    )

    try {
        Write-Verbose "Calculating cost basis using $Method method..."

        # Load transactions
        $txPath = Join-Path $script:ModuleConfig.TransactionsPath "$TenantId-$TaxYear.json"
        if (-not (Test-Path $txPath)) {
            throw "No transactions found for $TenantId in $TaxYear"
        }

        $transactions = Get-Content $txPath -Raw | ConvertFrom-Json | Sort-Object Date

        # Group by asset
        $assetGroups = $transactions | Group-Object -Property Asset

        $costBasisRecords = @()

        foreach ($assetGroup in $assetGroups) {
            $asset = $assetGroup.Name
            $assetTxs = $assetGroup.Group

            # Separate buys and sells
            $buys = @($assetTxs | Where-Object { $_.Type -in @('Buy', 'Income', 'Mining', 'Staking', 'Airdrop') })
            $sells = @($assetTxs | Where-Object { $_.Type -eq 'Sell' })

            # Build inventory based on method
            $inventory = switch ($Method) {
                'FIFO' { $buys | Sort-Object Date }
                'LIFO' { $buys | Sort-Object Date -Descending }
                'HIFO' { $buys | Sort-Object Price -Descending }
                'SpecID' { $buys | Sort-Object Date }  # Would need user selection
            }

            # Match sells with buys
            foreach ($sell in $sells) {
                $remainingQuantity = $sell.Quantity
                $sellDate = [DateTime]::Parse($sell.Date)

                while ($remainingQuantity -gt 0 -and $inventory.Count -gt 0) {
                    $buy = $inventory[0]
                    $buyDate = [DateTime]::Parse($buy.Date)

                    $matchQuantity = [Math]::Min($remainingQuantity, $buy.Quantity)

                    # Calculate gain/loss
                    $costBasis = $matchQuantity * $buy.Price
                    $proceeds = $matchQuantity * $sell.Price
                    $gainLoss = $proceeds - $costBasis

                    # Determine holding period
                    $holdingDays = ($sellDate - $buyDate).Days
                    $termType = if ($holdingDays -gt 365) { "Long-Term" } else { "Short-Term" }

                    # Check for wash sale (sold at loss and repurchased within 30 days)
                    $isWashSale = $false
                    if ($gainLoss -lt 0) {
                        $isWashSale = Test-WashSale -Asset $asset -SellDate $sellDate -Transactions $transactions
                    }

                    $record = @{
                        Asset = $asset
                        AcquiredDate = $buy.Date
                        SoldDate = $sell.Date
                        Quantity = $matchQuantity
                        CostBasis = $costBasis
                        Proceeds = $proceeds
                        GainLoss = $gainLoss
                        Term = $termType
                        WashSale = $isWashSale
                        BuyTransactionId = $buy.TransactionId
                        SellTransactionId = $sell.TransactionId
                    }

                    $costBasisRecords += $record

                    # Update inventory
                    $buy.Quantity -= $matchQuantity
                    $remainingQuantity -= $matchQuantity

                    if ($buy.Quantity -le 0) {
                        $inventory = $inventory[1..($inventory.Count - 1)]
                    }
                }

                if ($remainingQuantity -gt 0) {
                    Write-Warning "Insufficient inventory for $asset sell on $($sell.Date)"
                }
            }
        }

        # Save cost basis records
        $savePath = Join-Path $script:ModuleConfig.CostBasisPath "$TenantId-$TaxYear-$Method.json"
        $costBasisRecords | ConvertTo-Json -Depth 10 | Set-Content $savePath

        Write-Verbose "Cost basis calculated: $($costBasisRecords.Count) records"
        return $costBasisRecords
    }
    catch {
        Write-Error "Failed to calculate cost basis: $_"
        return @()
    }
}

function New-Form8949 {
    <#
    .SYNOPSIS
        Generates IRS Form 8949 (Sales and Dispositions of Capital Assets)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [int]$TaxYear,

        [Parameter(Mandatory = $true)]
        [CostBasisMethod]$Method,

        [Parameter(Mandatory = $false)]
        [string]$TaxpayerName,

        [Parameter(Mandatory = $false)]
        [string]$SSN
    )

    try {
        Write-Verbose "Generating Form 8949..."

        # Load cost basis records
        $cbPath = Join-Path $script:ModuleConfig.CostBasisPath "$TenantId-$TaxYear-$Method.json"
        if (-not (Test-Path $cbPath)) {
            throw "Cost basis not calculated. Run Calculate-CostBasis first."
        }

        $records = Get-Content $cbPath -Raw | ConvertFrom-Json

        # Separate short-term and long-term
        $shortTerm = @($records | Where-Object { $_.Term -eq 'Short-Term' })
        $longTerm = @($records | Where-Object { $_.Term -eq 'Long-Term' })

        # Calculate totals
        $shortTermGain = ($shortTerm | Measure-Object -Property GainLoss -Sum).Sum
        $longTermGain = ($longTerm | Measure-Object -Property GainLoss -Sum).Sum
        $totalGain = $shortTermGain + $longTermGain

        # Generate form data
        $form8949 = @{
            FormName = "Form 8949"
            TaxYear = $TaxYear
            TaxpayerName = $TaxpayerName
            SSN = $SSN
            Method = $Method.ToString()
            GeneratedAt = (Get-Date).ToString('o')

            PartI_ShortTerm = @{
                Transactions = $shortTerm
                TotalProceeds = ($shortTerm | Measure-Object -Property Proceeds -Sum).Sum
                TotalCostBasis = ($shortTerm | Measure-Object -Property CostBasis -Sum).Sum
                TotalGainLoss = $shortTermGain
                Count = $shortTerm.Count
            }

            PartII_LongTerm = @{
                Transactions = $longTerm
                TotalProceeds = ($longTerm | Measure-Object -Property Proceeds -Sum).Sum
                TotalCostBasis = ($longTerm | Measure-Object -Property CostBasis -Sum).Sum
                TotalGainLoss = $longTermGain
                Count = $longTerm.Count
            }

            Summary = @{
                TotalShortTermGain = $shortTermGain
                TotalLongTermGain = $longTermGain
                TotalCapitalGain = $totalGain
                TotalTransactions = $records.Count
                WashSales = ($records | Where-Object { $_.WashSale -eq $true }).Count
            }
        }

        # Save form
        $formPath = Join-Path $script:ModuleConfig.Form8949Path "$TenantId-8949-$TaxYear.json"
        $form8949 | ConvertTo-Json -Depth 10 | Set-Content $formPath

        # Generate CSV for easy import to tax software
        Export-Form8949CSV -Form $form8949 -TenantId $TenantId -TaxYear $TaxYear

        Write-Verbose "Form 8949 generated successfully"
        return $form8949
    }
    catch {
        Write-Error "Failed to generate Form 8949: $_"
        return $null
    }
}

function Get-TaxSummary {
    <#
    .SYNOPSIS
        Generates comprehensive tax summary report
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [int]$TaxYear
    )

    try {
        Write-Verbose "Generating tax summary..."

        # Load transactions
        $txPath = Join-Path $script:ModuleConfig.TransactionsPath "$TenantId-$TaxYear.json"
        if (-not (Test-Path $txPath)) {
            throw "No transactions found"
        }

        $transactions = Get-Content $txPath -Raw | ConvertFrom-Json

        # Categorize income
        $tradingIncome = @($transactions | Where-Object { $_.Type -in @('Buy', 'Sell') })
        $miningIncome = @($transactions | Where-Object { $_.Type -eq 'Mining' })
        $stakingIncome = @($transactions | Where-Object { $_.Type -eq 'Staking' })
        $airdropIncome = @($transactions | Where-Object { $_.Type -eq 'Airdrop' })

        # Calculate ordinary income (mining, staking, airdrops at fair market value)
        $ordinaryIncome = 0
        foreach ($tx in ($miningIncome + $stakingIncome + $airdropIncome)) {
            $ordinaryIncome += $tx.Quantity * $tx.Price
        }

        # Try to load Form 8949 data for capital gains
        $form8949Path = Join-Path $script:ModuleConfig.Form8949Path "$TenantId-8949-$TaxYear.json"
        $capitalGains = @{
            ShortTerm = 0
            LongTerm = 0
            Total = 0
        }

        if (Test-Path $form8949Path) {
            $form = Get-Content $form8949Path -Raw | ConvertFrom-Json
            $capitalGains.ShortTerm = $form.Summary.TotalShortTermGain
            $capitalGains.LongTerm = $form.Summary.TotalLongTermGain
            $capitalGains.Total = $form.Summary.TotalCapitalGain
        }

        $summary = @{
            TaxYear = $TaxYear
            TenantId = $TenantId
            GeneratedAt = (Get-Date).ToString('o')

            Transactions = @{
                Total = $transactions.Count
                Buys = ($transactions | Where-Object { $_.Type -eq 'Buy' }).Count
                Sells = ($transactions | Where-Object { $_.Type -eq 'Sell' }).Count
                Trades = ($transactions | Where-Object { $_.Type -eq 'Trade' }).Count
                Income = ($miningIncome + $stakingIncome + $airdropIncome).Count
            }

            Income = @{
                OrdinaryIncome = $ordinaryIncome
                Mining = ($miningIncome | Measure-Object -Property @{Expression={$_.Quantity * $_.Price}} -Sum).Sum
                Staking = ($stakingIncome | Measure-Object -Property @{Expression={$_.Quantity * $_.Price}} -Sum).Sum
                Airdrops = ($airdropIncome | Measure-Object -Property @{Expression={$_.Quantity * $_.Price}} -Sum).Sum
            }

            CapitalGains = $capitalGains

            TotalTaxableIncome = $ordinaryIncome + $capitalGains.Total

            Assets = @{
                Traded = ($transactions | Select-Object -ExpandProperty Asset -Unique).Count
                List = ($transactions | Select-Object -ExpandProperty Asset -Unique)
            }
        }

        # Save summary
        $summaryPath = Join-Path $script:ModuleConfig.TaxReportsPath "$TenantId-Summary-$TaxYear.json"
        $summary | ConvertTo-Json -Depth 10 | Set-Content $summaryPath

        Write-Verbose "Tax summary generated successfully"
        return $summary
    }
    catch {
        Write-Error "Failed to generate tax summary: $_"
        return $null
    }
}

function Export-TaxReport {
    <#
    .SYNOPSIS
        Exports comprehensive tax report in multiple formats
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [int]$TaxYear,

        [Parameter(Mandatory = $false)]
        [ValidateSet('JSON', 'CSV', 'PDF', 'All')]
        [string]$Format = 'All'
    )

    try {
        Write-Verbose "Exporting tax report in $Format format..."

        $summary = Get-TaxSummary -TenantId $TenantId -TaxYear $TaxYear

        if (-not $summary) {
            throw "Failed to generate tax summary"
        }

        $exportPath = Join-Path $script:ModuleConfig.TaxReportsPath "$TenantId-$TaxYear"

        # JSON export
        if ($Format -in @('JSON', 'All')) {
            $summary | ConvertTo-Json -Depth 10 | Set-Content "$exportPath.json"
        }

        # CSV export
        if ($Format -in @('CSV', 'All')) {
            $csvData = @()
            $csvData += "Tax Year,$TaxYear"
            $csvData += "Tenant ID,$TenantId"
            $csvData += ""
            $csvData += "Category,Amount"
            $csvData += "Ordinary Income,$($summary.Income.OrdinaryIncome)"
            $csvData += "Short-Term Capital Gains,$($summary.CapitalGains.ShortTerm)"
            $csvData += "Long-Term Capital Gains,$($summary.CapitalGains.LongTerm)"
            $csvData += "Total Taxable Income,$($summary.TotalTaxableIncome)"

            $csvData | Set-Content "$exportPath.csv"
        }

        Write-Verbose "Tax report exported successfully"
        return $exportPath
    }
    catch {
        Write-Error "Failed to export tax report: $_"
        return $null
    }
}

#endregion

#region Helper Functions

function Test-WashSale {
    <#
    .SYNOPSIS
        Detects wash sales (selling at loss and repurchasing within 30 days)
    #>
    param(
        [string]$Asset,
        [DateTime]$SellDate,
        [array]$Transactions
    )

    # Check for purchases within 30 days before or after sell
    $washSaleWindow = 30

    $repurchases = $Transactions | Where-Object {
        $_.Asset -eq $Asset -and
        $_.Type -in @('Buy') -and
        [DateTime]::Parse($_.Date) -ge $SellDate.AddDays(-$washSaleWindow) -and
        [DateTime]::Parse($_.Date) -le $SellDate.AddDays($washSaleWindow)
    }

    return ($repurchases.Count -gt 0)
}

function Export-Form8949CSV {
    param($Form, $TenantId, $TaxYear)

    $csvPath = Join-Path $script:ModuleConfig.Form8949Path "$TenantId-8949-$TaxYear.csv"

    $csvData = @()
    $csvData += "Description,Date Acquired,Date Sold,Proceeds,Cost Basis,Gain/Loss,Term"

    # Short-term transactions
    foreach ($tx in $Form.PartI_ShortTerm.Transactions) {
        $csvData += "$($tx.Asset),$($tx.AcquiredDate),$($tx.SoldDate),$($tx.Proceeds),$($tx.CostBasis),$($tx.GainLoss),Short-Term"
    }

    # Long-term transactions
    foreach ($tx in $Form.PartII_LongTerm.Transactions) {
        $csvData += "$($tx.Asset),$($tx.AcquiredDate),$($tx.SoldDate),$($tx.Proceeds),$($tx.CostBasis),$($tx.GainLoss),Long-Term"
    }

    $csvData | Set-Content $csvPath
}

#endregion

# Initialize on module load
Initialize-TaxReporter | Out-Null

# Export public functions
Export-ModuleMember -Function @(
    'Initialize-TaxReporter',
    'Import-TradingTransactions',
    'Calculate-CostBasis',
    'New-Form8949',
    'Get-TaxSummary',
    'Export-TaxReport'
)
