#Requires -Version 7.0
<#
.SYNOPSIS
    Kraken Pro API - Institutional-grade crypto exchange
.DESCRIPTION
    Complete Kraken integration:
    - Trusted by institutions and regulators
    - Best fiat on/off ramps (USD, EUR, CAD, GBP, JPY)
    - Advanced order types
    - Staking and margin trading
    - OTC desk for large trades
    - Highest security standards
.NOTES
    Part of Phase 4: Crypto Trading Core
#>

$script:Config = @{
    BaseURL = "https://api.kraken.com"
    ApiKey = $env:KRAKEN_API_KEY
    ApiSecret = $env:KRAKEN_API_SECRET
}

# ============================================================================
# AUTHENTICATION
# ============================================================================

function Get-KrakenSignature {
    param(
        [string]$Path,
        [string]$Nonce,
        [string]$PostData
    )

    $message = $Nonce + $PostData
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($message))

    $pathBytes = [System.Text.Encoding]::UTF8.GetBytes($Path)
    $combined = $pathBytes + $hashBytes

    $secretBytes = [Convert]::FromBase64String($script:Config.ApiSecret)
    $hmac = [System.Security.Cryptography.HMACSHA512]::new($secretBytes)
    $signature = $hmac.ComputeHash($combined)

    return [Convert]::ToBase64String($signature)
}

function Get-KrakenHeaders {
    param([string]$Path, [string]$Nonce, [string]$PostData)

    return @{
        "API-Key" = $script:Config.ApiKey
        "API-Sign" = Get-KrakenSignature -Path $Path -Nonce $Nonce -PostData $PostData
    }
}

# ============================================================================
# MARKET DATA
# ============================================================================

function Get-KrakenPrice {
    param([Parameter(Mandatory)][string]$Pair)

    try {
        $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)/0/public/Ticker?pair=$Pair" -Method Get

        if ($response.error.Count -gt 0) {
            Write-Host "❌ Kraken API error: $($response.error -join ', ')" -ForegroundColor Red
            return $null
        }

        $data = $response.result.PSObject.Properties | Select-Object -First 1

        return @{
            pair = $Pair
            price = [double]$data.Value.c[0]
            volume = [double]$data.Value.v[1]
            high24h = [double]$data.Value.h[1]
            low24h = [double]$data.Value.l[1]
            timestamp = Get-Date
        }
    }
    catch {
        Write-Host "❌ Failed to fetch Kraken price: $_" -ForegroundColor Red
        return $null
    }
}

function Get-KrakenCandles {
    param(
        [Parameter(Mandatory)][string]$Pair,
        [ValidateSet("1","5","15","30","60","240","1440","10080","21600")][string]$Interval = "60",
        [int]$Since = 0
    )

    try {
        $params = "pair=$Pair&interval=$Interval"
        if ($Since -gt 0) { $params += "&since=$Since" }

        $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)/0/public/OHLC?$params" -Method Get

        if ($response.error.Count -gt 0) {
            Write-Host "❌ Kraken API error: $($response.error -join ', ')" -ForegroundColor Red
            return $null
        }

        $data = $response.result.PSObject.Properties | Where-Object { $_.Name -ne 'last' } | Select-Object -First 1

        $candles = @()
        foreach ($candle in $data.Value) {
            $candles += @{
                timestamp = [DateTimeOffset]::FromUnixTimeSeconds($candle[0]).DateTime
                open = [double]$candle[1]
                high = [double]$candle[2]
                low = [double]$candle[3]
                close = [double]$candle[4]
                vwap = [double]$candle[5]
                volume = [double]$candle[6]
                count = [int]$candle[7]
            }
        }

        return $candles
    }
    catch {
        Write-Host "❌ Failed to fetch Kraken candles: $_" -ForegroundColor Red
        return $null
    }
}

