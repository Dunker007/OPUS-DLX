<#
.SYNOPSIS
    Multi-Tenant Management System for LuxRig Enterprise
.DESCRIPTION
    Complete multi-tenant architecture with isolated data, separate configurations,
    per-tenant billing, resource allocation, and tenant lifecycle management.
.NOTES
    Version: 1.0.0
    Author: LuxRig Enterprise Team
    Requires: PowerShell 7.0+
#>

using namespace System.Collections.Generic

#region Module Configuration

$script:ModuleConfig = @{
    TenantsPath = "$PSScriptRoot/../../../Configs/tenants.json"
    TenantDataRoot = "$PSScriptRoot/../../../Data/Tenants"
    BillingPath = "$PSScriptRoot/../../../Configs/billing.json"
    ResourcePoolPath = "$PSScriptRoot/../../../Configs/resource-pools.json"
}

# Tenant Status Types
enum TenantStatus {
    Active
    Suspended
    Trial
    Canceled
    PendingActivation
}

#endregion

#region Core Functions

function Initialize-TenantManager {
    <#
    .SYNOPSIS
        Initializes the multi-tenant management system
    #>
    [CmdletBinding()]
    param()

    try {
        Write-Verbose "Initializing Tenant Manager..."

        # Create required directories
        $directories = @(
            (Split-Path -Parent $script:ModuleConfig.TenantsPath),
            $script:ModuleConfig.TenantDataRoot
        )

        foreach ($dir in $directories) {
            if (-not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
        }

        # Initialize tenant registry
        if (-not (Test-Path $script:ModuleConfig.TenantsPath)) {
            $registry = @{
                Version = "1.0.0"
                LastUpdated = (Get-Date).ToString('o')
                Tenants = @{}
            }
            $registry | ConvertTo-Json -Depth 10 | Set-Content $script:ModuleConfig.TenantsPath
        }

        # Initialize billing system
        if (-not (Test-Path $script:ModuleConfig.BillingPath)) {
            $billing = @{
                Version = "1.0.0"
                LastUpdated = (Get-Date).ToString('o')
                BillingCycles = @{}
                Invoices = @()
            }
            $billing | ConvertTo-Json -Depth 10 | Set-Content $script:ModuleConfig.BillingPath
        }

        # Initialize resource pools
        if (-not (Test-Path $script:ModuleConfig.ResourcePoolPath)) {
            $pools = @{
                CPU = @{
                    Total = 100
                    Allocated = 0
                    Available = 100
                }
                Memory = @{
                    Total = 256  # GB
                    Allocated = 0
                    Available = 256
                }
                Storage = @{
                    Total = 10240  # GB
                    Allocated = 0
                    Available = 10240
                }
            }
            $pools | ConvertTo-Json -Depth 10 | Set-Content $script:ModuleConfig.ResourcePoolPath
        }

        Write-Verbose "Tenant Manager initialized successfully"
        return $true
    }
    catch {
        Write-Error "Failed to initialize Tenant Manager: $_"
        return $false
    }
}

function New-Tenant {
    <#
    .SYNOPSIS
        Creates a new tenant with isolated configuration
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantName,

        [Parameter(Mandatory = $true)]
        [string]$AdminEmail,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Basic', 'Pro', 'Enterprise')]
        [string]$Tier,

        [Parameter(Mandatory = $false)]
        [string]$CompanyName = "",

        [Parameter(Mandatory = $false)]
        [int]$TrialDays = 0,

        [Parameter(Mandatory = $false)]
        [hashtable]$CustomConfig = @{}
    )

    try {
        Write-Verbose "Creating new tenant: $TenantName"

        # Generate unique tenant ID
        $tenantId = New-TenantId -TenantName $TenantName

        # Load registry
        $registry = Get-Content $script:ModuleConfig.TenantsPath -Raw | ConvertFrom-Json

        # Check for duplicate
        if ($registry.Tenants.PSObject.Properties.Name -contains $tenantId) {
            throw "Tenant ID already exists: $tenantId"
        }

        # Create tenant data structure
        $tenant = @{
            TenantId = $tenantId
            TenantName = $TenantName
            CompanyName = $CompanyName
            AdminEmail = $AdminEmail
            Tier = $Tier
            Status = if ($TrialDays -gt 0) { "Trial" } else { "Active" }
            CreatedAt = (Get-Date).ToString('o')
            TrialEndsAt = if ($TrialDays -gt 0) { (Get-Date).AddDays($TrialDays).ToString('o') } else { $null }
            LastAccessAt = (Get-Date).ToString('o')
            Configuration = $CustomConfig
            Resources = @{
                CPUUnits = Get-TierResourceAllocation -Tier $Tier -ResourceType 'CPU'
                MemoryGB = Get-TierResourceAllocation -Tier $Tier -ResourceType 'Memory'
                StorageGB = Get-TierResourceAllocation -Tier $Tier -ResourceType 'Storage'
            }
            Billing = @{
                CurrentPlan = $Tier
                BillingCycle = "Monthly"
                NextBillingDate = (Get-Date).AddMonths(1).ToString('o')
                PaymentMethod = $null
            }
            Metadata = @{
                TotalUsers = 0
                TotalStrategies = 0
                TotalTrades = 0
                DataSizeGB = 0
            }
        }

        # Allocate resources
        if (-not (Grant-TenantResources -TenantId $tenantId -Resources $tenant.Resources)) {
            throw "Failed to allocate resources for tenant"
        }

        # Create tenant data directory
        $tenantDir = Join-Path $script:ModuleConfig.TenantDataRoot $tenantId
        New-Item -ItemType Directory -Path $tenantDir -Force | Out-Null

        # Create isolated subdirectories
        $subdirs = @('Configs', 'Data', 'Logs', 'Backups', 'Strategies', 'Analytics')
        foreach ($subdir in $subdirs) {
            $path = Join-Path $tenantDir $subdir
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }

        # Initialize tenant-specific config
        $tenantConfig = @{
            TenantId = $tenantId
            Features = Get-TierFeatures -Tier $Tier
            Limits = Get-TierLimits -Tier $Tier
            Integrations = @{}
            CustomSettings = $CustomConfig
        }

        $configPath = Join-Path $tenantDir "Configs/tenant-config.json"
        $tenantConfig | ConvertTo-Json -Depth 10 | Set-Content $configPath

        # Add to registry
        $registry.Tenants | Add-Member -NotePropertyName $tenantId -NotePropertyValue $tenant -Force
        $registry.LastUpdated = (Get-Date).ToString('o')
        $registry | ConvertTo-Json -Depth 10 | Set-Content $script:ModuleConfig.TenantsPath

        # Create billing cycle
        Initialize-TenantBilling -TenantId $tenantId -Tier $Tier

        Write-Verbose "Tenant created successfully: $tenantId"

        return [PSCustomObject]@{
            TenantId = $tenantId
            TenantName = $TenantName
            Status = $tenant.Status
            Tier = $Tier
            DataDirectory = $tenantDir
        }
    }
    catch {
        Write-Error "Failed to create tenant: $_"
        return $null
    }
}

