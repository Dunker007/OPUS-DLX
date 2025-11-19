<#
.SYNOPSIS
    API Wrapper - Wraps AI capabilities as monetizable APIs

.DESCRIPTION
    Creates production-ready API endpoints:
    - Text generation API
    - Image analysis API
    - Data extraction API
    - Content summarization API
    - Custom endpoint generation
#>

Import-Module "$PSScriptRoot\..\..\Orchestrator\task-router.ps1" -Force

function New-APIEndpoint {
    param(
        [Parameter(Mandatory=$true)]
        [string]$EndpointName,

        [Parameter(Mandatory=$true)]
        [string]$Description,

        [hashtable]$Parameters = @{},

        [string]$OutputPath = "$PSScriptRoot\..\..\Products\deployed\api"
    )

    Write-Host "[API Wrapper] Creating endpoint: $EndpointName" -ForegroundColor Cyan

    $functionCode = @"
const { Invoke-TaskRouter } = require('../../orchestrator/task-router');
const { RateLimiter } = require('./rate-limiter');
const { AuthManager } = require('./auth-manager');

/**
 * $Description
 *
 * @param {Object} req - Request object
 * @param {Object} res - Response object
 */
module.exports = async (req, res) => {
    try {
        // Authentication
        const user = await AuthManager.verifyApiKey(req.headers['x-api-key']);
        if (!user) {
            return res.status(401).json({ error: 'Invalid API key' });
        }

        // Rate limiting
        const allowed = await RateLimiter.checkLimit(user.id, '$EndpointName');
        if (!allowed) {
            return res.status(429).json({ error: 'Rate limit exceeded' });
        }

        // Extract parameters
        $(
            $Parameters.Keys | ForEach-Object {
                "const $_ = req.body.$_;"
            }
        )

        // Validate required parameters
        $(
            $Parameters.Keys | ForEach-Object {
                if ($Parameters[$_].required) {
                    "if (!$_) return res.status(400).json({ error: '$_ is required' });"
                }
            }
        )

        // Call AI orchestrator
        const task = `Process request: \${JSON.stringify(req.body)}`;
        const result = await Invoke-TaskRouter({ task, priority: 'medium' });

        if (!result.success) {
            return res.status(500).json({ error: 'Processing failed', details: result.error });
        }

        // Increment usage
        await RateLimiter.incrementUsage(user.id, '$EndpointName');

        // Return result
        res.status(200).json({
            success: true,
            data: result.response,
            usage: {
                tokens: result.usage.total_tokens,
                cost: result.usage.cost
            }
        });

    } catch (error) {
        console.error('API Error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
};
"@

    # Create endpoint directory
    $endpointDir = Join-Path $OutputPath $EndpointName
    if (-not (Test-Path $endpointDir)) {
        New-Item -ItemType Directory -Path $endpointDir -Force | Out-Null
    }

    # Save function
    $functionCode | Set-Content "$endpointDir\index.js"

    # Generate OpenAPI spec
    $openApiSpec = @{
        openapi = "3.0.0"
        info = @{
            title = "$EndpointName API"
            description = $Description
            version = "1.0.0"
        }
        paths = @{
            "/$EndpointName" = @{
                post = @{
                    summary = $Description
                    security = @(@{"ApiKeyAuth" = @()})
                    requestBody = @{
                        required = $true
                        content = @{
                            "application/json" = @{
                                schema = @{
                                    type = "object"
                                    properties = $Parameters
                                }
                            }
                        }
                    }
                    responses = @{
                        "200" = @{
                            description = "Successful response"
                            content = @{
                                "application/json" = @{
                                    schema = @{
                                        type = "object"
                                        properties = @{
                                            success = @{type = "boolean"}
                                            data = @{type = "object"}
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        components = @{
            securitySchemes = @{
                ApiKeyAuth = @{
                    type = "apiKey"
                    in = "header"
                    name = "X-API-Key"
                }
            }
        }
    } | ConvertTo-Json -Depth 20

    $openApiSpec | Set-Content "$endpointDir\openapi.json"

    Write-Host "✓ Endpoint created: $EndpointName" -ForegroundColor Green

    return @{
        success = $true
        endpoint = $EndpointName
        path = $endpointDir
    }
}

function New-TextGenerationAPI {
    param([string]$OutputPath = "$PSScriptRoot\..\..\Products\deployed\api")

    return New-APIEndpoint -EndpointName "generate-text" `
        -Description "Generate high-quality text content using AI" `
        -Parameters @{
            prompt = @{type = "string"; required = $true; description = "Text generation prompt"}
            maxTokens = @{type = "integer"; default = 1000}
            temperature = @{type = "number"; default = 0.7}
        } `
        -OutputPath $OutputPath
}

function New-SummarizationAPI {
    param([string]$OutputPath = "$PSScriptRoot\..\..\Products\deployed\api")

    return New-APIEndpoint -EndpointName "summarize" `
        -Description "Summarize long-form content" `
        -Parameters @{
            text = @{type = "string"; required = $true; description = "Text to summarize"}
            maxLength = @{type = "integer"; default = 200}
            style = @{type = "string"; enum = @("bullet", "paragraph"); default = "paragraph"}
        } `
        -OutputPath $OutputPath
}

function New-DataExtractionAPI {
    param([string]$OutputPath = "$PSScriptRoot\..\..\Products\deployed\api")

    return New-APIEndpoint -EndpointName "extract-data" `
        -Description "Extract structured data from unstructured text" `
        -Parameters @{
            text = @{type = "string"; required = $true}
            schema = @{type = "object"; required = $true; description = "Target data schema"}
        } `
        -OutputPath $OutputPath
}

function Invoke-APIGeneration {
    param(
        [string[]]$Endpoints = @("generate-text", "summarize", "extract-data"),
        [string]$OutputPath = "$PSScriptRoot\..\..\Products\deployed\api"
    )

    Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║         API WRAPPER - GENERATING          ║" -ForegroundColor Magenta
    Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Magenta

    $results = @()

    foreach ($endpoint in $Endpoints) {
        $result = switch ($endpoint) {
            "generate-text" { New-TextGenerationAPI -OutputPath $OutputPath }
            "summarize" { New-SummarizationAPI -OutputPath $OutputPath }
            "extract-data" { New-DataExtractionAPI -OutputPath $OutputPath }
            default { Write-Warning "Unknown endpoint: $endpoint"; @{success = $false} }
        }

        $results += $result
    }

    Write-Host "`n✓ Generated $($results.Count) API endpoints" -ForegroundColor Green

    return $results
}

Export-ModuleMember -Function Invoke-APIGeneration, New-APIEndpoint
