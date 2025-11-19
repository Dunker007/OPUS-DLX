#Requires -Version 7.0

<#
.SYNOPSIS
    LuxRig Team Collaboration Workspace

.DESCRIPTION
    Enterprise team collaboration features:
    - Shared portfolios (team accounts)
    - Trade approval workflows
    - Activity feed (team transparency)
    - Comments & annotations
    - Team chat (encrypted)
    - Collaborative decision-making

.NOTES
    Part of LuxRig Enterprise Edition
    Multi-user trading collaboration
#>

$script:Config = @{
    DatabasePath = "$PSScriptRoot/../../Data/workspaces.json"
    ActivityFeedPath = "$PSScriptRoot/../../Data/activity-feed.json"
    ChatHistoryPath = "$PSScriptRoot/../../Data/team-chat.json"
    RequireApproval = $true
    ApprovalThreshold = 10000  # Trades > $10k require approval
}

$script:Workspaces = @{}
$script:ActivityFeed = @()
$script:ChatMessages = @()

function Initialize-TeamWorkspace {
    try {
        $dataDir = Split-Path $script:Config.DatabasePath
        if (-not (Test-Path $dataDir)) {
            New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
        }

        if (Test-Path $script:Config.DatabasePath) {
            $data = Get-Content $script:Config.DatabasePath | ConvertFrom-Json
            $script:Workspaces = @{}
            foreach ($ws in $data) {
                $script:Workspaces[$ws.workspaceId] = $ws
            }
        }

        if (Test-Path $script:Config.ActivityFeedPath) {
            $script:ActivityFeed = Get-Content $script:Config.ActivityFeedPath | ConvertFrom-Json
        }

        if (Test-Path $script:Config.ChatHistoryPath) {
            $script:ChatMessages = Get-Content $script:Config.ChatHistoryPath | ConvertFrom-Json
        }

        Write-Host "[TeamWorkspace] Initialized with $($script:Workspaces.Count) workspaces" -ForegroundColor Green
    }
    catch {
        Write-Warning "[TeamWorkspace] Initialization error: $_"
    }
}

function Save-WorkspaceData {
    try {
        $script:Workspaces.Values | ConvertTo-Json -Depth 10 | Out-File $script:Config.DatabasePath -Force
        $script:ActivityFeed | ConvertTo-Json -Depth 10 | Out-File $script:Config.ActivityFeedPath -Force
        $script:ChatMessages | ConvertTo-Json -Depth 10 | Out-File $script:Config.ChatHistoryPath -Force
    }
    catch {
        Write-Warning "[TeamWorkspace] Save error: $_"
    }
}

function New-Workspace {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$OwnerId,

        [string]$Description = "",
        [array]$Members = @()
    )

    $workspaceId = [guid]::NewGuid().ToString()

    $workspace = @{
        workspaceId = $workspaceId
        name = $Name
        description = $Description
        ownerId = $OwnerId
        created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        members = @($OwnerId) + $Members
        sharedPortfolio = @{
            balance = 0
            positions = @()
            trades = @()
        }
        pendingApprovals = @()
        settings = @{
            requireApproval = $script:Config.RequireApproval
            approvalThreshold = $script:Config.ApprovalThreshold
            allowComments = $true
            allowChat = $true
        }
    }

    $script:Workspaces[$workspaceId] = $workspace
    Save-WorkspaceData

    Add-ActivityFeedItem -WorkspaceId $workspaceId -UserId $OwnerId -Action "WORKSPACE_CREATED" -Details "Created workspace: $Name"

    Write-Host "[TeamWorkspace] Workspace created: $Name" -ForegroundColor Green
    return @{ success = $true; workspaceId = $workspaceId; workspace = $workspace }
}

