# ============================================================================
# LuxRig Environment Setup Script
# Purpose: Complete environment initialization and configuration
# Location: LuxRig/setup-environment.ps1
# ============================================================================

<#
.SYNOPSIS
    Sets up the complete LuxRig environment with all dependencies and configurations.

.DESCRIPTION
    This script performs a comprehensive environment setup including:
    - PowerShell version verification
    - Required module installation
    - Directory structure creation
    - Database initialization
    - Configuration file generation
    - Dependency checks

.PARAMETER Interactive
    Run in interactive mode to configure settings

.PARAMETER SkipModuleInstall
    Skip PowerShell module installation

.PARAMETER Force
    Force reinstallation of all components

.EXAMPLE
    .\setup-environment.ps1 -Interactive

.EXAMPLE
    .\setup-environment.ps1 -Force
#>

param(
    [switch]$Interactive,
    [switch]$SkipModuleInstall,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION
# ============================================================================

$Script:SetupConfig = @{
    RequiredPSVersion = [version]'7.0'
    RequiredModules = @(
        @{ Name = 'PSScriptAnalyzer'; MinVersion = '1.19.0' }
        @{ Name = 'Pester'; MinVersion = '5.0.0' }
    )
    Directories = @(
        'Data',
        'Data/Backups',
        'Logs',
        'Configs',
        'Temp',
        'Security',
        'Lib'
    )
}

# ============================================================================
# LOGGING
# ============================================================================

function Write-SetupLog {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Message
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        'INFO' { 'Cyan' }
        'SUCCESS' { 'Green' }
        'WARNING' { 'Yellow' }
        'ERROR' { 'Red' }
    }

    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color

    # Log to file
    $logFile = "$PSScriptRoot/Logs/setup.log"
    if (Test-Path (Split-Path $logFile)) {
        "[$timestamp] [$Level] $Message" | Add-Content -Path $logFile -ErrorAction SilentlyContinue
    }
}

# ============================================================================
# PREREQUISITE CHECKS
# ============================================================================

function Test-PowerShellVersion {
    Write-SetupLog -Level INFO -Message "Checking PowerShell version..."

    $currentVersion = $PSVersionTable.PSVersion

    if ($currentVersion -lt $Script:SetupConfig.RequiredPSVersion) {
        Write-SetupLog -Level ERROR -Message "PowerShell $($Script:SetupConfig.RequiredPSVersion) or higher is required. Current version: $currentVersion"
        Write-SetupLog -Level INFO -Message "Please install PowerShell 7+ from: https://github.com/PowerShell/PowerShell/releases"
        return $false
    }

    Write-SetupLog -Level SUCCESS -Message "PowerShell version $currentVersion is compatible"
    return $true
}

function Test-ExecutionPolicy {
    Write-SetupLog -Level INFO -Message "Checking execution policy..."

    $policy = Get-ExecutionPolicy

    if ($policy -eq 'Restricted' -or $policy -eq 'AllSigned') {
        Write-SetupLog -Level WARNING -Message "Current execution policy: $policy"
        Write-SetupLog -Level INFO -Message "Attempting to set execution policy to RemoteSigned..."

        try {
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            Write-SetupLog -Level SUCCESS -Message "Execution policy updated to RemoteSigned"
            return $true
        }
        catch {
            Write-SetupLog -Level ERROR -Message "Failed to update execution policy: $_"
            Write-SetupLog -Level INFO -Message "Please run: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
            return $false
        }
    }

    Write-SetupLog -Level SUCCESS -Message "Execution policy ($policy) is compatible"
    return $true
}

function Test-InternetConnection {
    Write-SetupLog -Level INFO -Message "Testing internet connectivity..."

    try {
        $null = Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -TimeoutSeconds 3
        Write-SetupLog -Level SUCCESS -Message "Internet connection verified"
        return $true
    }
    catch {
        Write-SetupLog -Level WARNING -Message "No internet connection detected. Some features may require internet access."
        return $false
    }
}

function Test-DiskSpace {
    Write-SetupLog -Level INFO -Message "Checking available disk space..."

    $drive = (Get-Item $PSScriptRoot).PSDrive
    $freeSpace = $drive.Free / 1GB

    if ($freeSpace -lt 1) {
        Write-SetupLog -Level WARNING -Message "Low disk space: $([math]::Round($freeSpace, 2)) GB available"
        Write-SetupLog -Level WARNING -Message "At least 1 GB of free space is recommended"
    }
    else {
        Write-SetupLog -Level SUCCESS -Message "Sufficient disk space: $([math]::Round($freeSpace, 2)) GB available"
    }

    return $freeSpace -gt 0.5
}

