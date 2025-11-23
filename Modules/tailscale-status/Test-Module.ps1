<#
.SYNOPSIS
    Test script for the tailscale-status module

.DESCRIPTION
    Demonstrates usage and validates the module functionality
    Run this after deploying to C:\LuxRig\ to verify everything works

.EXAMPLE
    .\Test-Module.ps1
#>

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "OPUS-DLX Module #1: Tailscale Status - Test Suite" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Check if script exists
Write-Host "[Test 1] Checking if Get-TailscaleStatus.ps1 exists..." -ForegroundColor Yellow
$scriptPath = Join-Path $PSScriptRoot "Get-TailscaleStatus.ps1"
if (Test-Path $scriptPath) {
    Write-Host "✓ Script found at: $scriptPath" -ForegroundColor Green
} else {
    Write-Host "✗ Script not found!" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Test 2: Check Tailscale installation
Write-Host "[Test 2] Checking Tailscale installation..." -ForegroundColor Yellow
$tailscaleCmd = Get-Command tailscale -ErrorAction SilentlyContinue
if ($tailscaleCmd) {
    Write-Host "✓ Tailscale CLI found at: $($tailscaleCmd.Source)" -ForegroundColor Green
} else {
    Write-Host "✗ Tailscale CLI not found in PATH" -ForegroundColor Red
    Write-Host "  Install from: https://tailscale.com/download" -ForegroundColor Yellow
}
Write-Host ""

# Test 3: Check Tailscale service
Write-Host "[Test 3] Checking Tailscale service status..." -ForegroundColor Yellow
try {
    $service = Get-Service -Name "Tailscale" -ErrorAction SilentlyContinue
    if ($service) {
        Write-Host "✓ Service status: $($service.Status)" -ForegroundColor Green
        if ($service.Status -ne 'Running') {
            Write-Host "  Warning: Service is not running" -ForegroundColor Yellow
            Write-Host "  Run: Start-Service Tailscale" -ForegroundColor Yellow
        }
    } else {
        Write-Host "✗ Tailscale service not found" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Error checking service: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 4: Run the module (basic)
Write-Host "[Test 4] Running module (compressed JSON)..." -ForegroundColor Yellow
try {
    $output = & $scriptPath
    $result = $output | ConvertFrom-Json

    Write-Host "✓ Module executed successfully" -ForegroundColor Green
    Write-Host "  Timestamp: $($result.Timestamp)" -ForegroundColor Cyan
    Write-Host "  Status: $($result.Status)" -ForegroundColor Cyan
    Write-Host "  Module Version: $($result.Version)" -ForegroundColor Cyan

    if ($result.Error) {
        Write-Host "  Error: $($result.Error)" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Module execution failed: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 5: Run with pretty output
Write-Host "[Test 5] Running module (pretty-printed JSON)..." -ForegroundColor Yellow
try {
    $prettyOutput = & $scriptPath -Pretty
    Write-Host "✓ Pretty output generated" -ForegroundColor Green
    Write-Host "  Output length: $($prettyOutput.Length) characters" -ForegroundColor Cyan
} catch {
    Write-Host "✗ Pretty output failed: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 6: Verify device summary
Write-Host "[Test 6] Checking device summary..." -ForegroundColor Yellow
try {
    $status = & $scriptPath | ConvertFrom-Json

    Write-Host "✓ Summary retrieved" -ForegroundColor Green
    Write-Host "  Total Devices: $($status.Summary.Total)" -ForegroundColor Cyan
    Write-Host "  Online: $($status.Summary.Online)" -ForegroundColor Green
    Write-Host "  Offline: $($status.Summary.Offline)" -ForegroundColor $(if ($status.Summary.Offline -eq 0) { "Green" } else { "Yellow" })

    if ($status.Summary.AverageLatency) {
        Write-Host "  Avg Latency: $($status.Summary.AverageLatency.Value)$($status.Summary.AverageLatency.Unit)" -ForegroundColor Cyan
    }
} catch {
    Write-Host "✗ Failed to retrieve summary: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 7: List all devices
Write-Host "[Test 7] Device status details..." -ForegroundColor Yellow
try {
    $status = & $scriptPath | ConvertFrom-Json

    foreach ($device in $status.Devices) {
        $color = if ($device.Online) { "Green" } else { "Red" }
        $statusIcon = if ($device.Online) { "✓" } else { "✗" }

        Write-Host "  $statusIcon $($device.Name) ($($device.Hostname))" -ForegroundColor $color

        if ($device.Online) {
            Write-Host "      IP: $($device.IPAddress)" -ForegroundColor Gray
            if ($device.Latency) {
                Write-Host "      Latency: $($device.Latency.Value)$($device.Latency.Unit)" -ForegroundColor Gray
            }
            Write-Host "      OS: $($device.OS)" -ForegroundColor Gray
        } else {
            Write-Host "      Status: $($device.Status)" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "✗ Failed to list devices: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 8: Test log output
Write-Host "[Test 8] Testing log output..." -ForegroundColor Yellow
try {
    $null = & $scriptPath -LogOutput -Verbose 2>&1

    $logDir = Join-Path $PSScriptRoot "logs"
    if (Test-Path $logDir) {
        $logFiles = Get-ChildItem $logDir -Filter "tailscale-status-*.json"
        if ($logFiles.Count -gt 0) {
            Write-Host "✓ Log files created: $($logFiles.Count) file(s)" -ForegroundColor Green
            $latestLog = $logFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            Write-Host "  Latest: $($latestLog.Name) ($($latestLog.Length) bytes)" -ForegroundColor Cyan
        } else {
            Write-Host "⚠ Log directory exists but no log files found" -ForegroundColor Yellow
        }
    } else {
        Write-Host "⚠ Log directory not created" -ForegroundColor Yellow
    }
} catch {
    Write-Host "✗ Log test failed: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Summary
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Module: tailscale-status v1.0.0" -ForegroundColor White
Write-Host "Location: $PSScriptRoot" -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Ensure all devices are connected to Tailscale" -ForegroundColor White
Write-Host "2. Verify device hostnames match configuration" -ForegroundColor White
Write-Host "3. Integrate with OPUS-DLX orchestrator" -ForegroundColor White
Write-Host "4. Set up scheduled monitoring (optional)" -ForegroundColor White
Write-Host ""
Write-Host "For full documentation, see README.md" -ForegroundColor Cyan
Write-Host ""
