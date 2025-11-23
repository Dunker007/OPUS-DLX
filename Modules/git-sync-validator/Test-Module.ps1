<#
.SYNOPSIS
    Test script for the git-sync-validator module

.DESCRIPTION
    Demonstrates usage and validates the module functionality
    Run this to verify everything works correctly

.EXAMPLE
    .\Test-Module.ps1
#>

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "OPUS-DLX Module #2: Git Sync Validator - Test Suite" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Check if script exists
Write-Host "[Test 1] Checking if Get-GitSyncStatus.ps1 exists..." -ForegroundColor Yellow
$scriptPath = Join-Path $PSScriptRoot "Get-GitSyncStatus.ps1"
if (Test-Path $scriptPath) {
    Write-Host "✓ Script found at: $scriptPath" -ForegroundColor Green
} else {
    Write-Host "✗ Script not found!" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Test 2: Check Git installation
Write-Host "[Test 2] Checking Git installation..." -ForegroundColor Yellow
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if ($gitCmd) {
    $gitVersion = & git --version
    Write-Host "✓ Git found: $gitVersion" -ForegroundColor Green
    Write-Host "  Location: $($gitCmd.Source)" -ForegroundColor Cyan
} else {
    Write-Host "✗ Git not found in PATH" -ForegroundColor Red
    Write-Host "  Install from: https://git-scm.com/download" -ForegroundColor Yellow
}
Write-Host ""

# Test 3: Detect current repository
Write-Host "[Test 3] Detecting Git repository..." -ForegroundColor Yellow
$currentPath = Get-Location
$gitCheck = & git rev-parse --git-dir 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Current directory is a Git repository" -ForegroundColor Green
    Write-Host "  Path: $currentPath" -ForegroundColor Cyan

    $repoRoot = & git rev-parse --show-toplevel 2>&1
    Write-Host "  Root: $repoRoot" -ForegroundColor Cyan
} else {
    Write-Host "⚠ Current directory is NOT a Git repository" -ForegroundColor Yellow
    Write-Host "  You can still test with a specific path using -RepositoryPath" -ForegroundColor Yellow
}
Write-Host ""

# Test 4: Run module on current directory
Write-Host "[Test 4] Running module on current directory..." -ForegroundColor Yellow
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

