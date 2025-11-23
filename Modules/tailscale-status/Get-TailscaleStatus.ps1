<#
.SYNOPSIS
    Checks Tailscale network status for all LuxRig devices

.DESCRIPTION
    Module #1: Tailscale Status Monitor
    - Checks Tailscale network connectivity
    - Lists all 5 devices (LuxRig, work PC, laptop, Chromebook, phone)
    - Shows online/offline status
    - Displays latency if connected
    - Outputs JSON for easy integration
    - Standalone - no dependencies on other modules

.OUTPUTS
    JSON object containing status of all Tailscale devices

.EXAMPLE
    .\Get-TailscaleStatus.ps1
    Returns JSON with all device statuses

.EXAMPLE
    .\Get-TailscaleStatus.ps1 | ConvertFrom-Json
    Returns PowerShell object for further processing

.NOTES
    Version: 1.0.0
    Author: OPUS-DLX AI Orchestration System
    Part of: LuxRig Passive Income Infrastructure
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$Pretty,

    [Parameter(Mandatory=$false)]
    [switch]$LogOutput
)

# Define expected devices in the Tailscale network
$ExpectedDevices = @(
    @{ Name = "LuxRig"; Hostname = "luxrig" },
    @{ Name = "Work PC"; Hostname = "workpc" },
    @{ Name = "Laptop"; Hostname = "laptop" },
    @{ Name = "Chromebook"; Hostname = "chromebook" },
    @{ Name = "Phone"; Hostname = "phone" }
)

function Test-TailscaleInstalled {
    <#
    .SYNOPSIS
        Checks if Tailscale CLI is installed and accessible
    #>
    try {
        $tailscaleCmd = Get-Command tailscale -ErrorAction SilentlyContinue
        return $null -ne $tailscaleCmd
    }
    catch {
        return $false
    }
}

function Get-TailscaleServiceStatus {
    <#
    .SYNOPSIS
        Checks if Tailscale service is running
    #>
    try {
        $service = Get-Service -Name "Tailscale" -ErrorAction SilentlyContinue
        if ($service) {
            return @{
                Installed = $true
                Running = ($service.Status -eq 'Running')
                Status = $service.Status.ToString()
            }
        }
        return @{
            Installed = $false
            Running = $false
            Status = "Not Installed"
        }
    }
    catch {
        return @{
            Installed = $false
            Running = $false
            Status = "Error: $($_.Exception.Message)"
        }
    }
}

function Get-TailscaleNetworkStatus {
    <#
    .SYNOPSIS
        Retrieves status of all devices on Tailscale network
    #>
    try {
        # Run tailscale status command
        $statusOutput = & tailscale status --json 2>&1

        if ($LASTEXITCODE -ne 0) {
            throw "Tailscale status command failed: $statusOutput"
        }

        $statusData = $statusOutput | ConvertFrom-Json
        return $statusData
    }
    catch {
        Write-Error "Failed to get Tailscale status: $($_.Exception.Message)"
        return $null
    }
}

function Test-DeviceLatency {
    <#
    .SYNOPSIS
        Pings a Tailscale device to check latency
    #>
    param(
        [string]$DeviceIP,
        [int]$Timeout = 2
    )

    try {
        # Use tailscale ping for more accurate results
        $pingOutput = & tailscale ping --c 1 --timeout ${Timeout}s $DeviceIP 2>&1

        if ($pingOutput -match "pong from .* in (\d+(?:\.\d+)?)ms") {
            return @{
                Reachable = $true
                LatencyMs = [math]::Round([decimal]$matches[1], 2)
            }
        }

        # Fallback to regular ping if tailscale ping fails
        $ping = Test-Connection -ComputerName $DeviceIP -Count 1 -Quiet -TimeoutSeconds $Timeout

        if ($ping) {
            $pingResult = Test-Connection -ComputerName $DeviceIP -Count 1 -TimeoutSeconds $Timeout
            return @{
                Reachable = $true
                LatencyMs = $pingResult.ResponseTime
            }
        }

        return @{
            Reachable = $false
            LatencyMs = $null
        }
    }
    catch {
        return @{
            Reachable = $false
            LatencyMs = $null
            Error = $_.Exception.Message
        }
    }
}

