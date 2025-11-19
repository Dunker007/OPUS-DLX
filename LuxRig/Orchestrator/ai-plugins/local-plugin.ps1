<#
.SYNOPSIS
    Local Models Plugin for LuxRig Orchestrator (Ollama/LM Studio)

.DESCRIPTION
    Standardized interface for local AI models running on LuxRig
    - Supports Ollama and LM Studio
    - Zero API costs (runs locally)
    - Tracks token usage and performance
    - Returns standardized response format
    - Logs all requests for analytics

.NOTES
    Part of LuxRig Phase 1 Foundation
    Tier: 3 (Workhorses) - Bulk processing, filtering, monitoring
    Cost: FREE (local processing)
#>

# Plugin Configuration
$script:PluginName = "LocalModels"
$script:PluginVersion = "1.0.0"
$script:Tier = 3
$script:CostPer1KTokens = 0.0  # Free!

# Load configuration
function Get-LocalConfig {
    param(
        [string]$ConfigPath = "$PSScriptRoot\..\..\..\Configs\ai-models.json"
    )

    try {
        if (Test-Path $ConfigPath) {
            $config = Get-Content $ConfigPath | ConvertFrom-Json
            return $config.local
        }

        # Fallback default config
        return @{
            model = "llama2"
            tier = 3
            monthly_budget = 0
            cost_per_1k_tokens = 0
            ollama_endpoint = "http://localhost:11434/api/generate"
            lmstudio_endpoint = "http://localhost:1234/v1/chat/completions"
            preferred_runtime = "ollama"
        }
    }
    catch {
        Write-Warning "Failed to load Local config: $_"
        return $null
    }
}

# Main function: Invoke Local Model
function Invoke-LocalAPI {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Prompt,

        [string]$SystemPrompt = "You are a helpful AI assistant.",

        [string]$Model = "llama2",

        [int]$MaxTokens = 2048,

        [double]$Temperature = 1.0,

        [string]$Runtime = "ollama",  # "ollama" or "lmstudio"

        [int]$MaxRetries = 3,

        [hashtable]$Metadata = @{}
    )

    $config = Get-LocalConfig
    $startTime = Get-Date

    # Choose runtime
    if ($Runtime -eq "lmstudio") {
        return Invoke-LMStudioModel @PSBoundParameters
    }
    else {
        return Invoke-OllamaModel @PSBoundParameters
    }
}

# Invoke Ollama model
function Invoke-OllamaModel {
    param(
        [string]$Prompt,
        [string]$SystemPrompt = "",
        [string]$Model = "llama2",
        [int]$MaxTokens = 2048,
        [double]$Temperature = 1.0,
        [int]$MaxRetries = 3,
        [hashtable]$Metadata = @{}
    )

    $config = Get-LocalConfig
    $endpoint = $config.ollama_endpoint

    # Build full prompt
    $fullPrompt = if ($SystemPrompt) { "$SystemPrompt`n`n$Prompt" } else { $Prompt }

    $body = @{
        model = $Model
        prompt = $fullPrompt
        stream = $false
        options = @{
            temperature = $Temperature
            num_predict = $MaxTokens
        }
    }

    $headers = @{
        "Content-Type" = "application/json"
    }

    $attempt = 0
    $startTime = Get-Date

    while ($attempt -lt $MaxRetries) {
        try {
            $attempt++

            $response = Invoke-RestMethod -Uri $endpoint `
                -Method Post `
                -Headers $headers `
                -Body ($body | ConvertTo-Json -Depth 10) `
                -TimeoutSec 180

            $endTime = Get-Date
            $duration = ($endTime - $startTime).TotalSeconds

            # Extract response
            $responseText = $response.response

            # Estimate tokens
            $inputTokens = [math]::Ceiling($fullPrompt.Length / 4)
            $outputTokens = [math]::Ceiling($responseText.Length / 4)
            $totalTokens = $inputTokens + $outputTokens

            # Log the request
            $logEntry = @{
                timestamp = $startTime.ToString("yyyy-MM-dd HH:mm:ss")
                plugin = $script:PluginName
                runtime = "ollama"
                model = $Model
                prompt_length = $Prompt.Length
                input_tokens = $inputTokens
                output_tokens = $outputTokens
                total_tokens = $totalTokens
                cost = 0.0
                duration_seconds = [math]::Round($duration, 2)
                success = $true
                metadata = $Metadata
            }

            Save-RequestLog -LogEntry $logEntry

            return @{
                success = $true
                provider = "LocalModels"
                runtime = "ollama"
                model = $Model
                response = $responseText
                usage = @{
                    input_tokens = $inputTokens
                    output_tokens = $outputTokens
                    total_tokens = $totalTokens
                    cost = 0.0
                }
                duration = $duration
                metadata = $Metadata
            }
        }
        catch {
            $errorMessage = $_.Exception.Message

            if ($attempt -lt $MaxRetries) {
                $waitTime = [math]::Pow(2, $attempt)
                Write-Warning "Ollama request failed (attempt $attempt/$MaxRetries): $errorMessage. Retrying in $waitTime seconds..."
                Start-Sleep -Seconds $waitTime
            }
            else {
                $endTime = Get-Date
                $duration = ($endTime - $startTime).TotalSeconds

                $logEntry = @{
                    timestamp = $startTime.ToString("yyyy-MM-dd HH:mm:ss")
                    plugin = $script:PluginName
                    runtime = "ollama"
                    model = $Model
                    error = $errorMessage
                    duration_seconds = [math]::Round($duration, 2)
                    success = $false
                    metadata = $Metadata
                }

                Save-RequestLog -LogEntry $logEntry

                return @{
                    success = $false
                    provider = "LocalModels"
                    runtime = "ollama"
                    model = $Model
                    error = $errorMessage
                    duration = $duration
                    metadata = $Metadata
                }
            }
        }
    }
}

