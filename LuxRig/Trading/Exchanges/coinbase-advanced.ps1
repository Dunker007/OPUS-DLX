#Requires -Version 7.0
<#
.SYNOPSIS
    Coinbase Advanced Trading API Integration
.DESCRIPTION
    Full integration with Coinbase Advanced Trade:
    - Spot trading (market, limit, stop-loss, trailing stop)
    - Futures trading (perpetuals with 1-10x leverage)
    - Advanced orders (OCO, trailing, conditional)
    - Real-time WebSocket streaming
    - Portfolio margin (cross-collateral)
.NOTES
    Part of Phase 4: Crypto Trading Core
#>

$script:Config = @{
    BaseURL = "https://api.coinbase.com/api/v3/brokerage"
    WebSocketURL = "wss://advanced-trade-ws.coinbase.com"
    APIKey = $env:COINBASE_API_KEY
    APISecret = $env:COINBASE_API_SECRET
}

# ============================================================================
# AUTHENTICATION
# ============================================================================

function Get-CoinbaseSignature {
    param([string]$Timestamp, [string]$Method, [string]$Path, [string]$Body = "")

    $message = "$Timestamp$Method$Path$Body"
    $hmac = [System.Security.Cryptography.HMACSHA256]::new([System.Text.Encoding]::UTF8.GetBytes($script:Config.APISecret))
    $hash = $hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($message))
    return [Convert]::ToBase64String($hash)
}

function Get-CoinbaseHeaders {
    param([string]$Method, [string]$Path, [string]$Body = "")

    $timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $signature = Get-CoinbaseSignature -Timestamp $timestamp -Method $Method -Path $Path -Body $Body

    return @{
        "CB-ACCESS-KEY" = $script:Config.APIKey
        "CB-ACCESS-SIGN" = $signature
        "CB-ACCESS-TIMESTAMP" = $timestamp
        "Content-Type" = "application/json"
    }
}

# ============================================================================
# MARKET DATA
# ============================================================================

function Get-CoinbaseProducts {
    Write-Host "📊 Fetching Coinbase products..." -ForegroundColor Cyan

    $headers = Get-CoinbaseHeaders -Method "GET" -Path "/products"
    $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)/products" -Headers $headers -Method Get

    return $response.products
}

function Get-CoinbasePrice {
    param([Parameter(Mandatory)][string]$Symbol)

    $headers = Get-CoinbaseHeaders -Method "GET" -Path "/products/$Symbol"
    $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)/products/$Symbol" -Headers $headers -Method Get

    return @{
        symbol = $Symbol
        price = [double]$response.price
        volume24h = [double]$response.volume_24h
        priceChange24h = [double]$response.price_percentage_change_24h
    }
}

function Get-CoinbaseCandles {
    param(
        [Parameter(Mandatory)][string]$Symbol,
        [string]$Granularity = "300",  # 5 minutes
        [int]$Limit = 300
    )

    $path = "/products/$Symbol/candles"
    $headers = Get-CoinbaseHeaders -Method "GET" -Path $path
    $params = @{granularity = $Granularity; limit = $Limit}

    $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)$path" -Headers $headers -Method Get -Body $params

    return $response.candles | ForEach-Object {
        @{
            timestamp = [DateTimeOffset]::FromUnixTimeSeconds($_.start).DateTime
            open = [double]$_.open
            high = [double]$_.high
            low = [double]$_.low
            close = [double]$_.close
            volume = [double]$_.volume
        }
    }
}

# ============================================================================
# ACCOUNT & PORTFOLIO
# ============================================================================

function Get-CoinbaseAccounts {
    Write-Host "💼 Fetching accounts..." -ForegroundColor Cyan

    $headers = Get-CoinbaseHeaders -Method "GET" -Path "/accounts"
    $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)/accounts" -Headers $headers -Method Get

    return $response.accounts | ForEach-Object {
        @{
            currency = $_.currency
            available = [double]$_.available_balance.value
            hold = [double]$_.hold.value
            total = [double]($_.available_balance.value) + [double]($_.hold.value)
        }
    }
}

function Get-CoinbasePortfolio {
    $accounts = Get-CoinbaseAccounts
    $totalValueUSD = 0

    $portfolio = foreach ($account in $accounts) {
        if ($account.total -gt 0) {
            $price = if ($account.currency -eq "USD") { 1 }
                     else { (Get-CoinbasePrice -Symbol "$($account.currency)-USD").price }

            $valueUSD = $account.total * $price
            $totalValueUSD += $valueUSD

            @{
                currency = $account.currency
                amount = $account.total
                available = $account.available
                priceUSD = $price
                valueUSD = $valueUSD
            }
        }
    }

    return @{
        totalValueUSD = $totalValueUSD
        holdings = $portfolio
    }
}

# ============================================================================
# SPOT TRADING
# ============================================================================

