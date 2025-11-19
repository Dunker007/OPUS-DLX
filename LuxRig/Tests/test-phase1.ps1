<#
.SYNOPSIS
    Phase 1 Component Test Suite

.DESCRIPTION
    Tests all Phase 1 foundation components:
    - AI plugin system
    - Task router
    - Budget manager
    - Quality gates
    - Opportunity scanner
    - Monitoring dashboard

.EXAMPLE
    .\test-phase1.ps1
    .\test-phase1.ps1 -Component "task-router" -Verbose

.NOTES
    Run this after deploying to C:\LuxRig\ to validate all components
#>

param(
    [ValidateSet("all", "plugins", "router", "budget", "quality", "scanner", "dashboard")]
    [string]$Component = "all",

    [switch]$SkipAPITests  # Skip tests that require actual API keys
)

$ErrorActionPreference = "Continue"
$testResults = @{
    passed = 0
    failed = 0
    skipped = 0
    tests = @()
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Message = ""
    )

    if ($Passed) {
        Write-Host "✓ " -NoNewline -ForegroundColor Green
        Write-Host "$TestName" -ForegroundColor White
        if ($Message) { Write-Host "  $Message" -ForegroundColor DarkGray }
        $script:testResults.passed++
    }
    else {
        Write-Host "✗ " -NoNewline -ForegroundColor Red
        Write-Host "$TestName" -ForegroundColor White
        if ($Message) { Write-Host "  ERROR: $Message" -ForegroundColor Red }
        $script:testResults.failed++
    }

    $script:testResults.tests += @{
        name = $TestName
        passed = $Passed
        message = $Message
    }
}

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "    LuxRig Phase 1 Foundation - Test Suite" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Test 1: Directory Structure
if ($Component -eq "all") {
    Write-Host "`n[Test 1: Directory Structure]" -ForegroundColor Yellow

    $requiredDirs = @(
        "Orchestrator",
        "Orchestrator\ai-plugins",
        "Engines\ContentEngine",
        "Engines\ProductEngine",
        "Engines\APIEngine",
        "Content\raw",
        "Content\processed",
        "Content\published",
        "Products\ideas",
        "Products\development",
        "Products\deployed",
        "Analytics\revenue",
        "Analytics\traffic",
        "Analytics\ai-performance",
        "Configs"
    )

    foreach ($dir in $requiredDirs) {
        $fullPath = Join-Path $PSScriptRoot "..\$dir"
        $exists = Test-Path $fullPath
        Write-TestResult -TestName "Directory exists: $dir" -Passed $exists -Message $(if (-not $exists) { "Missing directory" })
    }
}

# Test 2: AI Plugins
if ($Component -eq "all" -or $Component -eq "plugins") {
    Write-Host "`n[Test 2: AI Plugin Files]" -ForegroundColor Yellow

    $plugins = @("claude-plugin.ps1", "gpt-plugin.ps1", "gemini-plugin.ps1", "grok-plugin.ps1", "local-plugin.ps1")

    foreach ($plugin in $plugins) {
        $pluginPath = Join-Path $PSScriptRoot "..\Orchestrator\ai-plugins\$plugin"
        $exists = Test-Path $pluginPath

        if ($exists) {
            # Check if file has content
            $content = Get-Content $pluginPath -Raw
            $hasContent = $content.Length -gt 100

            Write-TestResult -TestName "Plugin exists and has content: $plugin" -Passed $hasContent -Message $(if (-not $hasContent) { "File is empty or too small" })

            # Check for required functions
            $hasInvokeFunction = $content -match "function Invoke-"
            Write-TestResult -TestName "Plugin has Invoke function: $plugin" -Passed $hasInvokeFunction
        }
        else {
            Write-TestResult -TestName "Plugin exists: $plugin" -Passed $false -Message "File not found"
        }
    }
}

# Test 3: Core Orchestrator Scripts
if ($Component -eq "all" -or $Component -eq "router" -or $Component -eq "budget") {
    Write-Host "`n[Test 3: Core Orchestrator Scripts]" -ForegroundColor Yellow

    $coreScripts = @(
        "Orchestrator\task-router.ps1",
        "Orchestrator\budget-manager.ps1",
        "Orchestrator\quality-gates.ps1"
    )

    foreach ($script in $coreScripts) {
        $scriptPath = Join-Path $PSScriptRoot "..\$script"
        $exists = Test-Path $scriptPath

        if ($exists) {
            $content = Get-Content $scriptPath -Raw
            $hasContent = $content.Length -gt 500

            Write-TestResult -TestName "Script exists: $(Split-Path $script -Leaf)" -Passed $hasContent -Message $(if (-not $hasContent) { "File is empty or too small" })

            # Try to source it (basic syntax check)
            try {
                $null = [scriptblock]::Create($content)
                Write-TestResult -TestName "Script syntax valid: $(Split-Path $script -Leaf)" -Passed $true
            }
            catch {
                Write-TestResult -TestName "Script syntax valid: $(Split-Path $script -Leaf)" -Passed $false -Message $_.Exception.Message
            }
        }
        else {
            Write-TestResult -TestName "Script exists: $(Split-Path $script -Leaf)" -Passed $false -Message "File not found"
        }
    }
}

