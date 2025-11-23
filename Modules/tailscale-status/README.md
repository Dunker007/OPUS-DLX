# Module #1: Tailscale Status Monitor

## Overview

The **tailscale-status** module provides real-time monitoring of your Tailscale VPN network across all LuxRig devices. It's designed to be a foundational monitoring tool for the OPUS-DLX AI orchestration system.

## Features

- ✅ **Network Health Check** - Verifies Tailscale service is running
- ✅ **Device Discovery** - Lists all 5 expected devices (LuxRig, Work PC, Laptop, Chromebook, Phone)
- ✅ **Online/Offline Status** - Real-time connectivity status for each device
- ✅ **Latency Monitoring** - Measures network latency for connected devices
- ✅ **JSON Output** - Structured data format for easy integration with other modules
- ✅ **Standalone** - No dependencies on other OPUS-DLX modules

## Device List

The module monitors these devices:

1. **LuxRig** - Main server (hostname: `luxrig`)
2. **Work PC** - Work desktop (hostname: `workpc`)
3. **Laptop** - Mobile workstation (hostname: `laptop`)
4. **Chromebook** - Lightweight device (hostname: `chromebook`)
5. **Phone** - Mobile device (hostname: `phone`)

## Installation

### On Windows (LuxRig)

1. Copy this module to `C:\LuxRig\Modules\tailscale-status\`
2. Ensure Tailscale is installed and running
3. Run PowerShell as Administrator (for service checks)

### Prerequisites

- **Tailscale** installed and configured
- **PowerShell 5.1+** (Windows) or **PowerShell Core 7+** (cross-platform)
- Tailscale CLI accessible in PATH

## Usage

### Basic Usage

```powershell
# Run from module directory
cd C:\LuxRig\Modules\tailscale-status
.\Get-TailscaleStatus.ps1
```

### Pretty-Printed Output

```powershell
.\Get-TailscaleStatus.ps1 -Pretty
```

### Save to Log File

```powershell
.\Get-TailscaleStatus.ps1 -LogOutput -Verbose
```

### Parse JSON in PowerShell

```powershell
$status = .\Get-TailscaleStatus.ps1 | ConvertFrom-Json

# Check if all devices are online
$status.Summary.Online -eq 5

# Get latency for specific device
$luxrig = $status.Devices | Where-Object { $_.Name -eq "LuxRig" }
Write-Host "LuxRig latency: $($luxrig.Latency.Value)ms"

# List offline devices
$status.Devices | Where-Object { -not $_.Online } | Select-Object Name, Status
```

### Integration with Other Modules

```powershell
# Example: Check connectivity before running AI tasks
$status = .\Get-TailscaleStatus.ps1 | ConvertFrom-Json

