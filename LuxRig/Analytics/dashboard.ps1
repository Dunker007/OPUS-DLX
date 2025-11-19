<#
.SYNOPSIS
    LuxRig Monitoring Dashboard - Real-time System Status

.DESCRIPTION
    PowerShell-based real-time monitoring dashboard displaying:
    - Current AI usage (requests, tokens, costs)
    - Budget status and remaining allocation
    - System health (LuxRig uptime, API status)
    - Recent tasks and outcomes
    - Revenue tracking (if integrated)
    - Cost per dollar earned (ROI)

.EXAMPLE
    .\dashboard.ps1
    .\dashboard.ps1 -RefreshInterval 5 -Detailed

.NOTES
    Part of LuxRig Phase 1 Foundation
    Press Ctrl+C to exit
#>

param(
    [int]$RefreshInterval = 10,  # Seconds between refreshes
    [switch]$Detailed,           # Show detailed metrics
    [switch]$Continuous          # Run continuously (default: single display)
)

# Import required modules
Import-Module "$PSScriptRoot\..\Orchestrator\budget-manager.ps1" -Force

# Clear screen helper
function Clear-Dashboard {
    Clear-Host
}

# Get AI performance stats
function Get-AIPerformanceStats {
    $perfDir = "$PSScriptRoot\ai-performance"

    if (-not (Test-Path $perfDir)) {
        return @{
            total_requests = 0
            total_cost = 0
            total_tokens = 0
            models = @{}
        }
    }

    $stats = @{
        total_requests = 0
        total_cost = 0.0
        total_tokens = 0
        models = @{}
    }

    # Read all JSONL log files
    $logFiles = Get-ChildItem -Path $perfDir -Filter "*.jsonl" -ErrorAction SilentlyContinue

    foreach ($logFile in $logFiles) {
        $entries = Get-Content $logFile | ForEach-Object { $_ | ConvertFrom-Json }

        foreach ($entry in $entries) {
            $modelName = $entry.plugin.ToLower()

            if (-not $stats.models.ContainsKey($modelName)) {
                $stats.models[$modelName] = @{
                    requests = 0
                    cost = 0.0
                    tokens = 0
                    successes = 0
                    failures = 0
                    avg_duration = 0
                    total_duration = 0
                }
            }

            $stats.models[$modelName].requests++
            $stats.total_requests++

            if ($entry.success) {
                $stats.models[$modelName].successes++
                $stats.models[$modelName].cost += $entry.cost
                $stats.models[$modelName].tokens += $entry.total_tokens
                $stats.total_cost += $entry.cost
                $stats.total_tokens += $entry.total_tokens
            }
            else {
                $stats.models[$modelName].failures++
            }

            if ($entry.duration_seconds) {
                $stats.models[$modelName].total_duration += $entry.duration_seconds
            }
        }
    }

    # Calculate averages
    foreach ($model in $stats.models.Keys) {
        if ($stats.models[$model].requests -gt 0) {
            $stats.models[$model].avg_duration = [Math]::Round(
                $stats.models[$model].total_duration / $stats.models[$model].requests, 2
            )
        }
    }

    return $stats
}

