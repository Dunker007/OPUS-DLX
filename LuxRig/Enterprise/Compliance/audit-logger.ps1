<#
.SYNOPSIS
    Comprehensive Audit Logging System for LuxRig Enterprise
.DESCRIPTION
    Logs every system action with immutable storage, tamper detection, compliance reporting,
    and full audit trail for regulatory requirements (SOC2, GDPR, SOX).
.NOTES
    Version: 1.0.0
    Author: LuxRig Enterprise Team
    Requires: PowerShell 7.0+
#>

using namespace System.Collections.Generic
using namespace System.Security.Cryptography

#region Module Configuration

$script:ModuleConfig = @{
    AuditLogPath = "$PSScriptRoot/../../../Data/AuditLogs"
    IndexPath = "$PSScriptRoot/../../../Data/AuditLogs/index.json"
    HashChainPath = "$PSScriptRoot/../../../Data/AuditLogs/hashchain.json"
    ComplianceReportsPath = "$PSScriptRoot/../../../Data/Compliance/Reports"
    RetentionDays = 2555  # 7 years for financial compliance
    CompressionEnabled = $true
}

# Audit Event Categories
enum AuditCategory {
    Authentication
    Authorization
    DataAccess
    DataModification
    SystemConfiguration
    Trading
    Financial
    UserManagement
    APIAccess
    SecurityEvent
    ComplianceEvent
}

# Severity Levels
enum AuditSeverity {
    Info
    Warning
    Error
    Critical
    Security
}

#endregion

#region Core Functions

function Initialize-AuditLogger {
    <#
    .SYNOPSIS
        Initializes the audit logging system
    #>
    [CmdletBinding()]
    param()

    try {
        Write-Verbose "Initializing Audit Logger..."

        # Create required directories
        $directories = @(
            $script:ModuleConfig.AuditLogPath,
            $script:ModuleConfig.ComplianceReportsPath,
            "$($script:ModuleConfig.AuditLogPath)/Archive"
        )

        foreach ($dir in $directories) {
            if (-not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
        }

        # Initialize index
        if (-not (Test-Path $script:ModuleConfig.IndexPath)) {
            $index = @{
                Version = "1.0.0"
                CreatedAt = (Get-Date).ToString('o')
                TotalEvents = 0
                LastEventId = 0
                Files = @()
            }
            $index | ConvertTo-Json -Depth 10 | Set-Content $script:ModuleConfig.IndexPath
        }

        # Initialize hash chain for tamper detection
        if (-not (Test-Path $script:ModuleConfig.HashChainPath)) {
            $hashChain = @{
                Version = "1.0.0"
                CreatedAt = (Get-Date).ToString('o')
                GenesisHash = Get-GenesisHash
                Chain = @()
            }
            $hashChain | ConvertTo-Json -Depth 10 | Set-Content $script:ModuleConfig.HashChainPath
        }

        Write-Verbose "Audit Logger initialized successfully"
        return $true
    }
    catch {
        Write-Error "Failed to initialize Audit Logger: $_"
        return $false
    }
}

function Write-AuditLog {
    <#
    .SYNOPSIS
        Writes an immutable audit log entry
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AuditCategory]$Category,

        [Parameter(Mandatory = $true)]
        [string]$Action,

        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [string]$UserId,

        [Parameter(Mandatory = $false)]
        [AuditSeverity]$Severity = [AuditSeverity]::Info,

        [Parameter(Mandatory = $false)]
        [hashtable]$Details = @{},

        [Parameter(Mandatory = $false)]
        [string]$ResourceId = "",

        [Parameter(Mandatory = $false)]
        [string]$IPAddress = "",

        [Parameter(Mandatory = $false)]
        [string]$UserAgent = ""
    )

    try {
        # Load index
        $index = Get-Content $script:ModuleConfig.IndexPath -Raw | ConvertFrom-Json

        # Generate event ID
        $eventId = $index.LastEventId + 1

        # Get previous hash for chain
        $hashChain = Get-Content $script:ModuleConfig.HashChainPath -Raw | ConvertFrom-Json
        $previousHash = if ($hashChain.Chain.Count -gt 0) {
            $hashChain.Chain[-1].Hash
        } else {
            $hashChain.GenesisHash
        }

        # Create audit entry
        $auditEntry = @{
            EventId = $eventId
            Timestamp = (Get-Date).ToUniversalTime().ToString('o')
            Category = $Category.ToString()
            Action = $Action
            Severity = $Severity.ToString()
            TenantId = $TenantId
            UserId = $UserId
            ResourceId = $ResourceId
            IPAddress = $IPAddress
            UserAgent = $UserAgent
            Details = $Details
            PreviousHash = $previousHash
            Hash = ""  # Will be calculated
        }

        # Calculate hash for tamper detection
        $auditEntry.Hash = Get-AuditEntryHash -Entry $auditEntry

        # Determine log file (daily rotation)
        $dateString = (Get-Date).ToString('yyyyMMdd')
        $logFileName = "audit-$dateString.json"
        $logFilePath = Join-Path $script:ModuleConfig.AuditLogPath $logFileName

        # Append to log file (immutable append-only)
        $auditEntry | ConvertTo-Json -Depth 10 -Compress | Add-Content -Path $logFilePath -Encoding UTF8

        # Update hash chain
        $chainEntry = @{
            EventId = $eventId
            Timestamp = $auditEntry.Timestamp
            Hash = $auditEntry.Hash
            PreviousHash = $previousHash
        }
        $hashChain.Chain += $chainEntry
        $hashChain | ConvertTo-Json -Depth 10 | Set-Content $script:ModuleConfig.HashChainPath

        # Update index
        $index.LastEventId = $eventId
        $index.TotalEvents++

        # Track file in index if new
        if ($index.Files -notcontains $logFileName) {
            $index.Files += $logFileName
        }

        $index | ConvertTo-Json -Depth 10 | Set-Content $script:ModuleConfig.IndexPath

        Write-Verbose "Audit log entry created: EventId=$eventId, Category=$Category, Action=$Action"
        return $eventId
    }
    catch {
        Write-Error "Failed to write audit log: $_"
        # Critical: write to emergency fallback log
        Write-EmergencyLog -Error $_ -Context $auditEntry
        return -1
    }
}

