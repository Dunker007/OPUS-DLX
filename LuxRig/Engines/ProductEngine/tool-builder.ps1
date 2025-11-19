<#
.SYNOPSIS
    Automated Micro-SaaS Tool Builder - Generates production-ready tools from ideas

.DESCRIPTION
    Takes scored opportunities and builds complete micro-SaaS products:
    - Analyzes idea and generates technical spec
    - Uses AI to write HTML/JS/CSS/backend code
    - Creates landing page with SEO optimization
    - Sets up payment integration scaffolding
    - Generates deployment configuration
    - Creates documentation and README

.EXAMPLE
    $idea = Get-Content "..\..\Products\ideas\top-idea.json" | ConvertFrom-Json
    $product = Build-MicroSaaS -Idea $idea -AutoDeploy

.NOTES
    Part of LuxRig Phase 2 - Revenue Engine
    Uses task router to leverage multiple AIs for different components
#>

Import-Module "$PSScriptRoot\..\..\Orchestrator\task-router.ps1" -Force

# Generate technical specification from idea
function New-TechnicalSpec {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Idea
    )

    Write-Host "`n[Tool Builder] Generating technical specification..." -ForegroundColor Cyan

    $specPrompt = @"
You are a senior software architect. Based on this problem/opportunity:

TITLE: $($Idea.title)
DESCRIPTION: $($Idea.description)
SOURCE: $($Idea.source)
DEMAND SCORE: $($Idea.score.demand)/10

Generate a complete technical specification for a micro-SaaS product that solves this problem.

Include:
1. Product Name (catchy, memorable)
2. Core Features (3-5 key features)
3. Tech Stack (frontend, backend, database, deployment)
4. User Flow (step-by-step user journey)
5. Monetization Strategy (pricing tiers)
6. Development Complexity (hours estimate)
7. Key Differentiators (what makes it unique)

Format as JSON with these exact keys: name, tagline, features, techStack, userFlow, pricing, estimatedHours, differentiators
"@

    $result = Invoke-TaskRouter -Task $specPrompt -Priority "high" -TaskType "analysis"

    if ($result.success) {
        try {
            $spec = $result.response | ConvertFrom-Json
            return $spec
        }
        catch {
            Write-Warning "Failed to parse spec JSON, returning raw response"
            return @{
                name = "Generated Tool"
                features = @()
                techStack = "HTML/JS/CSS"
                rawSpec = $result.response
            }
        }
    }
    else {
        throw "Failed to generate technical spec: $($result.error)"
    }
}

# Generate frontend code
function New-FrontendCode {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Spec,
        [string]$Framework = "vanilla-js"
    )

    Write-Host "[Tool Builder] Generating frontend code..." -ForegroundColor Cyan

    $frontendPrompt = @"
Generate a complete, production-ready single-page application for this product:

NAME: $($Spec.name)
TAGLINE: $($Spec.tagline)
FEATURES: $($Spec.features -join ', ')

Create a beautiful, modern, responsive web app with:
1. HTML5 structure with semantic tags
2. Professional CSS with gradient backgrounds, glassmorphism effects
3. Vanilla JavaScript with no dependencies
4. Dark mode toggle
5. Mobile-first responsive design
6. Form validation
7. Loading states and error handling
8. Analytics tracking hooks (data-analytics attributes)

Make it look like a premium SaaS product. Use modern design trends.
Output complete code in this format:

===HTML===
[complete HTML]
===CSS===
[complete CSS]
===JS===
[complete JavaScript]
"@

    $result = Invoke-TaskRouter -Task $frontendPrompt -Priority "high" -TaskType "code"

    if ($result.success) {
        # Parse the response to extract HTML, CSS, JS
        $response = $result.response

        $html = if ($response -match '===HTML===\s*([\s\S]*?)(?===CSS===|$)') { $Matches[1].Trim() } else { "" }
        $css = if ($response -match '===CSS===\s*([\s\S]*?)(?===JS===|$)') { $Matches[1].Trim() } else { "" }
        $js = if ($response -match '===JS===\s*([\s\S]*?)$') { $Matches[1].Trim() } else { "" }

        return @{
            html = $html
            css = $css
            js = $js
            success = $true
        }
    }
    else {
        Write-Warning "Frontend generation failed: $($result.error)"
        return @{ success = $false; error = $result.error }
    }
}

