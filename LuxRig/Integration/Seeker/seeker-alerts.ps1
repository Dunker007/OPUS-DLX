<#
.SYNOPSIS
    Seeker Device Alert System
.DESCRIPTION
    Push notifications for Solana Seeker device including price alerts,
    trade signals, portfolio updates, and security notifications.
.NOTES
    Version: 1.0.0
    Author: LuxRig Enterprise Team
    Requires: PowerShell 7.0+
#>

using namespace System.Collections.Generic

#region Module Configuration

$script:ModuleConfig = @{
    AlertsPath = "$PSScriptRoot/../../../Data/Seeker/Alerts"
    HistoryPath = "$PSScriptRoot/../../../Data/Seeker/AlertHistory"
    PreferencesPath = "$PSScriptRoot/../../../Data/Seeker/Preferences"
}

enum AlertType {
    PriceAlert
    TradeSignal
    PortfolioUpdate
    SecurityWarning
    SystemNotification
    MarketUpdate
    AirdropAlert
}

enum AlertPriority {
    Low
    Medium
    High
    Critical
}

#endregion

#region Core Functions

function Initialize-SeekerAlerts {
    <#
    .SYNOPSIS
        Initializes the Seeker alerts system
    #>
    [CmdletBinding()]
    param()

    try {
        Write-Verbose "Initializing Seeker Alerts..."

        $directories = @(
            $script:ModuleConfig.AlertsPath,
            $script:ModuleConfig.HistoryPath,
            $script:ModuleConfig.PreferencesPath
        )

        foreach ($dir in $directories) {
            if (-not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
        }

        Write-Verbose "Seeker Alerts initialized successfully"
        return $true
    }
    catch {
        Write-Error "Failed to initialize Seeker Alerts: $_"
        return $false
    }
}

function Send-SeekerAlert {
    <#
    .SYNOPSIS
        Sends push notification to Seeker device
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DeviceId,

        [Parameter(Mandatory = $true)]
        [AlertType]$Type,

        [Parameter(Mandatory = $true)]
        [string]$Title,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [AlertPriority]$Priority = [AlertPriority]::Medium,

        [Parameter(Mandatory = $false)]
        [hashtable]$Data = @{},

        [Parameter(Mandatory = $false)]
        [string]$ActionUrl = ""
    )

    try {
        Write-Verbose "Sending alert to device: $DeviceId"

        # Check user preferences
        $prefs = Get-AlertPreferences -DeviceId $DeviceId
        if (-not (Test-AlertEnabled -Preferences $prefs -Type $Type -Priority $Priority)) {
            Write-Verbose "Alert blocked by user preferences"
            return $false
        }

        # Create alert
        $alertId = [guid]::NewGuid().ToString()
        $alert = @{
            AlertId = $alertId
            DeviceId = $DeviceId
            Type = $Type.ToString()
            Title = $Title
            Message = $Message
            Priority = $Priority.ToString()
            Data = $Data
            ActionUrl = $ActionUrl
            CreatedAt = (Get-Date).ToString('o')
            DeliveredAt = $null
            ReadAt = $null
            Status = "Pending"
        }

        # Save alert
        $alertFile = Join-Path $script:ModuleConfig.AlertsPath "$alertId.json"
        $alert | ConvertTo-Json -Depth 10 | Set-Content $alertFile

        # Send to device (simulated)
        $delivered = Invoke-PushNotification -Alert $alert

        if ($delivered) {
            $alert.Status = "Delivered"
            $alert.DeliveredAt = (Get-Date).ToString('o')
            $alert | ConvertTo-Json -Depth 10 | Set-Content $alertFile
        }

        # Archive to history
        Save-AlertHistory -Alert $alert

        Write-Verbose "Alert sent successfully: $alertId"
        return $alert
    }
    catch {
        Write-Error "Failed to send alert: $_"
        return $null
    }
}

function New-PriceAlert {
    <#
    .SYNOPSIS
        Creates a price alert for specific asset
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DeviceId,

        [Parameter(Mandatory = $true)]
        [string]$Asset,

        [Parameter(Mandatory = $true)]
        [decimal]$TargetPrice,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Above', 'Below')]
        [string]$Condition,

        [Parameter(Mandatory = $false)]
        [decimal]$CurrentPrice = 0
    )

    try {
        $conditionMet = if ($Condition -eq 'Above') {
            $CurrentPrice -ge $TargetPrice
        } else {
            $CurrentPrice -le $TargetPrice
        }

        if ($conditionMet) {
            $message = "$Asset has reached $CurrentPrice (target: $TargetPrice $Condition)"

            return Send-SeekerAlert -DeviceId $DeviceId -Type PriceAlert `
                -Title "Price Alert: $Asset" -Message $message `
                -Priority High -Data @{
                    Asset = $Asset
                    CurrentPrice = $CurrentPrice
                    TargetPrice = $TargetPrice
                    Condition = $Condition
                }
        }

        return $null
    }
    catch {
        Write-Error "Failed to create price alert: $_"
        return $null
    }
}

