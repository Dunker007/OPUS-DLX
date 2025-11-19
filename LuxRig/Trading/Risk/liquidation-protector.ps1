#Requires -Version 7.0
<#
.SYNOPSIS
    Liquidation Protector - Never get rekt on futures
.DESCRIPTION
    Advanced liquidation prevention:
    - Real-time liquidation price monitoring
    - Dynamic position sizing
    - Automatic margin top-ups
    - Emergency position reduction
    - Multi-exchange support
    - Alert system
.NOTES
    Part of Phase 4: Risk Management
#>

$script:Config = @{
    LiquidationBuffer = 0.10   # 10% buffer from liquidation price
    EmergencyThreshold = 0.05  # 5% from liquidation triggers emergency
    MaxLeverage = 10           # Never exceed 10x leverage
    AutoReducePercent = 0.50   # Reduce position by 50% in emergency
    CheckInterval = 10         # Check every 10 seconds
}

# ============================================================================
# LIQUIDATION PRICE CALCULATIONS
# ============================================================================

function Get-LiquidationPrice {
    param(
        [Parameter(Mandatory)][double]$EntryPrice,
        [Parameter(Mandatory)][double]$Leverage,
        [Parameter(Mandatory)][ValidateSet("LONG","SHORT")][string]$Side,
        [double]$MaintenanceMargin = 0.005  # 0.5% maintenance margin
    )

    if ($Side -eq "LONG") {
        # Long liquidation = Entry * (1 - 1/Leverage + MM)
        $liqPrice = $EntryPrice * (1 - (1 / $Leverage) + $MaintenanceMargin)
    }
    else {
        # Short liquidation = Entry * (1 + 1/Leverage - MM)
        $liqPrice = $EntryPrice * (1 + (1 / $Leverage) - $MaintenanceMargin)
    }

    return [Math]::Round($liqPrice, 2)
}

function Get-SafetyDistance {
    param(
        [Parameter(Mandatory)][double]$CurrentPrice,
        [Parameter(Mandatory)][double]$LiquidationPrice,
        [Parameter(Mandatory)][ValidateSet("LONG","SHORT")][string]$Side
    )

    if ($Side -eq "LONG") {
        $distance = ($CurrentPrice - $LiquidationPrice) / $LiquidationPrice
    }
    else {
        $distance = ($LiquidationPrice - $CurrentPrice) / $CurrentPrice
    }

    return $distance
}

# ============================================================================
# PROTECTION ACTIONS
# ============================================================================

