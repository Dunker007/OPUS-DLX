<#
.SYNOPSIS
    Checks sync status for all configured repositories

.DESCRIPTION
    Helper script to check multiple repositories defined in repositories.json
    Provides a quick overview of all repository states

.PARAMETER ConfigFile
    Path to repositories.json config file (defaults to same directory)

.PARAMETER OnlyCritical
    Only check repositories marked as critical

.PARAMETER Pretty
    Pretty-print output

.EXAMPLE
    .\Check-AllRepositories.ps1

.EXAMPLE
    .\Check-AllRepositories.ps1 -OnlyCritical

.NOTES
    Version: 1.0.0
    Part of OPUS-DLX git-sync-validator module
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigFile,

    [Parameter(Mandatory=$false)]
    [switch]$OnlyCritical,

    [Parameter(Mandatory=$false)]
    [switch]$Pretty
)

# Set default config file path
if (-not $ConfigFile) {
    $ConfigFile = Join-Path $PSScriptRoot "repositories.json"
}

# Check if config file exists
if (-not (Test-Path $ConfigFile)) {
    Write-Error "Config file not found: $ConfigFile"
    Write-Host "Create repositories.json with your repository list" -ForegroundColor Yellow
    exit 1
}

# Load configuration
try {
    $config = Get-Content $ConfigFile | ConvertFrom-Json
} catch {
    Write-Error "Failed to parse config file: $($_.Exception.Message)"
    exit 1
}

# Get the main script path
$mainScript = Join-Path $PSScriptRoot "Get-GitSyncStatus.ps1"

if (-not (Test-Path $mainScript)) {
    Write-Error "Main script not found: $mainScript"
    exit 1
}

# Filter repositories
$repositoriesToCheck = $config.repositories
if ($OnlyCritical) {
    $repositoriesToCheck = $repositoriesToCheck | Where-Object { $_.critical -eq $true }
}

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Git Sync Status - Multiple Repositories" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Checking $($repositoriesToCheck.Count) repository/repositories..." -ForegroundColor White
Write-Host ""

$results = @()
$allSynced = $true
$hasErrors = $false

foreach ($repo in $repositoriesToCheck) {
    Write-Host "[$($repo.name)]" -ForegroundColor Cyan -NoNewline
    Write-Host " $($repo.path)" -ForegroundColor Gray

    # Check if path exists
    if (-not (Test-Path $repo.path)) {
        Write-Host "  ✗ Path does not exist" -ForegroundColor Red
        $hasErrors = $true
        $results += [PSCustomObject]@{
            Repository = $repo.name
            Status = "ERROR"
            Message = "Path not found"
            NeedsAction = $true
        }
        Write-Host ""
        continue
    }

    # Run sync check
    try {
        $status = & $mainScript -RepositoryPath $repo.path -RepositoryName $repo.name | ConvertFrom-Json

        if ($status.Status -eq "Error") {
            Write-Host "  ✗ Error: $($status.Error)" -ForegroundColor Red
            $hasErrors = $true
            $results += [PSCustomObject]@{
                Repository = $repo.name
                Status = "ERROR"
                Message = $status.Error
                NeedsAction = $true
            }
        }
        else {
            # Determine status color
            $statusColor = switch ($status.Sync.Status) {
                "synced" { "Green" }
                "ahead" { "Yellow" }
                "behind" { "Yellow" }
                "dirty" { "Red" }
                "diverged" { "Red" }
                default { "White" }
            }

            $statusIcon = switch ($status.Sync.Status) {
                "synced" { "✓" }
                "ahead" { "⬆" }
                "behind" { "⬇" }
                "dirty" { "⚠" }
                "diverged" { "⚡" }
                default { "?" }
            }

            Write-Host "  $statusIcon Status: $($status.Sync.Status.ToUpper())" -ForegroundColor $statusColor

            # Show details
            if ($status.Branch) {
                Write-Host "    Branch: $($status.Branch)" -ForegroundColor Gray
            }

            if ($status.Sync.Ahead -gt 0) {
                Write-Host "    ⬆ $($status.Sync.Ahead) commit(s) ahead (needs push)" -ForegroundColor Yellow
            }

            if ($status.Sync.Behind -gt 0) {
                Write-Host "    ⬇ $($status.Sync.Behind) commit(s) behind (needs pull)" -ForegroundColor Yellow
            }

            if ($status.Sync.IsDirty) {
                Write-Host "    ⚠ $($status.Sync.UncommittedChanges) uncommitted change(s)" -ForegroundColor Yellow
            }

            if ($status.Warnings -and $status.Warnings.Count -gt 0) {
                foreach ($warning in $status.Warnings) {
                    Write-Host "    ⚠ $warning" -ForegroundColor Yellow
                }
            }

            # Track overall status
            if ($status.Sync.Status -ne "synced") {
                $allSynced = $false
            }

            # Build result object
            $needsAction = $status.Sync.NeedsPush -or $status.Sync.NeedsPull -or $status.Sync.IsDirty

            $results += [PSCustomObject]@{
                Repository = $repo.name
                Status = $status.Sync.Status.ToUpper()
                Branch = $status.Branch
                Ahead = $status.Sync.Ahead
                Behind = $status.Sync.Behind
                Dirty = $status.Sync.IsDirty
                UncommittedChanges = $status.Sync.UncommittedChanges
                NeedsAction = $needsAction
                Critical = $repo.critical
            }
        }
    }
    catch {
        Write-Host "  ✗ Failed to check: $($_.Exception.Message)" -ForegroundColor Red
        $hasErrors = $true
        $results += [PSCustomObject]@{
            Repository = $repo.name
            Status = "ERROR"
            Message = $_.Exception.Message
            NeedsAction = $true
        }
    }

    Write-Host ""
}

