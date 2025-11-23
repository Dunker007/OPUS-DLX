<#
.SYNOPSIS
    Monitors LM Studio API health and model availability

.DESCRIPTION
    Module #3: LM Studio Health Monitor
    - Checks if LM Studio process is running
    - Tests API endpoint (localhost:1234)
    - Lists loaded models
    - Verifies primary model (qwen2.5-vl-7b-instruct) availability
    - Measures API response time
    - Outputs JSON with health status
    - Standalone - no dependencies on other modules

.PARAMETER APIEndpoint
    LM Studio API endpoint (defaults to http://localhost:1234)

.PARAMETER PrimaryModel
    Expected primary model name (defaults to qwen2.5-vl-7b-instruct)

.PARAMETER Timeout
    API request timeout in seconds (default: 10)

.PARAMETER Pretty
    Pretty-print JSON output for readability

.PARAMETER LogOutput
    Save output to logs folder

.OUTPUTS
    JSON object containing LM Studio health status

.EXAMPLE
    .\Get-LMStudioHealth.ps1
    Checks default endpoint with default model

.EXAMPLE
    .\Get-LMStudioHealth.ps1 -Pretty
    Pretty-printed output

.EXAMPLE
    .\Get-LMStudioHealth.ps1 -APIEndpoint "http://localhost:8080" -PrimaryModel "custom-model"
    Custom endpoint and model

.NOTES
    Version: 1.0.0
    Author: OPUS-DLX AI Orchestration System
    Part of: LuxRig Passive Income Infrastructure
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$APIEndpoint = "http://localhost:1234",

    [Parameter(Mandatory=$false)]
    [string]$PrimaryModel = "qwen2.5-vl-7b-instruct",

    [Parameter(Mandatory=$false)]
    [int]$Timeout = 10,

    [Parameter(Mandatory=$false)]
    [switch]$Pretty,

    [Parameter(Mandatory=$false)]
    [switch]$LogOutput
)

function Test-LMStudioProcess {
    <#
    .SYNOPSIS
        Checks if LM Studio process is running
    #>
    try {
        # Common LM Studio process names
        $processNames = @("lmstudio", "lms", "LM Studio")

        $runningProcesses = @()

        foreach ($name in $processNames) {
            $processes = Get-Process -Name $name -ErrorAction SilentlyContinue
            if ($processes) {
                $runningProcesses += $processes
            }
        }

        if ($runningProcesses.Count -gt 0) {
            return @{
                Running = $true
                ProcessCount = $runningProcesses.Count
                Processes = $runningProcesses | ForEach-Object {
                    @{
                        Name = $_.ProcessName
                        Id = $_.Id
                        StartTime = $_.StartTime
                        WorkingSet = [math]::Round($_.WorkingSet64 / 1MB, 2)
                    }
                }
            }
        }

        return @{
            Running = $false
            ProcessCount = 0
            Processes = @()
        }
    }
    catch {
        return @{
            Running = $false
            ProcessCount = 0
            Processes = @()
            Error = $_.Exception.Message
        }
    }
}

function Test-APIEndpoint {
    <#
    .SYNOPSIS
        Tests if API endpoint is responsive
    #>
    param(
        [string]$Endpoint,
        [int]$TimeoutSeconds
    )

    try {
        $healthUrl = "$Endpoint/v1/models"

        Write-Verbose "Testing API endpoint: $healthUrl"

        $startTime = Get-Date

        # Test basic connectivity
        try {
            $response = Invoke-RestMethod -Uri $healthUrl -Method Get -TimeoutSec $TimeoutSeconds -ErrorAction Stop
            $endTime = Get-Date
            $responseTime = ($endTime - $startTime).TotalMilliseconds

            return @{
                Responsive = $true
                ResponseTimeMs = [math]::Round($responseTime, 2)
                StatusCode = 200
                Endpoint = $healthUrl
            }
        }
        catch {
            $endTime = Get-Date
            $responseTime = ($endTime - $startTime).TotalMilliseconds

            # Check if it's a timeout or connection refused
            if ($_.Exception.Message -match "timeout|timed out") {
                return @{
                    Responsive = $false
                    ResponseTimeMs = [math]::Round($responseTime, 2)
                    StatusCode = $null
                    Endpoint = $healthUrl
                    Error = "Request timeout after $TimeoutSeconds seconds"
                }
            }
            elseif ($_.Exception.Message -match "refused|unable to connect") {
                return @{
                    Responsive = $false
                    ResponseTimeMs = [math]::Round($responseTime, 2)
                    StatusCode = $null
                    Endpoint = $healthUrl
                    Error = "Connection refused - service may not be running"
                }
            }
            else {
                return @{
                    Responsive = $false
                    ResponseTimeMs = [math]::Round($responseTime, 2)
                    StatusCode = $null
                    Endpoint = $healthUrl
                    Error = $_.Exception.Message
                }
            }
        }
    }
    catch {
        return @{
            Responsive = $false
            ResponseTimeMs = $null
            StatusCode = $null
            Endpoint = $Endpoint
            Error = $_.Exception.Message
        }
    }
}

