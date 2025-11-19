# ============================================================================
# LuxRig Secrets Manager
# Purpose: Secure API key storage and management with encryption
# Location: LuxRig/Security/secrets-manager.ps1
# ============================================================================

<#
.SYNOPSIS
    Manages encrypted storage of API keys and secrets for LuxRig.

.DESCRIPTION
    This module provides secure storage and retrieval of sensitive credentials
    using DPAPI encryption (Windows) or AES encryption (Linux/Mac).
    All secrets are stored in an encrypted SQLite database.

.EXAMPLE
    Set-LuxRigSecret -Service "OpenAI" -Key "API_KEY" -Value "sk-..."

.EXAMPLE
    $apiKey = Get-LuxRigSecret -Service "OpenAI" -Key "API_KEY"
#>

using namespace System.Security.Cryptography

# Import database module
$dbModule = Join-Path $PSScriptRoot '../Database/data-access.ps1'
if (Test-Path $dbModule) {
    . $dbModule
}

# ============================================================================
# CONFIGURATION
# ============================================================================

$Script:SecretsConfig = @{
    EncryptionMethod = if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT') { 'DPAPI' } else { 'AES' }
    KeyFile = Join-Path $PSScriptRoot 'master.key'
    SaltFile = Join-Path $PSScriptRoot 'master.salt'
    KeySize = 256
    Iterations = 10000
}

# ============================================================================
# LOGGING
# ============================================================================

function Write-SecretsLog {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'SUCCESS')]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Message
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        'INFO' { 'Cyan' }
        'WARNING' { 'Yellow' }
        'ERROR' { 'Red' }
        'SUCCESS' { 'Green' }
    }

    Write-Host "[$timestamp] [SECRETS] [$Level] $Message" -ForegroundColor $color

    # Log to file (without sensitive data)
    $logPath = Join-Path $PSScriptRoot '../Logs/secrets.log'
    if (Test-Path (Split-Path $logPath)) {
        "[$timestamp] [$Level] $Message" | Add-Content -Path $logPath -ErrorAction SilentlyContinue
    }
}

# ============================================================================
# ENCRYPTION - WINDOWS (DPAPI)
# ============================================================================

function Protect-DataWithDPAPI {
    param(
        [Parameter(Mandatory)]
        [string]$PlainText
    )

    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($PlainText)
        $encryptedBytes = [Security.Cryptography.ProtectedData]::Protect(
            $bytes,
            $null,
            [Security.Cryptography.DataProtectionScope]::CurrentUser
        )
        return [Convert]::ToBase64String($encryptedBytes)
    }
    catch {
        Write-SecretsLog -Level ERROR -Message "DPAPI encryption failed: $_"
        throw
    }
}

function Unprotect-DataWithDPAPI {
    param(
        [Parameter(Mandatory)]
        [string]$EncryptedText
    )

    try {
        $encryptedBytes = [Convert]::FromBase64String($EncryptedText)
        $bytes = [Security.Cryptography.ProtectedData]::Unprotect(
            $encryptedBytes,
            $null,
            [Security.Cryptography.DataProtectionScope]::CurrentUser
        )
        return [Text.Encoding]::UTF8.GetString($bytes)
    }
    catch {
        Write-SecretsLog -Level ERROR -Message "DPAPI decryption failed: $_"
        throw
    }
}

# ============================================================================
# ENCRYPTION - LINUX/MAC (AES)
# ============================================================================

function Initialize-MasterKey {
    param(
        [switch]$Force
    )

    if ((Test-Path $Script:SecretsConfig.KeyFile) -and -not $Force) {
        Write-SecretsLog -Level INFO -Message "Master key already exists"
        return $true
    }

    try {
        # Generate random key
        $key = New-Object byte[] 32
        $rng = [RNGCryptoServiceProvider]::new()
        $rng.GetBytes($key)
        $rng.Dispose()

        # Generate salt
        $salt = New-Object byte[] 16
        $rng2 = [RNGCryptoServiceProvider]::new()
        $rng2.GetBytes($salt)
        $rng2.Dispose()

        # Save key and salt
        [IO.File]::WriteAllBytes($Script:SecretsConfig.KeyFile, $key)
        [IO.File]::WriteAllBytes($Script:SecretsConfig.SaltFile, $salt)

        # Set restrictive permissions (Linux/Mac)
        if (-not $IsWindows -and -not ($PSVersionTable.Platform -eq 'Win32NT')) {
            chmod 600 $Script:SecretsConfig.KeyFile
            chmod 600 $Script:SecretsConfig.SaltFile
        }

        Write-SecretsLog -Level SUCCESS -Message "Master key initialized"
        return $true
    }
    catch {
        Write-SecretsLog -Level ERROR -Message "Failed to initialize master key: $_"
        return $false
    }
}