function Get-Tenant {
    <#
    .SYNOPSIS
        Retrieves tenant information
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$TenantId,

        [Parameter(Mandatory = $false)]
        [string]$TenantName
    )

    try {
        $registry = Get-Content $script:ModuleConfig.TenantsPath -Raw | ConvertFrom-Json

        if ($TenantId) {
            if ($registry.Tenants.PSObject.Properties.Name -contains $TenantId) {
                return $registry.Tenants.$TenantId
            }
        }
        elseif ($TenantName) {
            foreach ($prop in $registry.Tenants.PSObject.Properties) {
                if ($prop.Value.TenantName -eq $TenantName) {
                    return $prop.Value
                }
            }
        }
        else {
            # Return all tenants
            return $registry.Tenants
        }

        return $null
    }
    catch {
        Write-Error "Failed to get tenant: $_"
        return $null
    }
}

function Update-Tenant {
    <#
    .SYNOPSIS
        Updates tenant configuration
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Basic', 'Pro', 'Enterprise')]
        [string]$NewTier,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Active', 'Suspended', 'Trial', 'Canceled', 'PendingActivation')]
        [string]$NewStatus,

        [Parameter(Mandatory = $false)]
        [hashtable]$UpdatedConfig
    )

    try {
        Write-Verbose "Updating tenant: $TenantId"

        $registry = Get-Content $script:ModuleConfig.TenantsPath -Raw | ConvertFrom-Json

        if (-not $registry.Tenants.PSObject.Properties.Name -contains $TenantId) {
            throw "Tenant not found: $TenantId"
        }

        $tenant = $registry.Tenants.$TenantId

        # Update tier (with resource reallocation)
        if ($NewTier -and $NewTier -ne $tenant.Tier) {
            $oldResources = $tenant.Resources

            # Deallocate old resources
            Revoke-TenantResources -TenantId $TenantId -Resources $oldResources | Out-Null

            # Allocate new resources
            $newResources = @{
                CPUUnits = Get-TierResourceAllocation -Tier $NewTier -ResourceType 'CPU'
                MemoryGB = Get-TierResourceAllocation -Tier $NewTier -ResourceType 'Memory'
                StorageGB = Get-TierResourceAllocation -Tier $NewTier -ResourceType 'Storage'
            }

            if (Grant-TenantResources -TenantId $TenantId -Resources $newResources) {
                $tenant.Tier = $NewTier
                $tenant.Resources = $newResources
                $tenant.Billing.CurrentPlan = $NewTier

                # Update billing
                Update-TenantBilling -TenantId $TenantId -NewTier $NewTier
            }
        }

        # Update status
        if ($NewStatus) {
            $tenant.Status = $NewStatus
        }

        # Update custom configuration
        if ($UpdatedConfig) {
            foreach ($key in $UpdatedConfig.Keys) {
                $tenant.Configuration[$key] = $UpdatedConfig[$key]
            }
        }

        $tenant.LastUpdated = (Get-Date).ToString('o')
        $registry.LastUpdated = (Get-Date).ToString('o')

        $registry | ConvertTo-Json -Depth 10 | Set-Content $script:ModuleConfig.TenantsPath

        Write-Verbose "Tenant updated successfully"
        return $true
    }
    catch {
        Write-Error "Failed to update tenant: $_"
        return $false
    }
}

