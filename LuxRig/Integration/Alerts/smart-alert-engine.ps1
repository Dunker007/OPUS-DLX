<#
.SYNOPSIS
    Smart Alert Engine with ML Filtering for LuxRig
.DESCRIPTION
    Intelligent alert system with throttling, priority levels, ML-based filtering,
    duplicate detection, and adaptive notification strategies.
.NOTES
    Version: 1.0.0
    Author: LuxRig Enterprise Team
    Requires: PowerShell 7.0+
#>

using namespace System.Collections.Generic

#region Module Configuration

$script:ModuleConfig = @{
    AlertsPath = "$PSScriptRoot/../../../Data/Alerts"
    RulesPath = "$PSScriptRoot/../../../Configs/alert-rules.json"
    ThrottlePath = "$PSScriptRoot/../../../Data/Alerts/Throttle"
    MLModelsPath = "$PSScriptRoot/../../../Data/Alerts/MLModels"

    DefaultThrottling = @{
        Low = 3600  # 1 hour
        Medium = 1800  # 30 minutes
        High = 300  # 5 minutes
        Critical = 0  # No throttling
    }
}

enum AlertPriority {
    Low = 0
    Medium = 1
    High = 2
    Critical = 3
}

enum AlertType {
    Price
    Volume
    Signal
    Security
    System
    Portfolio
}

#endregion

#region Core Functions

function Initialize-SmartAlertEngine {
    <#
    .SYNOPSIS
        Initializes the smart alert engine
    #>
    [CmdletBinding()]
    param()

    try {
        Write-Verbose "Initializing Smart Alert Engine..."

        $directories = @(
            $script:ModuleConfig.AlertsPath,
            $script:ModuleConfig.ThrottlePath,
            $script:ModuleConfig.MLModelsPath,
            (Split-Path -Parent $script:ModuleConfig.RulesPath)
        )

        foreach ($dir in $directories) {
            if (-not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
        }

        # Initialize rules
        if (-not (Test-Path $script:ModuleConfig.RulesPath)) {
            $defaultRules = @{
                Version = "1.0.0"
                Rules = @()
                GlobalSettings = @{
                    MaxAlertsPerHour = 50
                    DuplicateWindowMinutes = 15
                    MLFilteringEnabled = $true
                }
            }
            $defaultRules | ConvertTo-Json -Depth 10 | Set-Content $script:ModuleConfig.RulesPath
        }

        Write-Verbose "Smart Alert Engine initialized successfully"
        return $true
    }
    catch {
        Write-Error "Failed to initialize Smart Alert Engine: $_"
        return $false
    }
}

function New-SmartAlert {
    <#
    .SYNOPSIS
        Creates a smart alert with ML filtering and throttling
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AlertType]$Type,

        [Parameter(Mandatory = $true)]
        [string]$Title,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $true)]
        [AlertPriority]$Priority,

        [Parameter(Mandatory = $false)]
        [string]$AssetSymbol = "",

        [Parameter(Mandatory = $false)]
        [hashtable]$Data = @{},

        [Parameter(Mandatory = $false)]
        [string]$UserId = ""
    )

    try {
        Write-Verbose "Creating smart alert: $Title"

        # Generate alert fingerprint for deduplication
        $fingerprint = Get-AlertFingerprint -Type $Type -Title $Title -AssetSymbol $AssetSymbol

        # Check for duplicate alerts
        if (Test-DuplicateAlert -Fingerprint $fingerprint) {
            Write-Verbose "Duplicate alert detected, skipping"
            return $null
        }

        # Check throttling
        if (Test-AlertThrottled -Type $Type -Priority $Priority -UserId $UserId) {
            Write-Verbose "Alert throttled"
            return $null
        }

        # Apply ML filtering
        $mlScore = Get-MLImportanceScore -Alert @{
            Type = $Type
            Title = $Title
            Message = $Message
            Priority = $Priority
            AssetSymbol = $AssetSymbol
        }

        # Filter low-importance alerts
        if ($mlScore -lt 0.3 -and $Priority -eq [AlertPriority]::Low) {
            Write-Verbose "Alert filtered by ML (low importance score: $mlScore)"
            return $null
        }

        # Create alert
        $alertId = [guid]::NewGuid().ToString()
        $alert = @{
            AlertId = $alertId
            Type = $Type.ToString()
            Title = $Title
            Message = $Message
            Priority = $Priority.ToString()
            AssetSymbol = $AssetSymbol
            Data = $Data
            UserId = $UserId
            Fingerprint = $fingerprint
            MLScore = $mlScore
            CreatedAt = (Get-Date).ToString('o')
            Status = "Active"
        }

        # Save alert
        $alertFile = Join-Path $script:ModuleConfig.AlertsPath "$alertId.json"
        $alert | ConvertTo-Json -Depth 10 | Set-Content $alertFile

        # Update throttle tracker
        Update-ThrottleTracker -Type $Type -Priority $Priority -UserId $UserId

        # Update duplicate tracker
        Save-AlertFingerprint -Fingerprint $fingerprint

        Write-Verbose "Smart alert created: $alertId (ML Score: $mlScore)"
        return $alert
    }
    catch {
        Write-Error "Failed to create smart alert: $_"
        return $null
    }
}

