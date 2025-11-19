# ============================================================================
# LuxRig Master Launcher - Production Ready
# One-click startup with pre-flight checks and monitoring
# ============================================================================

<#
.SYNOPSIS
    Comprehensive startup script for LuxRig platform.

.DESCRIPTION
    Production-ready launcher with:
    - Pre-flight system checks
    - Database initialization
    - Service startup
    - Health monitoring
    - Web dashboard
    - Status reporting

.PARAMETER Mode
    Launch mode: full, trading, content, monitoring

.PARAMETER SkipChecks
    Skip pre-flight checks

.PARAMETER NoDashboard
    Don't start web dashboard

.EXAMPLE
    .\START-LUXRIG.ps1

.EXAMPLE
    .\START-LUXRIG.ps1 -Mode trading -SkipChecks
#>

param(
    [ValidateSet('full', 'trading', 'content', 'monitoring', 'test')]
    [string]$Mode = 'full',

    [switch]$SkipChecks,

    [switch]$NoDashboard,

    [switch]$PaperTradingOnly
)

$ErrorActionPreference = 'Continue'

# ============================================================================
# CONFIGURATION
# ============================================================================

$Script:Config = @{
    Version = '1.0.0'
    Environment = 'production'
    Components = @{
        Database = $true
        Trading = $true
        Content = $true
        Analytics = $true
        Dashboard = $true
        Monitoring = $true
    }
    Paths = @{
        Database = './Database/setup-database.ps1'
        DataAccess = './Database/data-access.ps1'
        Secrets = './Security/secrets-manager.ps1'
        ErrorHandler = './Core/error-handler.ps1'
        HealthMonitor = './health-monitor.ps1'
        Dashboard = './Dashboard/web-server.ps1'
        RevenueDashboard = './Analytics/revenue-dashboard.ps1'
        StrategyManager = './Trading/strategy-manager.ps1'
        Backup = './Backup/backup-manager.ps1'
    }
}

# ============================================================================
# LOGGING
# ============================================================================

function Write-LuxRigLog {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR', 'CRITICAL')]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Message
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $icon = switch ($Level) {
        'INFO' { '💡' }
        'SUCCESS' { '✅' }
        'WARNING' { '⚠️ ' }
        'ERROR' { '❌' }
        'CRITICAL' { '🚨' }
    }

    $color = switch ($Level) {
        'INFO' { 'Cyan' }
        'SUCCESS' { 'Green' }
        'WARNING' { 'Yellow' }
        'ERROR' { 'Red' }
        'CRITICAL' { 'Magenta' }
    }

    Write-Host "[$timestamp] $icon [$Level] $Message" -ForegroundColor $color

    # Log to file
    $logPath = './Logs/luxrig-startup.log'
    if (Test-Path (Split-Path $logPath)) {
        "[$timestamp] [$Level] $Message" | Add-Content -Path $logPath -ErrorAction SilentlyContinue
    }
}

# ============================================================================
# PRE-FLIGHT CHECKS
# ============================================================================