function Get-KrakenOrderBook {
    param(
        [Parameter(Mandatory)][string]$Pair,
        [int]$Count = 100
    )

    try {
        $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)/0/public/Depth?pair=$Pair&count=$Count" -Method Get

        if ($response.error.Count -gt 0) {
            Write-Host "❌ Kraken API error: $($response.error -join ', ')" -ForegroundColor Red
            return $null
        }

        $data = $response.result.PSObject.Properties | Select-Object -First 1

        $bids = @()
        foreach ($bid in $data.Value.bids) {
            $bids += @{ price = [double]$bid[0]; volume = [double]$bid[1]; timestamp = $bid[2] }
        }

        $asks = @()
        foreach ($ask in $data.Value.asks) {
            $asks += @{ price = [double]$ask[0]; volume = [double]$ask[1]; timestamp = $ask[2] }
        }

        return @{
            bids = $bids
            asks = $asks
            spread = [Math]::Round((($asks[0].price - $bids[0].price) / $bids[0].price) * 100, 4)
        }
    }
    catch {
        Write-Host "❌ Failed to fetch Kraken order book: $_" -ForegroundColor Red
        return $null
    }
}

# ============================================================================
# ACCOUNT
# ============================================================================

function Get-KrakenBalance {
    try {
        $nonce = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString()
        $path = "/0/private/Balance"
        $postData = "nonce=$nonce"

        $headers = Get-KrakenHeaders -Path $path -Nonce $nonce -PostData $postData

        $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)$path" -Method Post -Headers $headers -Body $postData

        if ($response.error.Count -gt 0) {
            Write-Host "❌ Kraken API error: $($response.error -join ', ')" -ForegroundColor Red
            return $null
        }

        return $response.result
    }
    catch {
        Write-Host "❌ Failed to fetch Kraken balance: $_" -ForegroundColor Red
        return $null
    }
}

function Get-KrakenPortfolio {
    $balance = Get-KrakenBalance
    if (-not $balance) { return $null }

    $totalUSD = 0
    $positions = @()

    foreach ($asset in $balance.PSObject.Properties) {
        $amount = [double]$asset.Value

        if ($amount -gt 0) {
            $assetName = $asset.Name

            # Convert Kraken asset codes
            $cleanAsset = $assetName -replace '^X', '' -replace '^Z', ''

            # Get USD value
            if ($cleanAsset -eq "USD" -or $cleanAsset -eq "USDT") {
                $usdValue = $amount
            }
            else {
                $pair = "${cleanAsset}USD"
                $price = Get-KrakenPrice -Pair $pair
                $usdValue = if ($price) { $amount * $price.price } else { 0 }
            }

            $totalUSD += $usdValue

            $positions += @{
                asset = $cleanAsset
                amount = $amount
                usdValue = [Math]::Round($usdValue, 2)
            }
        }
    }

    return @{
        totalUSD = [Math]::Round($totalUSD, 2)
        positions = $positions | Sort-Object -Property usdValue -Descending
        timestamp = Get-Date
    }
}

# ============================================================================
# TRADING
# ============================================================================

