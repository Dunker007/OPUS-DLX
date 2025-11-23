<#
.SYNOPSIS
    Validates Git repository synchronization status across devices

.DESCRIPTION
    Module #2: Git Sync Validator
    - Checks Git status on local machine
    - Verifies current branch
    - Detects uncommitted changes
    - Checks if local is ahead/behind remote
    - Compares commit hashes
    - Outputs JSON with sync status
    - Flags if push/pull needed
    - Standalone - no dependencies on other modules

.PARAMETER RepositoryPath
    Path to the Git repository to check (defaults to current directory)

.PARAMETER RepositoryName
    Friendly name for the repository (defaults to folder name)

.PARAMETER SkipFetch
    Skip fetching from remote (faster but may show stale data)

.PARAMETER Pretty
    Pretty-print JSON output for readability

.PARAMETER LogOutput
    Save output to logs folder

.OUTPUTS
    JSON object containing repository sync status

.EXAMPLE
    .\Get-GitSyncStatus.ps1
    Checks current directory

.EXAMPLE
    .\Get-GitSyncStatus.ps1 -RepositoryPath "C:\Repos GIT\Fresh-Start"
    Checks specific repository

.EXAMPLE
    .\Get-GitSyncStatus.ps1 -RepositoryPath "C:\LuxRig" -RepositoryName "OPUS-DLX" -Pretty
    Checks OPUS-DLX repository with pretty output

.NOTES
    Version: 1.0.0
    Author: OPUS-DLX AI Orchestration System
    Part of: LuxRig Passive Income Infrastructure
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$RepositoryPath = (Get-Location).Path,

    [Parameter(Mandatory=$false)]
    [string]$RepositoryName,

    [Parameter(Mandatory=$false)]
    [switch]$SkipFetch,

    [Parameter(Mandatory=$false)]
    [switch]$Pretty,

    [Parameter(Mandatory=$false)]
    [switch]$LogOutput
)

function Test-GitInstalled {
    <#
    .SYNOPSIS
        Checks if Git is installed and accessible
    #>
    try {
        $gitCmd = Get-Command git -ErrorAction SilentlyContinue
        if ($gitCmd) {
            $version = & git --version 2>&1
            return @{
                Installed = $true
                Version = $version -replace 'git version ', ''
                Path = $gitCmd.Source
            }
        }
        return @{
            Installed = $false
            Version = $null
            Path = $null
        }
    }
    catch {
        return @{
            Installed = $false
            Version = $null
            Path = $null
            Error = $_.Exception.Message
        }
    }
}

function Test-GitRepository {
    <#
    .SYNOPSIS
        Checks if the specified path is a valid Git repository
    #>
    param([string]$Path)

    try {
        if (-not (Test-Path $Path)) {
            return @{
                IsRepository = $false
                Error = "Path does not exist: $Path"
            }
        }

        $originalLocation = Get-Location
        Set-Location $Path

        $gitDir = & git rev-parse --git-dir 2>&1

        Set-Location $originalLocation

        if ($LASTEXITCODE -eq 0) {
            return @{
                IsRepository = $true
                GitDir = $gitDir
            }
        }
        else {
            return @{
                IsRepository = $false
                Error = "Not a Git repository: $Path"
            }
        }
    }
    catch {
        if ($originalLocation) {
            Set-Location $originalLocation
        }
        return @{
            IsRepository = $false
            Error = $_.Exception.Message
        }
    }
}

function Get-GitBranchInfo {
    <#
    .SYNOPSIS
        Gets current branch information
    #>
    param([string]$RepoPath)

    try {
        $originalLocation = Get-Location
        Set-Location $RepoPath

        # Get current branch
        $branch = & git rev-parse --abbrev-ref HEAD 2>&1

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to get current branch: $branch"
        }

        # Get tracking branch
        $trackingBranch = & git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>&1

        $hasTracking = $LASTEXITCODE -eq 0

        Set-Location $originalLocation

        return @{
            CurrentBranch = $branch.Trim()
            TrackingBranch = if ($hasTracking) { $trackingBranch.Trim() } else { $null }
            HasTracking = $hasTracking
        }
    }
    catch {
        if ($originalLocation) {
            Set-Location $originalLocation
        }
        throw
    }
}

