#Requires -Version 7.0
<#
.SYNOPSIS
    Portfolio Optimizer - Modern Portfolio Theory (MPT)
.DESCRIPTION
    Institutional portfolio optimization:
    - Modern Portfolio Theory (Markowitz)
    - Efficient frontier calculation
    - Risk-return optimization
    - Asset correlation analysis
    - Portfolio rebalancing
    - Diversification scoring
.NOTES
    Part of Phase 4: Risk Management
#>

$script:Config = @{
    RiskFreeRate = 0.04      # 4% annual risk-free rate
    RebalanceThreshold = 0.05  # 5% drift triggers rebalance
    MinCorrelation = -1.0
    MaxCorrelation = 1.0
}

# ============================================================================
# PORTFOLIO STATISTICS
# ============================================================================

function Get-PortfolioReturn {
    param(
        [Parameter(Mandatory)][hashtable]$Weights,
        [Parameter(Mandatory)][hashtable]$AssetReturns
    )

    $portfolioReturn = 0

    foreach ($asset in $Weights.Keys) {
        $weight = $Weights[$asset]
        $return = $AssetReturns[$asset]
        $portfolioReturn += $weight * $return
    }

    return $portfolioReturn
}

function Get-PortfolioVolatility {
    param(
        [Parameter(Mandatory)][hashtable]$Weights,
        [Parameter(Mandatory)][hashtable]$CovarianceMatrix
    )

    # Calculate portfolio variance using: σ²p = w'Σw
    $assets = $Weights.Keys | Sort-Object
    $variance = 0

    foreach ($asset1 in $assets) {
        foreach ($asset2 in $assets) {
            $weight1 = $Weights[$asset1]
            $weight2 = $Weights[$asset2]
            $covariance = $CovarianceMatrix["$asset1-$asset2"]

            $variance += $weight1 * $weight2 * $covariance
        }
    }

    return [Math]::Sqrt($variance)
}

function Get-CovarianceMatrix {
    param([Parameter(Mandatory)][hashtable]$AssetReturnsHistory)

    $assets = $AssetReturnsHistory.Keys | Sort-Object
    $covMatrix = @{}

    foreach ($asset1 in $assets) {
        foreach ($asset2 in $assets) {
            if ($asset1 -eq $asset2) {
                # Variance
                $returns = $AssetReturnsHistory[$asset1]
                $mean = ($returns | Measure-Object -Average).Average
                $variance = ($returns | ForEach-Object { [Math]::Pow($_ - $mean, 2) } | Measure-Object -Average).Average
                $covMatrix["$asset1-$asset2"] = $variance
            }
            else {
                # Covariance
                $returns1 = $AssetReturnsHistory[$asset1]
                $returns2 = $AssetReturnsHistory[$asset2]

                $mean1 = ($returns1 | Measure-Object -Average).Average
                $mean2 = ($returns2 | Measure-Object -Average).Average

                $n = [Math]::Min($returns1.Count, $returns2.Count)
                $covariance = 0

                for ($i = 0; $i -lt $n; $i++) {
                    $covariance += ($returns1[$i] - $mean1) * ($returns2[$i] - $mean2)
                }

                $covariance /= ($n - 1)
                $covMatrix["$asset1-$asset2"] = $covariance
            }
        }
    }

    return $covMatrix
}

# ============================================================================
# EFFICIENT FRONTIER
# ============================================================================

