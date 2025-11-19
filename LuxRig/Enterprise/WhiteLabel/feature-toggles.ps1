<#
.SYNOPSIS
    Feature Toggle Management System for LuxRig Enterprise
.DESCRIPTION
    Modular feature control with tiered pricing (Basic/Pro/Enterprise), API access control, and usage limits.
    Provides dynamic feature flags, A/B testing, gradual rollouts, and tenant-specific configurations.
.NOTES
    Version: 1.0.0
    Author: LuxRig Enterprise Team
    Requires: PowerShell 7.0+
#>

using namespace System.Collections.Generic

#region Module Configuration

$script:ModuleConfig = @{
    ConfigPath = "$PSScriptRoot/../../../Configs/feature-toggles.json"
    UsagePath = "$PSScriptRoot/../../../Configs/feature-usage.json"
    CacheDuration = 300 # 5 minutes
    LastCacheUpdate = $null
    CachedToggles = $null
}

# Pricing Tiers Definition
$script:PricingTiers = @{
    Basic = @{
        Price = 0
        Features = @(
            'basic_trading', 'portfolio_tracking', 'basic_alerts',
            'standard_analytics', 'community_support'
        )
        Limits = @{
            ApiCallsPerDay = 1000
            ConcurrentStrategies = 3
            BacktestHistoryDays = 30
            ExchangeConnections = 2
            AlertsPerDay = 50
        }
    }
    Pro = @{
        Price = 49
        Features = @(
            'basic_trading', 'portfolio_tracking', 'basic_alerts',
            'standard_analytics', 'community_support',
            'advanced_strategies', 'ai_signals', 'multi_exchange',
            'custom_alerts', 'priority_support', 'advanced_analytics',
            'copy_trading', 'api_access'
        )
        Limits = @{
            ApiCallsPerDay = 10000
            ConcurrentStrategies = 10
            BacktestHistoryDays = 365
            ExchangeConnections = 5
            AlertsPerDay = 500
        }
    }
    Enterprise = @{
        Price = 499
        Features = @(
            'basic_trading', 'portfolio_tracking', 'basic_alerts',
            'standard_analytics', 'community_support',
            'advanced_strategies', 'ai_signals', 'multi_exchange',
            'custom_alerts', 'priority_support', 'advanced_analytics',
            'copy_trading', 'api_access',
            'white_label', 'custom_branding', 'dedicated_support',
            'sla_guarantee', 'audit_logs', 'compliance_reports',
            'multi_tenant', 'custom_integrations', 'unlimited_backtesting',
            'hedge_fund_tools', 'institutional_api', 'custom_development'
        )
        Limits = @{
            ApiCallsPerDay = -1  # Unlimited
            ConcurrentStrategies = -1
            BacktestHistoryDays = -1
            ExchangeConnections = -1
            AlertsPerDay = -1
        }
    }
}

#endregion

#region Core Functions

function Initialize-FeatureToggleSystem {
    <#
    .SYNOPSIS
        Initializes the feature toggle management system
    #>
    [CmdletBinding()]
    param()

    try {
        Write-Verbose "Initializing Feature Toggle System..."

        # Create config directory if it doesn't exist
        $configDir = Split-Path -Parent $script:ModuleConfig.ConfigPath
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }

        # Initialize config file if it doesn't exist
        if (-not (Test-Path $script:ModuleConfig.ConfigPath)) {
            $defaultConfig = @{
                Version = "1.0.0"
                LastUpdated = (Get-Date).ToString('o')
                GlobalToggles = @{}
                TenantToggles = @{}
                ExperimentalFeatures = @{}
                FeatureRollouts = @{}
            }
            $defaultConfig | ConvertTo-Json -Depth 10 | Set-Content $script:ModuleConfig.ConfigPath
        }

        # Initialize usage tracking
        if (-not (Test-Path $script:ModuleConfig.UsagePath)) {
            $defaultUsage = @{
                LastReset = (Get-Date).ToString('o')
                TenantUsage = @{}
            }
            $defaultUsage | ConvertTo-Json -Depth 10 | Set-Content $script:ModuleConfig.UsagePath
        }

        Write-Verbose "Feature Toggle System initialized successfully"
        return $true
    }
    catch {
        Write-Error "Failed to initialize Feature Toggle System: $_"
        return $false
    }
}

function Get-FeatureToggleConfig {
    <#
    .SYNOPSIS
        Retrieves feature toggle configuration with caching
    #>
    [CmdletBinding()]
    param()

    try {
        $now = Get-Date

        # Check cache validity
        if ($script:ModuleConfig.CachedToggles -and
            $script:ModuleConfig.LastCacheUpdate -and
            ($now - $script:ModuleConfig.LastCacheUpdate).TotalSeconds -lt $script:ModuleConfig.CacheDuration) {
            return $script:ModuleConfig.CachedToggles
        }

        # Load fresh config
        $config = Get-Content $script:ModuleConfig.ConfigPath -Raw | ConvertFrom-Json

        # Update cache
        $script:ModuleConfig.CachedToggles = $config
        $script:ModuleConfig.LastCacheUpdate = $now

        return $config
    }
    catch {
        Write-Error "Failed to load feature toggle config: $_"
        return $null
    }
}