function Set-AlertRule {
    <#
    .SYNOPSIS
        Creates or updates an alert rule
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RuleName,

        [Parameter(Mandatory = $true)]
        [AlertType]$Type,

        [Parameter(Mandatory = $true)]
        [hashtable]$Conditions,

        [Parameter(Mandatory = $true)]
        [AlertPriority]$Priority,

        [Parameter(Mandatory = $false)]
        [bool]$Enabled = $true
    )

    try {
        Write-Verbose "Setting alert rule: $RuleName"

        $rules = Get-Content $script:ModuleConfig.RulesPath -Raw | ConvertFrom-Json

        $rule = @{
            RuleId = [guid]::NewGuid().ToString()
            Name = $RuleName
            Type = $Type.ToString()
            Conditions = $Conditions
            Priority = $Priority.ToString()
            Enabled = $Enabled
            CreatedAt = (Get-Date).ToString('o')
            TriggeredCount = 0
            LastTriggered = $null
        }

        # Remove existing rule with same name
        $rules.Rules = @($rules.Rules | Where-Object { $_.Name -ne $RuleName })

        # Add new rule
        $rules.Rules += $rule

        $rules | ConvertTo-Json -Depth 10 | Set-Content $script:ModuleConfig.RulesPath

        Write-Verbose "Alert rule set successfully"
        return $rule
    }
    catch {
        Write-Error "Failed to set alert rule: $_"
        return $null
    }
}

function Test-AlertRules {
    <#
    .SYNOPSIS
        Evaluates all active alert rules
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$MarketData
    )

    try {
        Write-Verbose "Evaluating alert rules..."

        $rules = Get-Content $script:ModuleConfig.RulesPath -Raw | ConvertFrom-Json
        $triggeredAlerts = @()

        foreach ($rule in $rules.Rules) {
            if (-not $rule.Enabled) { continue }

            try {
                $triggered = Test-RuleConditions -Rule $rule -MarketData $MarketData

                if ($triggered) {
                    Write-Verbose "Rule triggered: $($rule.Name)"

                    # Create alert from rule
                    $alert = New-SmartAlert -Type ([AlertType]$rule.Type) `
                        -Title "Rule Alert: $($rule.Name)" `
                        -Message "Alert condition met for $($rule.Name)" `
                        -Priority ([AlertPriority]$rule.Priority) `
                        -Data @{ RuleId = $rule.RuleId; Conditions = $rule.Conditions }

                    if ($alert) {
                        $triggeredAlerts += $alert

                        # Update rule stats
                        $rule.TriggeredCount++
                        $rule.LastTriggered = (Get-Date).ToString('o')
                    }
                }
            }
            catch {
                Write-Warning "Error evaluating rule $($rule.Name): $_"
            }
        }

        # Save updated rules
        $rules | ConvertTo-Json -Depth 10 | Set-Content $script:ModuleConfig.RulesPath

        Write-Verbose "Triggered $($triggeredAlerts.Count) alerts"
        return $triggeredAlerts
    }
    catch {
        Write-Error "Failed to test alert rules: $_"
        return @()
    }
}

function Get-AlertStatistics {
    <#
    .SYNOPSIS
        Gets alert statistics and metrics
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$DaysBack = 7
    )

    try {
        $alertFiles = Get-ChildItem -Path $script:ModuleConfig.AlertsPath -Filter "*.json"

        $cutoffDate = (Get-Date).AddDays(-$DaysBack)
        $alerts = @()

        foreach ($file in $alertFiles) {
            $alert = Get-Content $file.FullName -Raw | ConvertFrom-Json

            $createdAt = [DateTime]::Parse($alert.CreatedAt)
            if ($createdAt -ge $cutoffDate) {
                $alerts += $alert
            }
        }

        $stats = @{
            TotalAlerts = $alerts.Count
            ByType = @{}
            ByPriority = @{}
            AverageMLScore = if ($alerts.Count -gt 0) {
                ($alerts | Measure-Object -Property MLScore -Average).Average
            } else { 0 }
            ThrottledCount = Get-ThrottledCount -DaysBack $DaysBack
            FilteredCount = Get-FilteredCount -DaysBack $DaysBack
        }

        # Group by type
        foreach ($type in [Enum]::GetValues([AlertType])) {
            $count = ($alerts | Where-Object { $_.Type -eq $type.ToString() }).Count
            $stats.ByType[$type.ToString()] = $count
        }

        # Group by priority
        foreach ($priority in [Enum]::GetValues([AlertPriority])) {
            $count = ($alerts | Where-Object { $_.Priority -eq $priority.ToString() }).Count
            $stats.ByPriority[$priority.ToString()] = $count
        }

        return $stats
    }
    catch {
        Write-Error "Failed to get alert statistics: $_"
        return @{}
    }
}