# ============================================================================
# MODULE MANAGEMENT
# ============================================================================

function Install-RequiredModules {
    if ($SkipModuleInstall) {
        Write-SetupLog -Level INFO -Message "Skipping module installation (SkipModuleInstall flag set)"
        return $true
    }

    Write-SetupLog -Level INFO -Message "Checking required PowerShell modules..."

    $allInstalled = $true

    foreach ($moduleInfo in $Script:SetupConfig.RequiredModules) {
        $moduleName = $moduleInfo.Name
        $minVersion = [version]$moduleInfo.MinVersion

        Write-SetupLog -Level INFO -Message "Checking module: $moduleName (>= $minVersion)"

        $installedModule = Get-Module -ListAvailable -Name $moduleName |
            Where-Object { $_.Version -ge $minVersion } |
            Select-Object -First 1

        if ($installedModule) {
            Write-SetupLog -Level SUCCESS -Message "$moduleName $($installedModule.Version) is already installed"
        }
        else {
            Write-SetupLog -Level INFO -Message "Installing $moduleName..."

            try {
                Install-Module -Name $moduleName -MinimumVersion $minVersion -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck
                Write-SetupLog -Level SUCCESS -Message "$moduleName installed successfully"
            }
            catch {
                Write-SetupLog -Level ERROR -Message "Failed to install $moduleName : $_"
                $allInstalled = $false
            }
        }
    }

    return $allInstalled
}

# ============================================================================
# DIRECTORY STRUCTURE
# ============================================================================

function Initialize-DirectoryStructure {
    Write-SetupLog -Level INFO -Message "Creating directory structure..."

    $createdCount = 0

    foreach ($dir in $Script:SetupConfig.Directories) {
        $fullPath = Join-Path $PSScriptRoot $dir

        if (-not (Test-Path $fullPath)) {
            try {
                New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
                Write-SetupLog -Level SUCCESS -Message "Created directory: $dir"
                $createdCount++
            }
            catch {
                Write-SetupLog -Level ERROR -Message "Failed to create directory $dir : $_"
                return $false
            }
        }
        else {
            Write-SetupLog -Level INFO -Message "Directory already exists: $dir"
        }
    }

    Write-SetupLog -Level SUCCESS -Message "Directory structure initialized ($createdCount new directories created)"
    return $true
}

# ============================================================================
# DATABASE SETUP
# ============================================================================

function Initialize-LuxRigDatabase {
    Write-SetupLog -Level INFO -Message "Initializing database..."

    try {
        $dbSetupScript = Join-Path $PSScriptRoot 'Database/setup-database.ps1'

        if (-not (Test-Path $dbSetupScript)) {
            Write-SetupLog -Level ERROR -Message "Database setup script not found: $dbSetupScript"
            return $false
        }

        # Import database module
        Import-Module $dbSetupScript -Force

        # Initialize database
        $result = Initialize-Database -Force:$Force

        if ($result.Success) {
            Write-SetupLog -Level SUCCESS -Message "Database initialized successfully"
            Write-SetupLog -Level INFO -Message "Database path: $($result.DatabasePath)"
            return $true
        }
        else {
            Write-SetupLog -Level ERROR -Message "Database initialization failed: $($result.Error)"
            return $false
        }
    }
    catch {
        Write-SetupLog -Level ERROR -Message "Database initialization error: $_"
        return $false
    }
}

# ============================================================================
# CONFIGURATION GENERATION
# ============================================================================