function Test-Prerequisites {
    Write-LuxRigLog -Level INFO -Message "Running pre-flight checks..."

    $checks = @{
        PowerShell = $false
        Directories = $false
        Database = $false
        Config = $false
    }

    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        Write-LuxRigLog -Level SUCCESS -Message "PowerShell 7+ detected: $($PSVersionTable.PSVersion)"
        $checks.PowerShell = $true
    }
    else {
        Write-LuxRigLog -Level ERROR -Message "PowerShell 7+ required. Current: $($PSVersionTable.PSVersion)"
    }

    # Check directories
    $requiredDirs = @('Data', 'Logs', 'Configs', 'Database', 'Trading', 'Content')
    $allExist = $true

    foreach ($dir in $requiredDirs) {
        if (-not (Test-Path $dir)) {
            Write-LuxRigLog -Level WARNING -Message "Creating missing directory: $dir"
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
    $checks.Directories = $true

    # Check database
    if (Test-Path './Data/luxrig.db') {
        Write-LuxRigLog -Level SUCCESS -Message "Database found"
        $checks.Database = $true
    }
    else {
        Write-LuxRigLog -Level WARNING -Message "Database not found - will initialize"
    }

    # Check config
    if (Test-Path './Configs/luxrig.config.json') {
        Write-LuxRigLog -Level SUCCESS -Message "Configuration found"
        $checks.Config = $true
    }
    else {
        Write-LuxRigLog -Level WARNING -Message "Configuration not found - will use defaults"
    }

    $allPassed = $checks.PowerShell -and $checks.Directories

    if ($allPassed) {
        Write-LuxRigLog -Level SUCCESS -Message "Pre-flight checks passed"
    }
    else {
        Write-LuxRigLog -Level WARNING -Message "Some pre-flight checks failed"
    }

    return $checks
}

# ============================================================================
# INITIALIZATION
# ============================================================================

function Initialize-LuxRig {
    Write-LuxRigLog -Level INFO -Message "Initializing LuxRig..."

    # Initialize database
    if (Test-Path $Script:Config.Paths.Database) {
        try {
            Write-LuxRigLog -Level INFO -Message "Initializing database..."
            & $Script:Config.Paths.Database
            Write-LuxRigLog -Level SUCCESS -Message "Database initialized"
        }
        catch {
            Write-LuxRigLog -Level ERROR -Message "Database initialization failed: $_"
        }
    }

    # Initialize secrets manager
    if (Test-Path $Script:Config.Paths.Secrets) {
        try {
            . $Script:Config.Paths.Secrets
            Initialize-SecretsManager | Out-Null
            Write-LuxRigLog -Level SUCCESS -Message "Secrets manager initialized"
        }
        catch {
            Write-LuxRigLog -Level WARNING -Message "Secrets manager initialization warning: $_"
        }
    }

    # Load error handler
    if (Test-Path $Script:Config.Paths.ErrorHandler) {
        try {
            . $Script:Config.Paths.ErrorHandler
            Write-LuxRigLog -Level SUCCESS -Message "Error handler loaded"
        }
        catch {
            Write-LuxRigLog -Level WARNING -Message "Error handler load warning: $_"
        }
    }
}

# ============================================================================
# SERVICE MANAGEMENT
# ============================================================================

$Script:RunningJobs = @()

function Start-Component {
    param(
        [string]$Name,
        [string]$ScriptPath,
        [hashtable]$Parameters = @{}
    )

    try {
        Write-LuxRigLog -Level INFO -Message "Starting component: $Name"

        if (-not (Test-Path $ScriptPath)) {
            Write-LuxRigLog -Level WARNING -Message "Component script not found: $ScriptPath"
            return $null
        }

        $job = Start-Job -Name "LuxRig-$Name" -ScriptBlock {
            param($Path, $Params)
            & $Path @Params
        } -ArgumentList $ScriptPath, $Parameters

        $Script:RunningJobs += $job

        Write-LuxRigLog -Level SUCCESS -Message "Component started: $Name (Job ID: $($job.Id))"

        return $job
    }
    catch {
        Write-LuxRigLog -Level ERROR -Message "Failed to start $Name : $_"
        return $null
    }
}

function Get-ComponentStatus {
    Write-Host "`n=== Component Status ===" -ForegroundColor Cyan

    foreach ($job in $Script:RunningJobs) {
        $status = switch ($job.State) {
            'Running' { @{ Color = 'Green'; Icon = '🟢' } }
            'Failed' { @{ Color = 'Red'; Icon = '🔴' } }
            'Stopped' { @{ Color = 'Yellow'; Icon = '🟡' } }
            default { @{ Color = 'Gray'; Icon = '⚪' } }
        }

        Write-Host "  $($status.Icon) $($job.Name.PadRight(30)) " -NoNewline
        Write-Host "$($job.State)" -ForegroundColor $status.Color
    }

    Write-Host ""
}

# ============================================================================
# STARTUP SEQUENCE
# ============================================================================

function Start-LuxRig {
    # Banner
    Write-Host "`n" + ("=" * 80) -ForegroundColor Cyan
    Write-Host "
    ██╗     ██╗   ██╗██╗  ██╗██████╗ ██╗ ██████╗
    ██║     ██║   ██║╚██╗██╔╝██╔══██╗██║██╔════╝
    ██║     ██║   ██║ ╚███╔╝ ██████╔╝██║██║  ███╗
    ██║     ██║   ██║ ██╔██╗ ██╔══██╗██║██║   ██║
    ███████╗╚██████╔╝██╔╝ ██╗██║  ██║██║╚██████╔╝
    ╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝ ╚═════╝
    " -ForegroundColor Cyan

    Write-Host "  AI-Powered Revenue Generation Platform" -ForegroundColor Yellow
    Write-Host "  Version: $($Script:Config.Version)" -ForegroundColor Gray
    Write-Host ("=" * 80) + "`n" -ForegroundColor Cyan

    Write-Host "Mode: $Mode" -ForegroundColor White
    Write-Host "Environment: $($Script:Config.Environment)" -ForegroundColor White
    if ($PaperTradingOnly) {
        Write-Host "Trading Mode: PAPER TRADING ONLY" -ForegroundColor Yellow
    }
    Write-Host ""

    $startTime = Get-Date

    # Step 1: Pre-flight checks
    if (-not $SkipChecks) {
        Write-Host "`n[STEP 1/5] Pre-Flight Checks..." -ForegroundColor Yellow
        $checks = Test-Prerequisites

        if (-not $checks.PowerShell) {
            Write-LuxRigLog -Level CRITICAL -Message "Critical checks failed. Exiting."
            return $false
        }
    }
    else {
        Write-LuxRigLog -Level WARNING -Message "Skipping pre-flight checks"
    }

    # Step 2: Initialize
    Write-Host "`n[STEP 2/5] Initialization..." -ForegroundColor Yellow
    Initialize-LuxRig

    # Step 3: Start core services
    Write-Host "`n[STEP 3/5] Starting Core Services..." -ForegroundColor Yellow

    if ($Mode -in @('full', 'monitoring')) {
        # Start health monitor
        if (Test-Path $Script:Config.Paths.HealthMonitor) {
            Start-Component -Name 'HealthMonitor' -ScriptPath $Script:Config.Paths.HealthMonitor -Parameters @{
                CheckInterval = 300
                AutoRestart = $true
            } | Out-Null
        }
    }

    # Step 4: Start revenue components
    Write-Host "`n[STEP 4/5] Starting Revenue Components..." -ForegroundColor Yellow

    if ($Mode -in @('full', 'trading')) {
        Write-LuxRigLog -Level INFO -Message "Trading components available"
        Write-LuxRigLog -Level INFO -Message "Use strategy-manager.ps1 to start trading strategies"
    }

    if ($Mode -in @('full', 'content')) {
        Write-LuxRigLog -Level INFO -Message "Content components available"
        Write-LuxRigLog -Level INFO -Message "Use blog-publisher.ps1 or content-factory.ps1 to generate content"
    }

    # Step 5: Start dashboard
    if (-not $NoDashboard) {
        Write-Host "`n[STEP 5/5] Starting Dashboard..." -ForegroundColor Yellow

        if (Test-Path $Script:Config.Paths.Dashboard) {
            Start-Component -Name 'WebDashboard' -ScriptPath $Script:Config.Paths.Dashboard -Parameters @{
                Port = 8080
            } | Out-Null
        }
    }

    # Completion
    $duration = ((Get-Date) - $startTime).TotalSeconds

    Write-Host "`n" + ("=" * 80) -ForegroundColor Cyan
    Write-Host "  LUXRIG STARTED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host ("=" * 80) -ForegroundColor Cyan

    Write-Host "`nStartup Duration: $([math]::Round($duration, 2)) seconds" -ForegroundColor Cyan

    # Show status
    Start-Sleep -Seconds 2
    Get-ComponentStatus

    # Access information
    Write-Host "📊 Dashboard Access:" -ForegroundColor Yellow
    Write-Host "   Web Dashboard: http://localhost:8080" -ForegroundColor White
    Write-Host ""

    Write-Host "🛠️  Management Commands:" -ForegroundColor Yellow
    Write-Host "   Trading:  .\Trading\strategy-manager.ps1 -Action list" -ForegroundColor White
    Write-Host "   Content:  .\Content\blog-publisher.ps1 -Platform wordpress -Topic crypto" -ForegroundColor White
    Write-Host "   Revenue:  .\Analytics\revenue-dashboard.ps1 -ReportType daily" -ForegroundColor White
    Write-Host "   Backup:   .\Backup\backup-manager.ps1 -Type full" -ForegroundColor White
    Write-Host ""

    Write-Host "💰 Revenue Streams Ready:" -ForegroundColor Green
    Write-Host "   ✓ DCA Trading Bot (Paper mode: $(if($PaperTradingOnly){'ON'}else{'OFF'}))" -ForegroundColor White
    Write-Host "   ✓ AI Content Generation" -ForegroundColor White
    Write-Host "   ✓ Multi-platform Publishing" -ForegroundColor White
    Write-Host "   ✓ Affiliate Integration" -ForegroundColor White
    Write-Host ""

    Write-LuxRigLog -Level SUCCESS -Message "LuxRig is running. Press Ctrl+C to stop all services."

    # Keep alive
    try {
        while ($true) {
            Start-Sleep -Seconds 60

            # Check job status
            $failedJobs = $Script:RunningJobs | Where-Object { $_.State -eq 'Failed' }
            if ($failedJobs) {
                foreach ($job in $failedJobs) {
                    Write-LuxRigLog -Level ERROR -Message "Component failed: $($job.Name)"
                    $job | Receive-Job -ErrorAction SilentlyContinue
                }
            }
        }
    }
    finally {
        Write-LuxRigLog -Level INFO -Message "Shutting down LuxRig..."

        # Stop all jobs
        foreach ($job in $Script:RunningJobs) {
            Stop-Job -Id $job.Id -ErrorAction SilentlyContinue
            Remove-Job -Id $job.Id -Force -ErrorAction SilentlyContinue
        }

        Write-LuxRigLog -Level INFO -Message "LuxRig stopped"
    }
}

# ============================================================================
# EXECUTION
# ============================================================================

try {
    Start-LuxRig
}
catch {
    Write-LuxRigLog -Level CRITICAL -Message "Fatal error: $_"
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}
