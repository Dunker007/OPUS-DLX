<#
.SYNOPSIS
    Grok (X.AI) Plugin for LuxRig Orchestrator

.DESCRIPTION
    Standardized interface for Grok models (ready for integration)
    - Handles authentication via API key
    - Tracks token usage and costs
    - Implements retry logic with exponential backoff
    - Returns standardized response format
    - Logs all requests for analytics

.NOTES
    Part of LuxRig Phase 1 Foundation
    Tier: 1 (Premium) - Real-time data, X/Twitter integration, creative reasoning
    Status: Ready for integration when X.AI API access is available
#>

# Plugin Configuration
$script:PluginName = "Grok"
$script:PluginVersion = "1.0.0"
$script:Tier = 1
$script:CostPer1KTokens = 0.02  # Estimated pricing

# Load configuration
function Get-GrokConfig {
    param(
        [string]$ConfigPath = "$PSScriptRoot\..\..\..\Configs\ai-models.json"
    )

    try {
        if (Test-Path $ConfigPath) {
            $config = Get-Content $ConfigPath | ConvertFrom-Json
            return $config.grok
        }

        # Fallback default config
        return @{
            model = "grok-1"
            tier = 1
            monthly_budget = 100
            cost_per_1k_tokens = 0.02
            endpoint = "https://api.x.ai/v1/chat/completions"
            rate_limits = @{
                requests_per_minute = 50
                tokens_per_minute = 100000
            }
        }
    }
    catch {
        Write-Warning "Failed to load Grok config: $_"
        return $null
    }
}

# Get API key from environment or config
function Get-GrokApiKey {
    param(
        [string]$KeyPath = "$PSScriptRoot\..\..\..\Configs\api-keys.json"
    )

    # Try environment variable first
    $apiKey = $env:XAI_API_KEY

    # Try config file if env var not set
    if (-not $apiKey -and (Test-Path $KeyPath)) {
        try {
            $keys = Get-Content $KeyPath | ConvertFrom-Json
            $apiKey = $keys.xai_api_key
        }
        catch {
            Write-Warning "Failed to load API key from config: $_"
        }
    }

    if (-not $apiKey) {
        throw "X.AI API key not found. Set XAI_API_KEY environment variable or add to Configs\api-keys.json"
    }

    return $apiKey
}

# Main function: Invoke Grok API
function Invoke-GrokAPI {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Prompt,

        [string]$SystemPrompt = "You are Grok, a helpful AI assistant with real-time knowledge.",

        [string]$Model = "grok-1",

        [int]$MaxTokens = 4096,

        [double]$Temperature = 1.0,

        [int]$MaxRetries = 3,

        [hashtable]$Metadata = @{}
    )

    $config = Get-GrokConfig
    $apiKey = Get-GrokApiKey
    $endpoint = $config.endpoint

    # Build request body (assuming OpenAI-compatible format)
    $messages = @(
        @{
            role = "system"
            content = $SystemPrompt
        },
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

    $headers = @{
        "Authorization" = "Bearer $apiKey"
        "Content-Type" = "application/json"
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
            $inputTokens = $response.usage.prompt_tokens
            $outputTokens = $response.usage.completion_tokens
            $totalTokens = $response.usage.total_tokens
            $cost = ($totalTokens / 1000) * $script:CostPer1KTokens

            # Extract response text
            $responseText = $response.choices[0].message.content

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
                provider = "Grok"
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
                $waitTime = [math]::Pow(2, $attempt)
                Write-Warning "Grok API request failed (attempt $attempt/$MaxRetries): $errorMessage. Retrying in $waitTime seconds..."
                Start-Sleep -Seconds $waitTime
            }
            else {
                # Max retries reached
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
                    provider = "Grok"
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
    $logFile = "$logDir\grok-requests-$(Get-Date -Format 'yyyy-MM').jsonl"

    try {
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }

        $LogEntry | ConvertTo-Json -Compress | Add-Content -Path $logFile
    }
    catch {
        Write-Warning "Failed to save request log: $_"
    }
}

# Export functions
Export-ModuleMember -Function Invoke-GrokAPI, Get-GrokConfig, Get-GrokApiKey
