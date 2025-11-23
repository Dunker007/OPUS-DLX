# Module #2: Git Sync Validator

## Overview

The **git-sync-validator** module provides comprehensive Git repository synchronization validation across all LuxRig devices. It ensures your repositories are properly synced before running distributed AI tasks and helps prevent merge conflicts.

## Features

- ✅ **Git Status Check** - Verifies Git installation and repository validity
- ✅ **Branch Tracking** - Identifies current branch and tracking status
- ✅ **Change Detection** - Detects uncommitted changes (staged, unstaged, untracked)
- ✅ **Sync Analysis** - Checks if local is ahead/behind remote
- ✅ **Commit Comparison** - Compares local and remote commit hashes
- ✅ **Action Flags** - Indicates if push/pull is needed
- ✅ **JSON Output** - Structured data format for easy integration
- ✅ **Standalone** - No dependencies on other OPUS-DLX modules

## Use Cases

### 1. Pre-Task Validation
Check if repositories are synced before running AI orchestration tasks across multiple devices.

### 2. Multi-Device Development
Ensure all devices (LuxRig, Work PC, Laptop) have the latest code before starting work.

### 3. Automated Monitoring
Schedule periodic checks to catch sync issues early.

### 4. CI/CD Integration
Validate repository state before deployments.

## Installation

### On Windows (LuxRig)

1. Copy this module to `C:\LuxRig\Modules\git-sync-validator\`
2. Ensure Git is installed and in PATH
3. Navigate to any Git repository to test

### Prerequisites

- **Git 2.0+** installed and configured
- **PowerShell 5.1+** (Windows) or **PowerShell Core 7+** (cross-platform)
- Valid Git repository with remote configured

## Usage

### Basic Usage

```powershell
# Check current directory
cd C:\Repos GIT\Fresh-Start
C:\LuxRig\Modules\git-sync-validator\Get-GitSyncStatus.ps1
```

### Check Specific Repository

```powershell
# Check Fresh-Start repository
.\Get-GitSyncStatus.ps1 -RepositoryPath "C:\Repos GIT\Fresh-Start" -RepositoryName "Fresh-Start"
```

### Pretty-Printed Output

```powershell
.\Get-GitSyncStatus.ps1 -RepositoryPath "C:\LuxRig" -Pretty
```

### Skip Remote Fetch (Faster)

```powershell
# Use cached remote data (faster but may be stale)
.\Get-GitSyncStatus.ps1 -SkipFetch
```

### Save to Log File

```powershell
.\Get-GitSyncStatus.ps1 -RepositoryPath "C:\Repos GIT\Fresh-Start" -LogOutput -Verbose
```

### Parse JSON in PowerShell

```powershell
$status = .\Get-GitSyncStatus.ps1 -RepositoryPath "C:\Repos GIT\Fresh-Start" | ConvertFrom-Json

# Check sync status
Write-Host "Status: $($status.Sync.Status)"

# Check if push/pull needed
if ($status.Sync.NeedsPush) {
    Write-Host "⚠ Needs push: $($status.Sync.Ahead) commit(s) ahead"
}

if ($status.Sync.NeedsPull) {
    Write-Host "⚠ Needs pull: $($status.Sync.Behind) commit(s) behind"
}

# Check for uncommitted changes
if ($status.Sync.IsDirty) {
    Write-Host "⚠ Uncommitted changes: $($status.Sync.UncommittedChanges)"
}

# List uncommitted files
if ($status.WorkingTree.IsDirty) {
    Write-Host "`nUncommitted files:"
    $status.WorkingTree.Details.Staged | ForEach-Object { Write-Host "  [Staged] $($_.File)" }
    $status.WorkingTree.Details.Unstaged | ForEach-Object { Write-Host "  [Unstaged] $($_.File)" }
    $status.WorkingTree.Details.Untracked | ForEach-Object { Write-Host "  [Untracked] $_" }
}
```

### Integration with Other Modules

```powershell
# Example: Check sync before running AI tasks
$freshStartStatus = .\Get-GitSyncStatus.ps1 -RepositoryPath "C:\Repos GIT\Fresh-Start" | ConvertFrom-Json
$opusDlxStatus = .\Get-GitSyncStatus.ps1 -RepositoryPath "C:\LuxRig" | ConvertFrom-Json