function Get-MasterKey {
    if (-not (Test-Path $Script:SecretsConfig.KeyFile)) {
        Initialize-MasterKey
    }

    return [IO.File]::ReadAllBytes($Script:SecretsConfig.KeyFile)
}

function Get-Salt {
    if (-not (Test-Path $Script:SecretsConfig.SaltFile)) {
        Initialize-MasterKey
    }

    return [IO.File]::ReadAllBytes($Script:SecretsConfig.SaltFile)
}

function Protect-DataWithAES {
    param(
        [Parameter(Mandatory)]
        [string]$PlainText
    )

    try {
        $key = Get-MasterKey
        $salt = Get-Salt

        $aes = [Aes]::Create()
        $aes.Key = $key
        $aes.IV = $salt

        $encryptor = $aes.CreateEncryptor()
        $plainBytes = [Text.Encoding]::UTF8.GetBytes($PlainText)

        $encryptedBytes = $encryptor.TransformFinalBlock($plainBytes, 0, $plainBytes.Length)

        $aes.Dispose()
        $encryptor.Dispose()

        return [Convert]::ToBase64String($encryptedBytes)
    }
    catch {
        Write-SecretsLog -Level ERROR -Message "AES encryption failed: $_"
        throw
    }
}

function Unprotect-DataWithAES {
    param(
        [Parameter(Mandatory)]
        [string]$EncryptedText
    )

    try {
        $key = Get-MasterKey
        $salt = Get-Salt

        $aes = [Aes]::Create()
        $aes.Key = $key
        $aes.IV = $salt

        $decryptor = $aes.CreateDecryptor()
        $encryptedBytes = [Convert]::FromBase64String($EncryptedText)

        $plainBytes = $decryptor.TransformFinalBlock($encryptedBytes, 0, $encryptedBytes.Length)

        $aes.Dispose()
        $decryptor.Dispose()

        return [Text.Encoding]::UTF8.GetString($plainBytes)
    }
    catch {
        Write-SecretsLog -Level ERROR -Message "AES decryption failed: $_"
        throw
    }
}

# ============================================================================
# UNIFIED ENCRYPTION INTERFACE
# ============================================================================

function Protect-Secret {
    param(
        [Parameter(Mandatory)]
        [string]$PlainText
    )

    if ($Script:SecretsConfig.EncryptionMethod -eq 'DPAPI') {
        return Protect-DataWithDPAPI -PlainText $PlainText
    }
    else {
        return Protect-DataWithAES -PlainText $PlainText
    }
}

function Unprotect-Secret {
    param(
        [Parameter(Mandatory)]
        [string]$EncryptedText
    )

    if ($Script:SecretsConfig.EncryptionMethod -eq 'DPAPI') {
        return Unprotect-DataWithDPAPI -EncryptedText $EncryptedText
    }
    else {
        return Unprotect-DataWithAES -EncryptedText $EncryptedText
    }
}

# ============================================================================
# SECRET MANAGEMENT
# ============================================================================

