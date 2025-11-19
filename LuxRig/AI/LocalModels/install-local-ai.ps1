# ============================================================================
# LuxRig Local AI Installation Script
# Purpose: Install and configure LM Studio with local AI models
# Location: LuxRig/AI/LocalModels/install-local-ai.ps1
# ============================================================================

<#
.SYNOPSIS
    Installs and configures local AI models for LuxRig.

.DESCRIPTION
    This script sets up LM Studio or Ollama for running local AI models including:
    - Llama-2-7B (general purpose)
    - CodeLlama (code generation)
    - Mistral-7B (balanced performance)
    - Phi-2 (lightweight, fast)

.PARAMETER ModelProvider
    Choose between 'lmstudio', 'ollama', or 'both'

.PARAMETER Models
    Array of model names to install

.PARAMETER AutoStart
    Configure models to start automatically

.EXAMPLE
    .\install-local-ai.ps1 -ModelProvider ollama -Models llama2,mistral

.EXAMPLE
    .\install-local-ai.ps1 -ModelProvider lmstudio -AutoStart
#>

param(
    [ValidateSet('lmstudio', 'ollama', 'both')]
    [string]$ModelProvider = 'ollama',

    [string[]]$Models = @('llama2', 'mistral', 'codellama'),

    [switch]$AutoStart,

    [switch]$SkipDownload
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION
# ============================================================================

$Script:Config = @{
    OllamaURL = 'https://ollama.ai/download'
    LMStudioURL = 'https://lmstudio.ai'
    ModelsDir = Join-Path $PSScriptRoot 'models'
    ConfigFile = Join-Path $PSScriptRoot 'local-ai-config.json'
    DefaultPort = 11434
    MaxMemoryMB = 8192
    AvailableModels = @{
        llama2 = @{
            Name = 'llama2:7b'
            Size = '3.8GB'
            Description = 'General purpose conversational model'
            UseCase = 'Content generation, Q&A'
        }
        mistral = @{
            Name = 'mistral:7b'
            Size = '4.1GB'
            Description = 'Balanced performance and quality'
            UseCase = 'Mixed tasks, content creation'
        }
        codellama = @{
            Name = 'codellama:7b'
            Size = '3.8GB'
            Description = 'Code generation and understanding'
            UseCase = 'Code generation, debugging'
        }
        phi = @{
            Name = 'phi:2'
            Size = '1.6GB'
            Description = 'Lightweight, fast responses'
            UseCase = 'Quick queries, low memory'
        }
        'neural-chat' = @{
            Name = 'neural-chat:7b'
            Size = '4.1GB'
            Description = 'Optimized for chat applications'
            UseCase = 'Conversational AI'
        }
    }
}

# ============================================================================
# LOGGING
# ============================================================================

function Write-AILog {
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

    Write-Host "[$timestamp] [AI-SETUP] [$Level] $Message" -ForegroundColor $color

    $logPath = Join-Path $PSScriptRoot '../../Logs/ai-setup.log'
    if (Test-Path (Split-Path $logPath)) {
        "[$timestamp] [$Level] $Message" | Add-Content -Path $logPath -ErrorAction SilentlyContinue
    }
}

# ============================================================================
# SYSTEM CHECKS
# ============================================================================

function Test-SystemRequirements {
    Write-AILog -Level INFO -Message "Checking system requirements..."

    $requirements = @{
        RAM = $true
        Disk = $true
        CPU = $true
    }

    # Check RAM
    if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT') {
        $ram = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB
    }
    else {
        $ram = (Get-Content /proc/meminfo | Select-String 'MemTotal' | ForEach-Object { ($_ -split '\s+')[1] }) / 1MB
    }

    if ($ram -lt 8) {
        Write-AILog -Level WARNING -Message "Low RAM detected: $([math]::Round($ram, 1))GB. 8GB+ recommended."
        $requirements.RAM = $false
    }
    else {
        Write-AILog -Level SUCCESS -Message "RAM: $([math]::Round($ram, 1))GB"
    }

    # Check disk space
    $drive = (Get-Item $PSScriptRoot).PSDrive
    $freeSpace = $drive.Free / 1GB

    if ($freeSpace -lt 10) {
        Write-AILog -Level WARNING -Message "Low disk space: $([math]::Round($freeSpace, 1))GB. 10GB+ recommended."
        $requirements.Disk = $false
    }
    else {
        Write-AILog -Level SUCCESS -Message "Disk space: $([math]::Round($freeSpace, 1))GB available"
    }

    # Check CPU
    $cpuCores = if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT') {
        (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors
    }
    else {
        (Get-Content /proc/cpuinfo | Select-String 'processor' | Measure-Object).Count
    }

    Write-AILog -Level SUCCESS -Message "CPU Cores: $cpuCores"

    return $requirements
}