if ($freshStartStatus.Sync.Status -eq "synced" -and $opusDlxStatus.Sync.Status -eq "synced") {
    Write-Host "✓ All repositories synced. Proceeding with AI orchestration..."
    # Run other OPUS-DLX modules
} else {
    Write-Warning "Repository sync issues detected. Please resolve before continuing."
    if ($freshStartStatus.Sync.Status -ne "synced") {
        Write-Host "Fresh-Start: $($freshStartStatus.Sync.Status)"
    }
    if ($opusDlxStatus.Sync.Status -ne "synced") {
        Write-Host "OPUS-DLX: $($opusDlxStatus.Sync.Status)"
    }
}
```

## Output Format

### Sync Status Values

- **`synced`** - Everything is up to date, no changes
- **`ahead`** - Local has commits not pushed to remote
- **`behind`** - Remote has commits not pulled locally
- **`diverged`** - Both local and remote have unique commits (merge needed)
- **`dirty`** - Uncommitted changes in working tree

### Success Response

```json
{
  "Timestamp": "2024-11-23T12:34:56.789Z",
  "Module": "git-sync-validator",
  "Version": "1.0.0",
  "Repository": "Fresh-Start",
  "LocalPath": "C:\\Repos GIT\\Fresh-Start",
  "Git": {
    "Installed": true,
    "Version": "2.42.0.windows.1",
    "Path": "C:\\Program Files\\Git\\cmd\\git.exe"
  },
  "Branch": "main",
  "Remote": {
    "HasRemote": true,
    "URL": "https://github.com/Dunker007/Fresh-Start",
    "Name": "origin"
  },
  "Commits": {
    "LocalHash": "abc123def456...",
    "LocalShortHash": "abc123d",
    "RemoteHash": "abc123def456...",
    "RemoteShortHash": "abc123d",
    "HashesMatch": true
  },
  "WorkingTree": {
    "IsDirty": false,
    "TotalChanges": 0,
    "Staged": 0,
    "Unstaged": 0,
    "Untracked": 0,
    "Details": {
      "Staged": [],
      "Unstaged": [],
      "Untracked": []
    }
  },
  "Sync": {
    "Status": "synced",
    "Ahead": 0,
    "Behind": 0,
    "NeedsPush": false,
    "NeedsPull": false,
    "IsDirty": false,
    "UncommittedChanges": 0,
    "HasTracking": true
  },
  "LastCommit": {
    "Date": "2024-11-22T19:30:00Z",
    "Message": "Add feature X",
    "Author": "John Doe"
  },
  "LastSync": "2024-11-22T19:30:00Z",
  "Status": "Success",
  "Error": null,
  "Warnings": []
}
```

### Dirty Repository Example

```json
{
  "Repository": "Fresh-Start",
  "LocalPath": "C:\\Repos GIT\\Fresh-Start",
  "Branch": "main",
  "WorkingTree": {
    "IsDirty": true,
    "TotalChanges": 3,
    "Staged": 1,
    "Unstaged": 1,
    "Untracked": 1,
    "Details": {
      "Staged": [
        {
          "Status": "M",
          "File": "src/main.ps1"
        }
      ],
      "Unstaged": [
        {
          "Status": "M",
          "File": "README.md"
        }
      ],
      "Untracked": [
        "temp.txt"
      ]
    }
  },
  "Sync": {
    "Status": "dirty",
    "UncommittedChanges": 3,
    "IsDirty": true
  }
}
```

### Ahead of Remote Example

```json
{
  "Repository": "Fresh-Start",
  "Sync": {
    "Status": "ahead",
    "Ahead": 2,
    "Behind": 0,
    "NeedsPush": true,
    "NeedsPull": false,
    "IsDirty": false
  }
}
```

### Behind Remote Example

```json
{
  "Repository": "Fresh-Start",
  "Sync": {
    "Status": "behind",
    "Ahead": 0,
    "Behind": 3,
    "NeedsPush": false,
    "NeedsPull": true,
    "IsDirty": false
  }
}
```

### Diverged Example

```json
{
  "Repository": "Fresh-Start",
  "Sync": {
    "Status": "diverged",
    "Ahead": 2,
    "Behind": 3,
    "NeedsPush": true,
    "NeedsPull": true,
    "IsDirty": false
  }
}
```

## Configuration

### Check Multiple Repositories

Create a simple loop script:

```powershell
# check-all-repos.ps1
$repositories = @(
    @{ Name = "Fresh-Start"; Path = "C:\Repos GIT\Fresh-Start" },
    @{ Name = "OPUS-DLX"; Path = "C:\LuxRig" },
    @{ Name = "MyProject"; Path = "C:\Projects\MyProject" }
)