function Remove-Tenant {
    <#
    .SYNOPSIS
        Removes a tenant and all associated data
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $false)]
        [switch]$KeepBackup
    )

    try {
        if ($PSCmdlet.ShouldProcess($TenantId, "Remove tenant")) {
            Write-Verbose "Removing tenant: $TenantId"

            $registry = Get-Content $script:ModuleConfig.TenantsPath -Raw | ConvertFrom-Json

            if (-not $registry.Tenants.PSObject.Properties.Name -contains $TenantId) {
                throw "Tenant not found: $TenantId"
            }

            $tenant = $registry.Tenants.$TenantId

            # Create backup if requested
            if ($KeepBackup) {
                $backupPath = "$($script:ModuleConfig.TenantDataRoot)/_backups/$TenantId-$(Get-Date -Format 'yyyyMMdd-HHmmss').zip"
                $tenantDir = Join-Path $script:ModuleConfig.TenantDataRoot $TenantId

                if (Test-Path $tenantDir) {
                    $backupDir = Split-Path -Parent $backupPath
                    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
                    Compress-Archive -Path $tenantDir -DestinationPath $backupPath -Force
                }
            }

            # Revoke resources
            Revoke-TenantResources -TenantId $TenantId -Resources $tenant.Resources | Out-Null

            # Remove data directory
            $tenantDir = Join-Path $script:ModuleConfig.TenantDataRoot $TenantId
            if (Test-Path $tenantDir) {
                Remove-Item -Path $tenantDir -Recurse -Force
            }

            # Remove from registry
            $registry.Tenants.PSObject.Properties.Remove($TenantId)
            $registry.LastUpdated = (Get-Date).ToString('o')
            $registry | ConvertTo-Json -Depth 10 | Set-Content $script:ModuleConfig.TenantsPath

            Write-Verbose "Tenant removed successfully"
            return $true
        }
    }
    catch {
        Write-Error "Failed to remove tenant: $_"
        return $false
    }
}

function Get-TenantDataPath {
    <#
    .SYNOPSIS
        Returns the isolated data path for a tenant
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $false)]
        [string]$Subdirectory = ""
    )

    $basePath = Join-Path $script:ModuleConfig.TenantDataRoot $TenantId

    if ($Subdirectory) {
        return Join-Path $basePath $Subdirectory
    }

    return $basePath
}

function Initialize-TenantBilling {
    <#
    .SYNOPSIS
        Initializes billing for a new tenant
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [string]$Tier
    )

    try {
        $billing = Get-Content $script:ModuleConfig.BillingPath -Raw | ConvertFrom-Json

        $billingCycle = @{
            TenantId = $TenantId
            Plan = $Tier
            StartDate = (Get-Date).ToString('o')
            NextBillingDate = (Get-Date).AddMonths(1).ToString('o')
            Amount = Get-TierPrice -Tier $Tier
            Status = "Active"
            PaymentHistory = @()
        }

        $billing.BillingCycles | Add-Member -NotePropertyName $TenantId -NotePropertyValue $billingCycle -Force
        $billing.LastUpdated = (Get-Date).ToString('o')

        $billing | ConvertTo-Json -Depth 10 | Set-Content $script:ModuleConfig.BillingPath

        return $true
    }
    catch {
        Write-Error "Failed to initialize tenant billing: $_"
        return $false
    }
}