function Set-LuxRigSecret {
    <#
    .SYNOPSIS
        Stores an encrypted secret in the database.

    .PARAMETER Service
        The service name (e.g., "OpenAI", "Coinbase")

    .PARAMETER Key
        The key name (e.g., "API_KEY", "SECRET_KEY")

    .PARAMETER Value
        The secret value to encrypt and store

    .PARAMETER Description
        Optional description of the secret

    .PARAMETER ExpiresAt
        Optional expiration date for the secret
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Service,

        [Parameter(Mandatory)]
        [string]$Key,

        [Parameter(Mandatory)]
        [string]$Value,

        [string]$Description,

        [DateTime]$ExpiresAt
    )

    try {
        # Encrypt the value
        $encryptedValue = Protect-Secret -PlainText $Value
        $encryptedBytes = [Text.Encoding]::UTF8.GetBytes($encryptedValue)

        # Create composite key
        $compositeKey = "${Service}:${Key}"

        # Check if secret already exists
        $existing = Invoke-DatabaseQuery -Query "SELECT id FROM secrets WHERE key = @key;" -Parameters @{ '@key' = $compositeKey }

        $data = @{
            key = $compositeKey
            encrypted_value = $encryptedBytes
            service = $Service
            description = $Description
            updated_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        }

        if ($ExpiresAt) {
            $data['expires_at'] = (Get-Date $ExpiresAt -Format "yyyy-MM-dd HH:mm:ss")
        }

        if ($existing) {
            # Update existing secret
            $result = Update-DatabaseRecord -Table 'secrets' -Data $data -Where @{ key = $compositeKey }
            Write-SecretsLog -Level SUCCESS -Message "Updated secret: $Service/$Key"
        }
        else {
            # Insert new secret
            $data['created_at'] = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            $result = New-DatabaseRecord -Table 'secrets' -Data $data
            Write-SecretsLog -Level SUCCESS -Message "Stored new secret: $Service/$Key"
        }

        return @{
            Success = $true
            Service = $Service
            Key = $Key
        }
    }
    catch {
        Write-SecretsLog -Level ERROR -Message "Failed to store secret $Service/$Key : $_"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Get-LuxRigSecret {
    <#
    .SYNOPSIS
        Retrieves and decrypts a secret from the database.

    .PARAMETER Service
        The service name

    .PARAMETER Key
        The key name

    .PARAMETER AsSecureString
        Return as SecureString instead of plain text
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Service,

        [Parameter(Mandatory)]
        [string]$Key,

        [switch]$AsSecureString
    )

    try {
        $compositeKey = "${Service}:${Key}"

        # Query database
        $result = Invoke-DatabaseQuery -Query "SELECT * FROM secrets WHERE key = @key;" -Parameters @{ '@key' = $compositeKey }

        if (-not $result) {
            Write-SecretsLog -Level WARNING -Message "Secret not found: $Service/$Key"
            return $null
        }

        $secret = $result[0]

        # Check expiration
        if ($secret.expires_at) {
            $expirationDate = [DateTime]::Parse($secret.expires_at)
            if ($expirationDate -lt (Get-Date)) {
                Write-SecretsLog -Level WARNING -Message "Secret expired: $Service/$Key"
                return $null
            }
        }

        # Update last accessed timestamp
        Update-DatabaseRecord -Table 'secrets' -Data @{ last_accessed = (Get-Date -Format "yyyy-MM-dd HH:mm:ss") } -Where @{ key = $compositeKey } | Out-Null

        # Decrypt value
        $encryptedValue = [Text.Encoding]::UTF8.GetString($secret.encrypted_value)
        $plainValue = Unprotect-Secret -EncryptedText $encryptedValue

        if ($AsSecureString) {
            $secureString = ConvertTo-SecureString -String $plainValue -AsPlainText -Force
            Write-SecretsLog -Level INFO -Message "Retrieved secret (as SecureString): $Service/$Key"
            return $secureString
        }
        else {
            Write-SecretsLog -Level INFO -Message "Retrieved secret: $Service/$Key"
            return $plainValue
        }
    }
    catch {
        Write-SecretsLog -Level ERROR -Message "Failed to retrieve secret $Service/$Key : $_"
        return $null
    }
}

function Get-AllLuxRigSecrets {
    <#
    .SYNOPSIS
        Lists all stored secrets (without decrypting values).

    .PARAMETER Service
        Filter by service name
    #>
    param(
        [string]$Service
    )

    try {
        $query = "SELECT key, service, description, created_at, expires_at, last_accessed FROM secrets"

        if ($Service) {
            $query += " WHERE service = @service"
        }

        $query += " ORDER BY service, key;"

        $parameters = @{}
        if ($Service) {
            $parameters['@service'] = $Service
        }

        $results = Invoke-DatabaseQuery -Query $query -Parameters $parameters

        return $results | ForEach-Object {
            [PSCustomObject]@{
                Service = $_.service
                Key = $_.key -replace "^$($_.service):", ""
                Description = $_.description
                CreatedAt = $_.created_at
                ExpiresAt = $_.expires_at
                LastAccessed = $_.last_accessed
                IsExpired = if ($_.expires_at) { [DateTime]::Parse($_.expires_at) -lt (Get-Date) } else { $false }
            }
        }
    }
    catch {
        Write-SecretsLog -Level ERROR -Message "Failed to list secrets: $_"
        return @()
    }
}

function Remove-LuxRigSecret {
    <#
    .SYNOPSIS
        Deletes a secret from the database.

    .PARAMETER Service
        The service name

    .PARAMETER Key
        The key name
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Service,

        [Parameter(Mandatory)]
        [string]$Key
    )

    try {
        $compositeKey = "${Service}:${Key}"

        $result = Remove-DatabaseRecord -Table 'secrets' -Where @{ key = $compositeKey }

        if ($result.Success -and $result.RowsAffected -gt 0) {
            Write-SecretsLog -Level SUCCESS -Message "Deleted secret: $Service/$Key"
            return $true
        }
        else {
            Write-SecretsLog -Level WARNING -Message "Secret not found: $Service/$Key"
            return $false
        }
    }
    catch {
        Write-SecretsLog -Level ERROR -Message "Failed to delete secret $Service/$Key : $_"
        return $false
    }
}

function Test-LuxRigSecret {
    <#
    .SYNOPSIS
        Checks if a secret exists and is valid.

    .PARAMETER Service
        The service name

    .PARAMETER Key
        The key name
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Service,

        [Parameter(Mandatory)]
        [string]$Key
    )

    $secret = Get-LuxRigSecret -Service $Service -Key $Key
    return $null -ne $secret
}

