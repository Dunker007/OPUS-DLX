<#
.SYNOPSIS
    Tracks availability and status of all devices in distributed network

.DESCRIPTION
    Module #4: Device Tracker
    - Pings/checks reachability of each device
    - Checks if device is on Tailscale network
    - Verifies SSH/RDP accessibility (if applicable)
    - Tracks device role (build/plan/portable)
    - Lists available services on each device
    - Outputs JSON with device matrix
    - Standalone - no dependencies on other modules

.PARAMETER ConfigFile
    Path to devices.json configuration file (defaults to same directory)

.PARAMETER SkipServiceCheck
    Skip checking individual services (faster)

.PARAMETER Timeout
    Ping/connectivity timeout in seconds (default: 5)

.PARAMETER Pretty
    Pretty-print JSON output for readability

.PARAMETER LogOutput
    Save output to logs folder

.OUTPUTS
    JSON object containing all device statuses

.EXAMPLE
    .\Get-DeviceStatus.ps1
    Checks all devices from devices.json

.EXAMPLE
    .\Get-DeviceStatus.ps1 -Pretty
    Pretty-printed output

.EXAMPLE
    .\Get-DeviceStatus.ps1 -SkipServiceCheck
    Faster execution, skips service checks

.NOTES
    Version: 1.0.0
    Author: OPUS-DLX AI Orchestration System
    Part of: LuxRig Passive Income Infrastructure
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigFile,

    [Parameter(Mandatory=$false)]
    [switch]$SkipServiceCheck,

    [Parameter(Mandatory=$false)]
    [int]$Timeout = 5,

    [Parameter(Mandatory=$false)]
    [switch]$Pretty,

    [Parameter(Mandatory=$false)]
    [switch]$LogOutput
)

# Set default config file path
if (-not $ConfigFile) {
    $ConfigFile = Join-Path $PSScriptRoot "devices.json"
}

