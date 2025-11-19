#Requires -Version 7.0
<#
.SYNOPSIS
    Bybit Derivatives API - Best perpetuals & futures platform
.DESCRIPTION
    Complete Bybit integration:
    - Industry-leading derivatives trading
    - Up to 100x leverage
    - Lowest liquidation risk
    - Dual price mechanism
    - Portfolio margin
    - Copy trading
    - Zero-fee spot trading
.NOTES
    Part of Phase 4: Crypto Trading Core
#>

$script:Config = @{
    BaseURL = "https://api.bybit.com"
    ApiKey = $env:BYBIT_API_KEY
    ApiSecret = $env:BYBIT_API_SECRET
}

# ============================================================================
# AUTHENTICATION
# ============================================================================

function Get-BybitSignature {
    param([string]$Timestamp, [string]$Params)

    $signStr = $Timestamp + $script:Config.ApiKey + "5000" + $Params
    $hmac = [System.Security.Cryptography.HMACSHA256]::new([System.Text.Encoding]::UTF8.GetBytes($script:Config.ApiSecret))
    $signature = $hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($signStr))
    return [BitConverter]::ToString($signature).Replace('-', '').ToLower()
}

function Get-BybitHeaders {
    param([string]$Timestamp, [string]$Signature)

    return @{
        "X-BAPI-API-KEY" = $script:Config.ApiKey
        "X-BAPI-TIMESTAMP" = $Timestamp
        "X-BAPI-SIGN" = $Signature
        "X-BAPI-RECV-WINDOW" = "5000"
        "Content-Type" = "application/json"
    }
}

# ============================================================================
# MARKET DATA
# ============================================================================

function Get-BybitPrice {
    param(
        [Parameter(Mandatory)][string]$Symbol,
        [ValidateSet("spot","linear","inverse")][string]$Category = "linear"
    )

    try {
        $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)/v5/market/tickers?category=$Category&symbol=$Symbol" -Method Get

        if ($response.retCode -ne 0) {
            Write-Host "❌ Bybit API error: $($response.retMsg)" -ForegroundColor Red
            return $null
        }

        $ticker = $response.result.list[0]

        return @{
            symbol = $ticker.symbol
            price = [double]$ticker.lastPrice
            change24h = [double]$ticker.price24hPcnt * 100
            volume24h = [double]$ticker.volume24h
            high24h = [double]$ticker.highPrice24h
            low24h = [double]$ticker.lowPrice24h
            fundingRate = if ($Category -eq "linear") { [double]$ticker.fundingRate } else { 0 }
            openInterest = [double]$ticker.openInterest
            timestamp = Get-Date
        }
    }
    catch {
        Write-Host "❌ Failed to fetch Bybit price: $_" -ForegroundColor Red
        return $null
    }
}

function Get-BybitCandles {
    param(
        [Parameter(Mandatory)][string]$Symbol,
        [ValidateSet("spot","linear","inverse")][string]$Category = "linear",
        [ValidateSet("1","3","5","15","30","60","120","240","360","720","D","W","M")][string]$Interval = "60",
        [int]$Limit = 200
    )

    try {
        $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)/v5/market/kline?category=$Category&symbol=$Symbol&interval=$Interval&limit=$Limit" -Method Get

        if ($response.retCode -ne 0) {
            Write-Host "❌ Bybit API error: $($response.retMsg)" -ForegroundColor Red
            return $null
        }

        $candles = @()
        foreach ($candle in $response.result.list) {
            $candles += @{
                timestamp = [DateTimeOffset]::FromUnixTimeMilliseconds([long]$candle[0]).DateTime
                open = [double]$candle[1]
                high = [double]$candle[2]
                low = [double]$candle[3]
                close = [double]$candle[4]
                volume = [double]$candle[5]
                turnover = [double]$candle[6]
            }
        }

        # Reverse to chronological order
        [array]::Reverse($candles)
        return $candles
    }
    catch {
        Write-Host "❌ Failed to fetch Bybit candles: $_" -ForegroundColor Red
        return $null
    }
}

function Get-BybitOrderBook {
    param(
        [Parameter(Mandatory)][string]$Symbol,
        [ValidateSet("spot","linear","inverse")][string]$Category = "linear",
        [ValidateSet("1","25","50","100","200")][int]$Limit = 25
    )

    try {
        $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)/v5/market/orderbook?category=$Category&symbol=$Symbol&limit=$Limit" -Method Get

        if ($response.retCode -ne 0) {
            Write-Host "❌ Bybit API error: $($response.retMsg)" -ForegroundColor Red
            return $null
        }

        $ob = $response.result

        $bids = @()
        foreach ($bid in $ob.b) {
            $bids += @{ price = [double]$bid[0]; quantity = [double]$bid[1] }
        }

        $asks = @()
        foreach ($ask in $ob.a) {
            $asks += @{ price = [double]$ask[0]; quantity = [double]$ask[1] }
        }

        return @{
            bids = $bids
            asks = $asks
            spread = [Math]::Round((($asks[0].price - $bids[0].price) / $bids[0].price) * 100, 4)
            updateId = $ob.u
        }
    }
    catch {
        Write-Host "❌ Failed to fetch Bybit order book: $_" -ForegroundColor Red
        return $null
    }
}

