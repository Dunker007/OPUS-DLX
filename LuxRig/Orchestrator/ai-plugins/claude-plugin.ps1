<#
.SYNOPSIS
    Claude (Anthropic) AI Plugin for LuxRig Orchestrator

.DESCRIPTION
    Standardized interface for Claude Opus/Sonnet models
    - Handles authentication via API key
    - Tracks token usage and costs
    - Implements retry logic with exponential backoff
    - Returns standardized response format
    - Logs all requests for analytics

.NOTES
    Part of LuxRig Phase 1 Foundation
    Tier: 1 (Premium) - Strategic thinking, quality control
#>

# Plugin Configuration
$script:PluginName = "Claude"
$script:PluginVersion = "1.0.0"
$script:Tier = 1
$script:CostPer1KTokens = 0.015  # Claude Opus pricing

# Load configuration
function Get-ClaudeConfig {
    param(
        [string]$ConfigPath = "$PSScriptRoot\..\..\..\Configs\ai-models.json"
    )

    try {
        if (Test-Path $ConfigPath) {
            $config = Get-Content $ConfigPath | ConvertFrom-Json
            return $config.claude
        }

        # Fallback default config
        return @{
            model = "claude-opus-4-1"
            tier = 1
            monthly_budget = 100
            cost_per_1k_tokens = 0.015
            endpoint = "https://api.anthropic.com/v1/messages"
            rate_limits = @{
                requests_per_minute = 50
                tokens_per_minute = 100000
            }
        }
    }
    catch {
        Write-Warning "Failed to load Claude config: $_"
        return $null
    }
}

# Get API key from environment or config
function Get-ClaudeApiKey {
    param(
        [string]$KeyPath = "$PSScriptRoot\..\..\..\Configs\api-keys.json"
    )

    # Try environment variable first
    $apiKey = $env:ANTHROPIC_API_KEY

    # Try config file if env var not set
    if (-not $apiKey -and (Test-Path $KeyPath)) {
        try {
            $keys = Get-Content $KeyPath | ConvertFrom-Json
            $apiKey = $keys.anthropic_api_key
        }
        catch {
            Write-Warning "Failed to load API key from config: $_"
        }
    }

    if (-not $apiKey) {
        throw "Claude API key not found. Set ANTHROPIC_API_KEY environment variable or add to Configs\api-keys.json"
    }

    return $apiKey
}

# Main function: Invoke Claude API
function Invoke-ClaudeAPI {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Prompt,

        [string]$SystemPrompt = "",

        [string]$Model = "claude-opus-4-1",

        [int]$MaxTokens = 4096,

        [double]$Temperature = 1.0,

        [int]$MaxRetries = 3,

        [hashtable]$Metadata = @{}
    )

    $config = Get-ClaudeConfig
    $apiKey = Get-ClaudeApiKey
    $endpoint = $config.endpoint

    # Build request body
    $messages = @(
        @{
            role = "user"
            content = $Prompt
        }
    )

    $body = @{
        model = $Model
        max_tokens = $MaxTokens
        temperature = $Temperature
        messages = $messages
    }

    if ($SystemPrompt) {
        $body.system = $SystemPrompt
    }

    $headers = @{
        "x-api-key" = $apiKey
        "anthropic-version" = "2023-06-01"
        "content-type" = "application/json"
    }

    # Retry logic with exponential backoff
    $attempt = 0
    $startTime = Get-Date

    while ($attempt -lt $MaxRetries) {
        try {
            $attempt++

            $response = Invoke-RestMethod -Uri $endpoint `
                -Method Post `
                -Headers $headers `
                -Body ($body | ConvertTo-Json -Depth 10) `
                -TimeoutSec 120

            $endTime = Get-Date
            $duration = ($endTime - $startTime).TotalSeconds

            # Calculate costs
            $inputTokens = $response.usage.input_tokens
            $outputTokens = $response.usage.output_tokens
            $totalTokens = $inputTokens + $outputTokens
            $cost = ($totalTokens / 1000) * $script:CostPer1KTokens

            # Extract response text
            $responseText = $response.content[0].text

            # Log the request
            $logEntry = @{
                timestamp = $startTime.ToString("yyyy-MM-dd HH:mm:ss")
                plugin = $script:PluginName
                model = $Model
                prompt_length = $Prompt.Length
                input_tokens = $inputTokens
                output_tokens = $outputTokens
                total_tokens = $totalTokens
                cost = $cost
                duration_seconds = [math]::Round($duration, 2)
                success = $true
                metadata = $Metadata
            }

            Save-RequestLog -LogEntry $logEntry

            # Return standardized response
            return @{
                success = $true
                provider = "Claude"
                model = $Model
                response = $responseText
                usage = @{
                    input_tokens = $inputTokens
                    output_tokens = $outputTokens
                    total_tokens = $totalTokens
                    cost = $cost
                }
                duration = $duration
                metadata = $Metadata
            }
        }
        catch {
            $errorMessage = $_.Exception.Message

            # Check if we should retry
            if ($attempt -lt $MaxRetries) {
                $waitTime = [math]::Pow(2, $attempt)  # Exponential backoff: 2, 4, 8 seconds
                Write-Warning "Claude API request failed (attempt $attempt/$MaxRetries): $errorMessage. Retrying in $waitTime seconds..."
                Start-Sleep -Seconds $waitTime
            }
            else {
                # Max retries reached, log and return error
                $endTime = Get-Date
                $duration = ($endTime - $startTime).TotalSeconds

                $logEntry = @{
                    timestamp = $startTime.ToString("yyyy-MM-dd HH:mm:ss")
                    plugin = $script:PluginName
                    model = $Model
                    prompt_length = $Prompt.Length
                    error = $errorMessage
                    duration_seconds = [math]::Round($duration, 2)
                    success = $false
                    metadata = $Metadata
                }

                Save-RequestLog -LogEntry $logEntry

                return @{
                    success = $false
                    provider = "Claude"
                    model = $Model
                    error = $errorMessage
                    duration = $duration
                    metadata = $Metadata
                }
            }
        }
    }
}

# Save request log to analytics
function Save-RequestLog {
    param(
        [hashtable]$LogEntry
    )

    $logDir = "$PSScriptRoot\..\..\..\Analytics\ai-performance"
    $logFile = "$logDir\claude-requests-$(Get-Date -Format 'yyyy-MM').jsonl"

    try {
        # Ensure directory exists
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }

        # Append log entry as JSON line
        $LogEntry | ConvertTo-Json -Compress | Add-Content -Path $logFile
    }
    catch {
        Write-Warning "Failed to save request log: $_"
    }
}

# Export functions
Export-ModuleMember -Function Invoke-ClaudeAPI, Get-ClaudeConfig, Get-ClaudeApiKey