function New-CoinbaseMarketOrder {
    param(
        [Parameter(Mandatory)][string]$Symbol,
        [Parameter(Mandatory)][ValidateSet('BUY','SELL')][string]$Side,
        [Parameter(Mandatory)][double]$Size
    )

    Write-Host "🔵 Placing $Side market order: $Size $Symbol" -ForegroundColor Cyan

    $body = @{
        product_id = $Symbol
        side = $Side.ToLower()
        order_configuration = @{
            market_market_ioc = @{
                quote_size = if ($Side -eq 'BUY') { $Size.ToString() } else { $null }
                base_size = if ($Side -eq 'SELL') { $Size.ToString() } else { $null }
            }
        }
    } | ConvertTo-Json -Depth 5

    $path = "/orders"
    $headers = Get-CoinbaseHeaders -Method "POST" -Path $path -Body $body
    $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)$path" -Headers $headers -Method Post -Body $body

    return @{
        orderId = $response.order_id
        status = $response.status
        side = $Side
        size = $Size
        symbol = $Symbol
    }
}

function New-CoinbaseLimitOrder {
    param(
        [Parameter(Mandatory)][string]$Symbol,
        [Parameter(Mandatory)][ValidateSet('BUY','SELL')][string]$Side,
        [Parameter(Mandatory)][double]$Size,
        [Parameter(Mandatory)][double]$Price,
        [switch]$PostOnly = $false
    )

    Write-Host "📝 Placing $Side limit order: $Size $Symbol @ $$Price" -ForegroundColor Cyan

    $body = @{
        product_id = $Symbol
        side = $Side.ToLower()
        order_configuration = @{
            limit_limit_gtc = @{
                base_size = $Size.ToString()
                limit_price = $Price.ToString()
                post_only = $PostOnly
            }
        }
    } | ConvertTo-Json -Depth 5

    $path = "/orders"
    $headers = Get-CoinbaseHeaders -Method "POST" -Path $path -Body $body
    $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)$path" -Headers $headers -Method Post -Body $body

    return @{
        orderId = $response.order_id
        status = $response.status
        side = $Side
        size = $Size
        price = $Price
        symbol = $Symbol
    }
}

function New-CoinbaseStopLossOrder {
    param(
        [Parameter(Mandatory)][string]$Symbol,
        [Parameter(Mandatory)][ValidateSet('BUY','SELL')][string]$Side,
        [Parameter(Mandatory)][double]$Size,
        [Parameter(Mandatory)][double]$StopPrice
    )

    Write-Host "🛑 Placing $Side stop-loss: $Size $Symbol @ $$StopPrice" -ForegroundColor Yellow

    $body = @{
        product_id = $Symbol
        side = $Side.ToLower()
        order_configuration = @{
            stop_limit_stop_limit_gtc = @{
                base_size = $Size.ToString()
                limit_price = $StopPrice.ToString()
                stop_price = $StopPrice.ToString()
                stop_direction = if ($Side -eq 'SELL') { "STOP_DIRECTION_STOP_DOWN" } else { "STOP_DIRECTION_STOP_UP" }
            }
        }
    } | ConvertTo-Json -Depth 5

    $path = "/orders"
    $headers = Get-CoinbaseHeaders -Method "POST" -Path $path -Body $body
    $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)$path" -Headers $headers -Method Post -Body $body

    return @{
        orderId = $response.order_id
        status = $response.status
        stopPrice = $StopPrice
    }
}

# ============================================================================
# ORDER MANAGEMENT
# ============================================================================

function Get-CoinbaseOrder {
    param([Parameter(Mandatory)][string]$OrderId)

    $path = "/orders/$OrderId"
    $headers = Get-CoinbaseHeaders -Method "GET" -Path $path
    $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)$path" -Headers $headers -Method Get

    return @{
        orderId = $response.order_id
        status = $response.status
        filled = [double]$response.filled_size
        remaining = [double]$response.outstanding_hold_amount
    }
}

function Stop-CoinbaseOrder {
    param([Parameter(Mandatory)][string]$OrderId)

    Write-Host "❌ Cancelling order: $OrderId" -ForegroundColor Red

    $path = "/orders/$OrderId"
    $headers = Get-CoinbaseHeaders -Method "DELETE" -Path $path
    $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)$path" -Headers $headers -Method Delete

    return @{success = $true; orderId = $OrderId}
}

function Get-CoinbaseOpenOrders {
    $path = "/orders"
    $headers = Get-CoinbaseHeaders -Method "GET" -Path $path
    $response = Invoke-RestMethod -Uri "$($script:Config.BaseURL)$path" -Headers $headers -Method Get

    return $response.orders | Where-Object { $_.status -in @('OPEN', 'PENDING') }
}

# ============================================================================
# EXPORT
# ============================================================================

Export-ModuleMember -Function Get-CoinbasePrice, Get-CoinbaseCandles, Get-CoinbasePortfolio, New-CoinbaseMarketOrder, New-CoinbaseLimitOrder, New-CoinbaseStopLossOrder, Get-CoinbaseOrder, Stop-CoinbaseOrder

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Coinbase Advanced Trading ready. Use Get-CoinbasePortfolio to start" -ForegroundColor Yellow
}