if ($status.TailscaleService.Running -and $status.Summary.Online -ge 3) {
    Write-Host "Network healthy, proceeding with AI orchestration..."
    # Run other OPUS-DLX modules
} else {
    Write-Warning "Network issues detected. Online devices: $($status.Summary.Online)/5"
}
```

## Output Format

### Success Response

```json
{
  "Timestamp": "2024-11-23T12:34:56.789Z",
  "Module": "tailscale-status",
  "Version": "1.0.0",
  "TailscaleService": {
    "Installed": true,
    "Running": true,
    "Status": "Running"
  },
  "Network": {
    "Connected": true,
    "SelfNode": {
      "Hostname": "luxrig",
      "IPAddress": "100.64.1.1",
      "OS": "windows",
      "Online": true
    }
  },
  "Devices": [
    {
      "Name": "LuxRig",
      "Hostname": "luxrig",
      "Status": "Online",
      "Online": true,
      "IPAddress": "100.64.1.1",
      "OS": "windows",
      "TailscaleVersion": "1.54.0",
      "LastSeen": "2024-11-23T12:34:50Z",
      "Latency": {
        "Value": 1.2,
        "Unit": "ms"
      },
      "ExitNode": false
    },
    {
      "Name": "Work PC",
      "Hostname": "workpc",
      "Status": "Online",
      "Online": true,
      "IPAddress": "100.64.1.2",
      "OS": "windows",
      "Latency": {
        "Value": 15.8,
        "Unit": "ms"
      }
    }
  ],
  "Summary": {
    "Total": 5,
    "Online": 4,
    "Offline": 1,
    "AverageLatency": {
      "Value": 12.5,
      "Unit": "ms"
    }
  },
  "Status": "Success",
  "Error": null
}
```

### Error Response

```json
{
  "Timestamp": "2024-11-23T12:34:56.789Z",
  "Module": "tailscale-status",
  "Version": "1.0.0",
  "TailscaleService": {
    "Installed": false,
    "Running": false,
    "Status": "Not Found"
  },
  "Status": "Error",
  "Error": "Tailscale CLI is not installed or not in PATH"
}
```

## Configuration

### Customizing Device List

Edit the `$ExpectedDevices` array in `Get-TailscaleStatus.ps1`:

```powershell
$ExpectedDevices = @(
    @{ Name = "LuxRig"; Hostname = "luxrig" },
    @{ Name = "Work PC"; Hostname = "workpc" },
    @{ Name = "Laptop"; Hostname = "laptop" },
    @{ Name = "Chromebook"; Hostname = "chromebook" },
    @{ Name = "Phone"; Hostname = "phone" }
    # Add more devices as needed
)
```

### Adjusting Ping Timeout

Modify the `Test-DeviceLatency` function's default timeout:

```powershell
function Test-DeviceLatency {
    param(
        [string]$DeviceIP,
        [int]$Timeout = 5  # Change from 2 to 5 seconds
    )
    # ...
}
```

## Troubleshooting

### "Tailscale CLI is not installed"

**Solution**: Install Tailscale and ensure the CLI is in your PATH
```powershell
# Check if tailscale is accessible
Get-Command tailscale
```

### "Tailscale service is not running"

**Solution**: Start the Tailscale service
```powershell
Start-Service Tailscale
```

### Device Shows as Offline But Is Connected

**Possible causes**:
1. Hostname mismatch - Check device's actual Tailscale hostname
2. Device recently connected - Wait a few seconds and retry
3. Tailscale subnet routing issues

**Check actual hostnames**:
```powershell
tailscale status
```

### High Latency Values

**Normal ranges**:
- Same LAN: 1-5ms
- Same city: 5-20ms
- Same country: 20-100ms
- International: 100-300ms

## Automation

### Scheduled Monitoring (Windows Task Scheduler)

Create a scheduled task to run every 5 minutes:

```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-File C:\LuxRig\Modules\tailscale-status\Get-TailscaleStatus.ps1 -LogOutput"

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5)

Register-ScheduledTask -TaskName "OPUS-TailscaleMonitor" `
    -Action $action -Trigger $trigger -RunLevel Highest
```

### Continuous Monitoring Script

```powershell
# monitor-loop.ps1
while ($true) {
    $status = .\Get-TailscaleStatus.ps1 | ConvertFrom-Json

    if ($status.Summary.Offline -gt 0) {
        Write-Warning "$(Get-Date) - $($status.Summary.Offline) device(s) offline"
    }

    Start-Sleep -Seconds 60  # Check every minute
}
```

## Integration with OPUS-DLX

This module is designed to work seamlessly with the OPUS-DLX AI orchestration system:

### Pre-Task Connectivity Check

```powershell
# Example integration in task-router.ps1
function Invoke-AITask {
    # Check network status before routing to AI
    $netStatus = & C:\LuxRig\Modules\tailscale-status\Get-TailscaleStatus.ps1 | ConvertFrom-Json

    if (-not $netStatus.Network.Connected) {
        throw "Cannot route task: Network not connected"
    }

    # Proceed with AI task routing...
}
```

### Dashboard Integration

```powershell
# Example for Analytics dashboard
$metrics = @{
    Timestamp = Get-Date
    NetworkHealth = (& .\Modules\tailscale-status\Get-TailscaleStatus.ps1 | ConvertFrom-Json)
    # Other metrics...
}
```

## Future Enhancements

Planned features for v2.0:

- [ ] **Bandwidth monitoring** per device
- [ ] **Historical tracking** with trend analysis
- [ ] **Alert system** for device disconnections
- [ ] **Web dashboard** with real-time updates
- [ ] **Mobile notifications** via Pushover/Telegram
- [ ] **Auto-remediation** (restart service on failure)

## Version History

### v1.0.0 (2024-11-23)
- Initial release
- Core device monitoring
- Latency measurement
- JSON output format
- Standalone operation

## License

Part of the OPUS-DLX project. See main repository for license information.

## Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review Tailscale documentation
3. Check OPUS-DLX main repository issues

---

**Part of the LuxRig Passive Income Infrastructure**
*AI-Powered Opportunity Hunter - Module #1*