# Generate landing page
function New-LandingPage {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Spec
    )

    Write-Host "[Tool Builder] Generating landing page..." -ForegroundColor Cyan

    $landingPrompt = @"
Create a high-converting landing page for this SaaS product:

PRODUCT: $($Spec.name)
TAGLINE: $($Spec.tagline)
FEATURES: $($Spec.features -join ', ')
PRICING: $($Spec.pricing)

Generate a complete HTML landing page with:
1. Hero section with compelling headline and CTA
2. Features section with icons
3. Pricing table
4. FAQ section
5. Footer with links
6. Email signup form (Netlify Forms compatible)
7. Social proof section
8. Mobile responsive
9. SEO optimized meta tags
10. Schema.org markup for SaaS

Use Tailwind CDN for styling. Make it convert visitors to customers.
Output complete HTML with inline Tailwind classes.
"@

    $result = Invoke-TaskRouter -Task $landingPrompt -Priority "medium" -TaskType "code"

    if ($result.success) {
        return @{
            html = $result.response
            success = $true
        }
    }
    else {
        return @{ success = $false; error = $result.error }
    }
}

# Main function: Build complete micro-SaaS product
function Build-MicroSaaS {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Idea,

        [string]$OutputPath = "$PSScriptRoot\..\..\Products\development",

        [switch]$GenerateFrontend = $true,
        [switch]$GenerateBackend = $true,
        [switch]$GenerateLanding = $true
    )

    Write-Host "`n╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║          MICRO-SAAS TOOL BUILDER - STARTING BUILD         ║" -ForegroundColor Magenta
    Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Magenta

    try {
        # Step 1: Generate technical spec
        $spec = New-TechnicalSpec -Idea $Idea
        Write-Host "✓ Technical specification generated" -ForegroundColor Green

        # Step 2: Create project directory
        $projectName = $spec.name -replace '[^a-zA-Z0-9]', '-' -replace '-+', '-'
        $projectPath = Join-Path $OutputPath $projectName

        if (-not (Test-Path $projectPath)) {
            New-Item -ItemType Directory -Path $projectPath -Force | Out-Null
            New-Item -ItemType Directory -Path "$projectPath\src" -Force | Out-Null
            New-Item -ItemType Directory -Path "$projectPath\public" -Force | Out-Null
            New-Item -ItemType Directory -Path "$projectPath\api" -Force | Out-Null
        }

        Write-Host "✓ Project structure created at: $projectPath" -ForegroundColor Green

        # Step 3: Generate frontend
        if ($GenerateFrontend) {
            $frontend = New-FrontendCode -Spec $spec

            if ($frontend.success) {
                if ($frontend.html) { $frontend.html | Set-Content "$projectPath\public\index.html" }
                if ($frontend.css) { $frontend.css | Set-Content "$projectPath\public\styles.css" }
                if ($frontend.js) { $frontend.js | Set-Content "$projectPath\public\app.js" }
                Write-Host "✓ Frontend code generated" -ForegroundColor Green
            }
        }

        # Step 4: Generate landing page
        if ($GenerateLanding) {
            $landing = New-LandingPage -Spec $spec
            if ($landing.success) {
                $landing.html | Set-Content "$projectPath\public\landing.html"
                Write-Host "✓ Landing page generated" -ForegroundColor Green
            }
        }

        # Save metadata
        @{
            idea = $Idea
            spec = $spec
            generated = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            path = $projectPath
        } | ConvertTo-Json -Depth 10 | Set-Content "$projectPath\metadata.json"

        return @{ success = $true; project = $spec.name; path = $projectPath }
    }
    catch {
        return @{ success = $false; error = $_.Exception.Message }
    }
}

Export-ModuleMember -Function Build-MicroSaaS, New-TechnicalSpec, New-FrontendCode, New-LandingPage
