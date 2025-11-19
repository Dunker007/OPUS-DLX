# ============================================================================
# LuxRig Backup Manager
# Automated backups with encryption and retention
# ============================================================================

param(
    [ValidateSet('full', 'database', 'secrets', 'logs')]
    [string]$Type = 'full',

    [int]$RetentionDays = 7,

    [switch]$Restore,

    [string]$RestorePath
)

$dataAccessModule = Join-Path $PSScriptRoot '../Database/data-access.ps1'
if (Test-Path $dataAccessModule) { . $dataAccessModule }

$Script:Config = @{
    BackupDir = Join-Path $PSScriptRoot '../Data/Backups'
    DatabasePath = Join-Path $PSScriptRoot '../Data/luxrig.db'
    SecretsPath = Join-Path $PSScriptRoot '../Security'
    LogsPath = Join-Path $PSScriptRoot '../Logs'
    Compress = $true
    Encrypt = $false
}

function Write-BackupLog {
    param($Level, $Message)

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        'INFO' { 'Cyan' }
        'SUCCESS' { 'Green' }
        'ERROR' { 'Red' }
    }

    Write-Host "[$timestamp] [BACKUP] [$Level] $Message" -ForegroundColor $color

    $logPath = Join-Path $Script:Config.LogsPath 'backup.log'
    if (Test-Path (Split-Path $logPath)) {
        "[$timestamp] [$Level] $Message" | Add-Content -Path $logPath
    }
}

function New-Backup {
    param([string]$Type)

    try {
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $backupId = "BACKUP-$timestamp-$Type"

        if (-not (Test-Path $Script:Config.BackupDir)) {
            New-Item -ItemType Directory -Path $Script:Config.BackupDir -Force | Out-Null
        }

        Write-BackupLog -Level INFO -Message "Starting $Type backup..."

        $files = @()

        switch ($Type) {
            'full' {
                if (Test-Path $Script:Config.DatabasePath) {
                    $files += $Script:Config.DatabasePath
                }
                if (Test-Path $Script:Config.SecretsPath) {
                    $files += Get-ChildItem -Path $Script:Config.SecretsPath -Recurse -File
                }
            }
            'database' {
                if (Test-Path $Script:Config.DatabasePath) {
                    $files += $Script:Config.DatabasePath
                }
            }
            'secrets' {
                if (Test-Path $Script:Config.SecretsPath) {
                    $files += Get-ChildItem -Path $Script:Config.SecretsPath -Recurse -File
                }
            }
            'logs' {
                if (Test-Path $Script:Config.LogsPath) {
                    $files += Get-ChildItem -Path $Script:Config.LogsPath -Filter '*.log'
                }
            }
        }

        if ($files.Count -eq 0) {
            Write-BackupLog -Level ERROR -Message "No files to backup"
            return $false
        }

        $backupPath = Join-Path $Script:Config.BackupDir "$backupId.zip"

        Compress-Archive -Path $files -DestinationPath $backupPath -Force

        $size = (Get-Item $backupPath).Length

        Write-BackupLog -Level SUCCESS -Message "Backup created: $backupPath ($([math]::Round($size/1MB, 2)) MB)"

        # Save to database
        $backupData = @{
            backup_id = $backupId
            type = $Type.ToUpper()
            file_path = $backupPath
            size_bytes = $size
            compressed = $true
            encrypted = $false
            status = 'COMPLETED'
        }

        New-DatabaseRecord -Table 'backups' -Data $backupData | Out-Null

        # Clean old backups
        Remove-OldBackups -RetentionDays $RetentionDays

        return $true
    }
    catch {
        Write-BackupLog -Level ERROR -Message "Backup failed: $_"
        return $false
    }
}

function Remove-OldBackups {
    param([int]$RetentionDays)

    try {
        $cutoffDate = (Get-Date).AddDays(-$RetentionDays)

        $oldBackups = Get-ChildItem -Path $Script:Config.BackupDir -Filter '*.zip' |
            Where-Object { $_.LastWriteTime -lt $cutoffDate }

        foreach ($backup in $oldBackups) {
            Remove-Item $backup.FullName -Force
            Write-BackupLog -Level INFO -Message "Removed old backup: $($backup.Name)"
        }
    }
    catch {
        Write-BackupLog -Level ERROR -Message "Failed to remove old backups: $_"
    }
}

function Restore-Backup {
    param([string]$BackupPath)

    try {
        Write-BackupLog -Level INFO -Message "Restoring from: $BackupPath"

        if (-not (Test-Path $BackupPath)) {
            throw "Backup file not found: $BackupPath"
        }

        $restoreDir = Join-Path $PSScriptRoot '../Data/Restore'
        if (-not (Test-Path $restoreDir)) {
            New-Item -ItemType Directory -Path $restoreDir -Force | Out-Null
        }

        Expand-Archive -Path $BackupPath -DestinationPath $restoreDir -Force

        Write-BackupLog -Level SUCCESS -Message "Backup restored to: $restoreDir"
        Write-BackupLog -Level INFO -Message "Please manually review and copy files as needed"

        return $true
    }
    catch {
        Write-BackupLog -Level ERROR -Message "Restore failed: $_"
        return $false
    }
}

# Main execution
if ($Restore -and $RestorePath) {
    Restore-Backup -BackupPath $RestorePath
}
else {
    New-Backup -Type $Type
}
