#Requires -Version 7.0

<#
.SYNOPSIS
    LuxRig Role-Based Access Control (RBAC) System

.DESCRIPTION
    Enterprise-grade permission system with:
    - Predefined roles (Admin, Manager, Trader, Analyst, Support)
    - Custom role builder
    - Permission matrix
    - Audit logging (who did what, when)
    - Fine-grained access control

.NOTES
    Part of LuxRig Enterprise Edition
    Integrates with user-manager.ps1
#>

# Module configuration
$script:Config = @{
    DatabasePath = "$PSScriptRoot/../../Data/permissions.json"
    AuditLogPath = "$PSScriptRoot/../../Data/rbac-audit.log"
    EnableAudit = $true
}

# Define all available permissions
$script:AllPermissions = @(
    # Trading permissions
    "trade.execute.spot",
    "trade.execute.futures",
    "trade.execute.margin",
    "trade.cancel",
    "trade.modify",
    "trade.view",

    # Bot permissions
    "bot.create",
    "bot.start",
    "bot.stop",
    "bot.configure",
    "bot.delete",
    "bot.view",

    # Portfolio permissions
    "portfolio.view.own",
    "portfolio.view.all",
    "portfolio.modify",
    "portfolio.transfer",

    # Strategy permissions
    "strategy.create",
    "strategy.edit",
    "strategy.delete",
    "strategy.backtest",
    "strategy.deploy",
    "strategy.view",

    # Risk permissions
    "risk.limits.set",
    "risk.limits.override",
    "risk.reports.view",
    "risk.emergency.stop",

    # User management
    "users.create",
    "users.edit",
    "users.delete",
    "users.view",
    "users.roles.assign",

    # Analytics permissions
    "analytics.view",
    "analytics.export",
    "analytics.create.reports",

    # Configuration
    "config.view",
    "config.edit",
    "config.api.keys",

    # Compliance
    "compliance.audit.view",
    "compliance.reports.generate",
    "compliance.export",

    # Enterprise features
    "enterprise.whitelabel.configure",
    "enterprise.billing.manage",
    "enterprise.tenants.manage",

    # System permissions
    "system.logs.view",
    "system.health.view",
    "system.maintenance",
    "system.backup",

    # Support
    "support.tickets.view",
    "support.tickets.respond",
    "support.users.impersonate"
)

# Predefined roles with permissions
$script:DefaultRoles = @{
    Admin = @{
        name = "Admin"
        description = "Full system access - complete control"
        permissions = $script:AllPermissions
        priority = 100
        canModify = $false  # Protected role
    }

    Manager = @{
        name = "Manager"
        description = "Supervisory access - view all, approve/reject actions"
        permissions = @(
            "trade.view",
            "trade.cancel",
            "bot.view",
            "bot.stop",
            "portfolio.view.all",
            "strategy.view",
            "strategy.backtest",
            "risk.limits.set",
            "risk.reports.view",
            "risk.emergency.stop",
            "users.view",
            "analytics.view",
            "analytics.export",
            "config.view",
            "compliance.audit.view",
            "compliance.reports.generate",
            "system.logs.view",
            "system.health.view",
            "support.tickets.view",
            "support.tickets.respond"
        )
        priority = 75
        canModify = $false
    }

    Trader = @{
        name = "Trader"
        description = "Execute trades, manage bots, view own portfolio"
        permissions = @(
            "trade.execute.spot",
            "trade.execute.futures",
            "trade.execute.margin",
            "trade.cancel",
            "trade.modify",
            "trade.view",
            "bot.create",
            "bot.start",
            "bot.stop",
            "bot.configure",
            "bot.delete",
            "bot.view",
            "portfolio.view.own",
            "portfolio.modify",
            "strategy.create",
            "strategy.edit",
            "strategy.delete",
            "strategy.backtest",
            "strategy.deploy",
            "strategy.view",
            "risk.reports.view",
            "analytics.view",
            "config.view"
        )
        priority = 50
        canModify = $false
    }

    Analyst = @{
        name = "Analyst"
        description = "View-only access - reports and analytics"
        permissions = @(
            "trade.view",
            "bot.view",
            "portfolio.view.all",
            "strategy.view",
            "strategy.backtest",
            "risk.reports.view",
            "analytics.view",
            "analytics.export",
            "analytics.create.reports",
            "compliance.reports.generate",
            "config.view",
            "system.logs.view",
            "system.health.view"
        )
        priority = 25
        canModify = $false
    }

    Support = @{
        name = "Support"
        description = "Customer-facing support access"
        permissions = @(
            "users.view",
            "support.tickets.view",
            "support.tickets.respond",
            "portfolio.view.all",
            "trade.view",
            "bot.view",
            "analytics.view",
            "system.logs.view"
        )
        priority = 10
        canModify = $false
    }
}

# Custom roles (user-defined)
$script:CustomRoles = @{}