function New-TradeSignalAlert {
    <#
    .SYNOPSIS
        Sends trade signal notification
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DeviceId,

        [Parameter(Mandatory = $true)]
        [string]$Asset,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Buy', 'Sell', 'Hold')]
        [string]$Signal,

        [Parameter(Mandatory = $false)]
        [decimal]$Confidence = 0,

        [Parameter(Mandatory = $false)]
        [string]$Reason = ""
    )

    try {
        $emoji = switch ($Signal) {
            'Buy' { '🟢' }
            'Sell' { '🔴' }
            'Hold' { '🟡' }
        }

        $title = "$emoji $Signal Signal: $Asset"
        $message = "Confidence: $($Confidence)%"
        if ($Reason) {
            $message += "`n$Reason"
        }

        return Send-SeekerAlert -DeviceId $DeviceId -Type TradeSignal `
            -Title $title -Message $message -Priority High -Data @{
                Asset = $Asset
                Signal = $Signal
                Confidence = $Confidence
                Reason = $Reason
            }
    }
    catch {
        Write-Error "Failed to send trade signal alert: $_"
        return $null
    }
}

function New-PortfolioAlert {
    <#
    .SYNOPSIS
        Sends portfolio update notification
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DeviceId,

        [Parameter(Mandatory = $true)]
        [decimal]$TotalValue,

        [Parameter(Mandatory = $true)]
        [decimal]$Change24h,

        [Parameter(Mandatory = $false)]
        [hashtable]$TopGainers = @{},

        [Parameter(Mandatory = $false)]
        [hashtable]$TopLosers = @{}
    )

    try {
        $changePercent = [Math]::Round($Change24h, 2)
        $emoji = if ($changePercent -gt 0) { '📈' } else { '📉' }

        $title = "$emoji Portfolio Update"
        $message = "Total: `$$TotalValue`n24h Change: $changePercent%"

        return Send-SeekerAlert -DeviceId $DeviceId -Type PortfolioUpdate `
            -Title $title -Message $message -Priority Medium -Data @{
                TotalValue = $TotalValue
                Change24h = $Change24h
                TopGainers = $TopGainers
                TopLosers = $TopLosers
            }
    }
    catch {
        Write-Error "Failed to send portfolio alert: $_"
        return $null
    }
}

