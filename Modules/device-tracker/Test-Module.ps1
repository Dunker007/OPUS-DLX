<#
.SYNOPSIS
    Test script for the device-tracker module

.DESCRIPTION
    Demonstrates usage and validates the module functionality
    Run this to verify everything works correctly

.EXAMPLE
    .\Test-Module.ps1
#>

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "OPUS-DLX Module #4: Device Tracker - Test Suite" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Check if script exists
Write-Host "[Test 1] Checking if Get-DeviceStatus.ps1 exists..." -ForegroundColor Yellow
$scriptPath = Join-Path $PSScriptRoot "Get-DeviceStatus.ps1"
if (Test-Path $scriptPath) {
    Write-Host "✓ Script found at: $scriptPath" -ForegroundColor Green
} else {
    Write-Host "✗ Script not found!" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Test 2: Check if devices.json exists
Write-Host "[Test 2] Checking for devices.json configuration..." -ForegroundColor Yellow
$configPath = Join-Path $PSScriptRoot "devices.json"
if (Test-Path $configPath) {
    Write-Host "✓ Configuration file found: $configPath" -ForegroundColor Green

    try {
        $config = Get-Content $configPath | ConvertFrom-Json
        Write-Host "  Devices configured: $($config.devices.Count)" -ForegroundColor Cyan

        foreach ($device in $config.devices) {
            Write-Host "    - $($device.name) ($($device.role))" -ForegroundColor Gray
        }
    } catch {
        Write-Host "✗ Failed to parse config: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "✗ Configuration file not found!" -ForegroundColor Red
    Write-Host "  Create devices.json with your device list" -ForegroundColor Yellow
}
Write-Host ""

# Test 3: Check network connectivity basics
Write-Host "[Test 3] Testing basic network connectivity..." -ForegroundColor Yellow
try {
    $localhostPing = Test-Connection -ComputerName localhost -Count 1 -Quiet
    if ($localhostPing) {
        Write-Host "✓ Local ping works" -ForegroundColor Green
    } else {
        Write-Host "⚠ Local ping failed" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠ Ping test error: $($_.Exception.Message)" -ForegroundColor Yellow
}
Write-Host ""

# Test 4: Check if Tailscale is available
Write-Host "[Test 4] Checking for Tailscale..." -ForegroundColor Yellow
$tailscaleCmd = Get-Command tailscale -ErrorAction SilentlyContinue
if ($tailscaleCmd) {
    Write-Host "✓ Tailscale CLI found" -ForegroundColor Green
    Write-Host "  Path: $($tailscaleCmd.Source)" -ForegroundColor Cyan

    try {
        $tsStatus = & tailscale status 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ Tailscale is connected" -ForegroundColor Green
        } else {
            Write-Host "  ⚠ Tailscale status check failed" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ⚠ Could not get Tailscale status" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠ Tailscale CLI not found" -ForegroundColor Yellow
    Write-Host "  Module will work without Tailscale" -ForegroundColor Gray
}
Write-Host ""

# Test 5: Run the module (basic)
Write-Host "[Test 5] Running module (compressed JSON)..." -ForegroundColor Yellow
try {
    $output = & $scriptPath
    $result = $output | ConvertFrom-Json

    Write-Host "✓ Module executed successfully" -ForegroundColor Green
    Write-Host "  Timestamp: $($result.Timestamp)" -ForegroundColor Cyan
    Write-Host "  Module Version: $($result.Version)" -ForegroundColor Cyan
    Write-Host "  Status: $($result.Status)" -ForegroundColor Cyan

    if ($result.Error) {
        Write-Host "  Error: $($result.Error)" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Module execution failed: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 6: Run with pretty output
Write-Host "[Test 6] Running module with pretty output..." -ForegroundColor Yellow
try {
    $prettyOutput = & $scriptPath -Pretty
    Write-Host "✓ Pretty output generated" -ForegroundColor Green
    Write-Host "  Output length: $($prettyOutput.Length) characters" -ForegroundColor Cyan
} catch {
    Write-Host "✗ Pretty output failed: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 7: Analyze device status
Write-Host "[Test 7] Analyzing device status..." -ForegroundColor Yellow
try {
    $deviceStatus = & $scriptPath | ConvertFrom-Json

    if ($deviceStatus.Status -eq "Success") {
        Write-Host "✓ Device status retrieved" -ForegroundColor Green

        # Summary
        Write-Host "`n  Network Summary:" -ForegroundColor Cyan
        Write-Host "    Total Devices: $($deviceStatus.Summary.Total)" -ForegroundColor White
        Write-Host "    Online: $($deviceStatus.Summary.Online)" -ForegroundColor Green
        Write-Host "    Offline: $($deviceStatus.Summary.Offline)" -ForegroundColor $(if ($deviceStatus.Summary.Offline -eq 0) { "Green" } else { "Yellow" })

        if ($deviceStatus.Summary.Degraded -gt 0) {
            Write-Host "    Degraded: $($deviceStatus.Summary.Degraded)" -ForegroundColor Yellow
        }

        # Device details
        Write-Host "`n  Device Status:" -ForegroundColor Cyan

        foreach ($device in $deviceStatus.Devices) {
            $statusIcon = if ($device.Reachable) { "✓" } else { "✗" }
            $statusColor = if ($device.Reachable) { "Green" } else { "Red" }

            Write-Host "    $statusIcon $($device.Name) [$($device.Role)]" -ForegroundColor $statusColor

            if ($device.Reachable) {
                Write-Host "        IP: $($device.IPAddress)" -ForegroundColor Gray
                if ($device.LatencyMs) {
                    Write-Host "        Latency: $($device.LatencyMs)ms" -ForegroundColor Gray
                }
                if ($device.OnTailscale -ne $null) {
                    $tsStatus = if ($device.OnTailscale) { "Yes" } else { "No" }
                    Write-Host "        Tailscale: $tsStatus" -ForegroundColor Gray
                }

                $availableServices = $device.Services | Where-Object { $_.Available -eq $true }
                if ($availableServices) {
                    Write-Host "        Services: $($availableServices.Name -join ', ')" -ForegroundColor Gray
                }
            } else {
                Write-Host "        Status: Offline" -ForegroundColor Gray
            }
        }

        # Warnings
        if ($deviceStatus.Warnings -and $deviceStatus.Warnings.Count -gt 0) {
            Write-Host "`n  Warnings:" -ForegroundColor Yellow
            foreach ($warning in $deviceStatus.Warnings) {
                Write-Host "    ⚠ $warning" -ForegroundColor Yellow
            }
        }

    } else {
        Write-Host "✗ Failed to retrieve device status" -ForegroundColor Red
        if ($deviceStatus.Error) {
            Write-Host "  Error: $($deviceStatus.Error)" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "✗ Failed to analyze device status: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 8: Test SkipServiceCheck flag
Write-Host "[Test 8] Testing -SkipServiceCheck flag (faster execution)..." -ForegroundColor Yellow
try {
    $startTime = Get-Date
    $null = & $scriptPath -SkipServiceCheck
    $duration = ((Get-Date) - $startTime).TotalMilliseconds

    Write-Host "✓ SkipServiceCheck mode works" -ForegroundColor Green
    Write-Host "  Execution time: $([math]::Round($duration, 0))ms" -ForegroundColor Cyan
} catch {
    Write-Host "✗ SkipServiceCheck test failed: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 9: Test log output
Write-Host "[Test 9] Testing log output..." -ForegroundColor Yellow
try {
    $null = & $scriptPath -LogOutput -Verbose 2>&1

    $logDir = Join-Path $PSScriptRoot "logs"
    if (Test-Path $logDir) {
        $logFiles = Get-ChildItem $logDir -Filter "device-status-*.json" -ErrorAction SilentlyContinue
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

# Test 10: JSON structure validation
Write-Host "[Test 10] Validating JSON structure..." -ForegroundColor Yellow
try {
    $status = & $scriptPath | ConvertFrom-Json

    $requiredProperties = @(
        "Timestamp", "Module", "Version", "Devices", "Summary"
    )

    $missingProperties = @()
    foreach ($prop in $requiredProperties) {
        if (-not ($status.PSObject.Properties.Name -contains $prop)) {
            $missingProperties += $prop
        }
    }

    if ($missingProperties.Count -eq 0) {
        Write-Host "✓ All required properties present" -ForegroundColor Green
        Write-Host "  Total properties: $($status.PSObject.Properties.Name.Count)" -ForegroundColor Cyan

        # Check devices array
        if ($status.Devices -and $status.Devices.Count -gt 0) {
            Write-Host "  ✓ Devices array populated: $($status.Devices.Count) device(s)" -ForegroundColor Green
        }

        # Check summary
        if ($status.Summary) {
            Write-Host "  ✓ Summary data present" -ForegroundColor Green
        }
    } else {
        Write-Host "✗ Missing properties: $($missingProperties -join ', ')" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ JSON validation failed: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Summary
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

$status = & $scriptPath | ConvertFrom-Json

Write-Host "Module: device-tracker v$($status.Version)" -ForegroundColor White
Write-Host "Location: $PSScriptRoot" -ForegroundColor White
Write-Host ""

Write-Host "Current Network Status:" -ForegroundColor Yellow
Write-Host "  Devices: $($status.Summary.Online)/$($status.Summary.Total) online" -ForegroundColor White

if ($status.Summary.Online -eq $status.Summary.Total) {
    Write-Host "  ✓ All devices reachable!" -ForegroundColor Green
} elseif ($status.Summary.Online -eq 0) {
    Write-Host "  ✗ No devices reachable" -ForegroundColor Red
} else {
    Write-Host "  ⚠ Partial connectivity" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Usage Examples:" -ForegroundColor Yellow
Write-Host ""
Write-Host "# Check all devices:" -ForegroundColor Gray
Write-Host '  .\Get-DeviceStatus.ps1 -Pretty' -ForegroundColor White
Write-Host ""
Write-Host "# Quick check (skip service tests):" -ForegroundColor Gray
Write-Host '  .\Get-DeviceStatus.ps1 -SkipServiceCheck' -ForegroundColor White
Write-Host ""
Write-Host "# Parse and filter:" -ForegroundColor Gray
Write-Host '  $status = .\Get-DeviceStatus.ps1 | ConvertFrom-Json' -ForegroundColor White
Write-Host '  $status.Devices | Where-Object { $_.Role -eq "build" }' -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Edit devices.json with your actual device IPs" -ForegroundColor White
Write-Host "2. Ensure Tailscale is configured on all devices" -ForegroundColor White
Write-Host "3. Test connectivity to each device manually" -ForegroundColor White
Write-Host "4. Integrate with OPUS-DLX orchestrator" -ForegroundColor White
Write-Host ""
Write-Host "For full documentation, see README.md" -ForegroundColor Cyan
Write-Host ""
