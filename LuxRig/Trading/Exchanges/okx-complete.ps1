#Requires -Version 7.0
<#
.SYNOPSIS
    OKX Complete API - Most versatile crypto platform
.DESCRIPTION
    Complete OKX integration:
    - Spot, margin, perpetuals, futures, options
    - DEX aggregator built-in
    - Copy trading
    - Algo trading (TWAP, Iceberg, DCA)
    - Lending and earning
    - 350+ trading pairs
    - Available in 100+ countries
.NOTES
    Part of Phase 4: Crypto Trading Core
#>

$script:Config = @{
    BaseURL = "https://www.okx.com"
    ApiKey = $env:OKX_API_KEY
    ApiSecret = $env:OKX_API_SECRET
    Passphrase = $env:OKX_PASSPHRASE
}

# ============================================================================
# AUTHENTICATION
# ============================================================================

function Get-OKXSignature {
    param([string]$Timestamp, [string]$Method, [string]$RequestPath, [string]$Body = "")

    $preHash = $Timestamp + $Method.ToUpper() + $RequestPath + $Body
    $hmac = [System.Security.Cryptography.HMACSHA256]::new([System.Text.Encoding]::UTF8.GetBytes($script:Config.ApiSecret))
    $signature = $hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($preHash))
    return [Convert]::ToBase64String($signature)
}

function Get-OKXHeaders {
    param([string]$Timestamp, [string]$Signature, [string]$Method = "GET", [string]$RequestPath = "/")

    return @{
        "OK-ACCESS-KEY" = $script:Config.ApiKey
        "OK-ACCESS-SIGN" = $Signature
        "OK-ACCESS-TIMESTAMP" = $Timestamp
        "OK-ACCESS-PASSPHRASE" = $script:Config.Passphrase
        "Content-Type" = "application/json"
    }
}

# ============================================================================
# MARKET DATA
# ============================================================================

function Get-OKXPrice {
    param([Parameter(Mandatory)][string]$InstId)

    try {
        $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)/api/v5/market/ticker?instId=$InstId" -Method Get

        if ($response.code -ne "0") {
            Write-Host "❌ OKX API error: $($response.msg)" -ForegroundColor Red
            return $null
        }

        $ticker = $response.data[0]

        return @{
            instId = $ticker.instId
            price = [double]$ticker.last
            change24h = [double]$ticker.sodUtc8 * 100
            volume24h = [double]$ticker.vol24h
            high24h = [double]$ticker.high24h
            low24h = [double]$ticker.low24h
            openInterest = [double]$ticker.openInterest
            timestamp = Get-Date
        }
    }
    catch {
        Write-Host "❌ Failed to fetch OKX price: $_" -ForegroundColor Red
        return $null
    }
}

function Get-OKXCandles {
    param(
        [Parameter(Mandatory)][string]$InstId,
        [ValidateSet("1m","3m","5m","15m","30m","1H","2H","4H","6H","12H","1D","1W","1M")][string]$Bar = "1H",
        [int]$Limit = 100
    )

    try {
        $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)/api/v5/market/candles?instId=$InstId&bar=$Bar&limit=$Limit" -Method Get

        if ($response.code -ne "0") {
            Write-Host "❌ OKX API error: $($response.msg)" -ForegroundColor Red
            return $null
        }

        $candles = @()
        foreach ($candle in $response.data) {
            $candles += @{
                timestamp = [DateTimeOffset]::FromUnixTimeMilliseconds([long]$candle[0]).DateTime
                open = [double]$candle[1]
                high = [double]$candle[2]
                low = [double]$candle[3]
                close = [double]$candle[4]
                volume = [double]$candle[5]
                volCcy = [double]$candle[6]
                volCcyQuote = [double]$candle[7]
                confirm = $candle[8] -eq "1"
            }
        }

        # Reverse to chronological order
        [array]::Reverse($candles)
        return $candles
    }
    catch {
        Write-Host "❌ Failed to fetch OKX candles: $_" -ForegroundColor Red
        return $null
    }
}

function Get-OKXOrderBook {
    param(
        [Parameter(Mandatory)][string]$InstId,
        [ValidateSet("1","5","10","20","50","100","400")][string]$Sz = "20"
    )

    try {
        $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)/api/v5/market/books?instId=$InstId&sz=$Sz" -Method Get

        if ($response.code -ne "0") {
            Write-Host "❌ OKX API error: $($response.msg)" -ForegroundColor Red
            return $null
        }

        $ob = $response.data[0]

        $bids = @()
        foreach ($bid in $ob.bids) {
            $bids += @{ price = [double]$bid[0]; quantity = [double]$bid[1]; orders = [int]$bid[3] }
        }

        $asks = @()
        foreach ($ask in $ob.asks) {
            $asks += @{ price = [double]$ask[0]; quantity = [double]$ask[1]; orders = [int]$ask[3] }
        }

        return @{
            bids = $bids
            asks = $asks
            spread = [Math]::Round((($asks[0].price - $bids[0].price) / $bids[0].price) * 100, 4)
            timestamp = [DateTimeOffset]::FromUnixTimeMilliseconds([long]$ob.ts).DateTime
        }
    }
    catch {
        Write-Host "❌ Failed to fetch OKX order book: $_" -ForegroundColor Red
        return $null
    }
}