# Test 6: Analyze repository status (if in a Git repo)
Write-Host "[Test 6] Analyzing repository status..." -ForegroundColor Yellow
try {
    $status = & $scriptPath | ConvertFrom-Json

    if ($status.Status -eq "Success") {
        Write-Host "✓ Repository analysis completed" -ForegroundColor Green

        # Repository info
        if ($status.Repository) {
            Write-Host "`n  Repository Details:" -ForegroundColor Cyan
            Write-Host "    Name: $($status.Repository)" -ForegroundColor White
            Write-Host "    Path: $($status.LocalPath)" -ForegroundColor White
            Write-Host "    Branch: $($status.Branch)" -ForegroundColor White
        }

        # Git info
        if ($status.Git.Installed) {
            Write-Host "`n  Git Installation:" -ForegroundColor Cyan
            Write-Host "    Version: $($status.Git.Version)" -ForegroundColor White
            Write-Host "    Path: $($status.Git.Path)" -ForegroundColor White
        }

        # Remote info
        if ($status.Remote.HasRemote) {
            Write-Host "`n  Remote:" -ForegroundColor Cyan
            Write-Host "    URL: $($status.Remote.URL)" -ForegroundColor White
        } else {
            Write-Host "`n  Remote:" -ForegroundColor Yellow
            Write-Host "    ⚠ No remote configured" -ForegroundColor Yellow
        }

        # Commit info
        if ($status.Commits) {
            Write-Host "`n  Commits:" -ForegroundColor Cyan
            Write-Host "    Local:  $($status.Commits.LocalShortHash)" -ForegroundColor White
            if ($status.Commits.RemoteShortHash) {
                Write-Host "    Remote: $($status.Commits.RemoteShortHash)" -ForegroundColor White
                if ($status.Commits.HashesMatch) {
                    Write-Host "    ✓ Hashes match" -ForegroundColor Green
                } else {
                    Write-Host "    ✗ Hashes differ" -ForegroundColor Red
                }
            }
        }

        # Working tree status
        if ($status.WorkingTree) {
            Write-Host "`n  Working Tree:" -ForegroundColor Cyan
            if ($status.WorkingTree.IsDirty) {
                Write-Host "    ⚠ Has uncommitted changes: $($status.WorkingTree.TotalChanges)" -ForegroundColor Yellow
                Write-Host "      Staged: $($status.WorkingTree.Staged)" -ForegroundColor Gray
                Write-Host "      Unstaged: $($status.WorkingTree.Unstaged)" -ForegroundColor Gray
                Write-Host "      Untracked: $($status.WorkingTree.Untracked)" -ForegroundColor Gray
            } else {
                Write-Host "    ✓ Clean - no uncommitted changes" -ForegroundColor Green
            }
        }

        # Sync status
        if ($status.Sync) {
            Write-Host "`n  Sync Status:" -ForegroundColor Cyan

            $statusColor = switch ($status.Sync.Status) {
                "synced" { "Green" }
                "ahead" { "Yellow" }
                "behind" { "Yellow" }
                "dirty" { "Red" }
                "diverged" { "Red" }
                default { "White" }
            }

            Write-Host "    Status: $($status.Sync.Status.ToUpper())" -ForegroundColor $statusColor

            if ($status.Sync.Ahead -gt 0) {
                Write-Host "    ⬆ Ahead: $($status.Sync.Ahead) commit(s)" -ForegroundColor Yellow
            }

            if ($status.Sync.Behind -gt 0) {
                Write-Host "    ⬇ Behind: $($status.Sync.Behind) commit(s)" -ForegroundColor Yellow
            }

            if ($status.Sync.NeedsPush) {
                Write-Host "    📤 Action: Push required" -ForegroundColor Yellow
            }

            if ($status.Sync.NeedsPull) {
                Write-Host "    📥 Action: Pull required" -ForegroundColor Yellow
            }

            if ($status.Sync.Status -eq "synced" -and -not $status.Sync.IsDirty) {
                Write-Host "    ✓ Everything is synchronized" -ForegroundColor Green
            }
        }

        # Last commit
        if ($status.LastCommit) {
            Write-Host "`n  Last Commit:" -ForegroundColor Cyan
            Write-Host "    Message: $($status.LastCommit.Message)" -ForegroundColor White
            Write-Host "    Author: $($status.LastCommit.Author)" -ForegroundColor White
            Write-Host "    Date: $($status.LastCommit.Date)" -ForegroundColor White
        }

        # Warnings
        if ($status.Warnings -and $status.Warnings.Count -gt 0) {
            Write-Host "`n  Warnings:" -ForegroundColor Yellow
            foreach ($warning in $status.Warnings) {
                Write-Host "    ⚠ $warning" -ForegroundColor Yellow
            }
        }

    } else {
        Write-Host "✗ Repository analysis failed" -ForegroundColor Red
        if ($status.Error) {
            Write-Host "  Error: $($status.Error)" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "✗ Failed to analyze repository: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 7: Test with -SkipFetch flag
Write-Host "[Test 7] Testing -SkipFetch flag (faster execution)..." -ForegroundColor Yellow
try {
    $startTime = Get-Date
    $null = & $scriptPath -SkipFetch
    $duration = ((Get-Date) - $startTime).TotalMilliseconds

    Write-Host "✓ SkipFetch mode works" -ForegroundColor Green
    Write-Host "  Execution time: $([math]::Round($duration, 0))ms" -ForegroundColor Cyan
} catch {
    Write-Host "✗ SkipFetch test failed: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Test 8: Test log output
Write-Host "[Test 8] Testing log output..." -ForegroundColor Yellow
try {
    $null = & $scriptPath -LogOutput -Verbose 2>&1

    $logDir = Join-Path $PSScriptRoot "logs"
    if (Test-Path $logDir) {
        $logFiles = Get-ChildItem $logDir -Filter "git-sync-*.json" -ErrorAction SilentlyContinue
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

# Test 9: Test specific repository path
Write-Host "[Test 9] Testing with specific repository path..." -ForegroundColor Yellow
$testRepos = @(
    "C:\Repos GIT\Fresh-Start",
    "C:\LuxRig",
    "."  # current directory
)

$foundRepo = $null
foreach ($repo in $testRepos) {
    if (Test-Path $repo) {
        $gitTest = Push-Location $repo -PassThru -ErrorAction SilentlyContinue
        $isGit = & git rev-parse --git-dir 2>&1
        Pop-Location

        if ($LASTEXITCODE -eq 0) {
            $foundRepo = $repo
            break
        }
    }
}

if ($foundRepo) {
    try {
        $status = & $scriptPath -RepositoryPath $foundRepo -RepositoryName "TestRepo" | ConvertFrom-Json
        Write-Host "✓ Custom path works: $foundRepo" -ForegroundColor Green
        Write-Host "  Repository: $($status.Repository)" -ForegroundColor Cyan
        Write-Host "  Branch: $($status.Branch)" -ForegroundColor Cyan
    } catch {
        Write-Host "✗ Custom path test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "⚠ No test repositories found" -ForegroundColor Yellow
    Write-Host "  Skipping custom path test" -ForegroundColor Gray
}
Write-Host ""

# Test 10: JSON parsing test
Write-Host "[Test 10] Testing JSON parsing and PowerShell integration..." -ForegroundColor Yellow
try {
    $status = & $scriptPath | ConvertFrom-Json

    # Test object property access
    $hasAllProperties = $status.PSObject.Properties.Name -contains "Timestamp" -and
                        $status.PSObject.Properties.Name -contains "Module" -and
                        $status.PSObject.Properties.Name -contains "Sync"

    if ($hasAllProperties) {
        Write-Host "✓ JSON structure is valid" -ForegroundColor Green
        Write-Host "  Properties: $($status.PSObject.Properties.Name.Count)" -ForegroundColor Cyan
    } else {
        Write-Host "✗ JSON structure is missing expected properties" -ForegroundColor Red
    }

    # Test conditional logic
    if ($status.Sync) {
        $needsAction = $status.Sync.NeedsPush -or $status.Sync.NeedsPull -or $status.Sync.IsDirty

        if ($needsAction) {
            Write-Host "  ℹ Repository needs attention" -ForegroundColor Yellow
        } else {
            Write-Host "  ℹ Repository is in good state" -ForegroundColor Green
        }
    }
} catch {
    Write-Host "✗ JSON parsing failed: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# Summary
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Module: git-sync-validator v1.0.0" -ForegroundColor White
Write-Host "Location: $PSScriptRoot" -ForegroundColor White
Write-Host ""
Write-Host "Usage Examples:" -ForegroundColor Yellow
Write-Host ""
Write-Host "# Check specific repository:" -ForegroundColor Gray
Write-Host '  .\Get-GitSyncStatus.ps1 -RepositoryPath "C:\Repos GIT\Fresh-Start"' -ForegroundColor White
Write-Host ""
Write-Host "# Pretty output:" -ForegroundColor Gray
Write-Host '  .\Get-GitSyncStatus.ps1 -Pretty' -ForegroundColor White
Write-Host ""
Write-Host "# Parse and use in scripts:" -ForegroundColor Gray
Write-Host '  $status = .\Get-GitSyncStatus.ps1 | ConvertFrom-Json' -ForegroundColor White
Write-Host '  if ($status.Sync.NeedsPush) { git push }' -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Test with your Fresh-Start repository" -ForegroundColor White
Write-Host "2. Integrate with OPUS-DLX orchestrator" -ForegroundColor White
Write-Host "3. Set up automated sync monitoring" -ForegroundColor White
Write-Host "4. Create multi-repository checking script" -ForegroundColor White
Write-Host ""
Write-Host "For full documentation, see README.md" -ForegroundColor Cyan
Write-Host ""
