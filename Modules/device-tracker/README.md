# Module #4: Device Tracker

## Overview

The **device-tracker** module provides comprehensive monitoring of all devices in your distributed OPUS-DLX network. It tracks availability, connectivity, and service status across all 5 devices (LuxRig, Work PC, Laptop, Chromebook, Phone) to ensure your AI orchestration infrastructure is ready.

## Features

- ✅ **Reachability Testing** - Pings devices to check if they're online
- ✅ **Tailscale Integration** - Verifies devices are on VPN network
- ✅ **Service Monitoring** - Checks SSH, RDP, LM Studio, and other services
- ✅ **Role Tracking** - Identifies device roles (build/plan/portable)
- ✅ **Latency Measurement** - Measures network response times
- ✅ **Critical Device Alerts** - Warns when critical devices are offline
- ✅ **JSON Output** - Structured device matrix for integration
- ✅ **Standalone** - No dependencies on other OPUS-DLX modules

## Use Cases

### 1. Pre-Task Network Validation
Ensure all required devices are online before distributing AI tasks.

### 2. Distributed Task Routing
Route tasks only to online devices with available services.

### 3. High Availability Monitoring
Track device uptime and detect failures quickly.

### 4. Capacity Planning
Understand which devices are available for workload distribution.

## Installation

### On Windows (LuxRig)

1. Copy this module to `C:\LuxRig\Modules\device-tracker\`
2. Edit `devices.json` with your actual device details
3. Ensure Tailscale is configured on all devices

### Prerequisites

- **PowerShell 5.1+** (Windows) or **PowerShell Core 7+**
- **Network connectivity** to devices
- **Tailscale** (optional but recommended)
- **ICMP enabled** for ping checks

## Configuration

### Edit devices.json

Customize with your actual devices:

```json
{
  "devices": [
    {
      "name": "LuxRig",
      "hostname": "luxrig",
      "role": "build",
      "tailscaleIP": "100.64.1.1",
      "critical": true,
      "services": ["LM-Studio", "Git", "RDP"]
    }
  ]
}
```

**Important fields:**
- `name` - Friendly device name
- `hostname` - DNS hostname or IP
- `role` - build, plan, or portable
- `tailscaleIP` - Tailscale VPN IP address
- `critical` - If true, warns when offline
- `services` - Services to check (RDP, SSH, LM-Studio, etc.)

## Usage

### Basic Usage

```powershell
# Check all devices
cd C:\LuxRig\Modules\device-tracker
.\Get-DeviceStatus.ps1
```

### Pretty-Printed Output

```powershell
.\Get-DeviceStatus.ps1 -Pretty
```

### Skip Service Checks (Faster)

```powershell
# Only check ping/reachability, skip service port checks
.\Get-DeviceStatus.ps1 -SkipServiceCheck
```

### Custom Configuration File

```powershell
.\Get-DeviceStatus.ps1 -ConfigFile "C:\Custom\my-devices.json"
```

### Save to Log

```powershell
.\Get-DeviceStatus.ps1 -LogOutput -Verbose
```

### Parse JSON in PowerShell

```powershell
$deviceStatus = .\Get-DeviceStatus.ps1 | ConvertFrom-Json

# Check summary
Write-Host "Network Status: $($deviceStatus.Summary.Online)/$($deviceStatus.Summary.Total) devices online"

# List online devices
$onlineDevices = $deviceStatus.Devices | Where-Object { $_.Reachable -eq $true }
$onlineDevices | ForEach-Object {
    Write-Host "✓ $($_.Name) - $($_.Role) - $($_.LatencyMs)ms"
}

# List offline devices
$offlineDevices = $deviceStatus.Devices | Where-Object { $_.Reachable -eq $false }
if ($offlineDevices) {
    Write-Warning "Offline devices:"
    $offlineDevices | ForEach-Object {
        Write-Host "  ✗ $($_.Name) ($($_.Role))"
    }
}

# Check critical devices
$criticalOffline = $deviceStatus.Devices | Where-Object {
    $_.Status -eq "offline" -and
    ($deviceStatus.Devices | Where-Object { $_.Name -eq $_.Name }).critical -eq $true
}

if ($criticalOffline) {
    Write-Error "Critical device(s) offline!"
}

# Check specific device services
$luxrig = $deviceStatus.Devices | Where-Object { $_.Name -eq "LuxRig" }
if ($luxrig.Reachable) {
    $lmStudio = $luxrig.Services | Where-Object { $_.Name -eq "LM-Studio" }
    if ($lmStudio.Available) {
        Write-Host "✓ LuxRig LM Studio is available"
    }
}
```

### Integration with Task Routing

```powershell
# Example: Route AI task to available build device
$devices = .\Get-DeviceStatus.ps1 | ConvertFrom-Json

$buildDevices = $devices.Devices | Where-Object {
    $_.Role -eq "build" -and $_.Reachable -eq $true
}

