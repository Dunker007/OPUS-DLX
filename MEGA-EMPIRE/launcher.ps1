#!/usr/bin/env pwsh
<#
.SYNOPSIS
    MEGA-EMPIRE PowerShell Launcher

.DESCRIPTION
    Ultimate Passive Income Automation System - Windows PowerShell Edition

.PARAMETER Master
    Start Master Control Center only

.PARAMETER Status
    Show system status

.PARAMETER Stop
    Stop all running modules

.PARAMETER Category
    Start specific category (ContentFactory, RevenueEngines, TrafficDomination, AutomationCore, AIBrainNetwork)

.PARAMETER Module
    Start specific module by ID (1-50)

.EXAMPLE
    .\launcher.ps1
    Start entire MEGA-EMPIRE system

.EXAMPLE
    .\launcher.ps1 -Master
    Start Master Control Center only

.EXAMPLE
    .\launcher.ps1 -Category ContentFactory
    Start all ContentFactory modules

.EXAMPLE
    .\launcher.ps1 -Module 1
    Start Module 1 only
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage="Start Master Control Center only")]
    [switch]$Master,

    [Parameter(HelpMessage="Show system status")]
    [switch]$Status,

    [Parameter(HelpMessage="Stop all modules")]
    [switch]$Stop,

    [Parameter(HelpMessage="Start specific category")]
    [ValidateSet('ContentFactory', 'RevenueEngines', 'TrafficDomination', 'AutomationCore', 'AIBrainNetwork')]
    [string]$Category,

    [Parameter(HelpMessage="Start specific module ID")]
    [ValidateRange(1,50)]
    [int]$Module
)

# Banner
Write-Host @"

╔═══════════════════════════════════════════════════════════════════════════╗
║                                                                           ║
║                    MEGA-EMPIRE MASTER LAUNCHER                            ║
║                                                                           ║
║             Ultimate Passive Income Automation System                     ║
║                      PowerShell Edition                                   ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# Check Python installation
try {
    $pythonVersion = python --version 2>&1
    Write-Host "✓ Found $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Python is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install Python 3.8+ from https://www.python.org/" -ForegroundColor Yellow
    exit 1
}

# Check/create virtual environment
if (-not (Test-Path "venv")) {
    Write-Host "`nCreating virtual environment..." -ForegroundColor Yellow
    python -m venv venv
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to create virtual environment" -ForegroundColor Red
        exit 1
    }
    Write-Host "✓ Virtual environment created" -ForegroundColor Green
}

# Activate virtual environment
Write-Host "`nActivating virtual environment..." -ForegroundColor Yellow
& ".\venv\Scripts\Activate.ps1"

# Install dependencies
if (Test-Path "requirements.txt") {
    Write-Host "`nChecking dependencies..." -ForegroundColor Yellow
    pip install -q -r requirements.txt
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Dependencies up to date" -ForegroundColor Green
    } else {
        Write-Host "WARNING: Some dependencies may not have installed correctly" -ForegroundColor Yellow
    }
}

# Build arguments for Python launcher
$args = @()

if ($Master) {
    $args += "--master"
}

if ($Status) {
    $args += "--status"
}

if ($Stop) {
    $args += "--stop"
}

if ($Category) {
    $args += "--category"
    $args += $Category
}

if ($Module) {
    $args += "--module"
    $args += $Module
}

# Launch system
Write-Host "`n════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan

if ($args.Count -eq 0) {
    Write-Host "Starting MEGA-EMPIRE System..." -ForegroundColor Green
    python launcher.py
} else {
    python launcher.py @args
}

# Check exit code
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "ERROR: System exited with error code $LASTEXITCODE" -ForegroundColor Red
    Write-Host "Check logs in Logs\ directory for details" -ForegroundColor Yellow
    exit $LASTEXITCODE
}

Write-Host "`n════════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "System stopped successfully" -ForegroundColor Green
Write-Host ""