function Get-AuditLog {
    <#
    .SYNOPSIS
        Retrieves audit log entries with filtering
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$TenantId,

        [Parameter(Mandatory = $false)]
        [string]$UserId,

        [Parameter(Mandatory = $false)]
        [AuditCategory]$Category,

        [Parameter(Mandatory = $false)]
        [DateTime]$StartDate,

        [Parameter(Mandatory = $false)]
        [DateTime]$EndDate,

        [Parameter(Mandatory = $false)]
        [int]$MaxResults = 1000
    )

    try {
        Write-Verbose "Retrieving audit logs..."

        $results = @()
        $index = Get-Content $script:ModuleConfig.IndexPath -Raw | ConvertFrom-Json

        # Determine which files to search
        $filesToSearch = if ($StartDate -or $EndDate) {
            Get-LogFilesInDateRange -StartDate $StartDate -EndDate $EndDate -AllFiles $index.Files
        } else {
            $index.Files
        }

        foreach ($fileName in $filesToSearch) {
            $filePath = Join-Path $script:ModuleConfig.AuditLogPath $fileName

            if (-not (Test-Path $filePath)) {
                continue
            }

            # Read log file line by line
            $lines = Get-Content $filePath -Encoding UTF8

            foreach ($line in $lines) {
                try {
                    $entry = $line | ConvertFrom-Json

                    # Apply filters
                    if ($TenantId -and $entry.TenantId -ne $TenantId) { continue }
                    if ($UserId -and $entry.UserId -ne $UserId) { continue }
                    if ($Category -and $entry.Category -ne $Category.ToString()) { continue }

                    if ($StartDate) {
                        $entryDate = [DateTime]::Parse($entry.Timestamp)
                        if ($entryDate -lt $StartDate) { continue }
                    }

                    if ($EndDate) {
                        $entryDate = [DateTime]::Parse($entry.Timestamp)
                        if ($entryDate -gt $EndDate) { continue }
                    }

                    $results += $entry

                    if ($results.Count -ge $MaxResults) {
                        break
                    }
                }
                catch {
                    Write-Warning "Failed to parse audit log line: $_"
                }
            }

            if ($results.Count -ge $MaxResults) {
                break
            }
        }

        return $results
    }
    catch {
        Write-Error "Failed to retrieve audit logs: $_"
        return @()
    }
}