# ============================================================================
# BULK OPERATIONS
# ============================================================================

function Import-LuxRigSecrets {
    <#
    .SYNOPSIS
        Imports secrets from a JSON file.

    .PARAMETER Path
        Path to the JSON file containing secrets

    .EXAMPLE
        Import-LuxRigSecrets -Path "./secrets.json"

        File format:
        {
            "OpenAI": {
                "API_KEY": "sk-...",
                "ORG_ID": "org-..."
            },
            "Coinbase": {
                "API_KEY": "...",
                "API_SECRET": "..."
            }
        }
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    try {
        if (-not (Test-Path $Path)) {
            Write-SecretsLog -Level ERROR -Message "File not found: $Path"
            return $false
        }

        $secrets = Get-Content $Path -Raw | ConvertFrom-Json
        $importedCount = 0

        foreach ($service in $secrets.PSObject.Properties.Name) {
            foreach ($key in $secrets.$service.PSObject.Properties.Name) {
                $value = $secrets.$service.$key
                $result = Set-LuxRigSecret -Service $service -Key $key -Value $value

                if ($result.Success) {
                    $importedCount++
                }
            }
        }

        Write-SecretsLog -Level SUCCESS -Message "Imported $importedCount secrets from $Path"
        return $true
    }
    catch {
        Write-SecretsLog -Level ERROR -Message "Failed to import secrets: $_"
        return $false
    }
}

function Export-LuxRigSecrets {
    <#
    .SYNOPSIS
        Exports secrets to an encrypted JSON file.

    .PARAMETER Path
        Output file path

    .PARAMETER Service
        Optional: Export only secrets for specific service
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [string]$Service
    )

    try {
        $allSecrets = Get-AllLuxRigSecrets -Service $Service

        $export = @{}

        foreach ($secret in $allSecrets) {
            if (-not $export.ContainsKey($secret.Service)) {
                $export[$secret.Service] = @{}
            }

            $value = Get-LuxRigSecret -Service $secret.Service -Key $secret.Key
            $export[$secret.Service][$secret.Key] = $value
        }

        $export | ConvertTo-Json -Depth 10 | Set-Content -Path $Path -Encoding UTF8

        Write-SecretsLog -Level SUCCESS -Message "Exported secrets to $Path"
        Write-SecretsLog -Level WARNING -Message "Exported file contains unencrypted secrets! Handle with care."

        return $true
    }
    catch {
        Write-SecretsLog -Level ERROR -Message "Failed to export secrets: $_"
        return $false
    }
}

# ============================================================================
# INITIALIZATION
# ============================================================================

function Initialize-SecretsManager {
    try {
        Write-SecretsLog -Level INFO -Message "Initializing Secrets Manager..."
        Write-SecretsLog -Level INFO -Message "Encryption method: $($Script:SecretsConfig.EncryptionMethod)"

        if ($Script:SecretsConfig.EncryptionMethod -eq 'AES') {
            Initialize-MasterKey
        }

        Write-SecretsLog -Level SUCCESS -Message "Secrets Manager initialized"
        return $true
    }
    catch {
        Write-SecretsLog -Level ERROR -Message "Failed to initialize Secrets Manager: $_"
        return $false
    }
}

# ============================================================================
# EXPORT FUNCTIONS
# ============================================================================

Export-ModuleMember -Function @(
    'Set-LuxRigSecret',
    'Get-LuxRigSecret',
    'Get-AllLuxRigSecrets',
    'Remove-LuxRigSecret',
    'Test-LuxRigSecret',
    'Import-LuxRigSecrets',
    'Export-LuxRigSecrets',
    'Initialize-SecretsManager'
)

# ============================================================================
# MAIN EXECUTION (if run directly)
# ============================================================================

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "`n=== LuxRig Secrets Manager ===" -ForegroundColor Cyan

    Initialize-SecretsManager

    # Interactive mode
    Write-Host "`nAvailable Commands:" -ForegroundColor Yellow
    Write-Host "  Set-LuxRigSecret -Service 'ServiceName' -Key 'KEY_NAME' -Value 'secret_value'" -ForegroundColor White
    Write-Host "  Get-LuxRigSecret -Service 'ServiceName' -Key 'KEY_NAME'" -ForegroundColor White
    Write-Host "  Get-AllLuxRigSecrets" -ForegroundColor White
    Write-Host "  Remove-LuxRigSecret -Service 'ServiceName' -Key 'KEY_NAME'" -ForegroundColor White

    # Show existing secrets
    Write-Host "`nExisting Secrets:" -ForegroundColor Yellow
    $secrets = Get-AllLuxRigSecrets

    if ($secrets) {
        $secrets | Format-Table -Property Service, Key, CreatedAt, IsExpired -AutoSize
    }
    else {
        Write-Host "  No secrets stored yet." -ForegroundColor Gray
    }
}