function New-DefaultConfiguration {
    param(
        [switch]$Interactive
    )

    Write-SetupLog -Level INFO -Message "Generating default configuration..."

    $configPath = Join-Path $PSScriptRoot 'Configs/luxrig.config.json'

    if ((Test-Path $configPath) -and -not $Force) {
        Write-SetupLog -Level INFO -Message "Configuration file already exists: $configPath"
        return $true
    }

    $defaultConfig = @{
        System = @{
            Environment = 'development'
            LogLevel = 'INFO'
            EnableTelemetry = $true
            MaxWorkers = [Math]::Min([Environment]::ProcessorCount, 8)
        }
        Database = @{
            Path = './Data/luxrig.db'
            BackupEnabled = $true
            BackupRetentionDays = 7
        }
        Trading = @{
            PaperTradingMode = $true
            DefaultExchange = 'coinbase'
            MaxPositions = 5
            RiskPerTrade = 0.02
        }
        Content = @{
            AutoPublish = $false
            DefaultPlatform = 'wordpress'
            MaxDailyPosts = 10
        }
        AI = @{
            Provider = 'local'
            LocalModelPath = './AI/LocalModels'
            DefaultModel = 'llama-2-7b'
        }
        Monitoring = @{
            HealthCheckInterval = 300
            AlertsEnabled = $true
            EmailNotifications = $false
        }
        Security = @{
            EncryptSecrets = $true
            RequireAuth = $true
            SessionTimeout = 3600
        }
    }

    if ($Interactive) {
        Write-SetupLog -Level INFO -Message "Starting interactive configuration..."

        $envChoice = Read-Host "Environment (development/production) [default: development]"
        if ($envChoice) { $defaultConfig.System.Environment = $envChoice }

        $paperTrading = Read-Host "Enable paper trading mode? (y/n) [default: y]"
        $defaultConfig.Trading.PaperTradingMode = ($paperTrading -ne 'n')

        $autoPublish = Read-Host "Enable auto-publish for content? (y/n) [default: n]"
        $defaultConfig.Content.AutoPublish = ($autoPublish -eq 'y')
    }

    try {
        $defaultConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath -Encoding UTF8
        Write-SetupLog -Level SUCCESS -Message "Configuration file created: $configPath"
        return $true
    }
    catch {
        Write-SetupLog -Level ERROR -Message "Failed to create configuration file: $_"
        return $false
    }
}

# ============================================================================
# DEPENDENCIES CHECK
# ============================================================================

function Test-SystemDependencies {
    Write-SetupLog -Level INFO -Message "Checking system dependencies..."

    $dependencies = @{
        'Git' = { git --version 2>&1 }
        'Python' = { python --version 2>&1 }
        '.NET' = { dotnet --version 2>&1 }
    }

    $results = @{}

    foreach ($dep in $dependencies.Keys) {
        try {
            $version = & $dependencies[$dep]
            $results[$dep] = @{ Installed = $true; Version = $version }
            Write-SetupLog -Level SUCCESS -Message "$dep is installed: $version"
        }
        catch {
            $results[$dep] = @{ Installed = $false; Version = $null }
            Write-SetupLog -Level WARNING -Message "$dep is not installed (optional)"
        }
    }

    return $results
}

# ============================================================================
# SECURITY INITIALIZATION
# ============================================================================

function Initialize-SecurityComponents {
    Write-SetupLog -Level INFO -Message "Initializing security components..."

    try {
        # Create security directory
        $securityDir = Join-Path $PSScriptRoot 'Security'
        if (-not (Test-Path $securityDir)) {
            New-Item -ItemType Directory -Path $securityDir -Force | Out-Null
        }

        # Create .gitignore for security directory
        $gitignorePath = Join-Path $securityDir '.gitignore'
        $gitignoreContent = @"
# Ignore all secrets and keys
*.key
*.pem
*.p12
*.pfx
secrets.json
credentials.json
api-keys.json

# Allow tracking of example files
!*.example
"@
        Set-Content -Path $gitignorePath -Value $gitignoreContent

        Write-SetupLog -Level SUCCESS -Message "Security components initialized"
        return $true
    }
    catch {
        Write-SetupLog -Level ERROR -Message "Failed to initialize security: $_"
        return $false
    }
}

# ============================================================================
# POST-SETUP VALIDATION
# ============================================================================