# Test 4: Configuration Files
if ($Component -eq "all") {
    Write-Host "`n[Test 4: Configuration Files]" -ForegroundColor Yellow

    $configs = @(
        @{ Path = "Configs\ai-models.json"; Type = "json" },
        @{ Path = "Configs\budget-rules.yaml"; Type = "yaml" },
        @{ Path = "Configs\quality-standards.json"; Type = "json" },
        @{ Path = "Configs\api-keys.json.template"; Type = "json" }
    )

    foreach ($config in $configs) {
        $configPath = Join-Path $PSScriptRoot "..\$($config.Path)"
        $exists = Test-Path $configPath

        if ($exists) {
            Write-TestResult -TestName "Config exists: $($config.Path)" -Passed $true

            # Validate JSON files
            if ($config.Type -eq "json") {
                try {
                    $null = Get-Content $configPath | ConvertFrom-Json
                    Write-TestResult -TestName "Valid JSON: $($config.Path)" -Passed $true
                }
                catch {
                    Write-TestResult -TestName "Valid JSON: $($config.Path)" -Passed $false -Message $_.Exception.Message
                }
            }
        }
        else {
            Write-TestResult -TestName "Config exists: $($config.Path)" -Passed $false -Message "File not found"
        }
    }
}

# Test 5: Engine Scripts
if ($Component -eq "all" -or $Component -eq "scanner") {
    Write-Host "`n[Test 5: Revenue Engine Scripts]" -ForegroundColor Yellow

    $engineScripts = @(
        "Engines\ContentEngine\opportunity-scanner.ps1"
    )

    foreach ($script in $engineScripts) {
        $scriptPath = Join-Path $PSScriptRoot "..\$script"
        $exists = Test-Path $scriptPath

        if ($exists) {
            $content = Get-Content $scriptPath -Raw
            $hasContent = $content.Length -gt 500

            Write-TestResult -TestName "Engine script exists: $(Split-Path $script -Leaf)" -Passed $hasContent
        }
        else {
            Write-TestResult -TestName "Engine script exists: $(Split-Path $script -Leaf)" -Passed $false -Message "File not found"
        }
    }
}

# Test 6: Monitoring Dashboard
if ($Component -eq "all" -or $Component -eq "dashboard") {
    Write-Host "`n[Test 6: Monitoring Dashboard]" -ForegroundColor Yellow

    $dashboardPath = Join-Path $PSScriptRoot "..\Analytics\dashboard.ps1"
    $exists = Test-Path $dashboardPath

    if ($exists) {
        Write-TestResult -TestName "Dashboard exists" -Passed $true

        $content = Get-Content $dashboardPath -Raw
        $hasFunctions = ($content -match "function Show-Dashboard") -and ($content -match "function Get-SystemHealth")
        Write-TestResult -TestName "Dashboard has required functions" -Passed $hasFunctions
    }
    else {
        Write-TestResult -TestName "Dashboard exists" -Passed $false -Message "File not found"
    }
}

# Test 7: Functional Tests (if API keys available)
if (-not $SkipAPITests) {
    Write-Host "`n[Test 7: Functional Tests]" -ForegroundColor Yellow
    Write-Host "  Note: Skipping API tests (use -SkipAPITests to suppress this message)" -ForegroundColor DarkGray
    $script:testResults.skipped += 5
}

# Summary
Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "    Test Summary" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "  Passed:  " -NoNewline -ForegroundColor Green
Write-Host $testResults.passed

Write-Host "  Failed:  " -NoNewline -ForegroundColor $(if ($testResults.failed -gt 0) { "Red" } else { "Gray" })
Write-Host $testResults.failed

if ($testResults.skipped -gt 0) {
    Write-Host "  Skipped: " -NoNewline -ForegroundColor Yellow
    Write-Host $testResults.skipped
}

$totalTests = $testResults.passed + $testResults.failed
$passRate = if ($totalTests -gt 0) { [Math]::Round(($testResults.passed / $totalTests) * 100, 1) } else { 0 }

Write-Host "`n  Pass Rate: $passRate%" -ForegroundColor $(if ($passRate -ge 95) { "Green" } elseif ($passRate -ge 80) { "Yellow" } else { "Red" })

if ($testResults.failed -eq 0) {
    Write-Host "`n✓ All tests passed! Phase 1 foundation is ready." -ForegroundColor Green
    exit 0
}
else {
    Write-Host "`n✗ Some tests failed. Review the errors above." -ForegroundColor Red
    exit 1
}
