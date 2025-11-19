#Requires -Version 7.0
<#
.SYNOPSIS
    LuxRig Configuration Manager
.DESCRIPTION
    Centralized configuration management:
    - API key management
    - Strategy parameters
    - Risk limits
    - Exchange settings
#>

$script:ConfigFile = Join-Path $PSScriptRoot "config.json"

function Initialize-Config {
    $defaultConfig = @{
        Version = "1.0.0"
        Exchanges = @{
            Coinbase = @{ ApiKey = ""; ApiSecret = ""; Enabled = $false }
            Binance = @{ ApiKey = ""; ApiSecret = ""; Enabled = $false }
            Kraken = @{ ApiKey = ""; ApiSecret = ""; Enabled = $false }
            Bybit = @{ ApiKey = ""; ApiSecret = ""; Enabled = $false }
            OKX = @{ ApiKey = ""; ApiSecret = ""; Passphrase = ""; Enabled = $false }
        }
        Trading = @{
            MaxPositionSize = 0.10
            MaxLeverage = 10
            DefaultCommission = 0.001
            MaxDailyLoss = 0.05
            RiskPerTrade = 0.02
        }
        Strategies = @{
            Scalper = @{ Enabled = $false; Capital = 10000; Timeframe = "1m" }
            Grid = @{ Enabled = $false; Capital = 5000; Levels = 10 }
            Swing = @{ Enabled = $false; Capital = 10000; HoldDays = 7 }
            DCA = @{ Enabled = $false; BaseAmount = 100; Schedule = "Daily" }
            Arbitrage = @{ Enabled = $false; MinProfit = 0.005 }
            AIPredictor = @{ Enabled = $false; Confidence = 0.70 }
        }
        AI = @{
            ModelPath = "./models"
            RetrainingInterval = 100
            EnsembleMethod = "Weighted"
        }
        Monitoring = @{
            LogLevel = "Info"
            AlertEmail = ""
            SlackWebhook = ""
        }
    }

    if (-not (Test-Path $script:ConfigFile)) {
        $defaultConfig | ConvertTo-Json -Depth 10 | Out-File $script:ConfigFile
        Write-Host "✅ Config file created: $script:ConfigFile" -ForegroundColor Green
    }
}

function Get-Config {
    param([string]$Section = "", [string]$Key = "")

    if (-not (Test-Path $script:ConfigFile)) {
        Initialize-Config
    }

    $config = Get-Content $script:ConfigFile | ConvertFrom-Json -AsHashtable

    if ($Section -and $Key) {
        return $config[$Section][$Key]
    }
    elseif ($Section) {
        return $config[$Section]
    }

    return $config
}

function Set-Config {
    param(
        [Parameter(Mandatory)][string]$Section,
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)]$Value
    )

    $config = Get-Config

    if (-not $config.ContainsKey($Section)) {
        $config[$Section] = @{}
    }

    $config[$Section][$Key] = $Value
    $config | ConvertTo-Json -Depth 10 | Out-File $script:ConfigFile

    Write-Host "✅ Config updated: $Section.$Key = $Value" -ForegroundColor Green
}

function Set-ExchangeAPI {
    param(
        [Parameter(Mandatory)][ValidateSet("Coinbase","Binance","Kraken","Bybit","OKX")][string]$Exchange,
        [Parameter(Mandatory)][string]$ApiKey,
        [Parameter(Mandatory)][string]$ApiSecret,
        [string]$Passphrase = ""
    )

    $config = Get-Config

    $config.Exchanges[$Exchange].ApiKey = $ApiKey
    $config.Exchanges[$Exchange].ApiSecret = $ApiSecret
    if ($Passphrase) {
        $config.Exchanges[$Exchange].Passphrase = $Passphrase
    }
    $config.Exchanges[$Exchange].Enabled = $true

    $config | ConvertTo-Json -Depth 10 | Out-File $script:ConfigFile

    Write-Host "✅ $Exchange API configured" -ForegroundColor Green
}

function Enable-Strategy {
    param(
        [Parameter(Mandatory)][ValidateSet("Scalper","Grid","Swing","DCA","Arbitrage","AIPredictor")][string]$Strategy,
        [hashtable]$Parameters = @{}
    )

    $config = Get-Config

    $config.Strategies[$Strategy].Enabled = $true

    foreach ($key in $Parameters.Keys) {
        $config.Strategies[$Strategy][$key] = $Parameters[$key]
    }

    $config | ConvertTo-Json -Depth 10 | Out-File $script:ConfigFile

    Write-Host "✅ $Strategy strategy enabled" -ForegroundColor Green
}

function Show-ConfigWizard {
    Write-Host "`n╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║           🔧 LUXRIG SETUP WIZARD                     ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

    Initialize-Config

    # Exchange setup
    Write-Host "Configure Exchanges:`n" -ForegroundColor Yellow

    $setupExchanges = Read-Host "Configure exchanges now? (y/n)"
    if ($setupExchanges -eq 'y') {
        $exchanges = @("Coinbase", "Binance", "Kraken")
        foreach ($exchange in $exchanges) {
            $configure = Read-Host "`nConfigure $exchange? (y/n)"
            if ($configure -eq 'y') {
                $apiKey = Read-Host "  API Key"
                $apiSecret = Read-Host "  API Secret" -AsSecureString
                $apiSecretText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($apiSecret))

                Set-ExchangeAPI -Exchange $exchange -ApiKey $apiKey -ApiSecret $apiSecretText
            }
        }
    }

    # Risk limits
    Write-Host "`nRisk Management Settings:`n" -ForegroundColor Yellow
    $maxLoss = Read-Host "Max daily loss % (default: 5)"
    if ($maxLoss) {
        Set-Config -Section "Trading" -Key "MaxDailyLoss" -Value ([double]$maxLoss / 100)
    }

    Write-Host "`n✅ Setup complete! Run ./LuxRig/master-control.ps1 to start`n" -ForegroundColor Green
}

Export-ModuleMember -Function Initialize-Config, Get-Config, Set-Config, Set-ExchangeAPI, Enable-Strategy, Show-ConfigWizard

if ($MyInvocation.InvocationName -ne '.') {
    Show-ConfigWizard
}
