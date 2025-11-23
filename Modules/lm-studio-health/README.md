# Module #3: LM Studio Health Monitor

## Overview

The **lm-studio-health** module provides comprehensive health monitoring for LM Studio API and local AI model availability. It ensures your local AI infrastructure is ready before delegating tasks to the AI orchestration system.

## Features

- ✅ **Process Detection** - Checks if LM Studio is running
- ✅ **API Health Check** - Tests API endpoint connectivity and response time
- ✅ **Model Discovery** - Lists all loaded models
- ✅ **Primary Model Verification** - Confirms qwen2.5-vl-7b-instruct (or custom model) is ready
- ✅ **Performance Metrics** - Measures API response time
- ✅ **Health Status** - Provides overall status: healthy, degraded, or offline
- ✅ **JSON Output** - Structured data format for easy integration
- ✅ **Standalone** - No dependencies on other OPUS-DLX modules

## Use Cases

### 1. Pre-Task AI Validation
Check if local AI models are available before routing tasks to LM Studio.

### 2. Cost Optimization
Verify local models are ready to avoid unnecessary cloud API costs.

### 3. Service Monitoring
Continuous health monitoring with automated alerts.

### 4. Load Balancing
Route tasks between local and cloud models based on availability.

## Installation

### On Windows (LuxRig)

1. Copy this module to `C:\LuxRig\Modules\lm-studio-health\`
2. Ensure LM Studio is installed
3. Start LM Studio and load qwen2.5-vl-7b-instruct model

### Prerequisites

- **LM Studio** installed and configured
- **PowerShell 5.1+** (Windows) or **PowerShell Core 7+**
- Model loaded in LM Studio (default: qwen2.5-vl-7b-instruct)

## Usage

### Basic Usage

```powershell
# Check default endpoint (localhost:1234)
cd C:\LuxRig\Modules\lm-studio-health
.\Get-LMStudioHealth.ps1
```

### Pretty-Printed Output

```powershell
.\Get-LMStudioHealth.ps1 -Pretty
```

### Custom Endpoint

```powershell
.\Get-LMStudioHealth.ps1 -APIEndpoint "http://localhost:8080"
```

### Custom Primary Model

```powershell
.\Get-LMStudioHealth.ps1 -PrimaryModel "llama-3-8b-instruct"
```

### Save to Log

```powershell
.\Get-LMStudioHealth.ps1 -LogOutput -Verbose
```

### Parse JSON in PowerShell

```powershell
$health = .\Get-LMStudioHealth.ps1 | ConvertFrom-Json

# Check overall status
Write-Host "Status: $($health.Status)"

# Check if service is running
if (-not $health.ServiceRunning) {
    Write-Warning "LM Studio is not running!"
}

# Check API response time
if ($health.APIResponsive) {
    Write-Host "API response time: $($health.ResponseTimeMs)ms"
}

# Check primary model
if ($health.PrimaryModelReady) {
    Write-Host "✓ Primary model ready: $($health.PrimaryModel)"
} else {
    Write-Warning "Primary model not ready"
    Write-Host "Loaded models: $($health.ModelsLoaded -join ', ')"
}

# Check warnings
if ($health.Warnings.Count -gt 0) {
    Write-Warning "Issues detected:"
    $health.Warnings | ForEach-Object { Write-Host "  - $_" }
}
```

### Integration with AI Orchestration

```powershell
# Example: Route tasks based on LM Studio availability
$lmHealth = .\Get-LMStudioHealth.ps1 | ConvertFrom-Json