function Get-GitRemoteInfo {
    <#
    .SYNOPSIS
        Gets remote repository information
    #>
    param([string]$RepoPath)

    try {
        $originalLocation = Get-Location
        Set-Location $RepoPath

        # Get remote URL
        $remoteUrl = & git config --get remote.origin.url 2>&1

        if ($LASTEXITCODE -ne 0) {
            Set-Location $originalLocation
            return @{
                HasRemote = $false
                URL = $null
                Name = "origin"
            }
        }

        Set-Location $originalLocation

        return @{
            HasRemote = $true
            URL = $remoteUrl.Trim()
            Name = "origin"
        }
    }
    catch {
        if ($originalLocation) {
            Set-Location $originalLocation
        }
        return @{
            HasRemote = $false
            URL = $null
            Name = "origin"
            Error = $_.Exception.Message
        }
    }
}

function Get-GitCommitHashes {
    <#
    .SYNOPSIS
        Gets local and remote commit hashes
    #>
    param(
        [string]$RepoPath,
        [string]$Branch,
        [string]$TrackingBranch
    )

    try {
        $originalLocation = Get-Location
        Set-Location $RepoPath

        # Get local commit hash
        $localHash = & git rev-parse HEAD 2>&1

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to get local commit hash: $localHash"
        }

        # Get remote commit hash if tracking branch exists
        $remoteHash = $null
        if ($TrackingBranch) {
            $remoteHash = & git rev-parse $TrackingBranch 2>&1
            if ($LASTEXITCODE -ne 0) {
                $remoteHash = $null
            }
            else {
                $remoteHash = $remoteHash.Trim()
            }
        }

        # Get short hashes
        $localShort = & git rev-parse --short HEAD 2>&1
        $remoteShort = $null
        if ($remoteHash) {
            $remoteShort = & git rev-parse --short $TrackingBranch 2>&1
            if ($LASTEXITCODE -ne 0) {
                $remoteShort = $null
            }
            else {
                $remoteShort = $remoteShort.Trim()
            }
        }

        Set-Location $originalLocation

        return @{
            LocalHash = $localHash.Trim()
            LocalShortHash = $localShort.Trim()
            RemoteHash = $remoteHash
            RemoteShortHash = $remoteShort
        }
    }
    catch {
        if ($originalLocation) {
            Set-Location $originalLocation
        }
        throw
    }
}

function Get-GitWorkingTreeStatus {
    <#
    .SYNOPSIS
        Gets working tree status (uncommitted changes)
    #>
    param([string]$RepoPath)

    try {
        $originalLocation = Get-Location
        Set-Location $RepoPath

        # Get porcelain status
        $statusOutput = & git status --porcelain 2>&1

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to get status: $statusOutput"
        }

        $statusLines = $statusOutput | Where-Object { $_ -ne "" }
        $changes = @{
            Staged = @()
            Unstaged = @()
            Untracked = @()
        }

        foreach ($line in $statusLines) {
            if ($line -match '^([MADRCU?!]{2})\s+(.+)$') {
                $status = $matches[1]
                $file = $matches[2]

                # First character is staged status
                $stagedStatus = $status.Substring(0, 1)
                # Second character is unstaged status
                $unstagedStatus = $status.Substring(1, 1)

                if ($stagedStatus -match '[MADRC]') {
                    $changes.Staged += @{
                        Status = $stagedStatus
                        File = $file
                    }
                }

                if ($unstagedStatus -match '[MADRC]') {
                    $changes.Unstaged += @{
                        Status = $unstagedStatus
                        File = $file
                    }
                }

                if ($status -eq '??') {
                    $changes.Untracked += $file
                }
            }
        }

        $totalChanges = $changes.Staged.Count + $changes.Unstaged.Count + $changes.Untracked.Count
        $isDirty = $totalChanges -gt 0

        Set-Location $originalLocation

        return @{
            IsDirty = $isDirty
            TotalChanges = $totalChanges
            StagedCount = $changes.Staged.Count
            UnstagedCount = $changes.Unstaged.Count
            UntrackedCount = $changes.Untracked.Count
            Changes = $changes
        }
    }
    catch {
        if ($originalLocation) {
            Set-Location $originalLocation
        }
        throw
    }
}