# ============================================================================
# ACCOUNT
# ============================================================================

function Get-BybitBalance {
    param([ValidateSet("UNIFIED","CONTRACT","SPOT")][string]$AccountType = "UNIFIED")

    try {
        $timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString()
        $params = "accountType=$AccountType"
        $signature = Get-BybitSignature -Timestamp $timestamp -Params $params

        $headers = Get-BybitHeaders -Timestamp $timestamp -Signature $signature

        $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)/v5/account/wallet-balance?$params" -Method Get -Headers $headers

        if ($response.retCode -ne 0) {
            Write-Host "❌ Bybit API error: $($response.retMsg)" -ForegroundColor Red
            return $null
        }

        return $response.result.list[0]
    }
    catch {
        Write-Host "❌ Failed to fetch Bybit balance: $_" -ForegroundColor Red
        return $null
    }
}

function Get-BybitPortfolio {
    $balance = Get-BybitBalance
    if (-not $balance) { return $null }

    $totalEquity = [double]$balance.totalEquity
    $totalWalletBalance = [double]$balance.totalWalletBalance
    $totalMarginBalance = [double]$balance.totalMarginBalance
    $totalAvailableBalance = [double]$balance.totalAvailableBalance

    $positions = @()
    foreach ($coin in $balance.coin) {
        $equity = [double]$coin.equity
        if ($equity -gt 0) {
            $positions += @{
                coin = $coin.coin
                equity = [Math]::Round($equity, 6)
                walletBalance = [Math]::Round([double]$coin.walletBalance, 6)
                availableToWithdraw = [Math]::Round([double]$coin.availableToWithdraw, 6)
                usdValue = [Math]::Round([double]$coin.usdValue, 2)
            }
        }
    }

    return @{
        accountType = $balance.accountType
        totalEquity = [Math]::Round($totalEquity, 2)
        totalWalletBalance = [Math]::Round($totalWalletBalance, 2)
        totalMarginBalance = [Math]::Round($totalMarginBalance, 2)
        totalAvailableBalance = [Math]::Round($totalAvailableBalance, 2)
        positions = $positions | Sort-Object -Property usdValue -Descending
        timestamp = Get-Date
    }
}

# ============================================================================
# PERPETUALS TRADING
# ============================================================================

function Set-BybitLeverage {
    param(
        [Parameter(Mandatory)][string]$Symbol,
        [ValidateRange(1,100)][int]$BuyLeverage = 10,
        [ValidateRange(1,100)][int]$SellLeverage = 10,
        [ValidateSet("linear","inverse")][string]$Category = "linear"
    )

    try {
        $timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString()

        $body = @{
            category = $Category
            symbol = $Symbol
            buyLeverage = $BuyLeverage.ToString()
            sellLeverage = $SellLeverage.ToString()
        } | ConvertTo-Json -Compress

        $signature = Get-BybitSignature -Timestamp $timestamp -Params $body
        $headers = Get-BybitHeaders -Timestamp $timestamp -Signature $signature

        $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)/v5/position/set-leverage" -Method Post -Headers $headers -Body $body

        if ($response.retCode -ne 0) {
            Write-Host "❌ Bybit leverage error: $($response.retMsg)" -ForegroundColor Red
            return $null
        }

        Write-Host "⚡ Leverage set: ${BuyLeverage}x (Buy) / ${SellLeverage}x (Sell) for $Symbol" -ForegroundColor Yellow
        return $response.result
    }
    catch {
        Write-Host "❌ Failed to set leverage: $_" -ForegroundColor Red
        return $null
    }
}