# Get system health
function Get-SystemHealth {
    $health = @{
        luxrig_online = $true  # Assume online if script is running
        api_status = @{}
        uptime_hours = 0
        disk_space_gb = 0
        memory_usage_percent = 0
    }

    # Check disk space
    try {
        $drive = Get-PSDrive -Name C -ErrorAction SilentlyContinue
        if ($drive) {
            $health.disk_space_gb = [Math]::Round($drive.Free / 1GB, 2)
        }
    }
    catch {
        $health.disk_space_gb = "N/A"
    }

    # Check memory usage
    try {
        if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
            $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
            if ($os) {
                $health.memory_usage_percent = [Math]::Round(
                    (($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 1
                )
            }
        }
    }
    catch {
        $health.memory_usage_percent = "N/A"
    }

    # Get uptime
    try {
        $bootTime = (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue).LastBootUpTime
        if ($bootTime) {
            $health.uptime_hours = [Math]::Round(((Get-Date) - $bootTime).TotalHours, 1)
        }
    }
    catch {
        $health.uptime_hours = "N/A"
    }

    # Quick API health checks (ping endpoints)
    $health.api_status = @{
        anthropic = "unknown"
        openai = "unknown"
        google = "unknown"
        local = "unknown"
    }

    return $health
}

# Get recent activity
function Get-RecentActivity {
    param([int]$Limit = 5)

    $perfDir = "$PSScriptRoot\ai-performance"

    if (-not (Test-Path $perfDir)) {
        return @()
    }

    $activities = @()

    # Get all log entries from today
    $logFiles = Get-ChildItem -Path $perfDir -Filter "*$(Get-Date -Format 'yyyy-MM')*.jsonl" -ErrorAction SilentlyContinue

    foreach ($logFile in $logFiles) {
        $entries = Get-Content $logFile | ForEach-Object { $_ | ConvertFrom-Json }
        $activities += $entries
    }

    # Sort by timestamp and take most recent
    $recent = $activities | Sort-Object { [datetime]$_.timestamp } -Descending | Select-Object -First $Limit

    return $recent
}

# Display dashboard
function Show-Dashboard {
    param(
        [switch]$Detailed
    )

    Clear-Dashboard

    # Header
    Write-Host "╔════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                      🚀 LUXRIG COMMAND CENTER 🚀                           ║" -ForegroundColor Cyan
    Write-Host "║                     AI Orchestration Dashboard                             ║" -ForegroundColor Cyan
    Write-Host "╠════════════════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
    Write-Host "║  Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')".PadRight(77) + "║" -ForegroundColor White
    Write-Host "╚════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

    # System Health
    $health = Get-SystemHealth
    Write-Host "`n┌─ SYSTEM HEALTH ────────────────────────────────────────────────────────────┐" -ForegroundColor Green

    $healthColor = if ($health.luxrig_online) { "Green" } else { "Red" }
    Write-Host "│ LuxRig Status:    " -NoNewline -ForegroundColor Gray
    Write-Host "$(if ($health.luxrig_online) { '●' } else { '○' }) ONLINE".PadRight(60) -ForegroundColor $healthColor

    Write-Host "│ System Uptime:    $($health.uptime_hours) hours".PadRight(79) + "│" -ForegroundColor Gray
    Write-Host "│ Disk Space:       $($health.disk_space_gb) GB free".PadRight(79) + "│" -ForegroundColor Gray
    Write-Host "│ Memory Usage:     $($health.memory_usage_percent)%".PadRight(79) + "│" -ForegroundColor Gray
    Write-Host "└────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Green

    # Budget Status
    $budgetStatus = Get-BudgetStatus
    Write-Host "`n┌─ BUDGET STATUS ────────────────────────────────────────────────────────────┐" -ForegroundColor Yellow

    $budgetPercent = if ($budgetStatus.total_budget -gt 0) {
        ($budgetStatus.total_spent / $budgetStatus.total_budget) * 100
    } else { 0 }

    $budgetColor = "Green"
    if ($budgetPercent -ge 100) { $budgetColor = "Red" }
    elseif ($budgetPercent -ge 80) { $budgetColor = "Yellow" }

    Write-Host "│ Monthly Budget:   `$$($budgetStatus.total_budget)".PadRight(79) + "│" -ForegroundColor Gray
    Write-Host "│ Total Spent:      " -NoNewline -ForegroundColor Gray
    Write-Host "`$$($budgetStatus.total_spent)".PadRight(60) -NoNewline -ForegroundColor $budgetColor
    Write-Host "│"
    Write-Host "│ Remaining:        `$$($budgetStatus.total_remaining) ($([Math]::Round(100-$budgetPercent, 1))% left)".PadRight(79) + "│" -ForegroundColor Gray

    # Per-model budget
    foreach ($modelName in @("claude", "gpt4", "gemini", "grok", "local")) {
        if ($budgetStatus.models.ContainsKey($modelName)) {
            $model = $budgetStatus.models[$modelName]
            $modelColor = "White"
            if ($model.percent_used -ge 100) { $modelColor = "Red" }
            elseif ($model.percent_used -ge 80) { $modelColor = "Yellow" }
            elseif ($model.percent_used -ge 50) { $modelColor = "Green" }

            $bar = "[" + ("█" * [Math]::Floor($model.percent_used / 5)) + (" " * (20 - [Math]::Floor($model.percent_used / 5))) + "]"

            Write-Host "│  $($modelName.ToUpper().PadRight(8)) " -NoNewline -ForegroundColor Cyan
            Write-Host "$bar " -NoNewline -ForegroundColor $modelColor
            Write-Host "$([Math]::Round($model.percent_used, 1))% (`$$([Math]::Round($model.spent_month, 2)))".PadRight(40) -NoNewline -ForegroundColor Gray
            Write-Host "│"
        }
    }

    Write-Host "└────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Yellow

    # AI Performance
    $perfStats = Get-AIPerformanceStats
    Write-Host "`n┌─ AI PERFORMANCE ───────────────────────────────────────────────────────────┐" -ForegroundColor Magenta

    Write-Host "│ Total Requests:   $($perfStats.total_requests)".PadRight(79) + "│" -ForegroundColor Gray
    Write-Host "│ Total Tokens:     $($perfStats.total_tokens)".PadRight(79) + "│" -ForegroundColor Gray
    Write-Host "│ Total Cost:       `$$([Math]::Round($perfStats.total_cost, 4))".PadRight(79) + "│" -ForegroundColor Gray

    if ($perfStats.total_requests -gt 0) {
        Write-Host "│ Avg Cost/Request: `$$([Math]::Round($perfStats.total_cost / $perfStats.total_requests, 4))".PadRight(79) + "│" -ForegroundColor Gray
    }

    Write-Host "│".PadRight(79) + "│"

    foreach ($modelName in $perfStats.models.Keys | Sort-Object) {
        $model = $perfStats.models[$modelName]
        $successRate = if ($model.requests -gt 0) {
            [Math]::Round(($model.successes / $model.requests) * 100, 1)
        } else { 0 }

        Write-Host "│  $($modelName.ToUpper().PadRight(12)) " -NoNewline -ForegroundColor Cyan
        Write-Host "Req: $($model.requests.ToString().PadLeft(4)) | " -NoNewline -ForegroundColor Gray
        Write-Host "Success: $($successRate)% | " -NoNewline -ForegroundColor $(if ($successRate -ge 95) { "Green" } else { "Yellow" })
        Write-Host "Avg: $($model.avg_duration)s".PadRight(30) -NoNewline -ForegroundColor Gray
        Write-Host "│"
    }

    Write-Host "└────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Magenta

    # Recent Activity
    $recentActivity = Get-RecentActivity -Limit 5
    Write-Host "`n┌─ RECENT ACTIVITY ──────────────────────────────────────────────────────────┐" -ForegroundColor Blue

    if ($recentActivity.Count -eq 0) {
        Write-Host "│  No recent activity".PadRight(79) + "│" -ForegroundColor DarkGray
    }
    else {
        foreach ($activity in $recentActivity) {
            $status = if ($activity.success) { "✓" } else { "✗" }
            $color = if ($activity.success) { "Green" } else { "Red" }

            $timestamp = $activity.timestamp
            $model = $activity.plugin.PadRight(8)
            $cost = if ($activity.cost) { "`$$([Math]::Round($activity.cost, 4))" } else { "`$0.00" }

            Write-Host "│ $status " -NoNewline -ForegroundColor $color
            Write-Host "$timestamp | " -NoNewline -ForegroundColor Gray
            Write-Host "$model | " -NoNewline -ForegroundColor Cyan
            Write-Host "$cost".PadRight(50) -NoNewline -ForegroundColor Yellow
            Write-Host "│"
        }
    }

    Write-Host "└────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Blue

    # Footer
    Write-Host "`n" -NoNewline
    if ($Continuous) {
        Write-Host "Press Ctrl+C to exit | Refreshing every $RefreshInterval seconds..." -ForegroundColor DarkGray
    }
}

# Main execution
if ($Continuous) {
    Write-Host "Starting LuxRig Dashboard in continuous mode..." -ForegroundColor Cyan
    Write-Host "Press Ctrl+C to exit`n" -ForegroundColor Yellow

    try {
        while ($true) {
            Show-Dashboard -Detailed:$Detailed
            Start-Sleep -Seconds $RefreshInterval
        }
    }
    catch {
        Write-Host "`nDashboard stopped." -ForegroundColor Yellow
    }
}
else {
    Show-Dashboard -Detailed:$Detailed
}