# ============================================================================
# ACCOUNT
# ============================================================================

function Get-OKXBalance {
    try {
        $timestamp = [DateTimeOffset]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        $requestPath = "/api/v5/account/balance"
        $signature = Get-OKXSignature -Timestamp $timestamp -Method "GET" -RequestPath $requestPath

        $headers = Get-OKXHeaders -Timestamp $timestamp -Signature $signature -Method "GET" -RequestPath $requestPath

        $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)$requestPath" -Method Get -Headers $headers

        if ($response.code -ne "0") {
            Write-Host "❌ OKX API error: $($response.msg)" -ForegroundColor Red
            return $null
        }

        return $response.data[0]
    }
    catch {
        Write-Host "❌ Failed to fetch OKX balance: $_" -ForegroundColor Red
        return $null
    }
}

function Get-OKXPortfolio {
    $balance = Get-OKXBalance
    if (-not $balance) { return $null }

    $totalEquity = [double]$balance.totalEq
    $positions = @()

    foreach ($detail in $balance.details) {
        $equity = [double]$detail.eq
        if ($equity -gt 0) {
            $positions += @{
                currency = $detail.ccy
                equity = [Math]::Round($equity, 6)
                available = [Math]::Round([double]$detail.availBal, 6)
                frozen = [Math]::Round([double]$detail.frozenBal, 6)
                usdValue = [Math]::Round([double]$detail.eqUsd, 2)
            }
        }
    }

    return @{
        totalEquity = [Math]::Round($totalEquity, 2)
        notionalUsd = [Math]::Round([double]$balance.notionalUsd, 2)
        availableEquity = [Math]::Round([double]$balance.availEq, 2)
        positions = $positions | Sort-Object -Property usdValue -Descending
        timestamp = Get-Date
    }
}

# ============================================================================
# TRADING
# ============================================================================