foreach ($repo in $repositories) {
    Write-Host "`nChecking $($repo.Name)..." -ForegroundColor Cyan
    $status = .\Get-GitSyncStatus.ps1 -RepositoryPath $repo.Path -RepositoryName $repo.Name | ConvertFrom-Json

    $color = switch ($status.Sync.Status) {
        "synced" { "Green" }
        "ahead" { "Yellow" }
        "behind" { "Yellow" }
        "dirty" { "Red" }
        "diverged" { "Red" }
        default { "White" }
    }

    Write-Host "  Status: $($status.Sync.Status)" -ForegroundColor $color

    if ($status.Sync.NeedsPush) {
        Write-Host "  ⬆ $($status.Sync.Ahead) commit(s) to push" -ForegroundColor Yellow
    }

    if ($status.Sync.NeedsPull) {
        Write-Host "  ⬇ $($status.Sync.Behind) commit(s) to pull" -ForegroundColor Yellow
    }

    if ($status.Sync.IsDirty) {
        Write-Host "  ⚠ $($status.Sync.UncommittedChanges) uncommitted change(s)" -ForegroundColor Red
    }
}
```

## Troubleshooting

### "Git is not installed or not in PATH"

**Solution**: Install Git and ensure it's in your PATH
```powershell
# Check if git is accessible
Get-Command git

# Add Git to PATH (restart PowerShell after)
$env:Path += ";C:\Program Files\Git\cmd"
```

### "Not a Git repository"

**Solution**: Ensure you're in a valid Git repository
```powershell
# Check if directory is a Git repository
cd C:\Repos GIT\Fresh-Start
git status
```

### "Branch has no tracking branch"

**Cause**: Local branch isn't set up to track a remote branch

**Solution**: Set up tracking
```powershell
git branch --set-upstream-to=origin/main main
```

### "Failed to fetch from remote"

**Possible causes**:
1. No internet connection
2. Remote URL is incorrect
3. Authentication failure

**Solutions**:
```powershell
# Check remote URL
git remote -v

# Test connection
git ls-remote origin

# Update remote URL if needed
git remote set-url origin https://github.com/username/repo.git
```

### Stale Remote Data

**Issue**: Using `-SkipFetch` may show outdated remote status

**Solution**: Run without `-SkipFetch` or manually fetch
```powershell
git fetch
.\Get-GitSyncStatus.ps1
```

## Automation

### Scheduled Monitoring (Windows Task Scheduler)

Check all repositories every hour:

```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-File C:\LuxRig\Scripts\check-all-repos.ps1"

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1)

Register-ScheduledTask -TaskName "OPUS-GitSyncMonitor" `
    -Action $action -Trigger $trigger -RunLevel Highest
```

### Pre-Commit Hook

Prevent commits when behind remote:

```powershell
# .git/hooks/pre-commit (PowerShell version)
$status = C:\LuxRig\Modules\git-sync-validator\Get-GitSyncStatus.ps1 | ConvertFrom-Json

if ($status.Sync.Behind -gt 0) {
    Write-Host "❌ Cannot commit: Repository is $($status.Sync.Behind) commit(s) behind remote" -ForegroundColor Red
    Write-Host "Run 'git pull' first" -ForegroundColor Yellow
    exit 1
}
```

### Auto-Sync Script

```powershell
# auto-sync.ps1
$status = .\Get-GitSyncStatus.ps1 | ConvertFrom-Json

if ($status.Sync.Status -eq "behind") {
    Write-Host "Pulling $($status.Sync.Behind) commit(s)..."
    git pull
}

if ($status.Sync.Status -eq "ahead") {
    Write-Host "Pushing $($status.Sync.Ahead) commit(s)..."
    git push
}

if ($status.Sync.Status -eq "synced") {
    Write-Host "✓ Already synced" -ForegroundColor Green
}
```

## Integration with OPUS-DLX

### Pre-Task Repository Validation

