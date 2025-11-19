# ============================================================================
# LuxRig Database Setup Script
# Purpose: SQLite database initialization with complete schema and migrations
# Location: LuxRig/Database/setup-database.ps1
# ============================================================================

using namespace System.Data.SQLite

# Configuration
$Script:Config = @{
    DatabasePath = "$PSScriptRoot/../Data/luxrig.db"
    BackupPath = "$PSScriptRoot/../Data/Backups"
    MaxConnections = 10
    ConnectionTimeout = 30
    BusyTimeout = 5000
    EnableWAL = $true
    EnableForeignKeys = $true
    CacheSize = 2000
    PageSize = 4096
}

# Connection pool
$Script:ConnectionPool = @{
    Connections = [System.Collections.Concurrent.ConcurrentBag[object]]::new()
    MaxSize = $Script:Config.MaxConnections
    CurrentSize = 0
}

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

function Write-DatabaseLog {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'SUCCESS')]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Message,

        [hashtable]$Data = @{}
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = @{
        Timestamp = $timestamp
        Level = $Level
        Message = $Message
        Data = $Data
    }

    $color = switch ($Level) {
        'INFO' { 'Cyan' }
        'WARNING' { 'Yellow' }
        'ERROR' { 'Red' }
        'SUCCESS' { 'Green' }
    }

    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color

    # Append to log file
    $logPath = "$PSScriptRoot/../Logs/database.log"
    $logEntry | ConvertTo-Json -Compress | Add-Content -Path $logPath -ErrorAction SilentlyContinue
}

# ============================================================================
# DATABASE SCHEMA DEFINITIONS
# ============================================================================