function Get-GitAheadBehindCount {
    <#
    .SYNOPSIS
        Gets count of commits ahead/behind remote
    #>
    param(
        [string]$RepoPath,
        [string]$TrackingBranch
    )

    try {
        if (-not $TrackingBranch) {
            return @{
                Ahead = 0
                Behind = 0
                CanCompare = $false
            }
        }

        $originalLocation = Get-Location
        Set-Location $RepoPath

        # Count commits ahead
        $aheadCount = & git rev-list --count "$TrackingBranch..HEAD" 2>&1

        if ($LASTEXITCODE -ne 0) {
            Set-Location $originalLocation
            return @{
                Ahead = 0
                Behind = 0
                CanCompare = $false
                Error = "Failed to count ahead commits: $aheadCount"
            }
        }

        # Count commits behind
        $behindCount = & git rev-list --count "HEAD..$TrackingBranch" 2>&1

        if ($LASTEXITCODE -ne 0) {
            Set-Location $originalLocation
            return @{
                Ahead = [int]$aheadCount
                Behind = 0
                CanCompare = $false
                Error = "Failed to count behind commits: $behindCount"
            }
        }

        Set-Location $originalLocation

        return @{
            Ahead = [int]$aheadCount
            Behind = [int]$behindCount
            CanCompare = $true
        }
    }
    catch {
        if ($originalLocation) {
            Set-Location $originalLocation
        }
        return @{
            Ahead = 0
            Behind = 0
            CanCompare = $false
            Error = $_.Exception.Message
        }
    }
}

function Get-GitLastCommitInfo {
    <#
    .SYNOPSIS
        Gets information about the last commit
    #>
    param([string]$RepoPath)

    try {
        $originalLocation = Get-Location
        Set-Location $RepoPath

        # Get last commit info
        $commitDate = & git log -1 --format=%cI 2>&1
        $commitMessage = & git log -1 --format=%s 2>&1
        $commitAuthor = & git log -1 --format=%an 2>&1

        Set-Location $originalLocation

        if ($LASTEXITCODE -eq 0) {
            return @{
                Date = $commitDate.Trim()
                Message = $commitMessage.Trim()
                Author = $commitAuthor.Trim()
            }
        }
        else {
            return $null
        }
    }
    catch {
        if ($originalLocation) {
            Set-Location $originalLocation
        }
        return $null
    }
}