function New-SecurityAlert {
    <#
    .SYNOPSIS
        Sends security warning notification
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DeviceId,

        [Parameter(Mandatory = $true)]
        [string]$Threat,

        [Parameter(Mandatory = $true)]
        [string]$Description,

        [Parameter(Mandatory = $false)]
        [string]$RecommendedAction = ""
    )

    try {
        $title = "⚠️ Security Alert: $Threat"
        $message = $Description
        if ($RecommendedAction) {
            $message += "`n`nRecommended: $RecommendedAction"
        }

        return Send-SeekerAlert -DeviceId $DeviceId -Type SecurityWarning `
            -Title $title -Message $message -Priority Critical -Data @{
                Threat = $Threat
                Description = $Description
                RecommendedAction = $RecommendedAction
            }
    }
    catch {
        Write-Error "Failed to send security alert: $_"
        return $null
    }
}

function Set-AlertPreferences {
    <#
    .SYNOPSIS
        Sets alert preferences for a device
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DeviceId,

        [Parameter(Mandatory = $false)]
        [hashtable]$EnabledTypes = @{},

        [Parameter(Mandatory = $false)]
        [ValidateSet('Low', 'Medium', 'High', 'Critical')]
        [string]$MinimumPriority = 'Low',

        [Parameter(Mandatory = $false)]
        [bool]$QuietHoursEnabled = $false,

        [Parameter(Mandatory = $false)]
        [int]$QuietHoursStart = 22,

        [Parameter(Mandatory = $false)]
        [int]$QuietHoursEnd = 7
    )

    try {
        Write-Verbose "Setting alert preferences for device: $DeviceId"

        $preferences = @{
            DeviceId = $DeviceId
            EnabledTypes = if ($EnabledTypes.Count -gt 0) {
                $EnabledTypes
            } else {
                @{
                    PriceAlert = $true
                    TradeSignal = $true
                    PortfolioUpdate = $true
                    SecurityWarning = $true
                    SystemNotification = $true
                    MarketUpdate = $false
                    AirdropAlert = $true
                }
            }
            MinimumPriority = $MinimumPriority
            QuietHours = @{
                Enabled = $QuietHoursEnabled
                Start = $QuietHoursStart
                End = $QuietHoursEnd
            }
            UpdatedAt = (Get-Date).ToString('o')
        }

        $prefsFile = Join-Path $script:ModuleConfig.PreferencesPath "$DeviceId-prefs.json"
        $preferences | ConvertTo-Json -Depth 10 | Set-Content $prefsFile

        Write-Verbose "Alert preferences updated successfully"
        return $preferences
    }
    catch {
        Write-Error "Failed to set alert preferences: $_"
        return $null
    }
}

function Get-AlertPreferences {
    <#
    .SYNOPSIS
        Retrieves alert preferences for a device
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DeviceId
    )

    try {
        $prefsFile = Join-Path $script:ModuleConfig.PreferencesPath "$DeviceId-prefs.json"

        if (Test-Path $prefsFile) {
            return Get-Content $prefsFile -Raw | ConvertFrom-Json
        }

        # Return defaults if no preferences set
        return @{
            DeviceId = $DeviceId
            EnabledTypes = @{
                PriceAlert = $true
                TradeSignal = $true
                PortfolioUpdate = $true
                SecurityWarning = $true
                SystemNotification = $true
                MarketUpdate = $false
                AirdropAlert = $true
            }
            MinimumPriority = 'Low'
            QuietHours = @{
                Enabled = $false
                Start = 22
                End = 7
            }
        }
    }
    catch {
        Write-Error "Failed to get alert preferences: $_"
        return $null
    }
}

function Get-AlertHistory {
    <#
    .SYNOPSIS
        Retrieves alert history for a device
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DeviceId,

        [Parameter(Mandatory = $false)]
        [int]$DaysBack = 7,

        [Parameter(Mandatory = $false)]
        [AlertType]$FilterType
    )

    try {
        $historyFile = Join-Path $script:ModuleConfig.HistoryPath "$DeviceId-history.json"

        if (-not (Test-Path $historyFile)) {
            return @()
        }

        $history = Get-Content $historyFile -Raw | ConvertFrom-Json

        # Filter by date
        $cutoffDate = (Get-Date).AddDays(-$DaysBack)
        $filtered = $history | Where-Object {
            [DateTime]::Parse($_.CreatedAt) -ge $cutoffDate
        }

        # Filter by type if specified
        if ($FilterType) {
            $filtered = $filtered | Where-Object { $_.Type -eq $FilterType.ToString() }
        }

        return $filtered
    }
    catch {
        Write-Error "Failed to get alert history: $_"
        return @()
    }
}

#endregion

#region Helper Functions

function Test-AlertEnabled {
    param($Preferences, $Type, $Priority)

    # Check if type is enabled
    if (-not $Preferences.EnabledTypes.$($Type.ToString())) {
        return $false
    }

    # Check priority
    $priorityLevels = @('Low', 'Medium', 'High', 'Critical')
    $minIndex = $priorityLevels.IndexOf($Preferences.MinimumPriority)
    $currentIndex = $priorityLevels.IndexOf($Priority.ToString())

    if ($currentIndex -lt $minIndex) {
        return $false
    }

    # Check quiet hours
    if ($Preferences.QuietHours.Enabled) {
        $currentHour = (Get-Date).Hour
        $start = $Preferences.QuietHours.Start
        $end = $Preferences.QuietHours.End

        if ($start -gt $end) {
            # Quiet hours span midnight
            if ($currentHour -ge $start -or $currentHour -lt $end) {
                return $false
            }
        } else {
            if ($currentHour -ge $start -and $currentHour -lt $end) {
                return $false
            }
        }
    }

    return $true
}

function Invoke-PushNotification {
    param($Alert)

    # Simulate push notification delivery
    # In production, this would call Seeker notification API

    Write-Verbose "Delivering push notification: $($Alert.Title)"

    # Simulate 95% success rate
    $success = (Get-Random -Minimum 1 -Maximum 100) -le 95

    if ($success) {
        Write-Verbose "Push notification delivered successfully"
    } else {
        Write-Warning "Push notification delivery failed"
    }

    return $success
}

function Save-AlertHistory {
    param($Alert)

    try {
        $historyFile = Join-Path $script:ModuleConfig.HistoryPath "$($Alert.DeviceId)-history.json"

        $history = if (Test-Path $historyFile) {
            Get-Content $historyFile -Raw | ConvertFrom-Json
        } else {
            @()
        }

        # Add alert to history
        $history += $Alert

        # Keep only last 1000 alerts
        if ($history.Count -gt 1000) {
            $history = $history[-1000..-1]
        }

        $history | ConvertTo-Json -Depth 10 | Set-Content $historyFile
    }
    catch {
        Write-Warning "Failed to save alert history: $_"
    }
}

#endregion

# Initialize on module load
Initialize-SeekerAlerts | Out-Null

# Export public functions
Export-ModuleMember -Function @(
    'Initialize-SeekerAlerts',
    'Send-SeekerAlert',
    'New-PriceAlert',
    'New-TradeSignalAlert',
    'New-PortfolioAlert',
    'New-SecurityAlert',
    'Set-AlertPreferences',
    'Get-AlertPreferences',
    'Get-AlertHistory'
)
