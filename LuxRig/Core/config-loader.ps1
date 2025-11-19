#Requires -Version 7.0

<#
.SYNOPSIS
    LuxRig Configuration Loader

.DESCRIPTION
    Centralized configuration management system:
    - Load and merge configuration files
    - Environment variable overrides
    - Configuration validation
    - Hot reload support
    - Secure secrets management

.NOTES
    This is loaded first by all other modules
#>

# Global configuration object
$script:Config = $null
$script:ConfigPath = $null
$script:ConfigWatchers = @{}

<#
.SYNOPSIS
    Initialize configuration system

.PARAMETER ConfigPath
    Path to configuration file (defaults to config.json)

.PARAMETER Environment
    Environment name (development, staging, production)
#>
function Initialize-Configuration {
    param(
        [string]$ConfigPath = "./config.json",
        [string]$Environment = "development"
    )

    # Determine config file
    $script:ConfigPath = $ConfigPath

    # If config doesn't exist, use default
    if (-not (Test-Path $script:ConfigPath)) {
        $defaultConfig = Join-Path $PSScriptRoot "../config-default.json"

        if (Test-Path $defaultConfig) {
            Write-Host "[CONFIG] No config found, copying default config..." -ForegroundColor Yellow
            Copy-Item $defaultConfig $script:ConfigPath
            Write-Host "[CONFIG] Created config.json from defaults" -ForegroundColor Green
        } else {
            throw "Configuration file not found and no default available"
        }
    }

    # Load configuration
    try {
        $configJson = Get-Content $script:ConfigPath -Raw
        $script:Config = $configJson | ConvertFrom-Json

        # Set environment
        $script:Config.environment = $Environment

        Write-Host "[CONFIG] Configuration loaded successfully" -ForegroundColor Green
        Write-Host "  Mode: $($script:Config.mode)" -ForegroundColor Gray
        Write-Host "  Environment: $($script:Config.environment)" -ForegroundColor Gray
        Write-Host "  Budget Mode: $($script:Config.budgetMode)" -ForegroundColor Gray

        return $script:Config
    }
    catch {
        throw "Failed to load configuration: $_"
    }
}

<#
.SYNOPSIS
    Get configuration value

.PARAMETER Path
    Dot-notation path to config value (e.g., "database.usersDb")

.PARAMETER Default
    Default value if path not found
#>
function Get-ConfigValue {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        $Default = $null
    )

    if (-not $script:Config) {
        throw "Configuration not initialized. Call Initialize-Configuration first."
    }

    $parts = $Path.Split('.')
    $current = $script:Config

    foreach ($part in $parts) {
        if ($current.PSObject.Properties.Name -contains $part) {
            $current = $current.$part
        } else {
            return $Default
        }
    }

    return $current
}

<#
.SYNOPSIS
    Set configuration value

.PARAMETER Path
    Dot-notation path to config value

.PARAMETER Value
    Value to set
#>
function Set-ConfigValue {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        $Value
    )

    if (-not $script:Config) {
        throw "Configuration not initialized"
    }

    $parts = $Path.Split('.')
    $current = $script:Config

    # Navigate to parent
    for ($i = 0; $i -lt $parts.Count - 1; $i++) {
        $part = $parts[$i]
        if ($current.PSObject.Properties.Name -notcontains $part) {
            $current | Add-Member -MemberType NoteProperty -Name $part -Value ([PSCustomObject]@{})
        }
        $current = $current.$part
    }

    # Set final value
    $finalKey = $parts[-1]
    if ($current.PSObject.Properties.Name -contains $finalKey) {
        $current.$finalKey = $Value
    } else {
        $current | Add-Member -MemberType NoteProperty -Name $finalKey -Value $Value
    }
}

<#
.SYNOPSIS
    Save configuration to disk
#>
function Save-Configuration {
    param(
        [string]$Path = $script:ConfigPath
    )

    if (-not $script:Config) {
        throw "Configuration not initialized"
    }

    try {
        $configJson = $script:Config | ConvertTo-Json -Depth 10
        $configJson | Out-File $Path -Force
        Write-Host "[CONFIG] Configuration saved to: $Path" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to save configuration: $_"
        return $false
    }
}

<#
.SYNOPSIS
    Validate configuration

.DESCRIPTION
    Checks configuration for required fields and valid values