```powershell
# Example integration in task-router.ps1
function Invoke-AITask {
    param($Task)

    # Check if code repositories are synced
    $repoStatus = & C:\LuxRig\Modules\git-sync-validator\Get-GitSyncStatus.ps1 `
                    -RepositoryPath "C:\Repos GIT\Fresh-Start" | ConvertFrom-Json

    if ($repoStatus.Sync.Status -ne "synced") {
        throw "Cannot execute task: Fresh-Start repository is not synced ($($repoStatus.Sync.Status))"
    }

    # Proceed with AI task routing...
}
```

### Dashboard Integration

```powershell
# Example for Analytics dashboard
$metrics = @{
    Timestamp = Get-Date
    RepositorySync = @(
        (& .\Modules\git-sync-validator\Get-GitSyncStatus.ps1 -RepositoryPath "C:\Repos GIT\Fresh-Start" | ConvertFrom-Json),
        (& .\Modules\git-sync-validator\Get-GitSyncStatus.ps1 -RepositoryPath "C:\LuxRig" | ConvertFrom-Json)
    )
    # Other metrics...
}
```

### Multi-Device Sync Checker

```powershell
# check-device-sync.ps1
# Run this on each device to ensure all are synced

$devices = @("LuxRig", "Work PC", "Laptop")
$currentDevice = $env:COMPUTERNAME

$status = .\Get-GitSyncStatus.ps1 -RepositoryPath "C:\Repos GIT\Fresh-Start" | ConvertFrom-Json

# Store status in shared location (e.g., via Tailscale share)
$statusFile = "\\luxrig\sync-status\$currentDevice-freshstart.json"
$status | ConvertTo-Json -Depth 10 | Out-File $statusFile

# Compare with other devices
foreach ($device in $devices) {
    if ($device -eq $currentDevice) { continue }

    $deviceStatusFile = "\\luxrig\sync-status\$device-freshstart.json"
    if (Test-Path $deviceStatusFile) {
        $deviceStatus = Get-Content $deviceStatusFile | ConvertFrom-Json
        if ($deviceStatus.Commits.LocalHash -ne $status.Commits.LocalHash) {
            Write-Warning "$device is on different commit: $($deviceStatus.Commits.LocalShortHash)"
        }
    }
}
```

## Advanced Usage

### Check All Branches

```powershell
# Get status for all branches
$branches = git branch -r | ForEach-Object { $_.Trim() }

foreach ($branch in $branches) {
    git checkout $branch
    $status = .\Get-GitSyncStatus.ps1 | ConvertFrom-Json
    Write-Host "$branch : $($status.Sync.Status)"
}
```

### Export to CSV

```powershell
# Monitor multiple repos and export to CSV
$repos = @("C:\Repos GIT\Fresh-Start", "C:\LuxRig", "C:\Projects\MyApp")
$results = @()

foreach ($repo in $repos) {
    $status = .\Get-GitSyncStatus.ps1 -RepositoryPath $repo | ConvertFrom-Json
    $results += [PSCustomObject]@{
        Repository = $status.Repository
        Branch = $status.Branch
        Status = $status.Sync.Status
        Ahead = $status.Sync.Ahead
        Behind = $status.Sync.Behind
        Dirty = $status.Sync.IsDirty
        LastCommit = $status.LastCommit.Date
    }
}

$results | Export-Csv -Path "repo-sync-status.csv" -NoTypeInformation
```

## Future Enhancements

Planned features for v2.0:

- [ ] **Multi-remote support** (origin, upstream, etc.)
- [ ] **Submodule status checking**
- [ ] **Stash detection and reporting**
- [ ] **Auto-merge conflict detection**
- [ ] **Email/SMS alerts for sync issues**
- [ ] **Web dashboard integration**
- [ ] **LFS (Large File Storage) status**
- [ ] **Branch age and staleness warnings**

## Version History

### v1.0.0 (2024-11-23)
- Initial release
- Core sync validation
- Ahead/behind detection
- Uncommitted changes tracking
- JSON output format
- Standalone operation

## License

Part of the OPUS-DLX project. See main repository for license information.

## Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review Git documentation
3. Check OPUS-DLX main repository issues

---

**Part of the LuxRig Passive Income Infrastructure**
*AI-Powered Opportunity Hunter - Module #2*