function Build-DeviceStatusReport {
    <#
    .SYNOPSIS
        Builds comprehensive status report for all devices
    #>
    param(
        [object]$NetworkStatus
    )

    $deviceStatuses = @()
    $timestamp = Get-Date -Format "o"

    foreach ($device in $ExpectedDevices) {
        $deviceInfo = @{
            Name = $device.Name
            Hostname = $device.Hostname
            Status = "Unknown"
            Online = $false
            IPAddress = $null
            OS = $null
            TailscaleVersion = $null
            LastSeen = $null
            Latency = $null
            ExitNode = $false
        }

        # Search for device in Tailscale network status
        if ($NetworkStatus -and $NetworkStatus.Peer) {
            $peer = $NetworkStatus.Peer.PSObject.Properties |
                    Where-Object { $_.Value.HostName -like "*$($device.Hostname)*" } |
                    Select-Object -First 1

            if ($peer) {
                $peerData = $peer.Value
                $deviceInfo.Status = "Online"
                $deviceInfo.Online = $true
                $deviceInfo.IPAddress = $peerData.TailscaleIPs[0]
                $deviceInfo.OS = $peerData.OS
                $deviceInfo.TailscaleVersion = $peerData.TailscaleVersion
                $deviceInfo.LastSeen = $peerData.LastSeen
                $deviceInfo.ExitNode = $peerData.ExitNode -eq $true

                # Test latency if device is online
                if ($deviceInfo.IPAddress) {
                    $latencyTest = Test-DeviceLatency -DeviceIP $deviceInfo.IPAddress
                    if ($latencyTest.Reachable) {
                        $deviceInfo.Latency = @{
                            Value = $latencyTest.LatencyMs
                            Unit = "ms"
                        }
                    }
                }
            }
            else {
                $deviceInfo.Status = "Offline"
            }
        }
        else {
            $deviceInfo.Status = "No Network Data"
        }

        $deviceStatuses += $deviceInfo
    }

    return $deviceStatuses
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

try {
    # Initialize result object
    $result = @{
        Timestamp = Get-Date -Format "o"
        Module = "tailscale-status"
        Version = "1.0.0"
        TailscaleService = $null
        Network = @{
            Connected = $false
            SelfNode = $null
        }
        Devices = @()
        Summary = @{
            Total = $ExpectedDevices.Count
            Online = 0
            Offline = 0
            AverageLatency = $null
        }
        Status = "Success"
        Error = $null
    }

    # Check if Tailscale is installed
    if (-not (Test-TailscaleInstalled)) {
        $result.Status = "Error"
        $result.Error = "Tailscale CLI is not installed or not in PATH"
        $result.TailscaleService = @{
            Installed = $false
            Running = $false
            Status = "Not Found"
        }
    }
    else {
        # Get Tailscale service status
        $result.TailscaleService = Get-TailscaleServiceStatus

        # Get network status if service is running
        if ($result.TailscaleService.Running) {
            $networkStatus = Get-TailscaleNetworkStatus

            if ($networkStatus) {
                $result.Network.Connected = $true

                # Get self node information
                if ($networkStatus.Self) {
                    $result.Network.SelfNode = @{
                        Hostname = $networkStatus.Self.HostName
                        IPAddress = $networkStatus.Self.TailscaleIPs[0]
                        OS = $networkStatus.Self.OS
                        Online = $networkStatus.Self.Online
                    }
                }

                # Build device status report
                $result.Devices = Build-DeviceStatusReport -NetworkStatus $networkStatus

                # Calculate summary statistics
                $onlineDevices = $result.Devices | Where-Object { $_.Online -eq $true }
                $result.Summary.Online = $onlineDevices.Count
                $result.Summary.Offline = $result.Summary.Total - $result.Summary.Online

                # Calculate average latency for online devices
                $latencies = $onlineDevices |
                            Where-Object { $_.Latency -ne $null } |
                            ForEach-Object { $_.Latency.Value }

                if ($latencies.Count -gt 0) {
                    $result.Summary.AverageLatency = @{
                        Value = [math]::Round(($latencies | Measure-Object -Average).Average, 2)
                        Unit = "ms"
                    }
                }
            }
            else {
                $result.Network.Connected = $false
                $result.Status = "Warning"
                $result.Error = "Unable to retrieve network status from Tailscale"
            }
        }
        else {
            $result.Status = "Warning"
            $result.Error = "Tailscale service is not running"
        }
    }

    # Convert to JSON
    if ($Pretty) {
        $jsonOutput = $result | ConvertTo-Json -Depth 10
    }
    else {
        $jsonOutput = $result | ConvertTo-Json -Depth 10 -Compress
    }

    # Log output if requested
    if ($LogOutput) {
        $logDir = Join-Path $PSScriptRoot "logs"
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        $logFile = Join-Path $logDir "tailscale-status-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        $jsonOutput | Out-File -FilePath $logFile -Encoding utf8
        Write-Verbose "Log saved to: $logFile"
    }

    # Output JSON
    Write-Output $jsonOutput
}
catch {
    # Handle unexpected errors
    $errorResult = @{
        Timestamp = Get-Date -Format "o"
        Module = "tailscale-status"
        Version = "1.0.0"
        Status = "Error"
        Error = $_.Exception.Message
        StackTrace = $_.ScriptStackTrace
    }

    Write-Output ($errorResult | ConvertTo-Json -Depth 5 -Compress)
    exit 1
}