function Test-FeatureEnabled {
    <#
    .SYNOPSIS
        Checks if a feature is enabled for a specific tenant
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FeatureName,

        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $false)]
        [string]$Tier = 'Basic'
    )

    try {
        # Check tier-based access
        if ($script:PricingTiers.ContainsKey($Tier)) {
            $tierFeatures = $script:PricingTiers[$Tier].Features
            if ($tierFeatures -notcontains $FeatureName) {
                Write-Verbose "Feature '$FeatureName' not available in tier '$Tier'"
                return $false
            }
        }

        # Check global toggles
        $config = Get-FeatureToggleConfig
        if ($config.GlobalToggles.PSObject.Properties.Name -contains $FeatureName) {
            $globalToggle = $config.GlobalToggles.$FeatureName
            if ($globalToggle.Enabled -eq $false) {
                Write-Verbose "Feature '$FeatureName' globally disabled"
                return $false
            }
        }

        # Check tenant-specific toggles
        if ($config.TenantToggles.PSObject.Properties.Name -contains $TenantId) {
            $tenantToggles = $config.TenantToggles.$TenantId
            if ($tenantToggles.PSObject.Properties.Name -contains $FeatureName) {
                return $tenantToggles.$FeatureName.Enabled
            }
        }

        # Check experimental features (gradual rollout)
        if ($config.ExperimentalFeatures.PSObject.Properties.Name -contains $FeatureName) {
            $experiment = $config.ExperimentalFeatures.$FeatureName
            $rolloutPercentage = $experiment.RolloutPercentage
            $tenantHash = Get-StringHash -InputString "$TenantId-$FeatureName"
            $assignedPercentage = $tenantHash % 100

            if ($assignedPercentage -lt $rolloutPercentage) {
                Write-Verbose "Feature '$FeatureName' enabled via experimental rollout"
                return $true
            }
            return $false
        }

        # Default: enabled if in tier
        return $true
    }
    catch {
        Write-Error "Failed to check feature status: $_"
        return $false
    }
}

function Set-FeatureToggle {
    <#
    .SYNOPSIS
        Enables or disables a feature globally or for specific tenant
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FeatureName,

        [Parameter(Mandatory = $true)]
        [bool]$Enabled,

        [Parameter(Mandatory = $false)]
        [string]$TenantId,

        [Parameter(Mandatory = $false)]
        [string]$Reason = "Manual toggle"
    )

    try {
        $config = Get-Content $script:ModuleConfig.ConfigPath -Raw | ConvertFrom-Json

        if ($TenantId) {
            # Tenant-specific toggle
            if (-not $config.TenantToggles.PSObject.Properties.Name -contains $TenantId) {
                $config.TenantToggles | Add-Member -NotePropertyName $TenantId -NotePropertyValue @{} -Force
            }

            $toggleData = @{
                Enabled = $Enabled
                Reason = $Reason
                UpdatedAt = (Get-Date).ToString('o')
            }

            $config.TenantToggles.$TenantId | Add-Member -NotePropertyName $FeatureName -NotePropertyValue $toggleData -Force
        }
        else {
            # Global toggle
            $toggleData = @{
                Enabled = $Enabled
                Reason = $Reason
                UpdatedAt = (Get-Date).ToString('o')
            }

            $config.GlobalToggles | Add-Member -NotePropertyName $FeatureName -NotePropertyValue $toggleData -Force
        }

        $config.LastUpdated = (Get-Date).ToString('o')
        $config | ConvertTo-Json -Depth 10 | Set-Content $script:ModuleConfig.ConfigPath

        # Invalidate cache
        $script:ModuleConfig.LastCacheUpdate = $null

        Write-Verbose "Feature toggle updated successfully"
        return $true
    }
    catch {
        Write-Error "Failed to set feature toggle: $_"
        return $false
    }
}

function Test-UsageLimitExceeded {
    <#
    .SYNOPSIS
        Checks if tenant has exceeded usage limits
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [string]$Tier,

        [Parameter(Mandatory = $true)]
        [ValidateSet('ApiCallsPerDay', 'ConcurrentStrategies', 'BacktestHistoryDays', 'ExchangeConnections', 'AlertsPerDay')]
        [string]$LimitType
    )

    try {
        # Get tier limits
        $tierLimits = $script:PricingTiers[$Tier].Limits
        $limit = $tierLimits[$LimitType]

        # Unlimited
        if ($limit -eq -1) {
            return $false
        }

        # Get current usage
        $usage = Get-Content $script:ModuleConfig.UsagePath -Raw | ConvertFrom-Json

        if (-not $usage.TenantUsage.PSObject.Properties.Name -contains $TenantId) {
            return $false
        }

        $tenantUsage = $usage.TenantUsage.$TenantId
        $currentUsage = if ($tenantUsage.PSObject.Properties.Name -contains $LimitType) {
            $tenantUsage.$LimitType
        } else {
            0
        }

        return ($currentUsage -ge $limit)
    }
    catch {
        Write-Error "Failed to check usage limit: $_"
        return $false
    }
}