function Test-AuditLogIntegrity {
    <#
    .SYNOPSIS
        Verifies audit log integrity using hash chain
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$FileName
    )

    try {
        Write-Verbose "Verifying audit log integrity..."

        $hashChain = Get-Content $script:ModuleConfig.HashChainPath -Raw | ConvertFrom-Json
        $violations = @()

        # Verify hash chain continuity
        $expectedPreviousHash = $hashChain.GenesisHash

        foreach ($chainEntry in $hashChain.Chain) {
            if ($chainEntry.PreviousHash -ne $expectedPreviousHash) {
                $violations += @{
                    EventId = $chainEntry.EventId
                    Issue = "Hash chain broken"
                    Expected = $expectedPreviousHash
                    Actual = $chainEntry.PreviousHash
                }
            }

            $expectedPreviousHash = $chainEntry.Hash
        }

        # Verify individual log entries if file specified
        if ($FileName) {
            $filePath = Join-Path $script:ModuleConfig.AuditLogPath $FileName
            if (Test-Path $filePath) {
                $lines = Get-Content $filePath -Encoding UTF8

                foreach ($line in $lines) {
                    $entry = $line | ConvertFrom-Json
                    $storedHash = $entry.Hash
                    $entry.Hash = ""
                    $calculatedHash = Get-AuditEntryHash -Entry $entry

                    if ($storedHash -ne $calculatedHash) {
                        $violations += @{
                            EventId = $entry.EventId
                            Issue = "Entry hash mismatch (possible tampering)"
                            Expected = $calculatedHash
                            Actual = $storedHash
                        }
                    }
                }
            }
        }

        return [PSCustomObject]@{
            IsValid = ($violations.Count -eq 0)
            Violations = $violations
            CheckedAt = (Get-Date).ToString('o')
        }
    }
    catch {
        Write-Error "Failed to verify audit log integrity: $_"
        return [PSCustomObject]@{
            IsValid = $false
            Violations = @(@{ Issue = "Verification failed: $_" })
            CheckedAt = (Get-Date).ToString('o')
        }
    }
}