if ($buildDevices.Count -gt 0) {
    $targetDevice = $buildDevices[0]
    Write-Host "Routing task to: $($targetDevice.Name)"
    # Execute task on target device
} else {
    Write-Warning "No build devices available"
    # Fallback to cloud or queue task
}
```

## Output Format

### Success Response

```json
{
  "Timestamp": "2024-11-23T12:34:56.789Z",
  "Module": "device-tracker",
  "Version": "1.0.0",
  "ConfigFile": "C:\\LuxRig\\Modules\\device-tracker\\devices.json",
  "Devices": [
    {
      "Name": "LuxRig",
      "Role": "build",
      "Hostname": "luxrig",
      "TailscaleIP": "100.64.1.1",
      "Reachable": true,
      "OnTailscale": true,
      "IPAddress": "100.64.1.1",
      "LatencyMs": 1.2,
      "Services": [
        {
          "Name": "LM-Studio",
          "Available": true,
          "Port": 1234
        },
        {
          "Name": "Git",
          "Available": true,
          "Port": 9418
        },
        {
          "Name": "RDP",
          "Available": true,
          "Port": 3389
        }
      ],
      "LastSeen": "2024-11-23T12:34:56.789Z",
      "Status": "online"
    },
    {
      "Name": "WorkPC",
      "Role": "plan",
      "Hostname": "workpc",
      "TailscaleIP": "100.64.1.2",
      "Reachable": false,
      "OnTailscale": null,
      "IPAddress": null,
      "LatencyMs": null,
      "Services": [
        {
          "Name": "Copilot-Agent",
          "Available": false
        }
      ],
      "LastSeen": null,
      "Status": "offline"
    }
  ],
  "Summary": {
    "Total": 5,
    "Online": 2,
    "Offline": 3,
    "Degraded": 0
  },
  "Network": {
    "TailscaleAvailable": true
  },
  "Status": "Success",
  "Error": null,
  "Warnings": []
}
```

## Device Roles

### build
High-performance machines for AI inference and code compilation
- **Expected Services**: LM-Studio, Git, Docker, RDP
- **Use Cases**: Local AI model execution, building projects, heavy compute tasks
- **Example**: LuxRig

### plan
Machines for strategic planning and code review
- **Expected Services**: Copilot-Agent, Git, RDP
- **Use Cases**: AI planning (cloud-based), documentation, code review
- **Example**: Work PC

### portable
Mobile devices for remote access and monitoring
- **Expected Services**: SSH, HTTP
- **Use Cases**: Remote management, monitoring dashboards, emergency access
- **Example**: Laptop, Chromebook, Phone

## Service Port Mappings

The module automatically checks these services:

| Service | Port | Description |
|---------|------|-------------|
| RDP | 3389 | Remote Desktop Protocol |
| SSH | 22 | Secure Shell |
| LM-Studio | 1234 | Local AI model API |
| HTTP | 80 | Web server |
| HTTPS | 443 | Secure web server |
| Git | 9418 | Git protocol |
| Antigravity | 8080 | Custom service (example) |

Add custom services by editing the `$servicePorts` hashtable in the script.

## Troubleshooting

### "Configuration file not found"

**Solution**: Create or specify the path to devices.json
```powershell
# Use default location
Copy-Item devices.json.example devices.json

# Or specify custom path
.\Get-DeviceStatus.ps1 -ConfigFile "C:\Custom\devices.json"
```

### All Devices Show as Offline

**Possible causes**:
1. ICMP (ping) is blocked by firewall
2. Incorrect IP addresses in devices.json
3. Devices are actually offline

**Solutions**:
```powershell
# Check if ping is working
Test-Connection -ComputerName 100.64.1.1 -Count 2

# Check if Tailscale is running
tailscale status

# Verify device IPs in devices.json match actual Tailscale IPs
tailscale status | Select-String "100.64"
```

### "Tailscale CLI not available"

**Solution**: This is just a warning, the module will still work
```powershell
# Install Tailscale if needed
# Or ignore warning - devices will still be checked via ping
```

### Service Shows as Unavailable

**Possible causes**:
1. Service not running on device
2. Firewall blocking port
3. Incorrect port in configuration

**Solutions**:
```powershell
# Test port manually
Test-NetConnection -ComputerName 100.64.1.1 -Port 1234

# Check if service is running on target device
# (Run on the target device)
Get-Process lmstudio  # for LM Studio
Get-Service TermService  # for RDP
```

### High Latency Values

**Normal ranges**:
- Same LAN: <5ms
- Tailscale (same region): 5-30ms
- Tailscale (cross-country): 30-100ms
- Mobile/4G: 50-200ms

## Automation

### Scheduled Monitoring

```powershell
# Check devices every 5 minutes
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-File C:\LuxRig\Modules\device-tracker\Get-DeviceStatus.ps1 -LogOutput"

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5)

Register-ScheduledTask -TaskName "OPUS-DeviceTracker" `
    -Action $action -Trigger $trigger
```