function New-KrakenOrder {
    param(
        [Parameter(Mandatory)][string]$Pair,
        [Parameter(Mandatory)][ValidateSet("buy","sell")][string]$Type,
        [Parameter(Mandatory)][ValidateSet("market","limit","stop-loss","take-profit")][string]$OrderType,
        [Parameter(Mandatory)][double]$Volume,
        [double]$Price = 0,
        [double]$Price2 = 0,
        [ValidateSet("GTC","IOC","GTD")][string]$TimeInForce = "GTC",
        [switch]$PostOnly
    )

    try {
        $nonce = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString()
        $path = "/0/private/AddOrder"
        $postData = "nonce=$nonce&pair=$Pair&type=$Type&ordertype=$OrderType&volume=$Volume"

        if ($Price -gt 0) { $postData += "&price=$Price" }
        if ($Price2 -gt 0) { $postData += "&price2=$Price2" }
        if ($PostOnly) { $postData += "&oflags=post" }

        $headers = Get-KrakenHeaders -Path $path -Nonce $nonce -PostData $postData

        $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)$path" -Method Post -Headers $headers -Body $postData

        if ($response.error.Count -gt 0) {
            Write-Host "❌ Kraken order error: $($response.error -join ', ')" -ForegroundColor Red
            return $null
        }

        Write-Host "✅ Kraken $Type $OrderType order: $Volume $Pair $(if ($Price -gt 0) { "@ `$$Price" } else { "@ MARKET" })" -ForegroundColor Green

        return @{
            txid = $response.result.txid
            description = $response.result.descr
            timestamp = Get-Date
        }
    }
    catch {
        Write-Host "❌ Failed to place Kraken order: $_" -ForegroundColor Red
        return $null
    }
}

function Get-KrakenOpenOrders {
    try {
        $nonce = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString()
        $path = "/0/private/OpenOrders"
        $postData = "nonce=$nonce"

        $headers = Get-KrakenHeaders -Path $path -Nonce $nonce -PostData $postData

        $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)$path" -Method Post -Headers $headers -Body $postData

        if ($response.error.Count -gt 0) {
            Write-Host "❌ Kraken API error: $($response.error -join ', ')" -ForegroundColor Red
            return $null
        }

        return $response.result.open
    }
    catch {
        Write-Host "❌ Failed to fetch open orders: $_" -ForegroundColor Red
        return $null
    }
}

function Stop-KrakenOrder {
    param([Parameter(Mandatory)][string]$TxId)

    try {
        $nonce = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString()
        $path = "/0/private/CancelOrder"
        $postData = "nonce=$nonce&txid=$TxId"

        $headers = Get-KrakenHeaders -Path $path -Nonce $nonce -PostData $postData

        $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)$path" -Method Post -Headers $headers -Body $postData

        if ($response.error.Count -gt 0) {
            Write-Host "❌ Kraken cancel error: $($response.error -join ', ')" -ForegroundColor Red
            return $null
        }

        Write-Host "🚫 Order cancelled: $TxId" -ForegroundColor Yellow
        return $response.result
    }
    catch {
        Write-Host "❌ Failed to cancel order: $_" -ForegroundColor Red
        return $null
    }
}

# ============================================================================
# STAKING (Passive Income)
# ============================================================================

function Get-KrakenStakingAssets {
    try {
        $nonce = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString()
        $path = "/0/private/Staking/Assets"
        $postData = "nonce=$nonce"

        $headers = Get-KrakenHeaders -Path $path -Nonce $nonce -PostData $postData

        $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)$path" -Method Post -Headers $headers -Body $postData

        if ($response.error.Count -gt 0) {
            return $null
        }

        return $response.result
    }
    catch {
        return $null
    }
}

function Start-KrakenStaking {
    param(
        [Parameter(Mandatory)][string]$Asset,
        [Parameter(Mandatory)][double]$Amount
    )

    try {
        $nonce = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString()
        $path = "/0/private/Staking/Stake"
        $postData = "nonce=$nonce&asset=$Asset&amount=$Amount"

        $headers = Get-KrakenHeaders -Path $path -Nonce $nonce -PostData $postData

        $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)$path" -Method Post -Headers $headers -Body $postData

        if ($response.error.Count -gt 0) {
            Write-Host "❌ Staking error: $($response.error -join ', ')" -ForegroundColor Red
            return $null
        }

        Write-Host "💎 Staking activated: $Amount $Asset" -ForegroundColor Cyan
        return $response.result
    }
    catch {
        Write-Host "❌ Failed to stake: $_" -ForegroundColor Red
        return $null
    }
}

# ============================================================================
# EXPORT
# ============================================================================

Export-ModuleMember -Function Get-KrakenPrice, Get-KrakenCandles, Get-KrakenOrderBook, Get-KrakenBalance, Get-KrakenPortfolio, New-KrakenOrder, Get-KrakenOpenOrders, Stop-KrakenOrder, Get-KrakenStakingAssets, Start-KrakenStaking

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Kraken Pro API ready. Institutional-grade trading + staking activated" -ForegroundColor Yellow
    Write-Host "⚠️  Set KRAKEN_API_KEY and KRAKEN_API_SECRET environment variables" -ForegroundColor Yellow
}