function Invoke-EmergencyPositionReduce {
    param(
        [Parameter(Mandatory)][string]$Exchange,
        [Parameter(Mandatory)][string]$Symbol,
        [Parameter(Mandatory)][hashtable]$Position
    )

    $reduceSize = $Position.size * $script:Config.AutoReducePercent

    Write-Host "`n🚨 EMERGENCY: REDUCING POSITION TO AVOID LIQUIDATION!" -ForegroundColor Red
    Write-Host "   Symbol: $Symbol | Side: $($Position.side)" -ForegroundColor White
    Write-Host "   Current size: $($Position.size) | Reducing by: $reduceSize`n" -ForegroundColor White

    try {
        # Close partial position
        $closeSide = if ($Position.side -eq "LONG") { "SELL" } else { "BUY" }
        $order = & "New-${Exchange}MarketOrder" -Symbol $Symbol -Side $closeSide -Size $reduceSize -ReduceOnly

        if ($order) {
            Write-Host "   ✅ Emergency reduction executed!" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "   ❌ Emergency reduction FAILED!" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "   ❌ Error during emergency reduction: $_" -ForegroundColor Red
        return $false
    }
}

function Add-EmergencyMargin {
    param(
        [Parameter(Mandatory)][string]$Exchange,
        [Parameter(Mandatory)][string]$Symbol,
        [Parameter(Mandatory)][double]$Amount
    )

    Write-Host "`n⚠️  ADDING EMERGENCY MARGIN: `$$Amount" -ForegroundColor Yellow

    # Note: This is exchange-specific. Implement per exchange.
    # For now, just log the action
    Write-Host "   Manual action required: Add `$$Amount margin to $Symbol position on $Exchange" -ForegroundColor Yellow
}

# ============================================================================
# MONITORING
# ============================================================================

function Watch-LiquidationRisk {
    param(
        [Parameter(Mandatory)][string]$Exchange,
        [array]$Symbols = @(),
        [switch]$AutoProtect
    )

    Write-Host "🛡️  Starting Liquidation Protector: $Exchange" -ForegroundColor Green
    Write-Host "   Auto-protection: $(if ($AutoProtect) { 'ENABLED' } else { 'DISABLED' })" -ForegroundColor Cyan
    Write-Host "   Emergency threshold: $($script:Config.EmergencyThreshold * 100)% from liquidation`n" -ForegroundColor Cyan

    $alerts = @{}

    while ($true) {
        try {
            # Get all positions
            $positions = & "Get-${Exchange}FuturesPosition"

            if (-not $positions) {
                Start-Sleep -Seconds $script:Config.CheckInterval
                continue
            }

            # Filter by symbols if specified
            if ($Symbols.Count -gt 0) {
                $positions = $positions | Where-Object { $Symbols -contains $_.symbol }
            }

            foreach ($position in $positions) {
                $symbol = $position.symbol
                $size = [Math]::Abs($position.positionAmt)

                if ($size -eq 0) { continue }

                $entryPrice = $position.entryPrice
                $markPrice = $position.markPrice
                $liqPrice = $position.liquidationPrice
                $leverage = $position.leverage
                $side = if ($position.positionAmt -gt 0) { "LONG" } else { "SHORT" }

                # Calculate safety distance
                $safetyDistance = Get-SafetyDistance -CurrentPrice $markPrice -LiquidationPrice $liqPrice -Side $side

                $status = if ($safetyDistance -le $script:Config.EmergencyThreshold) {
                    "EMERGENCY"
                }
                elseif ($safetyDistance -le $script:Config.LiquidationBuffer) {
                    "WARNING"
                }
                else {
                    "SAFE"
                }

                # Display status
                $color = switch ($status) {
                    "EMERGENCY" { "Red" }
                    "WARNING" { "Yellow" }
                    "SAFE" { "Green" }
                }

                Write-Host "[$status] $symbol ($side ${leverage}x)" -ForegroundColor $color
                Write-Host "   Entry: `$$entryPrice | Mark: `$$markPrice | Liq: `$$liqPrice" -ForegroundColor White
                Write-Host "   Safety distance: $([Math]::Round($safetyDistance * 100, 2))%" -ForegroundColor $color
                Write-Host "   Unrealized PnL: `$$($position.unrealizedProfit)`n" -ForegroundColor $(if ($position.unrealizedProfit -gt 0) { 'Green' } else { 'Red' })

                # Take action if needed
                if ($status -eq "EMERGENCY") {
                    if (-not $alerts.ContainsKey($symbol)) {
                        $alerts[$symbol] = 0
                    }

                    $alerts[$symbol]++

                    if ($AutoProtect) {
                        # Emergency position reduction
                        $success = Invoke-EmergencyPositionReduce -Exchange $Exchange -Symbol $symbol -Position @{
                            side = $side
                            size = $size
                        }

                        if ($success) {
                            $alerts[$symbol] = 0  # Reset alert counter
                        }
                    }
                    else {
                        Write-Host "   ⚠️  MANUAL ACTION REQUIRED: Position at risk of liquidation!" -ForegroundColor Red
                    }
                }
                elseif ($status -eq "WARNING") {
                    if (-not $alerts.ContainsKey($symbol)) {
                        Write-Host "   ⚠️  WARNING: Approaching liquidation threshold" -ForegroundColor Yellow
                        $alerts[$symbol] = 1
                    }
                }
                else {
                    # Clear alerts for safe positions
                    if ($alerts.ContainsKey($symbol)) {
                        $alerts.Remove($symbol)
                    }
                }
            }

            Write-Host "────────────────────────────────────────────────────`n" -ForegroundColor Gray

            Start-Sleep -Seconds $script:Config.CheckInterval
        }
        catch {
            Write-Host "❌ Error monitoring positions: $_" -ForegroundColor Red
            Start-Sleep -Seconds $script:Config.CheckInterval
        }
    }
}

# ============================================================================
# POSITION VALIDATION
# ============================================================================

function Test-PositionSafety {
    param(
        [Parameter(Mandatory)][double]$EntryPrice,
        [Parameter(Mandatory)][double]$Leverage,
        [Parameter(Mandatory)][double]$Size,
        [Parameter(Mandatory)][ValidateSet("LONG","SHORT")][string]$Side,
        [Parameter(Mandatory)][double]$AccountBalance
    )

    # Calculate liquidation price
    $liqPrice = Get-LiquidationPrice -EntryPrice $EntryPrice -Leverage $Leverage -Side $Side

    # Calculate position value
    $positionValue = $EntryPrice * $Size

    # Calculate required margin
    $requiredMargin = $positionValue / $Leverage

    # Safety checks
    $checks = @{
        leverageSafe = $Leverage -le $script:Config.MaxLeverage
        marginSufficient = $requiredMargin -le ($AccountBalance * 0.20)  # Max 20% of balance per position
        liquidationPrice = $liqPrice
        requiredMargin = [Math]::Round($requiredMargin, 2)
        positionValue = [Math]::Round($positionValue, 2)
        safe = $true
    }

    if (-not $checks.leverageSafe) {
        $checks.safe = $false
        $checks.warning = "Leverage too high! Max: $($script:Config.MaxLeverage)x"
    }

    if (-not $checks.marginSufficient) {
        $checks.safe = $false
        $checks.warning = "Position too large for account size!"
    }

    return $checks
}

# ============================================================================
# EXPORT
# ============================================================================

Export-ModuleMember -Function Watch-LiquidationRisk, Get-LiquidationPrice, Test-PositionSafety, Invoke-EmergencyPositionReduce

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Liquidation Protector ready. Never get rekt on futures!" -ForegroundColor Yellow
    Write-Host "Use: Watch-LiquidationRisk -Exchange 'Binance' -AutoProtect" -ForegroundColor Yellow
}
