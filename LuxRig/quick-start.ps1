#Requires -Version 7.0
<#
.SYNOPSIS
    LuxRig Quick Start
.DESCRIPTION
    Fast setup and launch script for new users
#>

Write-Host @"

╔══════════════════════════════════════════════════════╗
║                                                      ║
║              💎 LUXRIG QUICK START                   ║
║                                                      ║
║        Autonomous Wealth Generation System           ║
║                                                      ║
╚══════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

Write-Host "Initializing LuxRig...`n" -ForegroundColor Yellow

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "❌ PowerShell 7.0+ required. Current: $($PSVersionTable.PSVersion)" -ForegroundColor Red
    Write-Host "   Install: https://github.com/PowerShell/PowerShell`n" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ PowerShell $($PSVersionTable.PSVersion)" -ForegroundColor Green

# Check directory structure
$requiredDirs = @(
    "Trading/Exchanges",
    "Trading/Strategies",
    "Trading/Risk",
    "Charts",
    "AI/RL",
    "AI/Ensemble"
)

Write-Host "`nVerifying directory structure..." -ForegroundColor Cyan
$allGood = $true
foreach ($dir in $requiredDirs) {
    $path = Join-Path $PSScriptRoot $dir
    if (Test-Path $path) {
        Write-Host "  ✅ $dir" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $dir missing" -ForegroundColor Red
        $allGood = $false
    }
}

if (-not $allGood) {
    Write-Host "`n❌ Some directories missing. Re-download LuxRig.`n" -ForegroundColor Red
    exit 1
}

Write-Host "`n✅ All modules present`n" -ForegroundColor Green

# Quick config
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Gray
Write-Host "QUICK SETUP" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════`n" -ForegroundColor Gray

$mode = Read-Host @"
Select mode:
  1. Demo Mode (Paper trading, no API keys)
  2. Live Trading (Requires exchange API keys)

Choice
"@

if ($mode -eq "1") {
    Write-Host "`n🎮 Demo Mode Selected" -ForegroundColor Green
    Write-Host "   No API keys required. Using simulated data.`n" -ForegroundColor Cyan

    # Load config manager
    . "$PSScriptRoot/config-manager.ps1"
    Initialize-Config

    # Start demo
    Write-Host "Starting demo dashboard...`n" -ForegroundColor Cyan
    Start-Sleep 2

    . "$PSScriptRoot/master-control.ps1"
}
elseif ($mode -eq "2") {
    Write-Host "`n🔴 LIVE TRADING MODE" -ForegroundColor Red
    Write-Host "   ⚠️  Real money at risk!`n" -ForegroundColor Yellow

    $confirm = Read-Host "Continue? (yes/no)"
    if ($confirm -eq "yes") {
        # Run config wizard
        . "$PSScriptRoot/config-manager.ps1"
        Show-ConfigWizard

        # Start master control
        . "$PSScriptRoot/master-control.ps1"
    } else {
        Write-Host "`nSetup cancelled.`n" -ForegroundColor Yellow
    }
}
else {
    Write-Host "`nInvalid selection.`n" -ForegroundColor Red
}

Write-Host @"

═══════════════════════════════════════════════════════
LUXRIG DOCUMENTATION
═══════════════════════════════════════════════════════

Quick Commands:
  ./LuxRig/master-control.ps1    Master dashboard
  ./LuxRig/CLI/trader-cli.ps1    Command-line interface
  ./LuxRig/config-manager.ps1    Configuration

Strategies:
  Scalper  - High-frequency (100+ trades/day)
  Grid     - Range trading automation
  Swing    - 1-7 day holds (3-10% targets)
  DCA      - Smart dollar-cost averaging
  Arb      - Cross-exchange arbitrage
  AI       - Machine learning predictions

Risk Management:
  - Max 5% daily loss (default)
  - Position sizing via Kelly Criterion
  - Automatic stop-loss
  - Liquidation protection

Support:
  📖 Read: ./PHASE4_COMPLETE.md
  💬 Issues: https://github.com/yourusername/luxrig

═══════════════════════════════════════════════════════

"@ -ForegroundColor Gray

Write-Host "Happy trading! 💎`n" -ForegroundColor Cyan