function Get-LoadedModels {
    <#
    .SYNOPSIS
        Gets list of loaded models from LM Studio API
    #>
    param(
        [string]$Endpoint,
        [int]$TimeoutSeconds
    )

    try {
        $modelsUrl = "$Endpoint/v1/models"

        Write-Verbose "Fetching models from: $modelsUrl"

        $response = Invoke-RestMethod -Uri $modelsUrl -Method Get -TimeoutSec $TimeoutSeconds -ErrorAction Stop

        $models = @()

        # Parse response - LM Studio uses OpenAI-compatible format
        if ($response.data) {
            foreach ($model in $response.data) {
                $models += @{
                    Id = $model.id
                    Object = $model.object
                    Created = $model.created
                    OwnedBy = $model.owned_by
                }
            }
        }
        elseif ($response.models) {
            # Alternative format
            foreach ($model in $response.models) {
                $models += @{
                    Id = $model.id -or $model.name
                    Object = "model"
                    Created = $null
                    OwnedBy = "lmstudio"
                }
            }
        }

        return @{
            Success = $true
            Count = $models.Count
            Models = $models
        }
    }
    catch {
        return @{
            Success = $false
            Count = 0
            Models = @()
            Error = $_.Exception.Message
        }
    }
}

function Test-ModelAvailability {
    <#
    .SYNOPSIS
        Checks if a specific model is loaded and ready
    #>
    param(
        [string]$Endpoint,
        [string]$ModelName,
        [int]$TimeoutSeconds
    )

    try {
        # First check if model is in the list
        $modelsResult = Get-LoadedModels -Endpoint $Endpoint -TimeoutSeconds $TimeoutSeconds

        if (-not $modelsResult.Success) {
            return @{
                Available = $false
                Ready = $false
                Error = "Failed to fetch models: $($modelsResult.Error)"
            }
        }

        # Check if model exists in loaded models
        $modelFound = $false
        foreach ($model in $modelsResult.Models) {
            if ($model.Id -eq $ModelName -or $model.Id -like "*$ModelName*") {
                $modelFound = $true
                break
            }
        }

        if (-not $modelFound) {
            return @{
                Available = $false
                Ready = $false
                LoadedModels = $modelsResult.Models.Id
            }
        }

        # Test model with a simple completion request
        try {
            $completionUrl = "$Endpoint/v1/completions"
            $body = @{
                model = $ModelName
                prompt = "test"
                max_tokens = 1
                temperature = 0
            } | ConvertTo-Json

            $testResponse = Invoke-RestMethod -Uri $completionUrl `
                                               -Method Post `
                                               -Body $body `
                                               -ContentType "application/json" `
                                               -TimeoutSec $TimeoutSeconds `
                                               -ErrorAction Stop

            return @{
                Available = $true
                Ready = $true
                ModelId = $ModelName
            }
        }
        catch {
            # Model is listed but not ready to serve requests
            return @{
                Available = $true
                Ready = $false
                ModelId = $ModelName
                Error = "Model found but not ready: $($_.Exception.Message)"
            }
        }
    }
    catch {
        return @{
            Available = $false
            Ready = $false
            Error = $_.Exception.Message
        }
    }
}

function Get-HealthStatus {
    <#
    .SYNOPSIS
        Determines overall health status
    #>
    param(
        [bool]$ProcessRunning,
        [bool]$APIResponsive,
        [bool]$PrimaryModelReady
    )

    if ($ProcessRunning -and $APIResponsive -and $PrimaryModelReady) {
        return "healthy"
    }
    elseif ($ProcessRunning -and $APIResponsive -and -not $PrimaryModelReady) {
        return "degraded"
    }
    elseif ($ProcessRunning -and -not $APIResponsive) {
        return "degraded"
    }
    else {
        return "offline"
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

try {
    # Initialize result object
    $result = @{
        Timestamp = Get-Date -Format "o"
        Module = "lm-studio-health"
        Version = "1.0.0"
        ServiceRunning = $false
        Process = $null
        APIEndpoint = $APIEndpoint
        APIResponsive = $false
        APITest = $null
        ResponseTimeMs = $null
        ModelsLoaded = @()
        ModelCount = 0
        PrimaryModel = $PrimaryModel
        PrimaryModelAvailable = $false
        PrimaryModelReady = $false
        Status = "offline"
        LastCheck = Get-Date -Format "o"
        Error = $null
        Warnings = @()
    }

    # Check if LM Studio process is running
    Write-Verbose "Checking LM Studio process..."
    $processCheck = Test-LMStudioProcess
    $result.Process = $processCheck
    $result.ServiceRunning = $processCheck.Running

    if (-not $processCheck.Running) {
        $result.Status = "offline"
        $result.Error = "LM Studio process is not running"
    }
    else {
        Write-Verbose "LM Studio process found: $($processCheck.ProcessCount) instance(s)"

        # Test API endpoint
        Write-Verbose "Testing API endpoint..."
        $apiTest = Test-APIEndpoint -Endpoint $APIEndpoint -TimeoutSeconds $Timeout
        $result.APITest = $apiTest
        $result.APIResponsive = $apiTest.Responsive
        $result.ResponseTimeMs = $apiTest.ResponseTimeMs

        if (-not $apiTest.Responsive) {
            $result.Status = "degraded"
            $result.Warnings += "API endpoint is not responsive: $($apiTest.Error)"
        }
        else {
            Write-Verbose "API responsive in $($apiTest.ResponseTimeMs)ms"

            # Get loaded models
            Write-Verbose "Fetching loaded models..."
            $modelsResult = Get-LoadedModels -Endpoint $APIEndpoint -TimeoutSeconds $Timeout

            if ($modelsResult.Success) {
                $result.ModelsLoaded = $modelsResult.Models | ForEach-Object { $_.Id }
                $result.ModelCount = $modelsResult.Count
                Write-Verbose "Found $($modelsResult.Count) loaded model(s)"
            }
            else {
                $result.Warnings += "Failed to fetch models: $($modelsResult.Error)"
            }

            # Test primary model
            if ($PrimaryModel) {
                Write-Verbose "Testing primary model: $PrimaryModel"
                $modelTest = Test-ModelAvailability -Endpoint $APIEndpoint `
                                                     -ModelName $PrimaryModel `
                                                     -TimeoutSeconds $Timeout

                $result.PrimaryModelAvailable = $modelTest.Available
                $result.PrimaryModelReady = $modelTest.Ready

                if (-not $modelTest.Available) {
                    $result.Warnings += "Primary model '$PrimaryModel' is not loaded"
                    if ($modelTest.LoadedModels) {
                        $result.Warnings += "Available models: $($modelTest.LoadedModels -join ', ')"
                    }
                }
                elseif ($modelTest.Available -and -not $modelTest.Ready) {
                    $result.Warnings += "Primary model is loaded but not ready: $($modelTest.Error)"
                }
            }

            # Determine overall status
            $result.Status = Get-HealthStatus -ProcessRunning $result.ServiceRunning `
                                               -APIResponsive $result.APIResponsive `
                                               -PrimaryModelReady $result.PrimaryModelReady
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
        $logFile = Join-Path $logDir "lm-studio-health-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        $jsonOutput | Out-File -FilePath $logFile -Encoding utf8
        Write-Verbose "Log saved to: $logFile"
    }

    # Output JSON
    Write-Output $jsonOutput

    # Exit code based on status
    switch ($result.Status) {
        "healthy" { exit 0 }
        "degraded" { exit 1 }
        "offline" { exit 2 }
        default { exit 3 }
    }
}
catch {
    # Handle unexpected errors
    $errorResult = @{
        Timestamp = Get-Date -Format "o"
        Module = "lm-studio-health"
        Version = "1.0.0"
        APIEndpoint = $APIEndpoint
        Status = "error"
        Error = $_.Exception.Message
        StackTrace = $_.ScriptStackTrace
    }

    Write-Output ($errorResult | ConvertTo-Json -Depth 5 -Compress)
    exit 99
}