function New-ComplianceReport {
    <#
    .SYNOPSIS
        Generates compliance reports for regulatory requirements
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('SOC2', 'GDPR', 'SOX', 'HIPAA', 'PCI-DSS', 'Custom')]
        [string]$ReportType,

        [Parameter(Mandatory = $true)]
        [DateTime]$StartDate,

        [Parameter(Mandatory = $true)]
        [DateTime]$EndDate,

        [Parameter(Mandatory = $false)]
        [string]$TenantId,

        [Parameter(Mandatory = $false)]
        [hashtable]$CustomCriteria = @{}
    )

    try {
        Write-Verbose "Generating $ReportType compliance report..."

        # Retrieve relevant audit logs
        $logs = Get-AuditLog -StartDate $StartDate -EndDate $EndDate -TenantId $TenantId -MaxResults 100000

        # Generate report based on type
        $report = switch ($ReportType) {
            'SOC2' { New-SOC2Report -Logs $logs -StartDate $StartDate -EndDate $EndDate }
            'GDPR' { New-GDPRReport -Logs $logs -StartDate $StartDate -EndDate $EndDate }
            'SOX' { New-SOXReport -Logs $logs -StartDate $StartDate -EndDate $EndDate }
            'HIPAA' { New-HIPAAReport -Logs $logs -StartDate $StartDate -EndDate $EndDate }
            'PCI-DSS' { New-PCIDSSReport -Logs $logs -StartDate $StartDate -EndDate $EndDate }
            'Custom' { New-CustomReport -Logs $logs -Criteria $CustomCriteria }
        }

        # Add metadata
        $report.Metadata = @{
            ReportType = $ReportType
            GeneratedAt = (Get-Date).ToString('o')
            PeriodStart = $StartDate.ToString('o')
            PeriodEnd = $EndDate.ToString('o')
            TenantId = $TenantId
            TotalEvents = $logs.Count
        }

        # Save report
        $reportFileName = "$ReportType-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        $reportPath = Join-Path $script:ModuleConfig.ComplianceReportsPath $reportFileName

        $report | ConvertTo-Json -Depth 10 | Set-Content $reportPath

        Write-Verbose "Compliance report generated: $reportPath"
        return $report
    }
    catch {
        Write-Error "Failed to generate compliance report: $_"
        return $null
    }
}

function Export-AuditLogArchive {
    <#
    .SYNOPSIS
        Exports audit logs for long-term archival
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [DateTime]$ArchiveDate,

        [Parameter(Mandatory = $false)]
        [switch]$Compress
    )

    try {
        Write-Verbose "Archiving audit logs older than $ArchiveDate..."

        $index = Get-Content $script:ModuleConfig.IndexPath -Raw | ConvertFrom-Json
        $archivedFiles = @()

        foreach ($fileName in $index.Files) {
            # Parse date from filename
            if ($fileName -match 'audit-(\d{8})\.json') {
                $fileDate = [DateTime]::ParseExact($matches[1], 'yyyyMMdd', $null)

                if ($fileDate -lt $ArchiveDate) {
                    $sourcePath = Join-Path $script:ModuleConfig.AuditLogPath $fileName
                    $archivePath = Join-Path "$($script:ModuleConfig.AuditLogPath)/Archive" $fileName

                    if (Test-Path $sourcePath) {
                        if ($Compress) {
                            Compress-Archive -Path $sourcePath -DestinationPath "$archivePath.zip" -Force
                            Remove-Item -Path $sourcePath -Force
                        } else {
                            Move-Item -Path $sourcePath -Destination $archivePath -Force
                        }

                        $archivedFiles += $fileName
                    }
                }
            }
        }

        Write-Verbose "Archived $($archivedFiles.Count) log files"
        return $archivedFiles
    }
    catch {
        Write-Error "Failed to archive audit logs: $_"
        return @()
    }
}

#endregion

#region Helper Functions

function Get-GenesisHash {
    <#
    .SYNOPSIS
        Generates the genesis hash for the hash chain
    #>
    $genesisData = "LuxRig-AuditLog-Genesis-$(Get-Date -Format 'o')"
    return Get-SHA256Hash -InputString $genesisData
}

function Get-AuditEntryHash {
    <#
    .SYNOPSIS
        Calculates hash for an audit entry
    #>
    param([hashtable]$Entry)

    # Create canonical representation
    $canonical = "$($Entry.EventId)|$($Entry.Timestamp)|$($Entry.Category)|$($Entry.Action)|$($Entry.TenantId)|$($Entry.UserId)|$($Entry.ResourceId)|$($Entry.PreviousHash)"

    return Get-SHA256Hash -InputString $canonical
}