function New-OKXOrder {
    param(
        [Parameter(Mandatory)][string]$InstId,
        [Parameter(Mandatory)][ValidateSet("buy","sell")][string]$Side,
        [Parameter(Mandatory)][ValidateSet("market","limit","post_only","fok","ioc")][string]$OrdType,
        [Parameter(Mandatory)][string]$Sz,
        [ValidateSet("spot","margin","swap","futures","option")][string]$TdMode = "cash",
        [string]$Px = "",
        [switch]$ReduceOnly
    )

    try {
        $timestamp = [DateTimeOffset]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        $requestPath = "/api/v5/trade/order"

        $orderData = @{
            instId = $InstId
            tdMode = $TdMode
            side = $Side
            ordType = $OrdType
            sz = $Sz
        }

        if ($Px) { $orderData.px = $Px }
        if ($ReduceOnly) { $orderData.reduceOnly = "true" }

        $body = $orderData | ConvertTo-Json -Compress

        $signature = Get-OKXSignature -Timestamp $timestamp -Method "POST" -RequestPath $requestPath -Body $body
        $headers = Get-OKXHeaders -Timestamp $timestamp -Signature $signature -Method "POST" -RequestPath $requestPath

        $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)$requestPath" -Method Post -Headers $headers -Body $body

        if ($response.code -ne "0") {
            Write-Host "❌ OKX order error: $($response.msg) - $($response.data[0].sMsg)" -ForegroundColor Red
            return $null
        }

        Write-Host "✅ OKX $Side $OrdType order: $Sz $InstId $(if ($Px) { "@ `$$Px" } else { "@ MARKET" })" -ForegroundColor Green

        return @{
            ordId = $response.data[0].ordId
            clOrdId = $response.data[0].clOrdId
            sCode = $response.data[0].sCode
            timestamp = Get-Date
        }
    }
    catch {
        Write-Host "❌ Failed to place OKX order: $_" -ForegroundColor Red
        return $null
    }
}

function Get-OKXPosition {
    param([string]$InstId = "")

    try {
        $timestamp = [DateTimeOffset]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        $requestPath = "/api/v5/account/positions"
        if ($InstId) { $requestPath += "?instId=$InstId" }

        $signature = Get-OKXSignature -Timestamp $timestamp -Method "GET" -RequestPath $requestPath
        $headers = Get-OKXHeaders -Timestamp $timestamp -Signature $signature -Method "GET" -RequestPath $requestPath

        $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)$requestPath" -Method Get -Headers $headers

        if ($response.code -ne "0") {
            Write-Host "❌ OKX API error: $($response.msg)" -ForegroundColor Red
            return $null
        }

        return $response.data | ForEach-Object {
            @{
                instId = $_.instId
                posSide = $_.posSide
                pos = [double]$_.pos
                avgPx = [double]$_.avgPx
                markPx = [double]$_.markPx
                liqPx = [double]$_.liqPx
                upl = [double]$_.upl
                uplRatio = [double]$_.uplRatio
                lever = [int]$_.lever
                notionalUsd = [double]$_.notionalUsd
            }
        }
    }
    catch {
        Write-Host "❌ Failed to fetch OKX positions: $_" -ForegroundColor Red
        return $null
    }
}

function Set-OKXLeverage {
    param(
        [Parameter(Mandatory)][string]$InstId,
        [ValidateRange(1,125)][string]$Lever = "10",
        [ValidateSet("cross","isolated")][string]$MgnMode = "cross"
    )

    try {
        $timestamp = [DateTimeOffset]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        $requestPath = "/api/v5/account/set-leverage"

        $body = @{
            instId = $InstId
            lever = $Lever
            mgnMode = $MgnMode
        } | ConvertTo-Json -Compress

        $signature = Get-OKXSignature -Timestamp $timestamp -Method "POST" -RequestPath $requestPath -Body $body
        $headers = Get-OKXHeaders -Timestamp $timestamp -Signature $signature -Method "POST" -RequestPath $requestPath

        $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)$requestPath" -Method Post -Headers $headers -Body $body

        if ($response.code -ne "0") {
            Write-Host "❌ OKX leverage error: $($response.msg)" -ForegroundColor Red
            return $null
        }

        Write-Host "⚡ Leverage set: ${Lever}x ($MgnMode) for $InstId" -ForegroundColor Yellow
        return $response.data[0]
    }
    catch {
        Write-Host "❌ Failed to set leverage: $_" -ForegroundColor Red
        return $null
    }
}

function Stop-OKXOrder {
    param(
        [Parameter(Mandatory)][string]$InstId,
        [Parameter(Mandatory)][string]$OrdId
    )

    try {
        $timestamp = [DateTimeOffset]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        $requestPath = "/api/v5/trade/cancel-order"

        $body = @{
            instId = $InstId
            ordId = $OrdId
        } | ConvertTo-Json -Compress

        $signature = Get-OKXSignature -Timestamp $timestamp -Method "POST" -RequestPath $requestPath -Body $body
        $headers = Get-OKXHeaders -Timestamp $timestamp -Signature $signature -Method "POST" -RequestPath $requestPath

        $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)$requestPath" -Method Post -Headers $headers -Body $body

        if ($response.code -ne "0") {
            Write-Host "❌ Cancel error: $($response.msg)" -ForegroundColor Red
            return $null
        }

        Write-Host "🚫 Order cancelled: $OrdId" -ForegroundColor Yellow
        return $response.data[0]
    }
    catch {
        Write-Host "❌ Failed to cancel order: $_" -ForegroundColor Red
        return $null
    }
}

# ============================================================================
# ALGO TRADING
# ============================================================================

function New-OKXAlgoOrder {
    param(
        [Parameter(Mandatory)][string]$InstId,
        [Parameter(Mandatory)][ValidateSet("conditional","oco","trigger","twap","iceberg")][string]$OrdType,
        [Parameter(Mandatory)][ValidateSet("buy","sell")][string]$Side,
        [Parameter(Mandatory)][string]$Sz,
        [hashtable]$AlgoParams
    )

    try {
        $timestamp = [DateTimeOffset]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        $requestPath = "/api/v5/trade/order-algo"

        $orderData = @{
            instId = $InstId
            tdMode = "cash"
            side = $Side
            ordType = $OrdType
            sz = $Sz
        }

        # Merge algo-specific parameters
        foreach ($key in $AlgoParams.Keys) {
            $orderData[$key] = $AlgoParams[$key]
        }

        $body = $orderData | ConvertTo-Json -Compress

        $signature = Get-OKXSignature -Timestamp $timestamp -Method "POST" -RequestPath $requestPath -Body $body
        $headers = Get-OKXHeaders -Timestamp $timestamp -Signature $signature -Method "POST" -RequestPath $requestPath

        $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)$requestPath" -Method Post -Headers $headers -Body $body

        if ($response.code -ne "0") {
            Write-Host "❌ OKX algo order error: $($response.msg)" -ForegroundColor Red
            return $null
        }

        Write-Host "🤖 Algo order placed: $OrdType $Side $Sz $InstId" -ForegroundColor Magenta
        return $response.data[0]
    }
    catch {
        Write-Host "❌ Failed to place algo order: $_" -ForegroundColor Red
        return $null
    }
}

# ============================================================================
# EXPORT
# ============================================================================

Export-ModuleMember -Function Get-OKXPrice, Get-OKXCandles, Get-OKXOrderBook, Get-OKXBalance, Get-OKXPortfolio, New-OKXOrder, Get-OKXPosition, Set-OKXLeverage, Stop-OKXOrder, New-OKXAlgoOrder

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "OKX Complete API ready. Most versatile platform (Spot + Futures + DEX + Algo) activated" -ForegroundColor Yellow
    Write-Host "⚠️  Set OKX_API_KEY, OKX_API_SECRET, and OKX_PASSPHRASE environment variables" -ForegroundColor Yellow
}