function Invoke-GitFetch {
    <#
    .SYNOPSIS
        Fetches latest from remote
    #>
    param([string]$RepoPath)

    try {
        $originalLocation = Get-Location
        Set-Location $RepoPath

        Write-Verbose "Fetching from remote..."
        $fetchOutput = & git fetch 2>&1

        Set-Location $originalLocation

        return @{
            Success = $LASTEXITCODE -eq 0
            Output = $fetchOutput
        }
    }
    catch {
        if ($originalLocation) {
            Set-Location $originalLocation
        }
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Get-SyncStatus {
    <#
    .SYNOPSIS
        Determines overall sync status
    #>
    param(
        [bool]$IsDirty,
        [int]$Ahead,
        [int]$Behind
    )

    # Priority: dirty > diverged > ahead > behind > synced
    if ($IsDirty) {
        return "dirty"
    }
    elseif ($Ahead -gt 0 -and $Behind -gt 0) {
        return "diverged"
    }
    elseif ($Ahead -gt 0) {
        return "ahead"
    }
    elseif ($Behind -gt 0) {
        return "behind"
    }
    else {
        return "synced"
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

try {
    # Initialize result object
    $result = @{
        Timestamp = Get-Date -Format "o"
        Module = "git-sync-validator"
        Version = "1.0.0"
        Repository = $RepositoryName
        LocalPath = $RepositoryPath
        Git = $null
        Branch = $null
        Remote = $null
        Commits = $null
        WorkingTree = $null
        Sync = @{
            Status = "unknown"
            Ahead = 0
            Behind = 0
            NeedsPush = $false
            NeedsPull = $false
            IsDirty = $false
        }
        LastCommit = $null
        LastCheck = Get-Date -Format "o"
        Status = "Success"
        Error = $null
        Warnings = @()
    }

    # Check if Git is installed
    $gitInfo = Test-GitInstalled
    $result.Git = $gitInfo

    if (-not $gitInfo.Installed) {
        $result.Status = "Error"
        $result.Error = "Git is not installed or not in PATH"
    }
    else {
        # Check if path is a Git repository
        $repoCheck = Test-GitRepository -Path $RepositoryPath

        if (-not $repoCheck.IsRepository) {
            $result.Status = "Error"
            $result.Error = $repoCheck.Error
        }
        else {
            # Set repository name if not provided
            if (-not $RepositoryName) {
                $result.Repository = Split-Path -Leaf $RepositoryPath
            }

            # Fetch from remote unless skipped
            if (-not $SkipFetch) {
                $fetchResult = Invoke-GitFetch -RepoPath $RepositoryPath
                if (-not $fetchResult.Success) {
                    $result.Warnings += "Failed to fetch from remote: $($fetchResult.Error)"
                }
            }

            # Get branch information
            $branchInfo = Get-GitBranchInfo -RepoPath $RepositoryPath
            $result.Branch = $branchInfo.CurrentBranch

            # Get remote information
            $remoteInfo = Get-GitRemoteInfo -RepoPath $RepositoryPath
            $result.Remote = $remoteInfo

            # Get commit hashes
            $commitInfo = Get-GitCommitHashes -RepoPath $RepositoryPath `
                                               -Branch $branchInfo.CurrentBranch `
                                               -TrackingBranch $branchInfo.TrackingBranch

            $result.Commits = @{
                LocalHash = $commitInfo.LocalHash
                LocalShortHash = $commitInfo.LocalShortHash
                RemoteHash = $commitInfo.RemoteHash
                RemoteShortHash = $commitInfo.RemoteShortHash
                HashesMatch = $commitInfo.LocalHash -eq $commitInfo.RemoteHash
            }

            # Get working tree status
            $workingTreeStatus = Get-GitWorkingTreeStatus -RepoPath $RepositoryPath
            $result.WorkingTree = @{
                IsDirty = $workingTreeStatus.IsDirty
                TotalChanges = $workingTreeStatus.TotalChanges
                Staged = $workingTreeStatus.StagedCount
                Unstaged = $workingTreeStatus.UnstagedCount
                Untracked = $workingTreeStatus.UntrackedCount
                Details = $workingTreeStatus.Changes
            }

            # Get ahead/behind counts
            $aheadBehind = Get-GitAheadBehindCount -RepoPath $RepositoryPath `
                                                    -TrackingBranch $branchInfo.TrackingBranch

            # Determine sync status
            $syncStatus = Get-SyncStatus -IsDirty $workingTreeStatus.IsDirty `
                                          -Ahead $aheadBehind.Ahead `
                                          -Behind $aheadBehind.Behind

            $result.Sync = @{
                Status = $syncStatus
                Ahead = $aheadBehind.Ahead
                Behind = $aheadBehind.Behind
                NeedsPush = $aheadBehind.Ahead -gt 0
                NeedsPull = $aheadBehind.Behind -gt 0
                IsDirty = $workingTreeStatus.IsDirty
                UncommittedChanges = $workingTreeStatus.TotalChanges
                HasTracking = $branchInfo.HasTracking
            }

            # Get last commit info
            $lastCommit = Get-GitLastCommitInfo -RepoPath $RepositoryPath
            if ($lastCommit) {
                $result.LastCommit = $lastCommit
                $result.LastSync = $lastCommit.Date
            }

            # Add warnings if needed
            if (-not $branchInfo.HasTracking) {
                $result.Warnings += "Branch '$($branchInfo.CurrentBranch)' has no tracking branch"
            }

            if (-not $remoteInfo.HasRemote) {
                $result.Warnings += "No remote repository configured"
            }
        }
    }

    # Convert to JSON
    if ($Pretty) {
        $jsonOutput = $result | ConvertTo-Json -Depth 10
    }
    else {
        $jsonOutput = $result | ConvertTo-Json -Depth 10 -Compress
    }

    # Log output if requested
    if ($LogOutput) {
        $logDir = Join-Path $PSScriptRoot "logs"
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        $repoNameSafe = $result.Repository -replace '[^\w\-]', '_'
        $logFile = Join-Path $logDir "git-sync-$repoNameSafe-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        $jsonOutput | Out-File -FilePath $logFile -Encoding utf8
        Write-Verbose "Log saved to: $logFile"
    }

    # Output JSON
    Write-Output $jsonOutput
}
catch {
    # Handle unexpected errors
    $errorResult = @{
        Timestamp = Get-Date -Format "o"
        Module = "git-sync-validator"
        Version = "1.0.0"
        Repository = $RepositoryName
        LocalPath = $RepositoryPath
        Status = "Error"
        Error = $_.Exception.Message
        StackTrace = $_.ScriptStackTrace
    }

    Write-Output ($errorResult | ConvertTo-Json -Depth 5 -Compress)
    exit 1
}