function Get-EfficientFrontier {
    param(
        [Parameter(Mandatory)][hashtable]$AssetReturns,
        [Parameter(Mandatory)][hashtable]$AssetReturnsHistory,
        [int]$Points = 20
    )

    Write-Host "`n📊 Calculating Efficient Frontier..." -ForegroundColor Cyan

    $assets = $AssetReturns.Keys | Sort-Object
    $covMatrix = Get-CovarianceMatrix -AssetReturnsHistory $AssetReturnsHistory

    $frontierPoints = @()

    # Generate random portfolios
    for ($i = 0; $i -lt $Points * 10; $i++) {
        # Random weights
        $weights = @{}
        $total = 0

        foreach ($asset in $assets) {
            $random = Get-Random -Minimum 0.0 -Maximum 1.0
            $weights[$asset] = $random
            $total += $random
        }

        # Normalize to sum to 1
        foreach ($asset in $assets) {
            $weights[$asset] /= $total
        }

        # Calculate metrics
        $return = Get-PortfolioReturn -Weights $weights -AssetReturns $AssetReturns
        $volatility = Get-PortfolioVolatility -Weights $weights -CovarianceMatrix $covMatrix
        $sharpe = ($return - $script:Config.RiskFreeRate) / $volatility

        $frontierPoints += @{
            weights = $weights
            return = $return
            volatility = $volatility
            sharpe = $sharpe
        }
    }

    # Find efficient portfolios (highest return for each volatility level)
    $efficientFrontier = $frontierPoints | Sort-Object -Property volatility | Group-Object {
        [Math]::Round($_.volatility, 2)
    } | ForEach-Object {
        $_.Group | Sort-Object -Property return -Descending | Select-Object -First 1
    }

    return $efficientFrontier | Sort-Object -Property volatility
}

function Get-OptimalPortfolio {
    param(
        [Parameter(Mandatory)][array]$EfficientFrontier,
        [ValidateSet("MaxSharpe","MinVolatility","TargetReturn")][string]$Objective = "MaxSharpe",
        [double]$TargetReturn = 0
    )

    switch ($Objective) {
        "MaxSharpe" {
            # Maximum Sharpe ratio portfolio
            return $EfficientFrontier | Sort-Object -Property sharpe -Descending | Select-Object -First 1
        }
        "MinVolatility" {
            # Minimum variance portfolio
            return $EfficientFrontier | Sort-Object -Property volatility | Select-Object -First 1
        }
        "TargetReturn" {
            # Portfolio closest to target return
            return $EfficientFrontier | Sort-Object { [Math]::Abs($_.return - $TargetReturn) } | Select-Object -First 1
        }
    }
}

# ============================================================================
# PORTFOLIO OPTIMIZATION
# ============================================================================

function Optimize-Portfolio {
    param(
        [Parameter(Mandatory)][hashtable]$AssetReturns,
        [Parameter(Mandatory)][hashtable]$AssetReturnsHistory,
        [ValidateSet("MaxSharpe","MinVolatility","TargetReturn")][string]$Objective = "MaxSharpe",
        [double]$TargetReturn = 0.15
    )

    Write-Host "`n╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║         🎯 PORTFOLIO OPTIMIZATION (MPT)              ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

    # Calculate efficient frontier
    $frontier = Get-EfficientFrontier -AssetReturns $AssetReturns -AssetReturnsHistory $AssetReturnsHistory -Points 30

    # Find optimal portfolio
    $optimal = Get-OptimalPortfolio -EfficientFrontier $frontier -Objective $Objective -TargetReturn $TargetReturn

    Write-Host "✅ Optimization complete!`n" -ForegroundColor Green

    Write-Host "📈 OPTIMAL PORTFOLIO ($Objective):" -ForegroundColor Yellow
    Write-Host "   Expected return: $([Math]::Round($optimal.return * 100, 2))% per year" -ForegroundColor White
    Write-Host "   Volatility (risk): $([Math]::Round($optimal.volatility * 100, 2))%" -ForegroundColor White
    Write-Host "   Sharpe ratio: $([Math]::Round($optimal.sharpe, 3))`n" -ForegroundColor White

    Write-Host "💼 ASSET ALLOCATION:" -ForegroundColor Yellow
    foreach ($asset in ($optimal.weights.Keys | Sort-Object { $optimal.weights[$_] } -Descending)) {
        $weight = $optimal.weights[$asset]
        $percentage = [Math]::Round($weight * 100, 2)

        if ($percentage -gt 0.1) {
            Write-Host "   $asset`: $percentage%" -ForegroundColor Cyan
        }
    }

    Write-Host ""

    return @{
        weights = $optimal.weights
        expectedReturn = $optimal.return
        volatility = $optimal.volatility
        sharpe = $optimal.sharpe
        frontier = $frontier
    }
}