# Invoke LM Studio model (OpenAI-compatible)
function Invoke-LMStudioModel {
    param(
        [string]$Prompt,
        [string]$SystemPrompt = "You are a helpful AI assistant.",
        [string]$Model = "local-model",
        [int]$MaxTokens = 2048,
        [double]$Temperature = 1.0,
        [int]$MaxRetries = 3,
        [hashtable]$Metadata = @{}
    )

    $config = Get-LocalConfig
    $endpoint = $config.lmstudio_endpoint

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
        messages = $messages
        max_tokens = $MaxTokens
        temperature = $Temperature
    }

    $headers = @{
        "Content-Type" = "application/json"
    }

    $attempt = 0
    $startTime = Get-Date

    while ($attempt -lt $MaxRetries) {
        try {
            $attempt++

            $response = Invoke-RestMethod -Uri $endpoint `
                -Method Post `
                -Headers $headers `
                -Body ($body | ConvertTo-Json -Depth 10) `
                -TimeoutSec 180

            $endTime = Get-Date
            $duration = ($endTime - $startTime).TotalSeconds

            $responseText = $response.choices[0].message.content
            $inputTokens = $response.usage.prompt_tokens
            $outputTokens = $response.usage.completion_tokens
            $totalTokens = $response.usage.total_tokens

            $logEntry = @{
                timestamp = $startTime.ToString("yyyy-MM-dd HH:mm:ss")
                plugin = $script:PluginName
                runtime = "lmstudio"
                model = $Model
                input_tokens = $inputTokens
                output_tokens = $outputTokens
                total_tokens = $totalTokens
                cost = 0.0
                duration_seconds = [math]::Round($duration, 2)
                success = $true
                metadata = $Metadata
            }

            Save-RequestLog -LogEntry $logEntry

            return @{
                success = $true
                provider = "LocalModels"
                runtime = "lmstudio"
                model = $Model
                response = $responseText
                usage = @{
                    input_tokens = $inputTokens
                    output_tokens = $outputTokens
                    total_tokens = $totalTokens
                    cost = 0.0
                }
                duration = $duration
                metadata = $Metadata
            }
        }
        catch {
            $errorMessage = $_.Exception.Message

            if ($attempt -lt $MaxRetries) {
                $waitTime = [math]::Pow(2, $attempt)
                Write-Warning "LM Studio request failed (attempt $attempt/$MaxRetries): $errorMessage. Retrying in $waitTime seconds..."
                Start-Sleep -Seconds $waitTime
            }
            else {
                $endTime = Get-Date
                $duration = ($endTime - $startTime).TotalSeconds

                $logEntry = @{
                    timestamp = $startTime.ToString("yyyy-MM-dd HH:mm:ss")
                    plugin = $script:PluginName
                    runtime = "lmstudio"
                    model = $Model
                    error = $errorMessage
                    duration_seconds = [math]::Round($duration, 2)
                    success = $false
                    metadata = $Metadata
                }

                Save-RequestLog -LogEntry $logEntry

                return @{
                    success = $false
                    provider = "LocalModels"
                    runtime = "lmstudio"
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
    $logFile = "$logDir\local-requests-$(Get-Date -Format 'yyyy-MM').jsonl"

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
Export-ModuleMember -Function Invoke-LocalAPI, Invoke-OllamaModel, Invoke-LMStudioModel, Get-LocalConfig