# Summary
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

$syncedCount = ($results | Where-Object { $_.Status -eq "SYNCED" }).Count
$aheadCount = ($results | Where-Object { $_.Status -eq "AHEAD" }).Count
$behindCount = ($results | Where-Object { $_.Status -eq "BEHIND" }).Count
$dirtyCount = ($results | Where-Object { $_.Status -eq "DIRTY" }).Count
$divergedCount = ($results | Where-Object { $_.Status -eq "DIVERGED" }).Count
$errorCount = ($results | Where-Object { $_.Status -eq "ERROR" }).Count

Write-Host "Total Repositories: $($results.Count)" -ForegroundColor White
Write-Host "  ✓ Synced: $syncedCount" -ForegroundColor Green
if ($aheadCount -gt 0) {
    Write-Host "  ⬆ Ahead: $aheadCount" -ForegroundColor Yellow
}
if ($behindCount -gt 0) {
    Write-Host "  ⬇ Behind: $behindCount" -ForegroundColor Yellow
}
if ($dirtyCount -gt 0) {
    Write-Host "  ⚠ Dirty: $dirtyCount" -ForegroundColor Red
}
if ($divergedCount -gt 0) {
    Write-Host "  ⚡ Diverged: $divergedCount" -ForegroundColor Red
}
if ($errorCount -gt 0) {
    Write-Host "  ✗ Errors: $errorCount" -ForegroundColor Red
}

Write-Host ""

# Action items
$reposNeedingAction = $results | Where-Object { $_.NeedsAction -eq $true }

if ($reposNeedingAction.Count -gt 0) {
    Write-Host "Repositories Needing Attention:" -ForegroundColor Yellow
    foreach ($repo in $reposNeedingAction) {
        Write-Host "  • $($repo.Repository) - $($repo.Status)" -ForegroundColor Yellow
    }
    Write-Host ""
}

# Overall status
if ($allSynced -and -not $hasErrors) {
    Write-Host "✓ All repositories are synchronized!" -ForegroundColor Green
    exit 0
}
elseif ($hasErrors) {
    Write-Host "✗ Some repositories have errors" -ForegroundColor Red
    exit 1
}
else {
    Write-Host "⚠ Some repositories need attention" -ForegroundColor Yellow
    exit 2
}