# ============================================================================
# OLLAMA INSTALLATION
# ============================================================================

function Test-OllamaInstalled {
    try {
        $result = ollama --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-AILog -Level SUCCESS -Message "Ollama is installed: $result"
            return $true
        }
    }
    catch {
        return $false
    }
    return $false
}

function Install-Ollama {
    Write-AILog -Level INFO -Message "Installing Ollama..."

    if (Test-OllamaInstalled) {
        Write-AILog -Level INFO -Message "Ollama is already installed"
        return $true
    }

    try {
        if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT') {
            Write-AILog -Level INFO -Message "Downloading Ollama for Windows..."
            $installerPath = Join-Path $env:TEMP 'OllamaSetup.exe'
            Invoke-WebRequest -Uri 'https://ollama.ai/download/OllamaSetup.exe' -OutFile $installerPath
            Start-Process -FilePath $installerPath -Wait
        }
        elseif ($IsMacOS) {
            Write-AILog -Level INFO -Message "Installing Ollama via Homebrew..."
            brew install ollama
        }
        else {
            Write-AILog -Level INFO -Message "Installing Ollama for Linux..."
            curl -fsSL https://ollama.ai/install.sh | sh
        }

        if (Test-OllamaInstalled) {
            Write-AILog -Level SUCCESS -Message "Ollama installed successfully"
            return $true
        }
        else {
            Write-AILog -Level ERROR -Message "Ollama installation verification failed"
            return $false
        }
    }
    catch {
        Write-AILog -Level ERROR -Message "Failed to install Ollama: $_"
        return $false
    }
}

function Start-OllamaService {
    Write-AILog -Level INFO -Message "Starting Ollama service..."

    try {
        # Start Ollama in background
        if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT') {
            Start-Process -FilePath 'ollama' -ArgumentList 'serve' -WindowStyle Hidden
        }
        else {
            Start-Process -FilePath 'ollama' -ArgumentList 'serve' -RedirectStandardOutput '/dev/null' -RedirectStandardError '/dev/null' &
        }

        Start-Sleep -Seconds 3

        # Test if service is running
        $testResult = Test-OllamaConnection

        if ($testResult) {
            Write-AILog -Level SUCCESS -Message "Ollama service is running"
            return $true
        }
        else {
            Write-AILog -Level WARNING -Message "Ollama service may not be running properly"
            return $false
        }
    }
    catch {
        Write-AILog -Level ERROR -Message "Failed to start Ollama service: $_"
        return $false
    }
}

function Test-OllamaConnection {
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:$($Script:Config.DefaultPort)/api/tags" -Method Get -TimeoutSec 5 -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Install-OllamaModel {
    param(
        [Parameter(Mandatory)]
        [string]$ModelName
    )

    Write-AILog -Level INFO -Message "Installing model: $ModelName"

    try {
        # Check if model info exists
        if (-not $Script:Config.AvailableModels.ContainsKey($ModelName)) {
            Write-AILog -Level WARNING -Message "Unknown model: $ModelName. Attempting to install anyway..."
            $fullModelName = $ModelName
        }
        else {
            $modelInfo = $Script:Config.AvailableModels[$ModelName]
            $fullModelName = $modelInfo.Name
            Write-AILog -Level INFO -Message "  Size: $($modelInfo.Size)"
            Write-AILog -Level INFO -Message "  Use case: $($modelInfo.UseCase)"
        }

        # Pull the model
        Write-AILog -Level INFO -Message "Downloading model (this may take several minutes)..."

        $pullProcess = Start-Process -FilePath 'ollama' -ArgumentList "pull $fullModelName" -Wait -NoNewWindow -PassThru

        if ($pullProcess.ExitCode -eq 0) {
            Write-AILog -Level SUCCESS -Message "Model installed: $fullModelName"
            return $true
        }
        else {
            Write-AILog -Level ERROR -Message "Failed to install model: $fullModelName"
            return $false
        }
    }
    catch {
        Write-AILog -Level ERROR -Message "Error installing model $ModelName : $_"
        return $false
    }
}