function Get-DeviceConfiguration {
    <#
    .SYNOPSIS
        Loads device configuration from JSON file
    #>
    param([string]$Path)

    try {
        if (-not (Test-Path $Path)) {
            throw "Configuration file not found: $Path"
        }

        $config = Get-Content $Path -Raw | ConvertFrom-Json
        return @{
            Success = $true
            Config = $config
        }
    }
    catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Test-DeviceReachability {
    <#
    .SYNOPSIS
        Tests if device is reachable via ping
    #>
    param(
        [string]$Target,
        [int]$TimeoutSeconds
    )

    try {
        Write-Verbose "Pinging $Target..."

        # Try ping
        $ping = Test-Connection -ComputerName $Target -Count 2 -Quiet -TimeoutSeconds $TimeoutSeconds

        if ($ping) {
            # Get detailed ping info
            $pingResult = Test-Connection -ComputerName $Target -Count 1 -TimeoutSeconds $TimeoutSeconds

            return @{
                Reachable = $true
                LatencyMs = $pingResult.ResponseTime
                Method = "ICMP"
            }
        }

        return @{
            Reachable = $false
            LatencyMs = $null
            Method = "ICMP"
            Error = "No response to ping"
        }
    }
    catch {
        return @{
            Reachable = $false
            LatencyMs = $null
            Method = "ICMP"
            Error = $_.Exception.Message
        }
    }
}

function Test-TailscalePresence {
    <#
    .SYNOPSIS
        Checks if device is on Tailscale network
    #>
    param([string]$DeviceName, [string]$TailscaleIP)

    try {
        # Check if tailscale command is available
        $tailscaleCmd = Get-Command tailscale -ErrorAction SilentlyContinue

        if (-not $tailscaleCmd) {
            return @{
                OnTailscale = $null
                CheckMethod = "unknown"
                Note = "Tailscale CLI not available"
            }
        }

        # Get tailscale status
        $tsStatus = & tailscale status --json 2>&1

        if ($LASTEXITCODE -eq 0) {
            $statusData = $tsStatus | ConvertFrom-Json

            # Search for device in peer list
            $found = $false
            foreach ($peer in $statusData.Peer.PSObject.Properties) {
                if ($peer.Value.HostName -like "*$DeviceName*" -or
                    $peer.Value.TailscaleIPs -contains $TailscaleIP) {
                    $found = $true
                    break
                }
            }

            return @{
                OnTailscale = $found
                CheckMethod = "tailscale-status"
            }
        }

        # Fallback: try to ping Tailscale IP
        if ($TailscaleIP) {
            $pingTest = Test-Connection -ComputerName $TailscaleIP -Count 1 -Quiet -TimeoutSeconds 2
            return @{
                OnTailscale = $pingTest
                CheckMethod = "ping-fallback"
            }
        }

        return @{
            OnTailscale = $false
            CheckMethod = "failed"
        }
    }
    catch {
        return @{
            OnTailscale = $null
            CheckMethod = "error"
            Error = $_.Exception.Message
        }
    }
}

function Test-ServiceAvailability {
    <#
    .SYNOPSIS
        Tests if a service is available on the device
    #>
    param(
        [string]$DeviceIP,
        [string]$ServiceName,
        [int]$TimeoutSeconds
    )

    try {
        # Service port mappings
        $servicePorts = @{
            "RDP" = 3389
            "SSH" = 22
            "LM-Studio" = 1234
            "HTTP" = 80
            "HTTPS" = 443
            "Git" = 9418
            "Antigravity" = 8080  # Example port
        }

        if (-not $servicePorts.ContainsKey($ServiceName)) {
            return @{
                Available = $null
                Note = "Unknown service port"
            }
        }

        $port = $servicePorts[$ServiceName]

        # Test port connectivity
        $testResult = Test-NetConnection -ComputerName $DeviceIP `
                                         -Port $port `
                                         -WarningAction SilentlyContinue `
                                         -InformationLevel Quiet `
                                         -ErrorAction Stop

        return @{
            Available = $testResult
            Port = $port
        }
    }
    catch {
        return @{
            Available = $false
            Port = $servicePorts[$ServiceName]
            Error = $_.Exception.Message
        }
    }
}

function Get-DeviceDetails {
    <#
    .SYNOPSIS
        Gets detailed information about a device
    #>
    param(
        [object]$DeviceConfig,
        [int]$TimeoutSeconds,
        [bool]$CheckServices
    )

    try {
        $deviceInfo = @{
            Name = $DeviceConfig.name
            Role = $DeviceConfig.role
            Hostname = $DeviceConfig.hostname
            TailscaleIP = $DeviceConfig.tailscaleIP
            ExpectedServices = $DeviceConfig.services
            Reachable = $false
            OnTailscale = $null
            IPAddress = $null
            LatencyMs = $null
            Services = @()
            LastSeen = $null
            Status = "offline"
        }

        # Determine target for reachability check
        $target = $DeviceConfig.tailscaleIP
        if (-not $target) {
            $target = $DeviceConfig.hostname
        }
        if (-not $target) {
            $target = $DeviceConfig.name
        }

        # Test reachability
        Write-Verbose "Checking reachability for $($DeviceConfig.name)..."
        $reachTest = Test-DeviceReachability -Target $target -TimeoutSeconds $TimeoutSeconds

        $deviceInfo.Reachable = $reachTest.Reachable
        $deviceInfo.LatencyMs = $reachTest.LatencyMs

        if ($reachTest.Reachable) {
            $deviceInfo.Status = "online"
            $deviceInfo.IPAddress = $DeviceConfig.tailscaleIP -or $target
            $deviceInfo.LastSeen = Get-Date -Format "o"

            # Check Tailscale presence
            if ($DeviceConfig.tailscaleIP) {
                Write-Verbose "Checking Tailscale presence for $($DeviceConfig.name)..."
                $tsCheck = Test-TailscalePresence -DeviceName $DeviceConfig.name `
                                                   -TailscaleIP $DeviceConfig.tailscaleIP
                $deviceInfo.OnTailscale = $tsCheck.OnTailscale
            }

            # Check services
            if ($CheckServices -and $DeviceConfig.services) {
                Write-Verbose "Checking services for $($DeviceConfig.name)..."

                $serviceResults = @()

                foreach ($service in $DeviceConfig.services) {
                    $serviceCheck = Test-ServiceAvailability -DeviceIP $deviceInfo.IPAddress `
                                                              -ServiceName $service `
                                                              -TimeoutSeconds $TimeoutSeconds

                    $serviceResults += @{
                        Name = $service
                        Available = $serviceCheck.Available
                        Port = $serviceCheck.Port
                    }
                }

                $deviceInfo.Services = $serviceResults
            }
            else {
                # Just list expected services without checking
                $deviceInfo.Services = $DeviceConfig.services | ForEach-Object {
                    @{ Name = $_; Available = $null }
                }
            }
        }
        else {
            $deviceInfo.Status = "offline"

            # Try to load last seen from cache (if implemented)
            # For now, just mark as offline
            $deviceInfo.Services = $DeviceConfig.services | ForEach-Object {
                @{ Name = $_; Available = $false }
            }
        }

        return $deviceInfo
    }
    catch {
        return @{
            Name = $DeviceConfig.name
            Role = $DeviceConfig.role
            Status = "error"
            Error = $_.Exception.Message
        }
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

try {
    # Initialize result object
    $result = @{
        Timestamp = Get-Date -Format "o"
        Module = "device-tracker"
        Version = "1.0.0"
        ConfigFile = $ConfigFile
        Devices = @()
        Summary = @{
            Total = 0
            Online = 0
            Offline = 0
            Degraded = 0
        }
        Network = @{
            TailscaleAvailable = $false
        }
        Status = "Success"
        Error = $null
        Warnings = @()
    }

    # Load device configuration
    Write-Verbose "Loading device configuration from: $ConfigFile"
    $configResult = Get-DeviceConfiguration -Path $ConfigFile

    if (-not $configResult.Success) {
        $result.Status = "Error"
        $result.Error = $configResult.Error
    }
    else {
        $config = $configResult.Config

        # Check if Tailscale is available
        $tailscaleCmd = Get-Command tailscale -ErrorAction SilentlyContinue
        $result.Network.TailscaleAvailable = $null -ne $tailscaleCmd

        # Process each device
        $devices = $config.devices

        if (-not $devices) {
            $result.Status = "Error"
            $result.Error = "No devices found in configuration file"
        }
        else {
            $result.Summary.Total = $devices.Count

            Write-Verbose "Processing $($devices.Count) device(s)..."

            foreach ($deviceConfig in $devices) {
                $deviceInfo = Get-DeviceDetails -DeviceConfig $deviceConfig `
                                                 -TimeoutSeconds $Timeout `
                                                 -CheckServices (-not $SkipServiceCheck)

                $result.Devices += $deviceInfo

                # Update summary
                switch ($deviceInfo.Status) {
                    "online" { $result.Summary.Online++ }
                    "offline" { $result.Summary.Offline++ }
                    "degraded" { $result.Summary.Degraded++ }
                }
            }

            # Add warnings for offline critical devices
            $offlineCritical = $devices | Where-Object {
                $_.critical -eq $true -and
                ($result.Devices | Where-Object { $_.Name -eq $_.name -and $_.Status -eq "offline" })
            }

            foreach ($device in $offlineCritical) {
                $result.Warnings += "Critical device offline: $($device.name)"
            }
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
        $logFile = Join-Path $logDir "device-status-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
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
        Module = "device-tracker"
        Version = "1.0.0"
        ConfigFile = $ConfigFile
        Status = "Error"
        Error = $_.Exception.Message
        StackTrace = $_.ScriptStackTrace
    }

    Write-Output ($errorResult | ConvertTo-Json -Depth 5 -Compress)
    exit 1
}