### Alert on Critical Device Failure

```powershell
# monitor-critical.ps1
$status = .\Get-DeviceStatus.ps1 | ConvertFrom-Json

if ($status.Warnings.Count -gt 0) {
    foreach ($warning in $status.Warnings) {
        Write-Warning $warning

        # Send alert (customize as needed)
        # Send-Email, Post to Discord, etc.
    }
}
```

### Track Device Uptime

```powershell
# uptime-tracker.ps1
$logFile = "C:\LuxRig\Analytics\device-uptime.csv"

while ($true) {
    $status = .\Get-DeviceStatus.ps1 | ConvertFrom-Json

    foreach ($device in $status.Devices) {
        $record = [PSCustomObject]@{
            Timestamp = $status.Timestamp
            Device = $device.Name
            Online = $device.Reachable
            Latency = $device.LatencyMs
        }

        $record | Export-Csv -Path $logFile -Append -NoTypeInformation
    }

    Start-Sleep -Seconds 300  # Every 5 minutes
}
```

## Integration with OPUS-DLX

### Pre-Task Device Check

```powershell
# Ensure required devices are online before running task
function Invoke-DistributedTask {
    param($Task, $RequiredRole = "build")

    $deviceStatus = & C:\LuxRig\Modules\device-tracker\Get-DeviceStatus.ps1 | ConvertFrom-Json

    $availableDevices = $deviceStatus.Devices | Where-Object {
        $_.Role -eq $RequiredRole -and $_.Reachable -eq $true
    }

    if ($availableDevices.Count -eq 0) {
        throw "No $RequiredRole devices available"
    }

    # Route task to first available device
    $target = $availableDevices[0]
    Write-Host "Routing to: $($target.Name)"

    # Execute task...
}
```

### Dashboard Integration

```powershell
# Add to Analytics dashboard
$metrics = @{
    Timestamp = Get-Date
    DeviceStatus = (& .\Modules\device-tracker\Get-DeviceStatus.ps1 | ConvertFrom-Json)
    # Other metrics...
}

# Display device grid
foreach ($device in $metrics.DeviceStatus.Devices) {
    $color = if ($device.Reachable) { "Green" } else { "Red" }
    $icon = if ($device.Reachable) { "✓" } else { "✗" }

    Write-Host "$icon $($device.Name) ($($device.Role))" -ForegroundColor $color
}
```

### Load Balancing

```powershell
# Distribute tasks across online build devices
$devices = .\Get-DeviceStatus.ps1 | ConvertFrom-Json

$buildDevices = $devices.Devices | Where-Object {
    $_.Role -eq "build" -and $_.Reachable -eq $true
} | Sort-Object LatencyMs

# Round-robin or latency-based distribution
foreach ($task in $tasks) {
    $targetDevice = $buildDevices[$taskIndex % $buildDevices.Count]
    Invoke-RemoteTask -Device $targetDevice.IPAddress -Task $task
    $taskIndex++
}
```

## Advanced Usage

### Custom Device Roles

Edit `devices.json` to add custom roles:

```json
{
  "roles": {
    "builder": { "description": "Custom build role" },
    "tester": { "description": "Testing devices" }
  }
}
```

### Multi-Network Support

Track devices across multiple networks:

```json
{
  "devices": [
    {
      "name": "CloudServer",
      "hostname": "server.example.com",
      "role": "cloud",
      "tailscaleIP": null,
      "services": ["HTTP", "HTTPS"]
    }
  ]
}
```

### Export Device Matrix

```powershell
# Create visual device matrix
$status = .\Get-DeviceStatus.ps1 | ConvertFrom-Json

$matrix = $status.Devices | ForEach-Object {
    [PSCustomObject]@{
        Device = $_.Name
        Role = $_.Role
        Status = if ($_.Reachable) { "●" } else { "○" }
        Latency = "$($_.LatencyMs)ms"
        Services = ($_.Services | Where-Object { $_.Available } | Select-Object -ExpandProperty Name) -join ", "
    }
}

$matrix | Format-Table -AutoSize
```

## Future Enhancements

Planned features for v2.0:

- [ ] **Performance history** (uptime statistics)
- [ ] **Automatic failover** (route to backup device)
- [ ] **Service dependency tracking**
- [ ] **Bandwidth monitoring**
- [ ] **Device capability scoring**
- [ ] **Alert thresholds** (configurable)
- [ ] **Web dashboard** for visualization
- [ ] **Device groups** and hierarchies

## Version History

### v1.0.0 (2024-11-23)
- Initial release
- Reachability testing via ping
- Tailscale network integration
- Service availability checking
- Role-based device tracking
- JSON output format
- Standalone operation

## License

Part of the OPUS-DLX project. See main repository for license information.

## Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Verify devices.json configuration
3. Check OPUS-DLX main repository issues

---

**Part of the LuxRig Passive Income Infrastructure**
*AI-Powered Opportunity Hunter - Module #4*
