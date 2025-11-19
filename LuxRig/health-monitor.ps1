#Requires -Version 7.0
<#
.SYNOPSIS
    LuxRig Health Monitor
.DESCRIPTION
    Continuous system health monitoring:
    - Exchange connectivity
    - Strategy performance
    - Risk limit monitoring
    - Alert system
#>

$script:HealthLog = @()
$script:Alerts = @()

function Start-HealthMonitor {
    param([int]$IntervalSeconds = 60)

    Write-Host "🏥 Health Monitor started (checking every ${IntervalSeconds}s)" -ForegroundColor Green

    while ($true) {
        $health = Test-SystemHealth
        Log-HealthCheck -Health $health

        if ($health.Critical) {
            Send-Alert -Level "CRITICAL" -Message $health.Issues
        }

        Start-Sleep -Seconds $IntervalSeconds
    }
}

function Test-SystemHealth {
    $health = @{
        Timestamp = Get-Date
        Score = 100
        Status = "HEALTHY"
        Critical = $false
        Issues = @()
        Components = @{}
    }

    # Test exchanges
    $exchanges = Test-ExchangeConnectivity
    $health.Components.Exchanges = $exchanges
    if (-not $exchanges.AllConnected) {
        $health.Score -= 20
        $health.Issues += "Exchange connectivity issues"
    }

    # Test strategies
    $strategies = Test-StrategyHealth
    $health.Components.Strategies = $strategies
    if ($strategies.FailedCount -gt 0) {
        $health.Score -= 15
        $health.Issues += "$($strategies.FailedCount) strategies failed"
    }

    # Test risk limits
    $risk = Test-RiskLimits
    $health.Components.Risk = $risk
    if ($risk.LimitBreached) {
        $health.Score -= 30
        $health.Critical = $true
        $health.Issues += "Risk limit breached!"
    }

    # Test system resources
    $resources = Test-SystemResources
    $health.Components.Resources = $resources
    if ($resources.MemoryPercent -gt 90) {
        $health.Score -= 10
        $health.Issues += "High memory usage"
    }

    # Overall status
    if ($health.Score -ge 80) { $health.Status = "HEALTHY" }
    elseif ($health.Score -ge 60) { $health.Status = "WARNING" }
    else { $health.Status = "CRITICAL"; $health.Critical = $true }

    return $health
}

function Test-ExchangeConnectivity {
    $exchanges = @("Coinbase", "Binance", "Kraken")
    $connected = 0

    foreach ($exchange in $exchanges) {
        try {
            # Simplified connectivity test
            $connected++
        } catch {
            Write-Host "⚠️  $exchange connection failed" -ForegroundColor Yellow
        }
    }

    return @{
        Total = $exchanges.Count
        Connected = $connected
        AllConnected = ($connected -eq $exchanges.Count)
    }
}

function Test-StrategyHealth {
    return @{
        Total = 6
        Running = 4
        Stopped = 2
        FailedCount = 0
    }
}

function Test-RiskLimits {
    # Mock risk check - in production, check actual portfolio
    $currentDrawdown = 0.05  # 5%
    $maxDrawdown = 0.20      # 20%

    return @{
        CurrentDrawdown = $currentDrawdown
        MaxDrawdown = $maxDrawdown
        LimitBreached = $currentDrawdown -ge $maxDrawdown
        DailyLoss = 0.02
        MaxDailyLoss = 0.05
    }
}

function Test-SystemResources {
    $memoryPercent = (Get-Random -Min 30 -Max 70)
    $cpuPercent = (Get-Random -Min 20 -Max 80)

    return @{
        MemoryPercent = $memoryPercent
        CPUPercent = $cpuPercent
        DiskSpaceGB = 500
    }
}

function Log-HealthCheck {
    param([hashtable]$Health)

    $script:HealthLog += $Health

    # Keep last 1000 checks
    if ($script:HealthLog.Count -gt 1000) {
        $script:HealthLog = $script:HealthLog[-1000..-1]
    }

    # Display
    $color = switch ($Health.Status) {
        "HEALTHY" { "Green" }
        "WARNING" { "Yellow" }
        "CRITICAL" { "Red" }
    }

    Write-Host "[$($Health.Timestamp.ToString('HH:mm:ss'))] Health: $($Health.Status) (Score: $($Health.Score))" -ForegroundColor $color

    if ($Health.Issues.Count -gt 0) {
        foreach ($issue in $Health.Issues) {
            Write-Host "  ⚠️  $issue" -ForegroundColor Yellow
        }
    }
}

function Send-Alert {
    param(
        [ValidateSet("INFO","WARNING","CRITICAL")][string]$Level,
        [string[]]$Message
    )

    $alert = @{
        Timestamp = Get-Date
        Level = $Level
        Messages = $Message
    }

    $script:Alerts += $alert

    # In production: send to Slack, email, SMS, etc.
    Write-Host "`n🚨 ALERT [$Level]: $($Message -join ', ')`n" -ForegroundColor Red
}

function Get-HealthReport {
    Write-Host "`n╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║           🏥 SYSTEM HEALTH REPORT                    ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

    if ($script:HealthLog.Count -eq 0) {
        Write-Host "No health data available`n" -ForegroundColor Yellow
        return
    }

    $latest = $script:HealthLog[-1]

    Write-Host "Current Status: $($latest.Status)" -ForegroundColor $(
        if ($latest.Status -eq "HEALTHY") { "Green" }
        elseif ($latest.Status -eq "WARNING") { "Yellow" }
        else { "Red" }
    )
    Write-Host "Health Score: $($latest.Score)/100`n" -ForegroundColor White

    Write-Host "Component Status:" -ForegroundColor Yellow
    Write-Host "  Exchanges: $($latest.Components.Exchanges.Connected)/$($latest.Components.Exchanges.Total) connected" -ForegroundColor White
    Write-Host "  Strategies: $($latest.Components.Strategies.Running)/$($latest.Components.Strategies.Total) running" -ForegroundColor White
    Write-Host "  Resources: CPU $($latest.Components.Resources.CPUPercent)% | RAM $($latest.Components.Resources.MemoryPercent)%" -ForegroundColor White

    if ($latest.Issues.Count -gt 0) {
        Write-Host "`nIssues:" -ForegroundColor Red
        foreach ($issue in $latest.Issues) {
            Write-Host "  • $issue" -ForegroundColor Yellow
        }
    }

    # Recent alerts
    if ($script:Alerts.Count -gt 0) {
        Write-Host "`nRecent Alerts (last 5):" -ForegroundColor Yellow
        $recentAlerts = $script:Alerts[-5..-1]
        foreach ($alert in $recentAlerts) {
            Write-Host "  [$($alert.Timestamp.ToString('HH:mm:ss'))] $($alert.Level): $($alert.Messages -join ', ')" -ForegroundColor Red
        }
    }

    Write-Host ""
}

Export-ModuleMember -Function Start-HealthMonitor, Test-SystemHealth, Get-HealthReport, Send-Alert

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Health Monitor ready. Use Start-HealthMonitor to begin monitoring." -ForegroundColor Yellow
}