if ($lmHealth.Status -eq "healthy") {
    Write-Host "Using local LM Studio (cost: $0)"
    # Route task to LM Studio
    Invoke-LMStudioTask -Prompt $task
} else {
    Write-Host "Falling back to cloud API (cost: $$$)"
    # Route to Claude/GPT
    Invoke-CloudAI -Provider "anthropic" -Model "claude-sonnet-4" -Prompt $task
}
```

## Output Format

### Health Status Values

- **`healthy`** - LM Studio running, API responsive, primary model ready ✓
- **`degraded`** - LM Studio running but API issues or model not ready ⚠
- **`offline`** - LM Studio not running or completely unresponsive ✗

### Success Response (Healthy)

```json
{
  "Timestamp": "2024-11-23T12:34:56.789Z",
  "Module": "lm-studio-health",
  "Version": "1.0.0",
  "ServiceRunning": true,
  "Process": {
    "Running": true,
    "ProcessCount": 1,
    "Processes": [
      {
        "Name": "lmstudio",
        "Id": 12345,
        "StartTime": "2024-11-23T10:00:00Z",
        "WorkingSet": 2048.5
      }
    ]
  },
  "APIEndpoint": "http://localhost:1234",
  "APIResponsive": true,
  "APITest": {
    "Responsive": true,
    "ResponseTimeMs": 45.23,
    "StatusCode": 200,
    "Endpoint": "http://localhost:1234/v1/models"
  },
  "ResponseTimeMs": 45.23,
  "ModelsLoaded": [
    "qwen2.5-vl-7b-instruct"
  ],
  "ModelCount": 1,
  "PrimaryModel": "qwen2.5-vl-7b-instruct",
  "PrimaryModelAvailable": true,
  "PrimaryModelReady": true,
  "Status": "healthy",
  "LastCheck": "2024-11-23T12:34:56.789Z",
  "Error": null,
  "Warnings": []
}
```

### Degraded Response (Model Not Ready)

```json
{
  "Timestamp": "2024-11-23T12:34:56.789Z",
  "Module": "lm-studio-health",
  "Version": "1.0.0",
  "ServiceRunning": true,
  "APIResponsive": true,
  "ResponseTimeMs": 52.1,
  "ModelsLoaded": [
    "llama-3-8b-instruct"
  ],
  "ModelCount": 1,
  "PrimaryModel": "qwen2.5-vl-7b-instruct",
  "PrimaryModelAvailable": false,
  "PrimaryModelReady": false,
  "Status": "degraded",
  "Warnings": [
    "Primary model 'qwen2.5-vl-7b-instruct' is not loaded",
    "Available models: llama-3-8b-instruct"
  ]
}
```

### Offline Response

```json
{
  "Timestamp": "2024-11-23T12:34:56.789Z",
  "Module": "lm-studio-health",
  "Version": "1.0.0",
  "ServiceRunning": false,
  "APIEndpoint": "http://localhost:1234",
  "APIResponsive": false,
  "Status": "offline",
  "Error": "LM Studio process is not running"
}
```

## Troubleshooting

### "LM Studio process is not running"

**Solution**: Start LM Studio
```powershell
# Check if LM Studio is installed
Get-Command lmstudio -ErrorAction SilentlyContinue

# Start LM Studio (adjust path as needed)
Start-Process "C:\Users\$env:USERNAME\AppData\Local\LM-Studio\LM Studio.exe"
```

### "API endpoint is not responsive"

**Possible causes**:
1. LM Studio API server not started
2. Different port than 1234
3. Firewall blocking connection

**Solutions**:
```powershell
# Check which port LM Studio is using
netstat -ano | findstr :1234

# Test with custom port
.\Get-LMStudioHealth.ps1 -APIEndpoint "http://localhost:8080"

# Check firewall
Test-NetConnection -ComputerName localhost -Port 1234
```

### "Primary model is not loaded"

**Solution**: Load the model in LM Studio
1. Open LM Studio
2. Go to Models tab
3. Load qwen2.5-vl-7b-instruct
4. Wait for model to fully load
5. Re-run health check

### "Model found but not ready"

**Possible causes**:
1. Model still loading
2. Insufficient VRAM
3. Model corrupted

**Solutions**:
```powershell
# Wait a minute and retry
Start-Sleep -Seconds 60
.\Get-LMStudioHealth.ps1

# Check system resources
Get-Counter '\Memory\Available MBytes'
```

### High Response Time

**Normal ranges**:
- Cold start: 100-500ms
- Warm: 20-100ms
- Loaded model: <50ms

**If consistently slow**:
- Check system resources (CPU, RAM, GPU)
- Restart LM Studio
- Try smaller model

## Configuration

### Change Default Model

Edit the script or use parameter:

```powershell
# Via parameter
.\Get-LMStudioHealth.ps1 -PrimaryModel "llama-3-70b-instruct"

# Or edit the script default
# Line 32: [string]$PrimaryModel = "your-model-name"
```

### Change Default Endpoint

```powershell
# Via parameter
.\Get-LMStudioHealth.ps1 -APIEndpoint "http://192.168.1.100:1234"

# For remote LM Studio instance
.\Get-LMStudioHealth.ps1 -APIEndpoint "http://luxrig.tailscale-network:1234"
```

### Adjust Timeout

```powershell
# Increase timeout for slow networks
.\Get-LMStudioHealth.ps1 -Timeout 30
```

## Automation

### Scheduled Health Checks

```powershell
# Create scheduled task to check every 5 minutes
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-File C:\LuxRig\Modules\lm-studio-health\Get-LMStudioHealth.ps1 -LogOutput"

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5)

Register-ScheduledTask -TaskName "OPUS-LMStudioHealthCheck" `
    -Action $action -Trigger $trigger
```

### Auto-Restart on Failure

```powershell
# monitor-and-restart.ps1
while ($true) {
    $health = .\Get-LMStudioHealth.ps1 | ConvertFrom-Json

    if ($health.Status -eq "offline") {
        Write-Warning "LM Studio offline - attempting restart..."
        Start-Process "C:\Users\$env:USERNAME\AppData\Local\LM-Studio\LM Studio.exe"
        Start-Sleep -Seconds 60  # Wait for startup
    }

    Start-Sleep -Seconds 300  # Check every 5 minutes
}
```