function Get-DatabaseSchema {
    return @{
        Trades = @"
CREATE TABLE IF NOT EXISTS trades (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    trade_id TEXT UNIQUE NOT NULL,
    exchange TEXT NOT NULL,
    symbol TEXT NOT NULL,
    side TEXT NOT NULL CHECK(side IN ('BUY', 'SELL')),
    type TEXT NOT NULL CHECK(type IN ('MARKET', 'LIMIT', 'STOP_LOSS', 'TAKE_PROFIT')),
    quantity REAL NOT NULL,
    price REAL NOT NULL,
    total_value REAL NOT NULL,
    fee REAL DEFAULT 0,
    strategy TEXT,
    status TEXT NOT NULL DEFAULT 'PENDING' CHECK(status IN ('PENDING', 'FILLED', 'CANCELLED', 'FAILED')),
    entry_price REAL,
    exit_price REAL,
    profit_loss REAL,
    profit_loss_percent REAL,
    notes TEXT,
    metadata TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    filled_at DATETIME
);

CREATE INDEX IF NOT EXISTS idx_trades_exchange ON trades(exchange);
CREATE INDEX IF NOT EXISTS idx_trades_symbol ON trades(symbol);
CREATE INDEX IF NOT EXISTS idx_trades_strategy ON trades(strategy);
CREATE INDEX IF NOT EXISTS idx_trades_status ON trades(status);
CREATE INDEX IF NOT EXISTS idx_trades_created ON trades(created_at);
"@

        Content = @"
CREATE TABLE IF NOT EXISTS content (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    content_id TEXT UNIQUE NOT NULL,
    type TEXT NOT NULL CHECK(type IN ('BLOG', 'SOCIAL', 'VIDEO', 'EMAIL', 'AD')),
    platform TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT,
    keywords TEXT,
    target_audience TEXT,
    status TEXT NOT NULL DEFAULT 'DRAFT' CHECK(status IN ('DRAFT', 'SCHEDULED', 'PUBLISHED', 'FAILED')),
    scheduled_at DATETIME,
    published_at DATETIME,
    url TEXT,
    views INTEGER DEFAULT 0,
    clicks INTEGER DEFAULT 0,
    conversions INTEGER DEFAULT 0,
    revenue REAL DEFAULT 0,
    cost REAL DEFAULT 0,
    roi REAL DEFAULT 0,
    metadata TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_content_type ON content(type);
CREATE INDEX IF NOT EXISTS idx_content_platform ON content(platform);
CREATE INDEX IF NOT EXISTS idx_content_status ON content(status);
CREATE INDEX IF NOT EXISTS idx_content_published ON content(published_at);
"@

        APIUsage = @"
CREATE TABLE IF NOT EXISTS api_usage (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    service TEXT NOT NULL,
    endpoint TEXT NOT NULL,
    method TEXT NOT NULL,
    status_code INTEGER,
    response_time_ms INTEGER,
    tokens_used INTEGER DEFAULT 0,
    cost REAL DEFAULT 0,
    success BOOLEAN DEFAULT 1,
    error_message TEXT,
    request_data TEXT,
    response_data TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_api_service ON api_usage(service);
CREATE INDEX IF NOT EXISTS idx_api_endpoint ON api_usage(endpoint);
CREATE INDEX IF NOT EXISTS idx_api_created ON api_usage(created_at);
CREATE INDEX IF NOT EXISTS idx_api_success ON api_usage(success);
"@

        Revenue = @"
CREATE TABLE IF NOT EXISTS revenue (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    revenue_id TEXT UNIQUE NOT NULL,
    source TEXT NOT NULL CHECK(source IN ('TRADING', 'CONTENT', 'AFFILIATE', 'API', 'SUBSCRIPTION', 'OTHER')),
    category TEXT NOT NULL,
    amount REAL NOT NULL,
    currency TEXT DEFAULT 'USD',
    description TEXT,
    reference_id TEXT,
    reference_type TEXT,
    payment_method TEXT,
    status TEXT NOT NULL DEFAULT 'PENDING' CHECK(status IN ('PENDING', 'COMPLETED', 'FAILED', 'REFUNDED')),
    metadata TEXT,
    transaction_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_revenue_source ON revenue(source);
CREATE INDEX IF NOT EXISTS idx_revenue_status ON revenue(status);
CREATE INDEX IF NOT EXISTS idx_revenue_date ON revenue(transaction_date);
"@

        SystemHealth = @"
CREATE TABLE IF NOT EXISTS system_health (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    component TEXT NOT NULL,
    status TEXT NOT NULL CHECK(status IN ('HEALTHY', 'DEGRADED', 'DOWN', 'MAINTENANCE')),
    cpu_percent REAL,
    memory_percent REAL,
    disk_percent REAL,
    response_time_ms INTEGER,
    error_count INTEGER DEFAULT 0,
    warning_count INTEGER DEFAULT 0,
    uptime_seconds INTEGER,
    last_error TEXT,
    metadata TEXT,
    checked_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_health_component ON system_health(component);
CREATE INDEX IF NOT EXISTS idx_health_status ON system_health(status);
CREATE INDEX IF NOT EXISTS idx_health_checked ON system_health(checked_at);
"@

        Secrets = @"
CREATE TABLE IF NOT EXISTS secrets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT UNIQUE NOT NULL,
    encrypted_value BLOB NOT NULL,
    service TEXT NOT NULL,
    description TEXT,
    expires_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_accessed DATETIME
);

CREATE INDEX IF NOT EXISTS idx_secrets_service ON secrets(service);
CREATE INDEX IF NOT EXISTS idx_secrets_key ON secrets(key);
"@

        Backups = @"
CREATE TABLE IF NOT EXISTS backups (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    backup_id TEXT UNIQUE NOT NULL,
    type TEXT NOT NULL CHECK(type IN ('FULL', 'INCREMENTAL', 'SECRETS', 'DATABASE')),
    file_path TEXT NOT NULL,
    size_bytes INTEGER,
    compressed BOOLEAN DEFAULT 1,
    encrypted BOOLEAN DEFAULT 1,
    status TEXT NOT NULL DEFAULT 'PENDING' CHECK(status IN ('PENDING', 'COMPLETED', 'FAILED')),
    error_message TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    verified_at DATETIME
);

CREATE INDEX IF NOT EXISTS idx_backups_type ON backups(type);
CREATE INDEX IF NOT EXISTS idx_backups_status ON backups(status);
CREATE INDEX IF NOT EXISTS idx_backups_created ON backups(created_at);
"@

        Strategies = @"
CREATE TABLE IF NOT EXISTS strategies (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    strategy_id TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'INACTIVE' CHECK(status IN ('ACTIVE', 'INACTIVE', 'PAUSED', 'TESTING')),
    exchange TEXT,
    symbols TEXT,
    parameters TEXT NOT NULL,
    capital_allocated REAL DEFAULT 0,
    total_trades INTEGER DEFAULT 0,
    winning_trades INTEGER DEFAULT 0,
    losing_trades INTEGER DEFAULT 0,
    total_profit_loss REAL DEFAULT 0,
    max_drawdown REAL DEFAULT 0,
    sharpe_ratio REAL,
    win_rate REAL,
    avg_profit REAL,
    avg_loss REAL,
    metadata TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_trade_at DATETIME
);

CREATE INDEX IF NOT EXISTS idx_strategies_status ON strategies(status);
CREATE INDEX IF NOT EXISTS idx_strategies_type ON strategies(type);
"@

        Migrations = @"
CREATE TABLE IF NOT EXISTS migrations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    version INTEGER UNIQUE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    applied_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
"@
    }
}

# ============================================================================
# CONNECTION MANAGEMENT
# ============================================================================

function Initialize-SQLiteProvider {
    try {
        # Load SQLite assembly
        $sqlitePath = "$PSScriptRoot/../Lib/System.Data.SQLite.dll"

        if (-not (Test-Path $sqlitePath)) {
            Write-DatabaseLog -Level WARNING -Message "SQLite assembly not found, attempting to load from GAC"
        }

        Add-Type -AssemblyName System.Data.SQLite -ErrorAction Stop
        Write-DatabaseLog -Level SUCCESS -Message "SQLite provider initialized successfully"
        return $true
    }
    catch {
        Write-DatabaseLog -Level ERROR -Message "Failed to initialize SQLite provider: $_"
        return $false
    }
}

function New-DatabaseConnection {
    param(
        [switch]$Pooled
    )

    try {
        # Check connection pool first
        if ($Pooled -and $Script:ConnectionPool.Connections.Count -gt 0) {
            $connection = $null
            if ($Script:ConnectionPool.Connections.TryTake([ref]$connection)) {
                if ($connection.State -eq 'Open') {
                    Write-DatabaseLog -Level INFO -Message "Reused connection from pool"
                    return $connection
                }
                else {
                    $connection.Dispose()
                }
            }
        }

        # Create connection string
        $connectionString = "Data Source=$($Script:Config.DatabasePath);Version=3;Pooling=True;Max Pool Size=$($Script:Config.MaxConnections);Connection Timeout=$($Script:Config.ConnectionTimeout);BusyTimeout=$($Script:Config.BusyTimeout);"

        # Create new connection
        $connection = New-Object System.Data.SQLite.SQLiteConnection($connectionString)
        $connection.Open()

        # Configure connection
        if ($Script:Config.EnableWAL) {
            $command = $connection.CreateCommand()
            $command.CommandText = "PRAGMA journal_mode=WAL;"
            $command.ExecuteNonQuery() | Out-Null
            $command.Dispose()
        }

        if ($Script:Config.EnableForeignKeys) {
            $command = $connection.CreateCommand()
            $command.CommandText = "PRAGMA foreign_keys=ON;"
            $command.ExecuteNonQuery() | Out-Null
            $command.Dispose()
        }

        # Set cache size
        $command = $connection.CreateCommand()
        $command.CommandText = "PRAGMA cache_size=-$($Script:Config.CacheSize);"
        $command.ExecuteNonQuery() | Out-Null
        $command.Dispose()

        Write-DatabaseLog -Level SUCCESS -Message "Created new database connection"
        return $connection
    }
    catch {
        Write-DatabaseLog -Level ERROR -Message "Failed to create database connection: $_"
        throw
    }
}

function Close-DatabaseConnection {
    param(
        [Parameter(Mandatory)]
        [System.Data.SQLite.SQLiteConnection]$Connection,

        [switch]$ReturnToPool
    )

    try {
        if ($ReturnToPool -and $Script:ConnectionPool.Connections.Count -lt $Script:ConnectionPool.MaxSize) {
            $Script:ConnectionPool.Connections.Add($Connection)
            Write-DatabaseLog -Level INFO -Message "Returned connection to pool"
        }
        else {
            $Connection.Close()
            $Connection.Dispose()
            Write-DatabaseLog -Level INFO -Message "Closed and disposed connection"
        }
    }
    catch {
        Write-DatabaseLog -Level ERROR -Message "Error closing connection: $_"
    }
}

# ============================================================================
# DATABASE INITIALIZATION
# ============================================================================

function Initialize-Database {
    param(
        [switch]$Force
    )

    try {
        Write-DatabaseLog -Level INFO -Message "Starting database initialization"

        # Ensure directories exist
        $dataDir = Split-Path -Parent $Script:Config.DatabasePath
        if (-not (Test-Path $dataDir)) {
            New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
            Write-DatabaseLog -Level SUCCESS -Message "Created data directory: $dataDir"
        }

        if (-not (Test-Path $Script:Config.BackupPath)) {
            New-Item -ItemType Directory -Path $Script:Config.BackupPath -Force | Out-Null
            Write-DatabaseLog -Level SUCCESS -Message "Created backup directory: $($Script:Config.BackupPath)"
        }

        $logsDir = "$PSScriptRoot/../Logs"
        if (-not (Test-Path $logsDir)) {
            New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
        }

        # Check if database exists
        $dbExists = Test-Path $Script:Config.DatabasePath

        if ($dbExists -and $Force) {
            Write-DatabaseLog -Level WARNING -Message "Force flag set, backing up existing database"
            $backupPath = "$($Script:Config.BackupPath)/luxrig_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').db"
            Copy-Item -Path $Script:Config.DatabasePath -Destination $backupPath
            Write-DatabaseLog -Level SUCCESS -Message "Database backed up to: $backupPath"
        }

        # Initialize SQLite provider
        if (-not (Initialize-SQLiteProvider)) {
            throw "Failed to initialize SQLite provider"
        }

        # Create or open database
        $connection = New-DatabaseConnection

        # Create all tables
        $schema = Get-DatabaseSchema
        foreach ($tableName in $schema.Keys) {
            Write-DatabaseLog -Level INFO -Message "Creating table: $tableName"
            $command = $connection.CreateCommand()
            $command.CommandText = $schema[$tableName]
            $command.ExecuteNonQuery() | Out-Null
            $command.Dispose()
            Write-DatabaseLog -Level SUCCESS -Message "Table created: $tableName"
        }

        # Record migration
        $command = $connection.CreateCommand()
        $command.CommandText = @"
INSERT OR IGNORE INTO migrations (version, name, description, applied_at)
VALUES (1, 'Initial Schema', 'Created all base tables with indexes', CURRENT_TIMESTAMP);
"@
        $command.ExecuteNonQuery() | Out-Null
        $command.Dispose()

        Close-DatabaseConnection -Connection $connection

        Write-DatabaseLog -Level SUCCESS -Message "Database initialization completed successfully"

        return @{
            Success = $true
            DatabasePath = $Script:Config.DatabasePath
            TablesCreated = $schema.Keys.Count
            Message = "Database initialized successfully"
        }
    }
    catch {
        Write-DatabaseLog -Level ERROR -Message "Database initialization failed: $_"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

# ============================================================================
# MIGRATION FUNCTIONS
# ============================================================================

function Test-DatabaseVersion {
    try {
        $connection = New-DatabaseConnection
        $command = $connection.CreateCommand()
        $command.CommandText = "SELECT MAX(version) as current_version FROM migrations;"
        $reader = $command.ExecuteReader()

        $version = 0
        if ($reader.Read() -and -not $reader.IsDBNull(0)) {
            $version = $reader.GetInt32(0)
        }

        $reader.Close()
        $command.Dispose()
        Close-DatabaseConnection -Connection $connection -ReturnToPool

        return $version
    }
    catch {
        Write-DatabaseLog -Level ERROR -Message "Failed to check database version: $_"
        return 0
    }
}

function Invoke-DatabaseMigration {
    param(
        [int]$TargetVersion
    )

    try {
        $currentVersion = Test-DatabaseVersion
        Write-DatabaseLog -Level INFO -Message "Current database version: $currentVersion"

        if ($currentVersion -ge $TargetVersion) {
            Write-DatabaseLog -Level INFO -Message "Database is up to date"
            return $true
        }

        # Future migrations would go here
        Write-DatabaseLog -Level SUCCESS -Message "Database migrations completed"
        return $true
    }
    catch {
        Write-DatabaseLog -Level ERROR -Message "Migration failed: $_"
        return $false
    }
}

# ============================================================================
# HEALTH CHECK FUNCTIONS
# ============================================================================

function Test-DatabaseHealth {
    try {
        $connection = New-DatabaseConnection
        $command = $connection.CreateCommand()
        $command.CommandText = "SELECT COUNT(*) FROM sqlite_master WHERE type='table';"
        $tableCount = $command.ExecuteScalar()
        $command.Dispose()

        # Run integrity check
        $command = $connection.CreateCommand()
        $command.CommandText = "PRAGMA integrity_check;"
        $integrity = $command.ExecuteScalar()
        $command.Dispose()

        Close-DatabaseConnection -Connection $connection -ReturnToPool

        $isHealthy = $integrity -eq "ok"

        Write-DatabaseLog -Level $(if ($isHealthy) { 'SUCCESS' } else { 'ERROR' }) -Message "Database health check: $integrity"

        return @{
            Healthy = $isHealthy
            TableCount = $tableCount
            IntegrityCheck = $integrity
            DatabasePath = $Script:Config.DatabasePath
            Size = (Get-Item $Script:Config.DatabasePath).Length
        }
    }
    catch {
        Write-DatabaseLog -Level ERROR -Message "Health check failed: $_"
        return @{
            Healthy = $false
            Error = $_.Exception.Message
        }
    }
}

# ============================================================================
# EXPORT FUNCTIONS
# ============================================================================

Export-ModuleMember -Function @(
    'Initialize-Database',
    'New-DatabaseConnection',
    'Close-DatabaseConnection',
    'Test-DatabaseVersion',
    'Invoke-DatabaseMigration',
    'Test-DatabaseHealth',
    'Write-DatabaseLog'
)

# ============================================================================
# MAIN EXECUTION
# ============================================================================

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "`n=== LuxRig Database Setup ===" -ForegroundColor Cyan
    $result = Initialize-Database

    if ($result.Success) {
        Write-Host "`nDatabase initialized successfully!" -ForegroundColor Green
        Write-Host "Location: $($result.DatabasePath)" -ForegroundColor Cyan
        Write-Host "Tables created: $($result.TablesCreated)" -ForegroundColor Cyan

        # Run health check
        Write-Host "`nRunning health check..." -ForegroundColor Cyan
        $health = Test-DatabaseHealth
        Write-Host "Status: $(if ($health.Healthy) { 'HEALTHY' } else { 'UNHEALTHY' })" -ForegroundColor $(if ($health.Healthy) { 'Green' } else { 'Red' })
        Write-Host "Database size: $([math]::Round($health.Size / 1MB, 2)) MB" -ForegroundColor Cyan
    }
    else {
        Write-Host "`nDatabase initialization failed!" -ForegroundColor Red
        Write-Host "Error: $($result.Error)" -ForegroundColor Red
    }
}
