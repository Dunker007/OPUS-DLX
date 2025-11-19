<#
.SYNOPSIS
    Rate Limiter - Request throttling and quota management

.DESCRIPTION
    Implements rate limiting:
    - Per-user request limits
    - Sliding window algorithm
    - Tier-based quotas
    - Quota reset scheduling
#>

$script:RateLimitCache = @{}

function Test-RateLimit {
    param(
        [Parameter(Mandatory=$true)]
        [string]$UserId,

        [Parameter(Mandatory=$true)]
        [hashtable]$Limits,

        [string]$Period = "day"
    )

    $cacheKey = "${UserId}:${Period}"
    $now = Get-Date

    # Initialize cache if needed
    if (-not $script:RateLimitCache.ContainsKey($cacheKey)) {
        $script:RateLimitCache[$cacheKey] = @{
            requests = @()
            resetTime = $now.AddDays(1).Date
        }
    }

    $cache = $script:RateLimitCache[$cacheKey]

    # Check if cache needs reset
    if ($now -gt $cache.resetTime) {
        $cache.requests = @()
        $cache.resetTime = switch ($Period) {
            "day" { $now.AddDays(1).Date }
            "hour" { $now.AddHours(1) }
            "minute" { $now.AddMinutes(1) }
        }
    }

    # Clean old requests (sliding window)
    $windowStart = switch ($Period) {
        "day" { $now.AddDays(-1) }
        "hour" { $now.AddHours(-1) }
        "minute" { $now.AddMinutes(-1) }
    }

    $cache.requests = $cache.requests | Where-Object { $_ -gt $windowStart }

    # Check limit
    $limitKey = switch ($Period) {
        "day" { "requestsPerDay" }
        "month" { "requestsPerMonth" }
        default { "requestsPerDay" }
    }

    $limit = $Limits[$limitKey]
    $currentCount = $cache.requests.Count

    $allowed = $currentCount -lt $limit

    return @{
        allowed = $allowed
        current = $currentCount
        limit = $limit
        remaining = [Math]::Max(0, $limit - $currentCount)
        resetTime = $cache.resetTime
    }
}

function Add-RequestToLimit {
    param(
        [Parameter(Mandatory=$true)]
        [string]$UserId,

        [string]$Period = "day"
    )

    $cacheKey = "${UserId}:${Period}"

    if (-not $script:RateLimitCache.ContainsKey($cacheKey)) {
        $script:RateLimitCache[$cacheKey] = @{
            requests = @()
            resetTime = (Get-Date).AddDays(1).Date
        }
    }

    $script:RateLimitCache[$cacheKey].requests += Get-Date
}

function Get-RateLimitStatus {
    param(
        [Parameter(Mandatory=$true)]
        [string]$UserId,

        [Parameter(Mandatory=$true)]
        [hashtable]$Limits
    )

    $dayStatus = Test-RateLimit -UserId $UserId -Limits $Limits -Period "day"
    $monthStatus = Test-RateLimit -UserId $UserId -Limits $Limits -Period "month"

    return @{
        day = $dayStatus
        month = $monthStatus
        withinLimits = ($dayStatus.allowed -and $monthStatus.allowed)
    }
}

function Invoke-RateLimitCheck {
    param(
        [Parameter(Mandatory=$true)]
        [string]$APIKey
    )

    # Get user info and limits
    Import-Module "$PSScriptRoot\auth-manager.ps1" -Force

    $authResult = Test-APIKey -APIKey $APIKey

    if (-not $authResult.valid) {
        return @{
            allowed = $false
            error = $authResult.error
        }
    }

    # Check rate limits
    $status = Get-RateLimitStatus -UserId $authResult.userId -Limits $authResult.limits

    if (-not $status.withinLimits) {
        $resetTime = if (-not $status.day.allowed) { $status.day.resetTime } else { $status.month.resetTime }

        return @{
            allowed = $false
            error = "Rate limit exceeded"
            resetTime = $resetTime
            limits = @{
                day = $status.day
                month = $status.month
            }
        }
    }

    # Increment counters
    Add-RequestToLimit -UserId $authResult.userId -Period "day"
    Add-RequestToLimit -UserId $authResult.userId -Period "month"

    return @{
        allowed = $true
        userId = $authResult.userId
        tier = $authResult.tier
        limits = @{
            day = $status.day
            month = $status.month
        }
    }
}

function Clear-RateLimitCache {
    param([string]$UserId = "")

    if ($UserId) {
        $keysToRemove = $script:RateLimitCache.Keys | Where-Object { $_ -match "^${UserId}:" }
        foreach ($key in $keysToRemove) {
            $script:RateLimitCache.Remove($key)
        }
    }
    else {
        $script:RateLimitCache = @{}
    }

    Write-Host "✓ Rate limit cache cleared" -ForegroundColor Green
}

Export-ModuleMember -Function Invoke-RateLimitCheck, Test-RateLimit, Get-RateLimitStatus, Clear-RateLimitCache