# ============================================================================
# PORTFOLIO REBALANCING
# ============================================================================

function Get-RebalanceSignals {
    param(
        [Parameter(Mandatory)][hashtable]$CurrentWeights,
        [Parameter(Mandatory)][hashtable]$TargetWeights,
        [Parameter(Mandatory)][double]$PortfolioValue
    )

    Write-Host "`n📊 REBALANCING ANALYSIS:" -ForegroundColor Cyan

    $trades = @()
    $totalDrift = 0

    foreach ($asset in $TargetWeights.Keys) {
        $target = $TargetWeights[$asset]
        $current = if ($CurrentWeights.ContainsKey($asset)) { $CurrentWeights[$asset] } else { 0 }

        $drift = $current - $target
        $totalDrift += [Math]::Abs($drift)

        if ([Math]::Abs($drift) -gt $script:Config.RebalanceThreshold) {
            $action = if ($drift -gt 0) { "SELL" } else { "BUY" }
            $amount = [Math]::Abs($drift) * $PortfolioValue

            Write-Host "   $action $asset`: $([Math]::Round([Math]::Abs($drift) * 100, 2))% (``$$([Math]::Round($amount, 2)))" -ForegroundColor $(if ($action -eq "BUY") { 'Green' } else { 'Red' })

            $trades += @{
                asset = $asset
                action = $action
                amount = $amount
                percentChange = [Math]::Round($drift * 100, 2)
            }
        }
    }

    Write-Host "`n   Total drift: $([Math]::Round($totalDrift * 100, 2))%" -ForegroundColor White
    Write-Host "   Rebalancing $(if ($totalDrift -gt $script:Config.RebalanceThreshold) { 'RECOMMENDED' } else { 'NOT NEEDED' })`n" -ForegroundColor $(if ($totalDrift -gt $script:Config.RebalanceThreshold) { 'Yellow' } else { 'Green' })

    return @{
        trades = $trades
        totalDrift = $totalDrift
        shouldRebalance = $totalDrift -gt $script:Config.RebalanceThreshold
    }
}

# ============================================================================
# DIVERSIFICATION ANALYSIS
# ============================================================================

function Get-DiversificationScore {
    param([Parameter(Mandatory)][hashtable]$Weights)

    # Calculate Herfindahl-Hirschman Index (HHI)
    # HHI = sum of squared weights
    # Lower HHI = more diversified
    # Diversification score = 1 - normalized HHI

    $hhi = 0
    $n = $Weights.Count

    foreach ($weight in $Weights.Values) {
        $hhi += [Math]::Pow($weight, 2)
    }

    # Normalize: HHI ranges from 1/n (perfect diversification) to 1 (single asset)
    $minHHI = 1.0 / $n
    $normalizedHHI = ($hhi - $minHHI) / (1 - $minHHI)

    $diversificationScore = 1 - $normalizedHHI

    return @{
        score = [Math]::Round($diversificationScore, 3)
        hhi = [Math]::Round($hhi, 3)
        rating = if ($diversificationScore -gt 0.8) { "EXCELLENT" }
                 elseif ($diversificationScore -gt 0.6) { "GOOD" }
                 elseif ($diversificationScore -gt 0.4) { "MODERATE" }
                 else { "POOR" }
    }
}

# ============================================================================
# EXPORT
# ============================================================================

Export-ModuleMember -Function Optimize-Portfolio, Get-RebalanceSignals, Get-DiversificationScore, Get-EfficientFrontier, Get-PortfolioReturn, Get-PortfolioVolatility

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Portfolio Optimizer ready. Modern Portfolio Theory (Markowitz) activated" -ForegroundColor Yellow
}