#endregion

#region Helper Functions

function Get-AlertFingerprint {
    param($Type, $Title, $AssetSymbol)

    $data = "$Type|$Title|$AssetSymbol"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($data)
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $hasher.ComputeHash($bytes)
    return [BitConverter]::ToString($hashBytes).Replace('-', '').ToLower()
}

function Test-DuplicateAlert {
    param($Fingerprint)

    $trackFile = Join-Path $script:ModuleConfig.ThrottlePath "fingerprints.json"

    if (Test-Path $trackFile) {
        $tracker = Get-Content $trackFile -Raw | ConvertFrom-Json

        foreach ($entry in $tracker.Fingerprints) {
            if ($entry.Fingerprint -eq $Fingerprint) {
                $age = ((Get-Date) - [DateTime]::Parse($entry.Timestamp)).TotalMinutes
                $windowMinutes = 15  # Duplicate window

                if ($age -lt $windowMinutes) {
                    return $true
                }
            }
        }
    }

    return $false
}

function Save-AlertFingerprint {
    param($Fingerprint)

    $trackFile = Join-Path $script:ModuleConfig.ThrottlePath "fingerprints.json"

    $tracker = if (Test-Path $trackFile) {
        Get-Content $trackFile -Raw | ConvertFrom-Json
    } else {
        @{ Fingerprints = @() }
    }

    $tracker.Fingerprints += @{
        Fingerprint = $Fingerprint
        Timestamp = (Get-Date).ToString('o')
    }

    # Keep only last 1000 fingerprints
    if ($tracker.Fingerprints.Count -gt 1000) {
        $tracker.Fingerprints = $tracker.Fingerprints[-1000..-1]
    }

    $tracker | ConvertTo-Json -Depth 10 | Set-Content $trackFile
}

function Test-AlertThrottled {
    param($Type, $Priority, $UserId)

    $throttleSeconds = $script:ModuleConfig.DefaultThrottling[$Priority.ToString()]

    if ($throttleSeconds -eq 0) {
        return $false  # No throttling for this priority
    }

    $trackFile = Join-Path $script:ModuleConfig.ThrottlePath "throttle-$Type.json"

    if (Test-Path $trackFile) {
        $tracker = Get-Content $trackFile -Raw | ConvertFrom-Json

        $lastAlert = $tracker.LastAlert
        if ($lastAlert) {
            $age = ((Get-Date) - [DateTime]::Parse($lastAlert)).TotalSeconds

            if ($age -lt $throttleSeconds) {
                return $true
            }
        }
    }

    return $false
}

function Update-ThrottleTracker {
    param($Type, $Priority, $UserId)

    $trackFile = Join-Path $script:ModuleConfig.ThrottlePath "throttle-$Type.json"

    @{
        Type = $Type.ToString()
        LastAlert = (Get-Date).ToString('o')
        Priority = $Priority.ToString()
    } | ConvertTo-Json | Set-Content $trackFile
}

function Get-MLImportanceScore {
    param($Alert)

    # Simulate ML scoring
    # In production, would use trained ML model

    $score = 0.5  # Base score

    # Adjust based on priority
    $score += $Alert.Priority.value__ * 0.1

    # Adjust based on type
    if ($Alert.Type -in @('Security', 'Signal')) {
        $score += 0.2
    }

    # Randomize slightly for simulation
    $score += (Get-Random -Minimum -0.1 -Maximum 0.1)

    return [Math]::Max(0, [Math]::Min(1, $score))
}

function Test-RuleConditions {
    param($Rule, $MarketData)

    # Simulate condition testing
    # In production, would evaluate actual conditions

    return (Get-Random -Minimum 1 -Maximum 100) -gt 90  # 10% trigger rate
}

function Get-ThrottledCount {
    param($DaysBack)

    # Would track throttled alerts in production
    return Get-Random -Minimum 10 -Maximum 100
}

function Get-FilteredCount {
    param($DaysBack)

    # Would track filtered alerts in production
    return Get-Random -Minimum 20 -Maximum 200
}

#endregion

# Initialize on module load
Initialize-SmartAlertEngine | Out-Null

# Export public functions
Export-ModuleMember -Function @(
    'Initialize-SmartAlertEngine',
    'New-SmartAlert',
    'Set-AlertRule',
    'Test-AlertRules',
    'Get-AlertStatistics'
)
