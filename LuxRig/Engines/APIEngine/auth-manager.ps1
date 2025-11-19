<#
.SYNOPSIS
    Auth Manager - API key generation and authentication

.DESCRIPTION
    Manages API authentication:
    - API key generation
    - Key validation
    - User tier management
    - Usage tracking per key
#>

function New-APIKey {
    param(
        [Parameter(Mandatory=$true)]
        [string]$UserId,

        [ValidateSet("free", "basic", "pro", "enterprise")]
        [string]$Tier = "free",

        [string]$KeyPrefix = "lux"
    )

    # Generate secure random key
    $randomBytes = New-Object byte[] 32
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($randomBytes)
    $keySecret = [Convert]::ToBase64String($randomBytes) -replace '[^a-zA-Z0-9]', ''

    $apiKey = "${KeyPrefix}_$($keySecret.Substring(0, 32))"

    $keyData = @{
        key = $apiKey
        userId = $UserId
        tier = $Tier
        created = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        lastUsed = $null
        requests = 0
        active = $true
        limits = Get-TierLimits -Tier $Tier
    }

    # Save to database (mock - would use actual DB)
    $keysFile = "$PSScriptRoot\..\..\Analytics\api-keys.jsonl"
    $keyData | ConvertTo-Json -Compress | Add-Content $keysFile

    Write-Host "✓ API key generated: $apiKey" -ForegroundColor Green

    return $keyData
}

function Get-TierLimits {
    param(
        [ValidateSet("free", "basic", "pro", "enterprise")]
        [string]$Tier
    )

    $limits = @{
        free = @{
            requestsPerDay = 100
            requestsPerMonth = 1000
            maxTokensPerRequest = 1000
            price = 0
        }
        basic = @{
            requestsPerDay = 1000
            requestsPerMonth = 30000
            maxTokensPerRequest = 5000
            price = 29
        }
        pro = @{
            requestsPerDay = 10000
            requestsPerMonth = 300000
            maxTokensPerRequest = 10000
            price = 99
        }
        enterprise = @{
            requestsPerDay = 999999
            requestsPerMonth = 999999
            maxTokensPerRequest = 50000
            price = 499
        }
    }

    return $limits[$Tier]
}

function Test-APIKey {
    param(
        [Parameter(Mandatory=$true)]
        [string]$APIKey
    )

    # Load keys from file (mock DB)
    $keysFile = "$PSScriptRoot\..\..\Analytics\api-keys.jsonl"

    if (-not (Test-Path $keysFile)) {
        return @{valid = $false; error = "No keys found"}
    }

    $keys = Get-Content $keysFile | ForEach-Object { $_ | ConvertFrom-Json }

    $keyData = $keys | Where-Object { $_.key -eq $APIKey } | Select-Object -First 1

    if (-not $keyData) {
        return @{valid = $false; error = "Invalid API key"}
    }

    if (-not $keyData.active) {
        return @{valid = $false; error = "API key is inactive"}
    }

    # Update last used
    # (In production, this would update the database)

    return @{
        valid = $true
        userId = $keyData.userId
        tier = $keyData.tier
        limits = $keyData.limits
    }
}

function Get-APIUsage {
    param(
        [Parameter(Mandatory=$true)]
        [string]$APIKey,

        [ValidateSet("day", "month", "all")]
        [string]$Period = "month"
    )

    # Mock usage tracking - in production, query actual usage logs
    $logsFile = "$PSScriptRoot\..\..\Analytics\api-usage.jsonl"

    if (-not (Test-Path $logsFile)) {
        return @{requests = 0; tokens = 0; cost = 0}
    }

    $logs = Get-Content $logsFile | ForEach-Object { $_ | ConvertFrom-Json }

    $userLogs = $logs | Where-Object { $_.apiKey -eq $APIKey }

    # Filter by period
    $now = Get-Date
    $filteredLogs = switch ($Period) {
        "day" { $userLogs | Where-Object { ([datetime]$_.timestamp).Date -eq $now.Date } }
        "month" { $userLogs | Where-Object { ([datetime]$_.timestamp).Month -eq $now.Month } }
        "all" { $userLogs }
    }

    $usage = @{
        requests = $filteredLogs.Count
        tokens = ($filteredLogs | Measure-Object -Property tokens -Sum).Sum
        cost = ($filteredLogs | Measure-Object -Property cost -Sum).Sum
    }

    return $usage
}

function Update-APIUsage {
    param(
        [Parameter(Mandatory=$true)]
        [string]$APIKey,

        [int]$Tokens = 0,

        [double]$Cost = 0
    )

    $usageEntry = @{
        apiKey = $APIKey
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        tokens = $Tokens
        cost = $Cost
    }

    $logsFile = "$PSScriptRoot\..\..\Analytics\api-usage.jsonl"

    $usageEntry | ConvertTo-Json -Compress | Add-Content $logsFile
}

Export-ModuleMember -Function New-APIKey, Test-APIKey, Get-APIUsage, Update-APIUsage, Get-TierLimits