function Update-TenantBilling {
    <#
    .SYNOPSIS
        Updates billing information for tier change
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [string]$NewTier
    )

    try {
        $billing = Get-Content $script:ModuleConfig.BillingPath -Raw | ConvertFrom-Json

        if ($billing.BillingCycles.PSObject.Properties.Name -contains $TenantId) {
            $cycle = $billing.BillingCycles.$TenantId
            $cycle.Plan = $NewTier
            $cycle.Amount = Get-TierPrice -Tier $NewTier
            $cycle.UpdatedAt = (Get-Date).ToString('o')

            $billing.LastUpdated = (Get-Date).ToString('o')
            $billing | ConvertTo-Json -Depth 10 | Set-Content $script:ModuleConfig.BillingPath
        }

        return $true
    }
    catch {
        Write-Error "Failed to update tenant billing: $_"
        return $false
    }
}

#endregion

#region Resource Management

function Grant-TenantResources {
    <#
    .SYNOPSIS
        Allocates resources from the pool to a tenant
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [hashtable]$Resources
    )

    try {
        $pools = Get-Content $script:ModuleConfig.ResourcePoolPath -Raw | ConvertFrom-Json

        # Check availability
        if ($pools.CPU.Available -lt $Resources.CPUUnits -or
            $pools.Memory.Available -lt $Resources.MemoryGB -or
            $pools.Storage.Available -lt $Resources.StorageGB) {
            Write-Warning "Insufficient resources available"
            return $false
        }

        # Allocate
        $pools.CPU.Allocated += $Resources.CPUUnits
        $pools.CPU.Available -= $Resources.CPUUnits
        $pools.Memory.Allocated += $Resources.MemoryGB
        $pools.Memory.Available -= $Resources.MemoryGB
        $pools.Storage.Allocated += $Resources.StorageGB
        $pools.Storage.Available -= $Resources.StorageGB

        $pools | ConvertTo-Json -Depth 10 | Set-Content $script:ModuleConfig.ResourcePoolPath

        return $true
    }
    catch {
        Write-Error "Failed to grant tenant resources: $_"
        return $false
    }
}

function Revoke-TenantResources {
    <#
    .SYNOPSIS
        Returns resources from tenant back to pool
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [hashtable]$Resources
    )

    try {
        $pools = Get-Content $script:ModuleConfig.ResourcePoolPath -Raw | ConvertFrom-Json

        $pools.CPU.Allocated -= $Resources.CPUUnits
        $pools.CPU.Available += $Resources.CPUUnits
        $pools.Memory.Allocated -= $Resources.MemoryGB
        $pools.Memory.Available += $Resources.MemoryGB
        $pools.Storage.Allocated -= $Resources.StorageGB
        $pools.Storage.Available += $Resources.StorageGB

        $pools | ConvertTo-Json -Depth 10 | Set-Content $script:ModuleConfig.ResourcePoolPath

        return $true
    }
    catch {
        Write-Error "Failed to revoke tenant resources: $_"
        return $false
    }
}

#endregion

#region Helper Functions

function New-TenantId {
    param([string]$TenantName)
    $sanitized = $TenantName -replace '[^a-zA-Z0-9]', ''
    $guid = [guid]::NewGuid().ToString('N').Substring(0, 8)
    return "$sanitized-$guid".ToLower()
}

function Get-TierPrice {
    param([string]$Tier)
    $prices = @{ Basic = 0; Pro = 49; Enterprise = 499 }
    return $prices[$Tier]
}

function Get-TierResourceAllocation {
    param([string]$Tier, [string]$ResourceType)
    $allocations = @{
        Basic = @{ CPU = 2; Memory = 4; Storage = 50 }
        Pro = @{ CPU = 8; Memory = 16; Storage = 200 }
        Enterprise = @{ CPU = 32; Memory = 64; Storage = 1000 }
    }
    return $allocations[$Tier][$ResourceType]
}

function Get-TierFeatures {
    param([string]$Tier)
    # This would typically call the feature-toggles module
    return @('basic_features')
}

function Get-TierLimits {
    param([string]$Tier)
    $limits = @{
        Basic = @{ ApiCalls = 1000; Strategies = 3 }
        Pro = @{ ApiCalls = 10000; Strategies = 10 }
        Enterprise = @{ ApiCalls = -1; Strategies = -1 }
    }
    return $limits[$Tier]
}

#endregion

# Initialize on module load
Initialize-TenantManager | Out-Null

# Export public functions
Export-ModuleMember -Function @(
    'Initialize-TenantManager',
    'New-Tenant',
    'Get-Tenant',
    'Update-Tenant',
    'Remove-Tenant',
    'Get-TenantDataPath'
)