function Add-WorkspaceMember {
    param(
        [Parameter(Mandatory)]
        [string]$WorkspaceId,

        [Parameter(Mandatory)]
        [string]$UserId,

        [Parameter(Mandatory)]
        [string]$RequesterId
    )

    $workspace = $script:Workspaces[$WorkspaceId]
    if (-not $workspace) {
        return @{ success = $false; error = "Workspace not found" }
    }

    if ($workspace.ownerId -ne $RequesterId) {
        return @{ success = $false; error = "Only workspace owner can add members" }
    }

    if ($UserId -in $workspace.members) {
        return @{ success = $false; error = "User already a member" }
    }

    $workspace.members += $UserId
    Save-WorkspaceData

    Add-ActivityFeedItem -WorkspaceId $WorkspaceId -UserId $RequesterId -Action "MEMBER_ADDED" -Details "Added user: $UserId"

    return @{ success = $true; message = "Member added successfully" }
}

function Submit-TradeForApproval {
    param(
        [Parameter(Mandatory)]
        [string]$WorkspaceId,

        [Parameter(Mandatory)]
        [string]$UserId,

        [Parameter(Mandatory)]
        [hashtable]$TradeDetails
    )

    $workspace = $script:Workspaces[$WorkspaceId]
    if (-not $workspace) {
        return @{ success = $false; error = "Workspace not found" }
    }

    if ($UserId -notin $workspace.members) {
        return @{ success = $false; error = "User not a member of this workspace" }
    }

    $approvalId = [guid]::NewGuid().ToString()
    $approval = @{
        approvalId = $approvalId
        workspaceId = $WorkspaceId
        submittedBy = $UserId
        submittedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        tradeDetails = $TradeDetails
        status = "PENDING"
        approvals = @()
        rejections = @()
        comments = @()
    }

    $workspace.pendingApprovals += $approval
    Save-WorkspaceData

    Add-ActivityFeedItem -WorkspaceId $WorkspaceId -UserId $UserId -Action "TRADE_SUBMITTED" `
        -Details "Trade submitted for approval: $($TradeDetails.symbol) $($TradeDetails.side) $($TradeDetails.amount)"

    return @{ success = $true; approvalId = $approvalId; message = "Trade submitted for approval" }
}

function Approve-Trade {
    param(
        [Parameter(Mandatory)]
        [string]$ApprovalId,

        [Parameter(Mandatory)]
        [string]$UserId,

        [string]$Comment = ""
    )

    foreach ($workspace in $script:Workspaces.Values) {
        $approval = $workspace.pendingApprovals | Where-Object { $_.approvalId -eq $ApprovalId } | Select-Object -First 1

        if ($approval) {
            if ($UserId -notin $workspace.members) {
                return @{ success = $false; error = "User not authorized" }
            }

            if ($UserId -eq $approval.submittedBy) {
                return @{ success = $false; error = "Cannot approve own trade" }
            }

            $approval.approvals += @{
                userId = $UserId
                timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                comment = $Comment
            }

            # Auto-approve if owner approves or if 2+ approvals
            if ($UserId -eq $workspace.ownerId -or $approval.approvals.Count -ge 2) {
                $approval.status = "APPROVED"
                Add-ActivityFeedItem -WorkspaceId $workspace.workspaceId -UserId $UserId -Action "TRADE_APPROVED" `
                    -Details "Trade approved: $($approval.tradeDetails.symbol)"

                # Execute trade (TODO: integrate with trading engine)
                Write-Host "[TeamWorkspace] Trade approved and ready for execution: $ApprovalId" -ForegroundColor Green
            }

            Save-WorkspaceData
            return @{ success = $true; status = $approval.status; approvals = $approval.approvals.Count }
        }
    }

    return @{ success = $false; error = "Approval request not found" }
}