function Update-UsageCounter {
    <#
    .SYNOPSIS
        Increments usage counter for a tenant
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [ValidateSet('ApiCallsPerDay', 'ConcurrentStrategies', 'BacktestHistoryDays', 'ExchangeConnections', 'AlertsPerDay')]
        [string]$LimitType,

        [Parameter(Mandatory = $false)]
        [int]$Increment = 1
    )

    try {
        $usage = Get-Content $script:ModuleConfig.UsagePath -Raw | ConvertFrom-Json

        # Reset daily counters if needed
        $lastReset = [DateTime]::Parse($usage.LastReset)
        if ((Get-Date).Date -gt $lastReset.Date) {
            $usage.TenantUsage = @{}
            $usage.LastReset = (Get-Date).ToString('o')
        }

        # Initialize tenant usage if needed
        if (-not $usage.TenantUsage.PSObject.Properties.Name -contains $TenantId) {
            $usage.TenantUsage | Add-Member -NotePropertyName $TenantId -NotePropertyValue @{} -Force
        }

        # Increment counter
        $currentValue = if ($usage.TenantUsage.$TenantId.PSObject.Properties.Name -contains $LimitType) {
            $usage.TenantUsage.$TenantId.$LimitType
        } else {
            0
        }

        $usage.TenantUsage.$TenantId | Add-Member -NotePropertyName $LimitType -NotePropertyValue ($currentValue + $Increment) -Force

        $usage | ConvertTo-Json -Depth 10 | Set-Content $script:ModuleConfig.UsagePath

        return $true
    }
    catch {
        Write-Error "Failed to update usage counter: $_"
        return $false
    }
}

function Start-ExperimentalRollout {
    <#
    .SYNOPSIS
        Starts a gradual feature rollout with percentage-based distribution
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FeatureName,

        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 100)]
        [int]$RolloutPercentage,

        [Parameter(Mandatory = $false)]
        [string]$Description = ""
    )

    try {
        $config = Get-Content $script:ModuleConfig.ConfigPath -Raw | ConvertFrom-Json

        $experimentData = @{
            RolloutPercentage = $RolloutPercentage
            Description = $Description
            StartedAt = (Get-Date).ToString('o')
            Status = "Active"
        }

        $config.ExperimentalFeatures | Add-Member -NotePropertyName $FeatureName -NotePropertyValue $experimentData -Force
        $config.LastUpdated = (Get-Date).ToString('o')

        $config | ConvertTo-Json -Depth 10 | Set-Content $script:ModuleConfig.ConfigPath

        # Invalidate cache
        $script:ModuleConfig.LastCacheUpdate = $null

        Write-Verbose "Experimental rollout started for '$FeatureName' at $RolloutPercentage%"
        return $true
    }
    catch {
        Write-Error "Failed to start experimental rollout: $_"
        return $false
    }
}

function Get-TenantFeatures {
    <#
    .SYNOPSIS
        Returns all available features for a tenant based on tier
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Basic', 'Pro', 'Enterprise')]
        [string]$Tier
    )

    try {
        $tierFeatures = $script:PricingTiers[$Tier].Features
        $enabledFeatures = @()

        foreach ($feature in $tierFeatures) {
            if (Test-FeatureEnabled -FeatureName $feature -TenantId $TenantId -Tier $Tier) {
                $enabledFeatures += $feature
            }
        }

        return [PSCustomObject]@{
            TenantId = $TenantId
            Tier = $Tier
            EnabledFeatures = $enabledFeatures
            Limits = $script:PricingTiers[$Tier].Limits
            Price = $script:PricingTiers[$Tier].Price
        }
    }
    catch {
        Write-Error "Failed to get tenant features: $_"
        return $null
    }
}

#endregion

#region Helper Functions

function Get-StringHash {
    <#
    .SYNOPSIS
        Generates a consistent hash for string input (for rollout percentage)
    #>
    param([string]$InputString)

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $hasher.ComputeHash($bytes)

    # Convert first 4 bytes to int
    $hashInt = [BitConverter]::ToInt32($hashBytes, 0)
    return [Math]::Abs($hashInt)
}

#endregion

# Initialize on module load
Initialize-FeatureToggleSystem | Out-Null

# Export public functions
Export-ModuleMember -Function @(
    'Initialize-FeatureToggleSystem',
    'Test-FeatureEnabled',
    'Set-FeatureToggle',
    'Test-UsageLimitExceeded',
    'Update-UsageCounter',
    'Start-ExperimentalRollout',
    'Get-TenantFeatures',
    'Get-FeatureToggleConfig'
)