function Get-OllamaModels {
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:$($Script:Config.DefaultPort)/api/tags" -Method Get -ErrorAction Stop

        if ($response.models) {
            return $response.models | ForEach-Object {
                [PSCustomObject]@{
                    Name = $_.name
                    Size = [math]::Round($_.size / 1GB, 2)
                    Modified = $_.modified_at
                }
            }
        }

        return @()
    }
    catch {
        Write-AILog -Level ERROR -Message "Failed to get Ollama models: $_"
        return @()
    }
}

# ============================================================================
# MODEL INTERACTION
# ============================================================================

function Invoke-LocalAICompletion {
    <#
    .SYNOPSIS
        Sends a prompt to a local AI model and gets a response.

    .PARAMETER Model
        The model name to use

    .PARAMETER Prompt
        The prompt to send

    .PARAMETER Stream
        Stream the response

    .EXAMPLE
        Invoke-LocalAICompletion -Model 'llama2' -Prompt 'Write a blog post about crypto trading'
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Model,

        [Parameter(Mandatory)]
        [string]$Prompt,

        [switch]$Stream
    )

    try {
        $body = @{
            model = if ($Script:Config.AvailableModels.ContainsKey($Model)) {
                $Script:Config.AvailableModels[$Model].Name
            }
            else {
                $Model
            }
            prompt = $Prompt
            stream = $Stream.IsPresent
        } | ConvertTo-Json

        $response = Invoke-RestMethod -Uri "http://localhost:$($Script:Config.DefaultPort)/api/generate" `
            -Method Post `
            -Body $body `
            -ContentType 'application/json' `
            -ErrorAction Stop

        return $response.response
    }
    catch {
        Write-AILog -Level ERROR -Message "Failed to get AI completion: $_"
        return $null
    }
}

# ============================================================================
# CONFIGURATION MANAGEMENT
# ============================================================================

function Save-LocalAIConfiguration {
    param(
        [hashtable]$Config
    )

    try {
        $config = @{
            Provider = $ModelProvider
            ModelsInstalled = @()
            Port = $Script:Config.DefaultPort
            AutoStart = $AutoStart.IsPresent
            InstalledAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        }

        # Get installed models
        if (Test-OllamaConnection) {
            $installedModels = Get-OllamaModels
            $config.ModelsInstalled = $installedModels | ForEach-Object { $_.Name }
        }

        $config | ConvertTo-Json -Depth 10 | Set-Content -Path $Script:Config.ConfigFile -Encoding UTF8

        Write-AILog -Level SUCCESS -Message "Configuration saved to: $($Script:Config.ConfigFile)"
        return $true
    }
    catch {
        Write-AILog -Level ERROR -Message "Failed to save configuration: $_"
        return $false
    }
}

function Get-LocalAIConfiguration {
    if (Test-Path $Script:Config.ConfigFile) {
        return Get-Content $Script:Config.ConfigFile -Raw | ConvertFrom-Json
    }
    return $null
}

# ============================================================================
# AUTO-START CONFIGURATION
# ============================================================================