function New-BybitOrder {
    param(
        [Parameter(Mandatory)][string]$Symbol,
        [Parameter(Mandatory)][ValidateSet("Buy","Sell")][string]$Side,
        [Parameter(Mandatory)][ValidateSet("Market","Limit")][string]$OrderType,
        [Parameter(Mandatory)][double]$Qty,
        [ValidateSet("spot","linear","inverse")][string]$Category = "linear",
        [double]$Price = 0,
        [ValidateSet("GTC","IOC","FOK","PostOnly")][string]$TimeInForce = "GTC",
        [switch]$ReduceOnly
    )

    try {
        $timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString()

        $orderData = @{
            category = $Category
            symbol = $Symbol
            side = $Side
            orderType = $OrderType
            qty = $Qty.ToString()
            timeInForce = $TimeInForce
        }

        if ($Price -gt 0) { $orderData.price = $Price.ToString() }
        if ($ReduceOnly) { $orderData.reduceOnly = $true }

        $body = $orderData | ConvertTo-Json -Compress

        $signature = Get-BybitSignature -Timestamp $timestamp -Params $body
        $headers = Get-BybitHeaders -Timestamp $timestamp -Signature $signature

        $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)/v5/order/create" -Method Post -Headers $headers -Body $body

        if ($response.retCode -ne 0) {
            Write-Host "❌ Bybit order error: $($response.retMsg)" -ForegroundColor Red
            return $null
        }

        Write-Host "✅ Bybit $Side $OrderType order: $Qty $Symbol $(if ($Price -gt 0) { "@ `$$Price" } else { "@ MARKET" })" -ForegroundColor Green

        return @{
            orderId = $response.result.orderId
            orderLinkId = $response.result.orderLinkId
            timestamp = Get-Date
        }
    }
    catch {
        Write-Host "❌ Failed to place Bybit order: $_" -ForegroundColor Red
        return $null
    }
}

function Get-BybitPosition {
    param(
        [ValidateSet("linear","inverse")][string]$Category = "linear",
        [string]$Symbol = ""
    )

    try {
        $timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString()
        $params = "category=$Category"
        if ($Symbol) { $params += "&symbol=$Symbol" }

        $signature = Get-BybitSignature -Timestamp $timestamp -Params $params
        $headers = Get-BybitHeaders -Timestamp $timestamp -Signature $signature

        $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)/v5/position/list?$params" -Method Get -Headers $headers

        if ($response.retCode -ne 0) {
            Write-Host "❌ Bybit API error: $($response.retMsg)" -ForegroundColor Red
            return $null
        }

        $positions = $response.result.list | Where-Object { [double]$_.size -gt 0 }

        return $positions | ForEach-Object {
            @{
                symbol = $_.symbol
                side = $_.side
                size = [double]$_.size
                entryPrice = [double]$_.avgPrice
                markPrice = [double]$_.markPrice
                liquidationPrice = [double]$_.liqPrice
                unrealizedPnl = [double]$_.unrealisedPnl
                leverage = [int]$_.leverage
                positionValue = [double]$_.positionValue
            }
        }
    }
    catch {
        Write-Host "❌ Failed to fetch Bybit positions: $_" -ForegroundColor Red
        return $null
    }
}

function Stop-BybitOrder {
    param(
        [Parameter(Mandatory)][string]$Symbol,
        [Parameter(Mandatory)][string]$OrderId,
        [ValidateSet("spot","linear","inverse")][string]$Category = "linear"
    )

    try {
        $timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString()

        $body = @{
            category = $Category
            symbol = $Symbol
            orderId = $OrderId
        } | ConvertTo-Json -Compress

        $signature = Get-BybitSignature -Timestamp $timestamp -Params $body
        $headers = Get-BybitHeaders -Timestamp $timestamp -Signature $signature

        $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)/v5/order/cancel" -Method Post -Headers $headers -Body $body

        if ($response.retCode -ne 0) {
            Write-Host "❌ Cancel error: $($response.retMsg)" -ForegroundColor Red
            return $null
        }

        Write-Host "🚫 Order cancelled: $OrderId" -ForegroundColor Yellow
        return $response.result
    }
    catch {
        Write-Host "❌ Failed to cancel order: $_" -ForegroundColor Red
        return $null
    }
}

# ============================================================================
# RISK MANAGEMENT
# ============================================================================

function Set-BybitStopLoss {
    param(
        [Parameter(Mandatory)][string]$Symbol,
        [Parameter(Mandatory)][ValidateSet("Buy","Sell")][string]$Side,
        [Parameter(Mandatory)][double]$StopLoss,
        [ValidateSet("linear","inverse")][string]$Category = "linear"
    )

    try {
        $timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString()

        $body = @{
            category = $Category
            symbol = $Symbol
            stopLoss = $StopLoss.ToString()
            positionIdx = 0
        } | ConvertTo-Json -Compress

        $signature = Get-BybitSignature -Timestamp $timestamp -Params $body
        $headers = Get-BybitHeaders -Timestamp $timestamp -Signature $signature

        $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)/v5/position/trading-stop" -Method Post -Headers $headers -Body $body

        if ($response.retCode -ne 0) {
            Write-Host "❌ Stop loss error: $($response.retMsg)" -ForegroundColor Red
            return $null
        }

        Write-Host "🛡️  Stop loss set: `$$StopLoss for $Symbol" -ForegroundColor Cyan
        return $response.result
    }
    catch {
        Write-Host "❌ Failed to set stop loss: $_" -ForegroundColor Red
        return $null
    }
}

# ============================================================================
# EXPORT
# ============================================================================

Export-ModuleMember -Function Get-BybitPrice, Get-BybitCandles, Get-BybitOrderBook, Get-BybitBalance, Get-BybitPortfolio, Set-BybitLeverage, New-BybitOrder, Get-BybitPosition, Stop-BybitOrder, Set-BybitStopLoss

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Bybit Derivatives API ready. Best perpetuals platform (100x leverage) activated" -ForegroundColor Yellow
    Write-Host "⚠️  Set BYBIT_API_KEY and BYBIT_API_SECRET environment variables" -ForegroundColor Yellow
}