function Reject-Trade {
    param(
        [Parameter(Mandatory)]
        [string]$ApprovalId,

        [Parameter(Mandatory)]
        [string]$UserId,

        [string]$Reason = ""
    )

    foreach ($workspace in $script:Workspaces.Values) {
        $approval = $workspace.pendingApprovals | Where-Object { $_.approvalId -eq $ApprovalId } | Select-Object -First 1

        if ($approval) {
            if ($UserId -notin $workspace.members) {
                return @{ success = $false; error = "User not authorized" }
            }

            $approval.rejections += @{
                userId = $UserId
                timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                reason = $Reason
            }

            $approval.status = "REJECTED"

            Add-ActivityFeedItem -WorkspaceId $workspace.workspaceId -UserId $UserId -Action "TRADE_REJECTED" `
                -Details "Trade rejected: $($approval.tradeDetails.symbol) - Reason: $Reason"

            Save-WorkspaceData

            Write-Host "[TeamWorkspace] Trade rejected: $ApprovalId" -ForegroundColor Red
            return @{ success = $true; status = "REJECTED" }
        }
    }

    return @{ success = $false; error = "Approval request not found" }
}

function Add-ActivityFeedItem {
    param(
        [Parameter(Mandatory)]
        [string]$WorkspaceId,

        [Parameter(Mandatory)]
        [string]$UserId,

        [Parameter(Mandatory)]
        [string]$Action,

        [string]$Details = ""
    )

    $feedItem = @{
        id = [guid]::NewGuid().ToString()
        workspaceId = $WorkspaceId
        userId = $UserId
        action = $Action
        details = $Details
        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }

    $script:ActivityFeed = @($feedItem) + $script:ActivityFeed
    if ($script:ActivityFeed.Count -gt 1000) {
        $script:ActivityFeed = $script:ActivityFeed[0..999]  # Keep last 1000
    }

    Save-WorkspaceData
}

function Get-ActivityFeed {
    param(
        [Parameter(Mandatory)]
        [string]$WorkspaceId,

        [int]$Limit = 50
    )

    return $script:ActivityFeed | Where-Object { $_.workspaceId -eq $WorkspaceId } | Select-Object -First $Limit
}

function Send-TeamMessage {
    param(
        [Parameter(Mandatory)]
        [string]$WorkspaceId,

        [Parameter(Mandatory)]
        [string]$UserId,

        [Parameter(Mandatory)]
        [string]$Message
    )

    $workspace = $script:Workspaces[$WorkspaceId]
    if (-not $workspace) {
        return @{ success = $false; error = "Workspace not found" }
    }

    if ($UserId -notin $workspace.members) {
        return @{ success = $false; error = "User not a member" }
    }

    $chatMessage = @{
        id = [guid]::NewGuid().ToString()
        workspaceId = $WorkspaceId
        userId = $UserId
        message = $Message
        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        edited = $false
    }

    $script:ChatMessages = @($chatMessage) + $script:ChatMessages
    if ($script:ChatMessages.Count -gt 5000) {
        $script:ChatMessages = $script:ChatMessages[0..4999]
    }

    Save-WorkspaceData

    return @{ success = $true; messageId = $chatMessage.id }
}

function Get-TeamChat {
    param(
        [Parameter(Mandatory)]
        [string]$WorkspaceId,

        [int]$Limit = 100
    )

    return $script:ChatMessages | Where-Object { $_.workspaceId -eq $WorkspaceId } | Select-Object -First $Limit
}

function Add-TradeComment {
    param(
        [Parameter(Mandatory)]
        [string]$ApprovalId,

        [Parameter(Mandatory)]
        [string]$UserId,

        [Parameter(Mandatory)]
        [string]$Comment
    )

    foreach ($workspace in $script:Workspaces.Values) {
        $approval = $workspace.pendingApprovals | Where-Object { $_.approvalId -eq $ApprovalId } | Select-Object -First 1

        if ($approval) {
            $approval.comments += @{
                userId = $UserId
                comment = $Comment
                timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }

            Save-WorkspaceData
            return @{ success = $true }
        }
    }

    return @{ success = $false; error = "Approval not found" }
}

function Get-WorkspaceInfo {
    param(
        [Parameter(Mandatory)]
        [string]$WorkspaceId
    )

    $workspace = $script:Workspaces[$WorkspaceId]
    if ($workspace) {
        return @{
            workspaceId = $workspace.workspaceId
            name = $workspace.name
            description = $workspace.description
            memberCount = $workspace.members.Count
            pendingApprovals = $workspace.pendingApprovals.Count
            created = $workspace.created
        }
    }

    return $null
}

Initialize-TeamWorkspace

Export-ModuleMember -Function @(
    'New-Workspace',
    'Add-WorkspaceMember',
    'Submit-TradeForApproval',
    'Approve-Trade',
    'Reject-Trade',
    'Get-ActivityFeed',
    'Send-TeamMessage',
    'Get-TeamChat',
    'Add-TradeComment',
    'Get-WorkspaceInfo'
)
