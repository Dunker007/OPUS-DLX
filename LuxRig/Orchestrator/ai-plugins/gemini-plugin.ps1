<#
.SYNOPSIS
    Gemini (Google AI) Plugin for LuxRig Orchestrator

.DESCRIPTION
    Standardized interface for Gemini Pro/Ultra models
    - Handles authentication via API key
    - Tracks token usage and costs
    - Implements retry logic with exponential backoff
    - Returns standardized response format
    - Logs all requests for analytics

.NOTES
    Part of LuxRig Phase 1 Foundation
    Tier: 1/2 (Premium/Mid) - Multimodal analysis, reasoning
#>

# Plugin Configuration
$script:PluginName = "Gemini"
$script:PluginVersion = "1.0.0"
$script:Tier = 1
$script:CostPer1KTokensInput = 0.00125   # Gemini Pro pricing
$script:CostPer1KTokensOutput = 0.00375

# Load configuration
function Get-GeminiConfig {
    param(
        [string]$ConfigPath = "$PSScriptRoot\..\..\..\Configs\ai-models.json"
    )

    try {
        if (Test-Path $ConfigPath) {
            $config = Get-Content $ConfigPath | ConvertFrom-Json
            return $config.gemini
        }

        # Fallback default config
        return @{
            model = "gemini-pro"
            tier = 1
            monthly_budget = 50
            cost_per_1k_tokens = 0.00125
            endpoint = "https://generativelanguage.googleapis.com/v1/models"
            rate_limits = @{
                requests_per_minute = 60
                tokens_per_minute = 120000
            }
        }
    }
    catch {
        Write-Warning "Failed to load Gemini config: $_"
        return $null
    }
}

# Get API key from environment or config
function Get-GeminiApiKey {
    param(
        [string]$KeyPath = "$PSScriptRoot\..\..\..\Configs\api-keys.json"
    )

    # Try environment variable first
    $apiKey = $env:GOOGLE_AI_API_KEY

    # Try config file if env var not set
    if (-not $apiKey -and (Test-Path $KeyPath)) {
        try {
            $keys = Get-Content $KeyPath | ConvertFrom-Json
            $apiKey = $keys.google_ai_api_key
        }
        catch {
            Write-Warning "Failed to load API key from config: $_"
        }
    }

    if (-not $apiKey) {
        throw "Google AI API key not found. Set GOOGLE_AI_API_KEY environment variable or add to Configs\api-keys.json"
    }

    return $apiKey
}

# Main function: Invoke Gemini API
function Invoke-GeminiAPI {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Prompt,

        [string]$SystemPrompt = "",

        [string]$Model = "gemini-pro",

        [int]$MaxTokens = 4096,

        [double]$Temperature = 1.0,

        [int]$MaxRetries = 3,

        [hashtable]$Metadata = @{}
    )

    $config = Get-GeminiConfig
    $apiKey = Get-GeminiApiKey
    $endpoint = "$($config.endpoint)/$($Model):generateContent?key=$apiKey"

    # Build request body
    $fullPrompt = if ($SystemPrompt) { "$SystemPrompt`n`n$Prompt" } else { $Prompt }

    $body = @{
        contents = @(
            @{
                parts = @(
                    @{
                        text = $fullPrompt
                    }
                )
            }
        )
        generationConfig = @{
            temperature = $Temperature
            maxOutputTokens = $MaxTokens
        }
    }

    $headers = @{
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

            # Extract response text
            $responseText = $response.candidates[0].content.parts[0].text

            # Estimate token usage (Gemini API doesn't always return exact counts)
            $inputTokens = [math]::Ceiling($fullPrompt.Length / 4)
            $outputTokens = [math]::Ceiling($responseText.Length / 4)
            $totalTokens = $inputTokens + $outputTokens
            $cost = (($inputTokens / 1000) * $script:CostPer1KTokensInput) + (($outputTokens / 1000) * $script:CostPer1KTokensOutput)

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
                provider = "Gemini"
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
                Write-Warning "Gemini API request failed (attempt $attempt/$MaxRetries): $errorMessage. Retrying in $waitTime seconds..."
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
                    provider = "Gemini"
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
    $logFile = "$logDir\gemini-requests-$(Get-Date -Format 'yyyy-MM').jsonl"

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
Export-ModuleMember -Function Invoke-GeminiAPI, Get-GeminiConfig, Get-GeminiApiKey