function Get-SHA256Hash {
    <#
    .SYNOPSIS
        Computes SHA256 hash of input string
    #>
    param([string]$InputString)

    $hasher = [SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
    $hashBytes = $hasher.ComputeHash($bytes)

    return [BitConverter]::ToString($hashBytes).Replace('-', '').ToLower()
}

function Get-LogFilesInDateRange {
    param($StartDate, $EndDate, $AllFiles)

    $filtered = @()

    foreach ($file in $AllFiles) {
        if ($file -match 'audit-(\d{8})\.json') {
            $fileDate = [DateTime]::ParseExact($matches[1], 'yyyyMMdd', $null)

            if ((!$StartDate -or $fileDate -ge $StartDate.Date) -and
                (!$EndDate -or $fileDate -le $EndDate.Date)) {
                $filtered += $file
            }
        }
    }

    return $filtered
}

function New-SOC2Report {
    param($Logs, $StartDate, $EndDate)

    return @{
        AccessControls = ($Logs | Where-Object { $_.Category -eq 'Authorization' }).Count
        DataAccess = ($Logs | Where-Object { $_.Category -eq 'DataAccess' }).Count
        SecurityEvents = ($Logs | Where-Object { $_.Severity -eq 'Security' }).Count
        ConfigurationChanges = ($Logs | Where-Object { $_.Category -eq 'SystemConfiguration' }).Count
        FailedAuthentications = ($Logs | Where-Object { $_.Category -eq 'Authentication' -and $_.Details.Success -eq $false }).Count
    }
}

function New-GDPRReport {
    param($Logs, $StartDate, $EndDate)

    return @{
        DataAccessRequests = ($Logs | Where-Object { $_.Action -like '*DataAccess*' }).Count
        DataDeletionRequests = ($Logs | Where-Object { $_.Action -like '*Delete*' }).Count
        ConsentChanges = ($Logs | Where-Object { $_.Action -like '*Consent*' }).Count
        DataExports = ($Logs | Where-Object { $_.Action -like '*Export*' }).Count
    }
}

function New-SOXReport {
    param($Logs, $StartDate, $EndDate)

    return @{
        FinancialTransactions = ($Logs | Where-Object { $_.Category -eq 'Financial' }).Count
        TradingActivity = ($Logs | Where-Object { $_.Category -eq 'Trading' }).Count
        PrivilegedAccess = ($Logs | Where-Object { $_.Details.Privileged -eq $true }).Count
        AuditIntegrity = (Test-AuditLogIntegrity).IsValid
    }
}

function New-HIPAAReport {
    param($Logs, $StartDate, $EndDate)

    return @{
        PHIAccess = ($Logs | Where-Object { $_.Details.ContainsPHI -eq $true }).Count
        SecurityIncidents = ($Logs | Where-Object { $_.Severity -eq 'Security' }).Count
        UnauthorizedAccess = ($Logs | Where-Object { $_.Details.Authorized -eq $false }).Count
    }
}

function New-PCIDSSReport {
    param($Logs, $StartDate, $EndDate)

    return @{
        PaymentTransactions = ($Logs | Where-Object { $_.Category -eq 'Financial' -and $_.Details.PaymentData -eq $true }).Count
        CardDataAccess = ($Logs | Where-Object { $_.Details.CardData -eq $true }).Count
        SecurityEvents = ($Logs | Where-Object { $_.Severity -eq 'Security' }).Count
    }
}

function New-CustomReport {
    param($Logs, $Criteria)

    # Custom report based on criteria
    return @{
        TotalEvents = $Logs.Count
        Criteria = $Criteria
        Events = $Logs
    }
}

function Write-EmergencyLog {
    param($Error, $Context)

    $emergencyPath = "$($script:ModuleConfig.AuditLogPath)/emergency.log"
    $entry = "$(Get-Date -Format 'o') | EMERGENCY | Error: $Error | Context: $($Context | ConvertTo-Json -Compress)"
    Add-Content -Path $emergencyPath -Value $entry -Encoding UTF8
}

#endregion

# Initialize on module load
Initialize-AuditLogger | Out-Null

# Export public functions
Export-ModuleMember -Function @(
    'Initialize-AuditLogger',
    'Write-AuditLog',
    'Get-AuditLog',
    'Test-AuditLogIntegrity',
    'New-ComplianceReport',
    'Export-AuditLogArchive'
)