# Initialize RBAC system
function Initialize-RBACSystem {
    try {
        # Create directories
        $dataDir = Split-Path $script:Config.DatabasePath
        if (-not (Test-Path $dataDir)) {
            New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
        }

        # Load custom roles
        if (Test-Path $script:Config.DatabasePath) {
            $data = Get-Content $script:Config.DatabasePath | ConvertFrom-Json
            $script:CustomRoles = @{}
            foreach ($role in $data.PSObject.Properties) {
                $script:CustomRoles[$role.Name] = $role.Value
            }
            Write-Host "[RBAC] Loaded $($script:CustomRoles.Count) custom roles" -ForegroundColor Green
        }

        Write-Host "[RBAC] System initialized with $($script:DefaultRoles.Count) default roles" -ForegroundColor Green
    }
    catch {
        Write-Warning "[RBAC] Initialization error: $_"
    }
}

# Save custom roles
function Save-RBACDatabase {
    try {
        $script:CustomRoles | ConvertTo-Json -Depth 10 | Out-File $script:Config.DatabasePath -Force
    }
    catch {
        Write-Warning "[RBAC] Save error: $_"
    }
}

# Audit log
function Write-AuditLog {
    param(
        [string]$UserId,
        [string]$Action,
        [string]$Resource,
        [string]$Result,
        [string]$Details = ""
    )

    if (-not $script:Config.EnableAudit) { return }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logEntry = "[$timestamp] User=$UserId Action=$Action Resource=$Resource Result=$Result Details=$Details"

    try {
        Add-Content -Path $script:Config.AuditLogPath -Value $logEntry
    }
    catch {
        Write-Warning "[RBAC] Audit log write failed: $_"
    }
}

# Get role definition
function Get-Role {
    param(
        [Parameter(Mandatory)]
        [string]$RoleName
    )

    # Check default roles first
    if ($script:DefaultRoles.ContainsKey($RoleName)) {
        return $script:DefaultRoles[$RoleName]
    }

    # Check custom roles
    if ($script:CustomRoles.ContainsKey($RoleName)) {
        return $script:CustomRoles[$RoleName]
    }

    return $null
}

# Create custom role
function New-CustomRole {
    param(
        [Parameter(Mandatory)]
        [string]$RoleName,

        [Parameter(Mandatory)]
        [string]$Description,

        [Parameter(Mandatory)]
        [array]$Permissions,

        [int]$Priority = 50
    )

    # Validate permissions
    $invalidPerms = $Permissions | Where-Object { $_ -notin $script:AllPermissions }
    if ($invalidPerms) {
        Write-Warning "[RBAC] Invalid permissions: $($invalidPerms -join ', ')"
        return @{ success = $false; error = "Invalid permissions specified" }
    }

    # Check if role already exists
    if ($script:DefaultRoles.ContainsKey($RoleName) -or $script:CustomRoles.ContainsKey($RoleName)) {
        return @{ success = $false; error = "Role already exists" }
    }

    $role = @{
        name = $RoleName
        description = $Description
        permissions = $Permissions
        priority = $Priority
        canModify = $true
        created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        createdBy = "system"  # TODO: Get actual user
    }

    $script:CustomRoles[$RoleName] = $role
    Save-RBACDatabase

    Write-Host "[RBAC] Custom role created: $RoleName" -ForegroundColor Green
    return @{ success = $true; role = $role }
}

# Update custom role
function Update-CustomRole {
    param(
        [Parameter(Mandatory)]
        [string]$RoleName,

        [array]$Permissions = $null,
        [string]$Description = $null,
        [int]$Priority = -1
    )

    if (-not $script:CustomRoles.ContainsKey($RoleName)) {
        return @{ success = $false; error = "Role not found or cannot be modified" }
    }

    $role = $script:CustomRoles[$RoleName]

    if ($Permissions) {
        # Validate permissions
        $invalidPerms = $Permissions | Where-Object { $_ -notin $script:AllPermissions }
        if ($invalidPerms) {
            return @{ success = $false; error = "Invalid permissions: $($invalidPerms -join ', ')" }
        }
        $role.permissions = $Permissions
    }

    if ($Description) { $role.description = $Description }
    if ($Priority -ge 0) { $role.priority = $Priority }

    $role.modified = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Save-RBACDatabase

    Write-Host "[RBAC] Role updated: $RoleName" -ForegroundColor Yellow
    return @{ success = $true; role = $role }
}

# Delete custom role
function Remove-CustomRole {
    param(
        [Parameter(Mandatory)]
        [string]$RoleName
    )

    if (-not $script:CustomRoles.ContainsKey($RoleName)) {
        return @{ success = $false; error = "Role not found or cannot be deleted" }
    }

    $script:CustomRoles.Remove($RoleName)
    Save-RBACDatabase

    Write-Host "[RBAC] Custom role deleted: $RoleName" -ForegroundColor Red
    return @{ success = $true; message = "Role deleted" }
}