function Test-SetupCompletion {
    Write-SetupLog -Level INFO -Message "Validating setup completion..."

    $validationSteps = @{
        'Directory Structure' = {
            $Script:SetupConfig.Directories | ForEach-Object {
                Test-Path (Join-Path $PSScriptRoot $_)
            } | Where-Object { -not $_ } | Measure-Object | Select-Object -ExpandProperty Count
        }
        'Database' = {
            Test-Path (Join-Path $PSScriptRoot 'Data/luxrig.db')
        }
        'Configuration' = {
            Test-Path (Join-Path $PSScriptRoot 'Configs/luxrig.config.json')
        }
    }

    $allValid = $true

    foreach ($step in $validationSteps.Keys) {
        $result = & $validationSteps[$step]

        if ($result -is [bool]) {
            $valid = $result
        }
        else {
            $valid = $result -eq 0
        }

        if ($valid) {
            Write-SetupLog -Level SUCCESS -Message "$step : Valid"
        }
        else {
            Write-SetupLog -Level ERROR -Message "$step : Invalid"
            $allValid = $false
        }
    }

    return $allValid
}

# ============================================================================
# MAIN SETUP ORCHESTRATION
# ============================================================================

function Start-LuxRigSetup {
    Write-Host "`n" + ("=" * 70) -ForegroundColor Cyan
    Write-Host "  LUXRIG ENVIRONMENT SETUP" -ForegroundColor Cyan
    Write-Host ("=" * 70) + "`n" -ForegroundColor Cyan

    $startTime = Get-Date

    # Step 1: Prerequisites
    Write-Host "`n[STEP 1/7] Checking Prerequisites..." -ForegroundColor Yellow

    if (-not (Test-PowerShellVersion)) { return $false }
    if (-not (Test-ExecutionPolicy)) { return $false }
    Test-InternetConnection | Out-Null
    if (-not (Test-DiskSpace)) { return $false }

    # Step 2: Module Installation
    Write-Host "`n[STEP 2/7] Installing Required Modules..." -ForegroundColor Yellow
    if (-not (Install-RequiredModules)) {
        Write-SetupLog -Level WARNING -Message "Some modules failed to install, but continuing..."
    }

    # Step 3: Directory Structure
    Write-Host "`n[STEP 3/7] Creating Directory Structure..." -ForegroundColor Yellow
    if (-not (Initialize-DirectoryStructure)) { return $false }

    # Step 4: Database
    Write-Host "`n[STEP 4/7] Initializing Database..." -ForegroundColor Yellow
    if (-not (Initialize-LuxRigDatabase)) { return $false }

    # Step 5: Configuration
    Write-Host "`n[STEP 5/7] Generating Configuration..." -ForegroundColor Yellow
    if (-not (New-DefaultConfiguration -Interactive:$Interactive)) { return $false }

    # Step 6: Security
    Write-Host "`n[STEP 6/7] Initializing Security..." -ForegroundColor Yellow
    if (-not (Initialize-SecurityComponents)) { return $false }

    # Step 7: Validation
    Write-Host "`n[STEP 7/7] Validating Setup..." -ForegroundColor Yellow
    $valid = Test-SetupCompletion

    # Check dependencies
    Write-Host "`n[OPTIONAL] Checking System Dependencies..." -ForegroundColor Yellow
    $deps = Test-SystemDependencies

    # Summary
    $duration = ((Get-Date) - $startTime).TotalSeconds

    Write-Host "`n" + ("=" * 70) -ForegroundColor Cyan
    Write-Host "  SETUP COMPLETE!" -ForegroundColor Green
    Write-Host ("=" * 70) -ForegroundColor Cyan

    Write-Host "`nSetup Duration: $([math]::Round($duration, 2)) seconds" -ForegroundColor Cyan
    Write-Host "Validation: $(if ($valid) { 'PASSED' } else { 'FAILED' })" -ForegroundColor $(if ($valid) { 'Green' } else { 'Red' })

    Write-Host "`nNext Steps:" -ForegroundColor Yellow
    Write-Host "  1. Review configuration: ./Configs/luxrig.config.json" -ForegroundColor White
    Write-Host "  2. Set up API keys: ./Security/secrets-manager.ps1" -ForegroundColor White
    Write-Host "  3. Start LuxRig: ./START-LUXRIG.ps1" -ForegroundColor White

    if (-not $valid) {
        Write-Host "`nWarning: Setup validation failed. Please review errors above." -ForegroundColor Red
    }

    return $valid
}

# ============================================================================
# EXECUTION
# ============================================================================

try {
    $result = Start-LuxRigSetup

    if ($result) {
        exit 0
    }
    else {
        Write-Host "`nSetup completed with errors. Please review the log file." -ForegroundColor Yellow
        exit 1
    }
}
catch {
    Write-Host "`nFatal error during setup: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}