function Enable-AutoStart {
    Write-AILog -Level INFO -Message "Configuring auto-start..."

    try {
        if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT') {
            # Create startup script
            $startupScript = Join-Path $PSScriptRoot 'start-ollama.ps1'
            $scriptContent = @'
# Auto-start Ollama service
Start-Process -FilePath 'ollama' -ArgumentList 'serve' -WindowStyle Hidden
'@
            Set-Content -Path $startupScript -Value $scriptContent

            # Add to Windows startup
            $shell = New-Object -ComObject WScript.Shell
            $shortcut = $shell.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\Ollama.lnk")
            $shortcut.TargetPath = "powershell.exe"
            $shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$startupScript`""
            $shortcut.WindowStyle = 7  # Minimized
            $shortcut.Save()

            Write-AILog -Level SUCCESS -Message "Auto-start enabled (Windows Startup)"
        }
        elseif ($IsMacOS) {
            # Create LaunchAgent
            $plistPath = "$HOME/Library/LaunchAgents/com.luxrig.ollama.plist"
            $plistContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.luxrig.ollama</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/ollama</string>
        <string>serve</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
"@
            Set-Content -Path $plistPath -Value $plistContent
            launchctl load $plistPath

            Write-AILog -Level SUCCESS -Message "Auto-start enabled (LaunchAgent)"
        }
        else {
            # Create systemd service
            $servicePath = "$HOME/.config/systemd/user/ollama.service"
            New-Item -ItemType Directory -Path (Split-Path $servicePath) -Force | Out-Null

            $serviceContent = @"
[Unit]
Description=Ollama AI Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/ollama serve
Restart=always

[Install]
WantedBy=default.target
"@
            Set-Content -Path $servicePath -Value $serviceContent
            systemctl --user enable ollama
            systemctl --user start ollama

            Write-AILog -Level SUCCESS -Message "Auto-start enabled (systemd)"
        }

        return $true
    }
    catch {
        Write-AILog -Level ERROR -Message "Failed to enable auto-start: $_"
        return $false
    }
}

# ============================================================================
# MAIN INSTALLATION
# ============================================================================

function Start-LocalAIInstallation {
    Write-Host "`n" + ("=" * 70) -ForegroundColor Cyan
    Write-Host "  LUXRIG LOCAL AI INSTALLATION" -ForegroundColor Cyan
    Write-Host ("=" * 70) + "`n" -ForegroundColor Cyan

    $startTime = Get-Date

    # Step 1: System Requirements
    Write-Host "`n[STEP 1/5] Checking System Requirements..." -ForegroundColor Yellow
    $sysReq = Test-SystemRequirements

    # Step 2: Install Ollama
    if ($ModelProvider -in @('ollama', 'both')) {
        Write-Host "`n[STEP 2/5] Installing Ollama..." -ForegroundColor Yellow
        if (-not (Install-Ollama)) {
            Write-AILog -Level ERROR -Message "Failed to install Ollama"
            return $false
        }

        # Start Ollama service
        Start-OllamaService
    }

    # Step 3: Install Models
    if (-not $SkipDownload) {
        Write-Host "`n[STEP 3/5] Installing AI Models..." -ForegroundColor Yellow

        foreach ($model in $Models) {
            Install-OllamaModel -ModelName $model
        }
    }
    else {
        Write-Host "`n[STEP 3/5] Skipping model downloads (SkipDownload flag set)" -ForegroundColor Yellow
    }

    # Step 4: Test Models
    Write-Host "`n[STEP 4/5] Testing Installation..." -ForegroundColor Yellow

    if (Test-OllamaConnection) {
        $installedModels = Get-OllamaModels

        if ($installedModels.Count -gt 0) {
            Write-AILog -Level SUCCESS -Message "Found $($installedModels.Count) installed models"
            $installedModels | Format-Table -Property Name, Size, Modified -AutoSize
        }
        else {
            Write-AILog -Level WARNING -Message "No models installed yet"
        }
    }

    # Step 5: Save Configuration
    Write-Host "`n[STEP 5/5] Saving Configuration..." -ForegroundColor Yellow
    Save-LocalAIConfiguration

    # Enable auto-start if requested
    if ($AutoStart) {
        Enable-AutoStart
    }

    # Summary
    $duration = ((Get-Date) - $startTime).TotalSeconds

    Write-Host "`n" + ("=" * 70) -ForegroundColor Cyan
    Write-Host "  INSTALLATION COMPLETE!" -ForegroundColor Green
    Write-Host ("=" * 70) -ForegroundColor Cyan

    Write-Host "`nInstallation Duration: $([math]::Round($duration, 2)) seconds" -ForegroundColor Cyan
    Write-Host "Provider: $ModelProvider" -ForegroundColor Cyan
    Write-Host "Models Installed: $($Models.Count)" -ForegroundColor Cyan

    Write-Host "`nNext Steps:" -ForegroundColor Yellow
    Write-Host "  1. Test a model: Invoke-LocalAICompletion -Model 'llama2' -Prompt 'Hello!'" -ForegroundColor White
    Write-Host "  2. View models: Get-OllamaModels" -ForegroundColor White
    Write-Host "  3. API endpoint: http://localhost:$($Script:Config.DefaultPort)" -ForegroundColor White

    return $true
}

# ============================================================================
# EXECUTION
# ============================================================================

try {
    $result = Start-LocalAIInstallation

    if ($result) {
        exit 0
    }
    else {
        exit 1
    }
}
catch {
    Write-AILog -Level ERROR -Message "Fatal error: $_"
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}

# ============================================================================
# EXPORT FUNCTIONS
# ============================================================================

Export-ModuleMember -Function @(
    'Install-Ollama',
    'Start-OllamaService',
    'Test-OllamaConnection',
    'Install-OllamaModel',
    'Get-OllamaModels',
    'Invoke-LocalAICompletion',
    'Enable-AutoStart'
)
