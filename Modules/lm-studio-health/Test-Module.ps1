<#
.SYNOPSIS
    Test script for the lm-studio-health module

.DESCRIPTION
    Demonstrates usage and validates the module functionality
    Run this to verify everything works correctly

.EXAMPLE
    .\Test-Module.ps1
#>

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "OPUS-DLX Module #3: LM Studio Health - Test Suite" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Check if script exists
Write-Host "[Test 1] Checking if Get-LMStudioHealth.ps1 exists..." -ForegroundColor Yellow
$scriptPath = Join-Path $PSScriptRoot "Get-LMStudioHealth.ps1"
if (Test-Path $scriptPath) {
    Write-Host "✓ Script found at: $scriptPath" -ForegroundColor Green
} else {
    Write-Host "✗ Script not found!" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Test 2: Check if LM Studio process is running
Write-Host "[Test 2] Checking for LM Studio process..." -ForegroundColor Yellow
$lmProcesses = Get-Process -Name "lmstudio","lms","LM Studio" -ErrorAction SilentlyContinue
if ($lmProcesses) {
    Write-Host "✓ LM Studio process found: $($lmProcesses.Count) instance(s)" -ForegroundColor Green
    foreach ($proc in $lmProcesses) {
        Write-Host "  - $($proc.ProcessName) (PID: $($proc.Id))" -ForegroundColor Cyan
    }
} else {
    Write-Host "⚠ LM Studio process not found" -ForegroundColor Yellow
    Write-Host "  This is OK if LM Studio isn't running" -ForegroundColor Gray
    Write-Host "  The module will report 'offline' status" -ForegroundColor Gray
}
Write-Host ""

# Test 3: Test API endpoint connectivity
Write-Host "[Test 3] Testing API endpoint (localhost:1234)..." -ForegroundColor Yellow
try {
    $testConnection = Test-NetConnection -ComputerName localhost -Port 1234 -WarningAction SilentlyContinue -ErrorAction Stop
    if ($testConnection.TcpTestSucceeded) {
        Write-Host "✓ Port 1234 is listening" -ForegroundColor Green
    } else {
        Write-Host "⚠ Port 1234 is not listening" -ForegroundColor Yellow
        Write-Host "  LM Studio API server may not be started" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠ Could not test port connection" -ForegroundColor Yellow
}
Write-Host ""

# Test 4: Run the module (basic)
Write-Host "[Test 4] Running module (compressed JSON)..." -ForegroundColor Yellow
try {
    $output = & $scriptPath
    $result = $output | ConvertFrom-Json

    Write-Host "✓ Module executed successfully" -ForegroundColor Green
    Write-Host "  Timestamp: $($result.Timestamp)" -ForegroundColor Cyan
    Write-Host "  Module Version: $($result.Version)" -ForegroundColor Cyan
    Write-Host "  Status: $($result.Status)" -ForegroundColor Cyan

    if ($result.Error) {
        Write-Host "  Error: $($result.Error)" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Module execution failed: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 5: Run with pretty output
Write-Host "[Test 5] Running module with pretty output..." -ForegroundColor Yellow
try {
    $prettyOutput = & $scriptPath -Pretty
    Write-Host "✓ Pretty output generated" -ForegroundColor Green
    Write-Host "  Output length: $($prettyOutput.Length) characters" -ForegroundColor Cyan
} catch {
    Write-Host "✗ Pretty output failed: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 6: Analyze health status
Write-Host "[Test 6] Analyzing LM Studio health..." -ForegroundColor Yellow
try {
    $health = & $scriptPath | ConvertFrom-Json

    # Determine status color
    $statusColor = switch ($health.Status) {
        "healthy" { "Green" }
        "degraded" { "Yellow" }
        "offline" { "Red" }
        default { "White" }
    }

    Write-Host "  Status: $($health.Status.ToUpper())" -ForegroundColor $statusColor

    # Service status
    Write-Host "`n  Service:" -ForegroundColor Cyan
    if ($health.ServiceRunning) {
        Write-Host "    ✓ LM Studio process running" -ForegroundColor Green
        if ($health.Process.ProcessCount) {
            Write-Host "      Instances: $($health.Process.ProcessCount)" -ForegroundColor Gray
        }
    } else {
        Write-Host "    ✗ LM Studio not running" -ForegroundColor Red
    }

    # API status
    Write-Host "`n  API:" -ForegroundColor Cyan
    if ($health.APIResponsive) {
        Write-Host "    ✓ API responsive" -ForegroundColor Green
        Write-Host "      Response time: $($health.ResponseTimeMs)ms" -ForegroundColor Gray
        Write-Host "      Endpoint: $($health.APIEndpoint)" -ForegroundColor Gray
    } else {
        Write-Host "    ✗ API not responsive" -ForegroundColor Red
        if ($health.APITest.Error) {
            Write-Host "      Error: $($health.APITest.Error)" -ForegroundColor Gray
        }
    }

    # Models status
    Write-Host "`n  Models:" -ForegroundColor Cyan
    if ($health.ModelCount -gt 0) {
        Write-Host "    ✓ $($health.ModelCount) model(s) loaded" -ForegroundColor Green
        foreach ($model in $health.ModelsLoaded) {
            $isPrimary = $model -eq $health.PrimaryModel
            if ($isPrimary) {
                Write-Host "      • $model [PRIMARY]" -ForegroundColor Green
            } else {
                Write-Host "      • $model" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "    ⚠ No models loaded" -ForegroundColor Yellow
    }

    # Primary model status
    Write-Host "`n  Primary Model ($($health.PrimaryModel)):" -ForegroundColor Cyan
    if ($health.PrimaryModelReady) {
        Write-Host "    ✓ Ready" -ForegroundColor Green
    } elseif ($health.PrimaryModelAvailable) {
        Write-Host "    ⚠ Available but not ready" -ForegroundColor Yellow
    } else {
        Write-Host "    ✗ Not loaded" -ForegroundColor Red
    }

    # Warnings
    if ($health.Warnings -and $health.Warnings.Count -gt 0) {
        Write-Host "`n  Warnings:" -ForegroundColor Yellow
        foreach ($warning in $health.Warnings) {
            Write-Host "    ⚠ $warning" -ForegroundColor Yellow
        }
    }

} catch {
    Write-Host "✗ Failed to analyze health: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 7: Test custom endpoint
Write-Host "[Test 7] Testing with custom parameters..." -ForegroundColor Yellow
try {
    $customTest = & $scriptPath -APIEndpoint "http://localhost:1234" -PrimaryModel "test-model" -Timeout 5
    $customResult = $customTest | ConvertFrom-Json
    Write-Host "✓ Custom parameters work" -ForegroundColor Green
    Write-Host "  Endpoint: $($customResult.APIEndpoint)" -ForegroundColor Cyan
    Write-Host "  Primary Model: $($customResult.PrimaryModel)" -ForegroundColor Cyan
} catch {
    Write-Host "✗ Custom parameters test failed: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 8: Test log output
Write-Host "[Test 8] Testing log output..." -ForegroundColor Yellow
try {
    $null = & $scriptPath -LogOutput -Verbose 2>&1

    $logDir = Join-Path $PSScriptRoot "logs"
    if (Test-Path $logDir) {
        $logFiles = Get-ChildItem $logDir -Filter "lm-studio-health-*.json" -ErrorAction SilentlyContinue
        if ($logFiles.Count -gt 0) {
            Write-Host "✓ Log files created: $($logFiles.Count) file(s)" -ForegroundColor Green
            $latestLog = $logFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            Write-Host "  Latest: $($latestLog.Name) ($($latestLog.Length) bytes)" -ForegroundColor Cyan
        } else {
            Write-Host "⚠ Log directory exists but no log files found" -ForegroundColor Yellow
        }
    } else {
        Write-Host "⚠ Log directory not created" -ForegroundColor Yellow
    }
} catch {
    Write-Host "✗ Log test failed: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 9: JSON structure validation
Write-Host "[Test 9] Validating JSON structure..." -ForegroundColor Yellow
try {
    $health = & $scriptPath | ConvertFrom-Json

    $requiredProperties = @(
        "Timestamp", "Module", "Version", "ServiceRunning", "APIEndpoint",
        "APIResponsive", "Status", "PrimaryModel"
    )

    $missingProperties = @()
    foreach ($prop in $requiredProperties) {
        if (-not ($health.PSObject.Properties.Name -contains $prop)) {
            $missingProperties += $prop
        }
    }

    if ($missingProperties.Count -eq 0) {
        Write-Host "✓ All required properties present" -ForegroundColor Green
        Write-Host "  Total properties: $($health.PSObject.Properties.Name.Count)" -ForegroundColor Cyan
    } else {
        Write-Host "✗ Missing properties: $($missingProperties -join ', ')" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ JSON validation failed: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 10: Exit code test
Write-Host "[Test 10] Testing exit codes..." -ForegroundColor Yellow
try {
    & $scriptPath | Out-Null
    $exitCode = $LASTEXITCODE

    $exitCodeMeaning = switch ($exitCode) {
        0 { "Healthy (all systems operational)" }
        1 { "Degraded (partial functionality)" }
        2 { "Offline (service not running)" }
        99 { "Error (unexpected failure)" }
        default { "Unknown status" }
    }

    Write-Host "✓ Exit code: $exitCode - $exitCodeMeaning" -ForegroundColor Cyan
} catch {
    Write-Host "✗ Exit code test failed: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Summary
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

$health = & $scriptPath | ConvertFrom-Json

Write-Host "Module: lm-studio-health v$($health.Version)" -ForegroundColor White
Write-Host "Location: $PSScriptRoot" -ForegroundColor White
Write-Host ""

Write-Host "Current Status:" -ForegroundColor Yellow
$statusIcon = switch ($health.Status) {
    "healthy" { "✓" }
    "degraded" { "⚠" }
    "offline" { "✗" }
    default { "?" }
}
$statusColor = switch ($health.Status) {
    "healthy" { "Green" }
    "degraded" { "Yellow" }
    "offline" { "Red" }
    default { "White" }
}
Write-Host "  $statusIcon $($health.Status.ToUpper())" -ForegroundColor $statusColor

if ($health.Status -ne "healthy") {
    Write-Host "`nRecommended Actions:" -ForegroundColor Yellow

    if (-not $health.ServiceRunning) {
        Write-Host "1. Start LM Studio application" -ForegroundColor White
    }

    if (-not $health.APIResponsive -and $health.ServiceRunning) {
        Write-Host "1. Start the API server in LM Studio settings" -ForegroundColor White
        Write-Host "2. Check if LM Studio is using port 1234" -ForegroundColor White
    }

    if (-not $health.PrimaryModelReady -and $health.APIResponsive) {
        Write-Host "1. Load the primary model: $($health.PrimaryModel)" -ForegroundColor White
        if ($health.ModelsLoaded.Count -gt 0) {
            Write-Host "2. Or use one of the loaded models: $($health.ModelsLoaded -join ', ')" -ForegroundColor White
        }
    }
}

Write-Host ""
Write-Host "For full documentation, see README.md" -ForegroundColor Cyan
Write-Host ""