### Alert on Degraded Status

```powershell
# alert-on-degraded.ps1
$health = .\Get-LMStudioHealth.ps1 | ConvertFrom-Json

if ($health.Status -ne "healthy") {
    # Send notification (customize as needed)
    $message = "LM Studio Status: $($health.Status)"
    if ($health.Warnings) {
        $message += "`nWarnings: $($health.Warnings -join '; ')"
    }

    # Example: Send to Discord webhook, email, etc.
    # Invoke-RestMethod -Uri $discordWebhook -Method Post -Body @{content=$message}

    Write-Warning $message
}
```

## Integration with OPUS-DLX

### Task Router Integration

```powershell
# Example: Intelligent task routing based on LM Studio health
function Invoke-AITask {
    param($Prompt, $Complexity = "medium")

    # Check LM Studio health
    $lmHealth = & C:\LuxRig\Modules\lm-studio-health\Get-LMStudioHealth.ps1 | ConvertFrom-Json

    # Route based on health and complexity
    if ($lmHealth.Status -eq "healthy" -and $Complexity -in @("low", "medium")) {
        Write-Host "Routing to LM Studio (local)" -ForegroundColor Green
        return Invoke-LMStudioCompletion -Prompt $Prompt
    }
    else {
        Write-Host "Routing to cloud AI (premium)" -ForegroundColor Yellow
        return Invoke-CloudAI -Prompt $Prompt
    }
}
```

### Budget Manager Integration

```powershell
# Track cost savings from using local models
$lmHealth = .\Get-LMStudioHealth.ps1 | ConvertFrom-Json

if ($lmHealth.Status -eq "healthy") {
    # Calculate cost saved by using local model
    $cloudCostPer1KTokens = 0.003  # e.g., GPT-4
    $localCost = 0.0  # Free!

    $tokensSaved = 10000  # Example
    $costSaved = ($tokensSaved / 1000) * $cloudCostPer1KTokens

    Write-Host "Cost saved by using local LM Studio: $$$costSaved"
}
```

### Dashboard Integration

```powershell
# Add to Analytics dashboard
$dashboardData = @{
    Timestamp = Get-Date
    LMStudioHealth = (& .\Modules\lm-studio-health\Get-LMStudioHealth.ps1 | ConvertFrom-Json)
    # Other metrics...
}

# Display health indicator
$status = $dashboardData.LMStudioHealth.Status
$color = switch ($status) {
    "healthy" { "Green" }
    "degraded" { "Yellow" }
    "offline" { "Red" }
}

Write-Host "LM Studio: " -NoNewline
Write-Host $status.ToUpper() -ForegroundColor $color
```

## Performance Benchmarking

```powershell
# benchmark-lm-studio.ps1
$iterations = 10
$responseTimes = @()

for ($i = 1; $i -le $iterations; $i++) {
    Write-Host "Run $i/$iterations..." -NoNewline
    $health = .\Get-LMStudioHealth.ps1 | ConvertFrom-Json
    $responseTimes += $health.ResponseTimeMs
    Write-Host " $($health.ResponseTimeMs)ms"
    Start-Sleep -Seconds 1
}

$avg = ($responseTimes | Measure-Object -Average).Average
$min = ($responseTimes | Measure-Object -Minimum).Minimum
$max = ($responseTimes | Measure-Object -Maximum).Maximum

Write-Host "`nResults:"
Write-Host "  Average: $([math]::Round($avg, 2))ms"
Write-Host "  Min: $([math]::Round($min, 2))ms"
Write-Host "  Max: $([math]::Round($max, 2))ms"
```

## Exit Codes

The script returns different exit codes based on status:

- **0** - Healthy (all systems operational)
- **1** - Degraded (partial functionality)
- **2** - Offline (service not running)
- **99** - Error (unexpected failure)

Use in scripts:

```powershell
.\Get-LMStudioHealth.ps1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ LM Studio is healthy"
    # Proceed with local AI tasks
}
else {
    Write-Warning "LM Studio not ready (exit code: $LASTEXITCODE)"
    # Fall back to cloud AI
}
```

## Future Enhancements

Planned features for v2.0:

- [ ] **GPU utilization monitoring**
- [ ] **VRAM usage tracking**
- [ ] **Model switching automation**
- [ ] **Performance history tracking**
- [ ] **Multi-instance support**
- [ ] **Model download progress**
- [ ] **Inference speed benchmarking**
- [ ] **Automatic model recommendations**

## Version History

### v1.0.0 (2024-11-23)
- Initial release
- Process detection
- API health checking
- Model availability verification
- Response time measurement
- JSON output format
- Standalone operation

## License

Part of the OPUS-DLX project. See main repository for license information.

## Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review LM Studio documentation
3. Check OPUS-DLX main repository issues

---

**Part of the LuxRig Passive Income Infrastructure**
*AI-Powered Opportunity Hunter - Module #3*