# Check if user has permission
function Test-Permission {
    param(
        [Parameter(Mandatory)]
        [string]$UserId,

        [Parameter(Mandatory)]
        [string]$Permission,

        [string]$Resource = "",
        [hashtable]$Context = @{}
    )

    try {
        # Get user info (from user-manager module)
        $userModule = Join-Path $PSScriptRoot "../Auth/user-manager.ps1"
        if (Test-Path $userModule) {
            Import-Module $userModule -Force -ErrorAction SilentlyContinue
            $user = Get-UserInfo -UserId $UserId
        } else {
            # Fallback: assume user data from context
            $user = $Context.user
        }

        if (-not $user) {
            Write-AuditLog -UserId $UserId -Action "PERMISSION_CHECK" -Resource $Permission -Result "DENIED" -Details "User not found"
            return $false
        }

        # Get user's role
        $role = Get-Role -RoleName $user.role

        if (-not $role) {
            Write-AuditLog -UserId $UserId -Action "PERMISSION_CHECK" -Resource $Permission -Result "DENIED" -Details "Role not found: $($user.role)"
            return $false
        }

        # Check permission
        $hasPermission = $Permission -in $role.permissions

        $result = if ($hasPermission) { "ALLOWED" } else { "DENIED" }
        Write-AuditLog -UserId $UserId -Action "PERMISSION_CHECK" -Resource $Permission -Result $result -Details "Role=$($user.role)"

        return $hasPermission
    }
    catch {
        Write-Warning "[RBAC] Permission check error: $_"
        Write-AuditLog -UserId $UserId -Action "PERMISSION_CHECK" -Resource $Permission -Result "ERROR" -Details $_.Exception.Message
        return $false
    }
}

# Require permission (throws if denied)
function Assert-Permission {
    param(
        [Parameter(Mandatory)]
        [string]$UserId,

        [Parameter(Mandatory)]
        [string]$Permission,

        [string]$Resource = "",
        [hashtable]$Context = @{}
    )

    if (-not (Test-Permission -UserId $UserId -Permission $Permission -Resource $Resource -Context $Context)) {
        throw "Access denied: User lacks permission '$Permission'"
    }
}

# Get all permissions for a role
function Get-RolePermissions {
    param(
        [Parameter(Mandatory)]
        [string]$RoleName
    )

    $role = Get-Role -RoleName $RoleName
    if ($role) {
        return $role.permissions
    }

    return @()
}

# Get all roles
function Get-AllRoles {
    $allRoles = @()

    # Add default roles
    foreach ($roleName in $script:DefaultRoles.Keys) {
        $role = $script:DefaultRoles[$roleName]
        $allRoles += @{
            name = $role.name
            description = $role.description
            permissionCount = $role.permissions.Count
            priority = $role.priority
            canModify = $role.canModify
            type = "default"
        }
    }

    # Add custom roles
    foreach ($roleName in $script:CustomRoles.Keys) {
        $role = $script:CustomRoles[$roleName]
        $allRoles += @{
            name = $role.name
            description = $role.description
            permissionCount = $role.permissions.Count
            priority = $role.priority
            canModify = $role.canModify
            type = "custom"
            created = $role.created
        }
    }

    return $allRoles | Sort-Object -Property priority -Descending
}

# Get permission matrix (all roles vs all permissions)
function Get-PermissionMatrix {
    $matrix = @()

    foreach ($permission in $script:AllPermissions) {
        $row = @{ permission = $permission }

        # Check each default role
        foreach ($roleName in $script:DefaultRoles.Keys) {
            $role = $script:DefaultRoles[$roleName]
            $row[$roleName] = $permission -in $role.permissions
        }

        # Check each custom role
        foreach ($roleName in $script:CustomRoles.Keys) {
            $role = $script:CustomRoles[$roleName]
            $row[$roleName] = $permission -in $role.permissions
        }

        $matrix += $row
    }

    return $matrix
}

# Get audit log entries
function Get-AuditLog {
    param(
        [int]$Last = 100,
        [string]$UserId = $null,
        [string]$Action = $null
    )

    if (-not (Test-Path $script:Config.AuditLogPath)) {
        return @()
    }

    $logs = Get-Content $script:Config.AuditLogPath -Tail $Last

    if ($UserId) {
        $logs = $logs | Where-Object { $_ -match "User=$UserId" }
    }

    if ($Action) {
        $logs = $logs | Where-Object { $_ -match "Action=$Action" }
    }

    return $logs
}

# Get available permissions
function Get-AvailablePermissions {
    return $script:AllPermissions | ForEach-Object {
        $parts = $_ -split '\.'
        @{
            permission = $_
            category = $parts[0]
            action = $parts[1..($parts.Length - 1)] -join '.'
        }
    } | Group-Object -Property category | ForEach-Object {
        @{
            category = $_.Name
            permissions = $_.Group.permission
        }
    }
}

# Initialize on module load
Initialize-RBACSystem

# Export functions
Export-ModuleMember -Function @(
    'Get-Role',
    'New-CustomRole',
    'Update-CustomRole',
    'Remove-CustomRole',
    'Test-Permission',
    'Assert-Permission',
    'Get-RolePermissions',
    'Get-AllRoles',
    'Get-PermissionMatrix',
    'Get-AuditLog',
    'Get-AvailablePermissions'
)
