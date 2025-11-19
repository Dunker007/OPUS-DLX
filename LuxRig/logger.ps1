#Requires -Version 7.0
<#
.SYNOPSIS
    LuxRig Logger - Unified logging system
.DESCRIPTION
    Centralized logging for all LuxRig components:
    - Multiple log levels
    - File rotation
    - Colored console output
    - Structured logging
#>

$script:LogPath = Join-Path $PSScriptRoot "logs"
$script:LogFile = Join-Path $script:LogPath "luxrig.log"
$script:LogLevel = "INFO"  # DEBUG, INFO, WARN, ERROR, CRITICAL

function Initialize-Logger {
    if (-not (Test-Path $script:LogPath)) {
        New-Item -ItemType Directory -Path $script:LogPath -Force | Out-Null
    }

    # Rotate old logs
    if (Test-Path $script:LogFile) {
        $size = (Get-Item $script:LogFile).Length
        if ($size -gt 10MB) {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            Move-Item $script:LogFile "$($script:LogFile).$timestamp" -Force
        }
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet("DEBUG","INFO","WARN","ERROR","CRITICAL")][string]$Level = "INFO",
        [string]$Component = "System"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logEntry = "[$timestamp] [$Level] [$Component] $Message"

    # Console output with colors
    $color = switch ($Level) {
        "DEBUG" { "Gray" }
        "INFO" { "White" }
        "WARN" { "Yellow" }
        "ERROR" { "Red" }
        "CRITICAL" { "Magenta" }
    }

    Write-Host $logEntry -ForegroundColor $color

    # File output
    $logEntry | Out-File -FilePath $script:LogFile -Append -Encoding UTF8
}

function Write-Debug {
    param([string]$Message, [string]$Component = "System")
    Write-Log -Message $Message -Level "DEBUG" -Component $Component
}

function Write-Info {
    param([string]$Message, [string]$Component = "System")
    Write-Log -Message $Message -Level "INFO" -Component $Component
}

function Write-Warn {
    param([string]$Message, [string]$Component = "System")
    Write-Log -Message $Message -Level "WARN" -Component $Component
}

function Write-Error {
    param([string]$Message, [string]$Component = "System")
    Write-Log -Message $Message -Level "ERROR" -Component $Component
}

function Write-Critical {
    param([string]$Message, [string]$Component = "System")
    Write-Log -Message $Message -Level "CRITICAL" -Component $Component
}

function Get-Logs {
    param(
        [int]$Last = 50,
        [string]$Level = "",
        [string]$Component = ""
    )

    if (-not (Test-Path $script:LogFile)) {
        Write-Host "No log file found" -ForegroundColor Yellow
        return
    }

    $logs = Get-Content $script:LogFile -Tail $Last

    if ($Level) {
        $logs = $logs | Where-Object { $_ -like "*[$Level]*" }
    }

    if ($Component) {
        $logs = $logs | Where-Object { $_ -like "*[$Component]*" }
    }

    $logs | ForEach-Object {
        if ($_ -match '\[(ERROR|CRITICAL)\]') {
            Write-Host $_ -ForegroundColor Red
        }
        elseif ($_ -match '\[WARN\]') {
            Write-Host $_ -ForegroundColor Yellow
        }
        else {
            Write-Host $_
        }
    }
}

function Clear-Logs {
    if (Test-Path $script:LogFile) {
        Remove-Item $script:LogFile -Force
        Write-Host "✅ Logs cleared" -ForegroundColor Green
    }
}

Export-ModuleMember -Function Initialize-Logger, Write-Log, Write-Debug, Write-Info, Write-Warn, Write-Error, Write-Critical, Get-Logs, Clear-Logs

Initialize-Logger