#>
function Test-Configuration {
    param(
        $Config = $script:Config
    )

    $errors = @()

    # Check required fields
    $requiredFields = @(
        'version',
        'mode',
        'system',
        'database',
        'security'
    )

    foreach ($field in $requiredFields) {
        if ($Config.PSObject.Properties.Name -notcontains $field) {
            $errors += "Missing required field: $field"
        }
    }

    # Validate mode
    $validModes = @('demo', 'paper', 'live')
    if ($Config.mode -notin $validModes) {
        $errors += "Invalid mode: $($Config.mode). Must be one of: $($validModes -join ', ')"
    }

    # Validate security settings
    if ($Config.security.passwordMinLength -lt 8) {
        $errors += "Password minimum length must be at least 8 characters"
    }

    if ($Config.security.sessionTimeout -lt 300) {
        $errors += "Session timeout should be at least 300 seconds (5 minutes)"
    }

    # Validate trading settings if enabled
    if ($Config.trading.enabled) {
        if ($Config.trading.risk.maxLeverage -gt 10) {
            $errors += "WARNING: Max leverage over 10x is extremely risky"
        }

        if ($Config.trading.risk.maxDrawdown -le 0) {
            $errors += "Max drawdown must be greater than 0"
        }
    }

    # Return results
    if ($errors.Count -gt 0) {
        Write-Host "[CONFIG] Configuration validation errors:" -ForegroundColor Red
        foreach ($error in $errors) {
            Write-Host "  - $error" -ForegroundColor Red
        }
        return $false
    } else {
        Write-Host "[CONFIG] Configuration validation passed ✓" -ForegroundColor Green
        return $true
    }
}

<#
.SYNOPSIS
    Get all configuration as hashtable
#>
function Get-Configuration {
    if (-not $script:Config) {
        throw "Configuration not initialized"
    }

    return $script:Config
}

<#
.SYNOPSIS
    Reload configuration from disk
#>
function Reset-Configuration {
    Write-Host "[CONFIG] Reloading configuration..." -ForegroundColor Yellow
    return Initialize-Configuration -ConfigPath $script:ConfigPath
}

<#
.SYNOPSIS
    Get environment-specific configuration override
#>
function Merge-EnvironmentConfig {
    param(
        [string]$Environment
    )

    $envConfigPath = "./config.$Environment.json"

    if (Test-Path $envConfigPath) {
        Write-Host "[CONFIG] Loading environment override: $envConfigPath" -ForegroundColor Yellow

        $envConfig = Get-Content $envConfigPath | ConvertFrom-Json

        # Merge env config into main config (env overrides main)
        # This is a simple shallow merge - you might want deep merge for production
        foreach ($prop in $envConfig.PSObject.Properties) {
            $script:Config.$($prop.Name) = $prop.Value
        }

        Write-Host "[CONFIG] Environment configuration merged" -ForegroundColor Green
    }
}

<#
.SYNOPSIS
    Apply environment variable overrides

.DESCRIPTION
    Looks for environment variables starting with LUXRIG_ and applies them
    Example: LUXRIG_MODE=live will set config.mode to "live"
#>
function Apply-EnvironmentVariables {
    $envVars = Get-ChildItem Env: | Where-Object { $_.Name.StartsWith("LUXRIG_") }

    if ($envVars.Count -gt 0) {
        Write-Host "[CONFIG] Applying environment variable overrides:" -ForegroundColor Yellow

        foreach ($envVar in $envVars) {
            # Remove LUXRIG_ prefix and convert to lowercase
            $key = $envVar.Name.Substring(7).ToLower()
            $value = $envVar.Value

            # Convert string booleans
            if ($value -in @('true', 'false')) {
                $value = [bool]::Parse($value)
            }

            # Convert string numbers
            if ($value -match '^\d+$') {
                $value = [int]$value
            }

            Set-ConfigValue -Path $key -Value $value
            Write-Host "  $key = $value" -ForegroundColor Gray
        }
    }
}

<#
.SYNOPSIS
    Initialize directories from configuration
#>
function Initialize-ConfigDirectories {
    $directories = @(
        $script:Config.system.dataPath,
        $script:Config.system.logsPath,
        $script:Config.system.backupPath,
        "$($script:Config.system.dataPath)/trades",
        "$($script:Config.system.dataPath)/analytics",
        "$($script:Config.system.dataPath)/ai-models"
    )

    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Host "[CONFIG] Created directory: $dir" -ForegroundColor Green
        }
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Initialize-Configuration',
    'Get-ConfigValue',
    'Set-ConfigValue',
    'Save-Configuration',
    'Test-Configuration',
    'Get-Configuration',
    'Reset-Configuration',
    'Merge-EnvironmentConfig',
    'Apply-EnvironmentVariables',
    'Initialize-ConfigDirectories'
)
