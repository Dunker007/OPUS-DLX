# ============================================================================
# LuxRig Data Access Layer
# Purpose: CRUD operations, transactions, and query builder for all tables
# Location: LuxRig/Database/data-access.ps1
# ============================================================================

using namespace System.Data.SQLite

# Import database setup
. "$PSScriptRoot/setup-database.ps1"

# ============================================================================
# QUERY BUILDER
# ============================================================================

class QueryBuilder {
    [string]$Table
    [System.Collections.ArrayList]$SelectColumns
    [System.Collections.ArrayList]$WhereConditions
    [System.Collections.ArrayList]$OrderByColumns
    [System.Collections.ArrayList]$Parameters
    [int]$LimitValue
    [int]$OffsetValue
    [string]$JoinClause

    QueryBuilder([string]$table) {
        $this.Table = $table
        $this.SelectColumns = @()
        $this.WhereConditions = @()
        $this.OrderByColumns = @()
        $this.Parameters = @()
        $this.LimitValue = 0
        $this.OffsetValue = 0
        $this.JoinClause = ""
    }

    [QueryBuilder] Select([string[]]$columns) {
        $this.SelectColumns.AddRange($columns)
        return $this
    }

    [QueryBuilder] Where([string]$condition, [object]$value) {
        $this.WhereConditions.Add($condition) | Out-Null
        $this.Parameters.Add($value) | Out-Null
        return $this
    }

    [QueryBuilder] OrderBy([string]$column, [string]$direction = 'ASC') {
        $this.OrderByColumns.Add("$column $direction") | Out-Null
        return $this
    }

    [QueryBuilder] Limit([int]$limit) {
        $this.LimitValue = $limit
        return $this
    }

    [QueryBuilder] Offset([int]$offset) {
        $this.OffsetValue = $offset
        return $this
    }

    [string] Build() {
        $select = if ($this.SelectColumns.Count -gt 0) {
            $this.SelectColumns -join ', '
        } else {
            '*'
        }

        $query = "SELECT $select FROM $($this.Table)"

        if ($this.JoinClause) {
            $query += " $($this.JoinClause)"
        }

        if ($this.WhereConditions.Count -gt 0) {
            $query += " WHERE " + ($this.WhereConditions -join ' AND ')
        }

        if ($this.OrderByColumns.Count -gt 0) {
            $query += " ORDER BY " + ($this.OrderByColumns -join ', ')
        }

        if ($this.LimitValue -gt 0) {
            $query += " LIMIT $($this.LimitValue)"
        }

        if ($this.OffsetValue -gt 0) {
            $query += " OFFSET $($this.OffsetValue)"
        }

        return $query
    }
}

# ============================================================================
# GENERIC CRUD OPERATIONS
# ============================================================================

function Invoke-DatabaseQuery {
    param(
        [Parameter(Mandatory)]
        [string]$Query,

        [hashtable]$Parameters = @{},

        [switch]$Scalar,

        [switch]$NonQuery
    )

    $connection = $null
    $command = $null
    $reader = $null

    try {
        $connection = New-DatabaseConnection -Pooled
        $command = $connection.CreateCommand()
        $command.CommandText = $Query

        # Add parameters
        foreach ($key in $Parameters.Keys) {
            $param = $command.CreateParameter()
            $param.ParameterName = $key
            $param.Value = $Parameters[$key] ?? [DBNull]::Value
            $command.Parameters.Add($param) | Out-Null
        }

        if ($Scalar) {
            $result = $command.ExecuteScalar()
            return $result
        }
        elseif ($NonQuery) {
            $result = $command.ExecuteNonQuery()
            return $result
        }
        else {
            $reader = $command.ExecuteReader()
            $results = @()

            while ($reader.Read()) {
                $row = @{}
                for ($i = 0; $i -lt $reader.FieldCount; $i++) {
                    $columnName = $reader.GetName($i)
                    $row[$columnName] = if ($reader.IsDBNull($i)) { $null } else { $reader.GetValue($i) }
                }
                $results += [PSCustomObject]$row
            }

            return $results
        }
    }
    catch {
        Write-DatabaseLog -Level ERROR -Message "Query execution failed: $_" -Data @{ Query = $Query }
        throw
    }
    finally {
        if ($reader) { $reader.Close(); $reader.Dispose() }
        if ($command) { $command.Dispose() }
        if ($connection) { Close-DatabaseConnection -Connection $connection -ReturnToPool }
    }
}

function New-DatabaseRecord {
    param(
        [Parameter(Mandatory)]
        [string]$Table,

        [Parameter(Mandatory)]
        [hashtable]$Data
    )

    try {
        $columns = $Data.Keys -join ', '
        $placeholders = ($Data.Keys | ForEach-Object { "@$_" }) -join ', '
        $query = "INSERT INTO $Table ($columns) VALUES ($placeholders); SELECT last_insert_rowid();"

        $parameters = @{}
        foreach ($key in $Data.Keys) {
            $parameters["@$key"] = $Data[$key]
        }

        $id = Invoke-DatabaseQuery -Query $query -Parameters $parameters -Scalar

        Write-DatabaseLog -Level SUCCESS -Message "Record created in $Table" -Data @{ ID = $id }

        return @{
            Success = $true
            ID = $id
        }
    }
    catch {
        Write-DatabaseLog -Level ERROR -Message "Failed to create record in $Table : $_"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Get-DatabaseRecord {
    param(
        [Parameter(Mandatory)]
        [string]$Table,

        [hashtable]$Where = @{},

        [string[]]$Select = @(),

        [string]$OrderBy,

        [int]$Limit = 0
    )

    try {
        $builder = [QueryBuilder]::new($Table)

        if ($Select.Count -gt 0) {
            $builder.Select($Select) | Out-Null
        }

        $parameters = @{}
        foreach ($key in $Where.Keys) {
            $builder.Where("$key = @$key", $Where[$key]) | Out-Null
            $parameters["@$key"] = $Where[$key]
        }

        if ($OrderBy) {
            $builder.OrderBy($OrderBy) | Out-Null
        }

        if ($Limit -gt 0) {
            $builder.Limit($Limit) | Out-Null
        }

        $query = $builder.Build()
        $results = Invoke-DatabaseQuery -Query $query -Parameters $parameters

        return $results
    }
    catch {
        Write-DatabaseLog -Level ERROR -Message "Failed to get records from $Table : $_"
        return @()
    }
}

function Update-DatabaseRecord {
    param(
        [Parameter(Mandatory)]
        [string]$Table,

        [Parameter(Mandatory)]
        [hashtable]$Data,

        [Parameter(Mandatory)]
        [hashtable]$Where
    )

    try {
        $setClause = ($Data.Keys | ForEach-Object { "$_ = @set_$_" }) -join ', '
        $whereClause = ($Where.Keys | ForEach-Object { "$_ = @where_$_" }) -join ' AND '
        $query = "UPDATE $Table SET $setClause WHERE $whereClause;"

        $parameters = @{}
        foreach ($key in $Data.Keys) {
            $parameters["@set_$key"] = $Data[$key]
        }
        foreach ($key in $Where.Keys) {
            $parameters["@where_$key"] = $Where[$key]
        }

        $rowsAffected = Invoke-DatabaseQuery -Query $query -Parameters $parameters -NonQuery

        Write-DatabaseLog -Level SUCCESS -Message "Updated $rowsAffected row(s) in $Table"

        return @{
            Success = $true
            RowsAffected = $rowsAffected
        }
    }
    catch {
        Write-DatabaseLog -Level ERROR -Message "Failed to update record in $Table : $_"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Remove-DatabaseRecord {
    param(
        [Parameter(Mandatory)]
        [string]$Table,

        [Parameter(Mandatory)]
        [hashtable]$Where
    )

    try {
        $whereClause = ($Where.Keys | ForEach-Object { "$_ = @$_" }) -join ' AND '
        $query = "DELETE FROM $Table WHERE $whereClause;"

        $parameters = @{}
        foreach ($key in $Where.Keys) {
            $parameters["@$key"] = $Where[$key]
        }

        $rowsAffected = Invoke-DatabaseQuery -Query $query -Parameters $parameters -NonQuery

        Write-DatabaseLog -Level SUCCESS -Message "Deleted $rowsAffected row(s) from $Table"

        return @{
            Success = $true
            RowsAffected = $rowsAffected
        }
    }
    catch {
        Write-DatabaseLog -Level ERROR -Message "Failed to delete record from $Table : $_"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

# ============================================================================
# BATCH OPERATIONS
# ============================================================================

function New-BatchDatabaseRecords {
    param(
        [Parameter(Mandatory)]
        [string]$Table,

        [Parameter(Mandatory)]
        [array]$Records
    )

    $connection = $null
    $transaction = $null

    try {
        $connection = New-DatabaseConnection -Pooled
        $transaction = $connection.BeginTransaction()

        $insertedCount = 0

        foreach ($record in $Records) {
            $columns = $record.Keys -join ', '
            $placeholders = ($record.Keys | ForEach-Object { "@$_" }) -join ', '
            $query = "INSERT INTO $Table ($columns) VALUES ($placeholders);"

            $command = $connection.CreateCommand()
            $command.CommandText = $query
            $command.Transaction = $transaction

            foreach ($key in $record.Keys) {
                $param = $command.CreateParameter()
                $param.ParameterName = "@$key"
                $param.Value = $record[$key] ?? [DBNull]::Value
                $command.Parameters.Add($param) | Out-Null
            }

            $command.ExecuteNonQuery() | Out-Null
            $command.Dispose()
            $insertedCount++
        }

        $transaction.Commit()

        Write-DatabaseLog -Level SUCCESS -Message "Batch inserted $insertedCount records into $Table"

        return @{
            Success = $true
            InsertedCount = $insertedCount
        }
    }
    catch {
        if ($transaction) { $transaction.Rollback() }
        Write-DatabaseLog -Level ERROR -Message "Batch insert failed: $_"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
    finally {
        if ($transaction) { $transaction.Dispose() }
        if ($connection) { Close-DatabaseConnection -Connection $connection -ReturnToPool }
    }
}

# ============================================================================
# TRADE OPERATIONS
# ============================================================================

function New-Trade {
    param(
        [Parameter(Mandatory)]
        [hashtable]$TradeData
    )

    try {
        # Ensure required fields
        $requiredFields = @('trade_id', 'exchange', 'symbol', 'side', 'type', 'quantity', 'price', 'total_value')
        foreach ($field in $requiredFields) {
            if (-not $TradeData.ContainsKey($field)) {
                throw "Missing required field: $field"
            }
        }

        $result = New-DatabaseRecord -Table 'trades' -Data $TradeData
        return $result
    }
    catch {
        Write-DatabaseLog -Level ERROR -Message "Failed to create trade: $_"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Get-Trades {
    param(
        [string]$Exchange,
        [string]$Symbol,
        [string]$Strategy,
        [string]$Status,
        [int]$Limit = 100
    )

    $where = @{}
    if ($Exchange) { $where['exchange'] = $Exchange }
    if ($Symbol) { $where['symbol'] = $Symbol }
    if ($Strategy) { $where['strategy'] = $Strategy }
    if ($Status) { $where['status'] = $Status }

    return Get-DatabaseRecord -Table 'trades' -Where $where -OrderBy 'created_at DESC' -Limit $Limit
}

function Update-TradeStatus {
    param(
        [Parameter(Mandatory)]
        [string]$TradeId,

        [Parameter(Mandatory)]
        [string]$Status,

        [hashtable]$AdditionalData = @{}
    )

    $data = @{
        status = $Status
        updated_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }

    foreach ($key in $AdditionalData.Keys) {
        $data[$key] = $AdditionalData[$key]
    }

    return Update-DatabaseRecord -Table 'trades' -Data $data -Where @{ trade_id = $TradeId }
}

function Get-TradeStatistics {
    param(
        [string]$Strategy,
        [DateTime]$StartDate,
        [DateTime]$EndDate
    )

    try {
        $whereClause = "status = 'FILLED'"

        if ($Strategy) {
            $whereClause += " AND strategy = '$Strategy'"
        }

        if ($StartDate) {
            $whereClause += " AND created_at >= '$(Get-Date $StartDate -Format 'yyyy-MM-dd')'"
        }

        if ($EndDate) {
            $whereClause += " AND created_at <= '$(Get-Date $EndDate -Format 'yyyy-MM-dd')'"
        }

        $query = @"
SELECT
    COUNT(*) as total_trades,
    SUM(CASE WHEN side = 'BUY' THEN 1 ELSE 0 END) as buy_trades,
    SUM(CASE WHEN side = 'SELL' THEN 1 ELSE 0 END) as sell_trades,
    SUM(CASE WHEN profit_loss > 0 THEN 1 ELSE 0 END) as winning_trades,
    SUM(CASE WHEN profit_loss < 0 THEN 1 ELSE 0 END) as losing_trades,
    SUM(profit_loss) as total_profit_loss,
    AVG(profit_loss) as avg_profit_loss,
    MAX(profit_loss) as max_profit,
    MIN(profit_loss) as max_loss,
    SUM(fee) as total_fees,
    SUM(total_value) as total_volume
FROM trades
WHERE $whereClause;
"@

        $result = Invoke-DatabaseQuery -Query $query

        if ($result) {
            $stats = $result[0]
            $stats | Add-Member -NotePropertyName 'win_rate' -NotePropertyValue $(
                if ($stats.total_trades -gt 0) {
                    [math]::Round(($stats.winning_trades / $stats.total_trades) * 100, 2)
                } else { 0 }
            )

            return $stats
        }

        return $null
    }
    catch {
        Write-DatabaseLog -Level ERROR -Message "Failed to get trade statistics: $_"
        return $null
    }
}

# ============================================================================
# CONTENT OPERATIONS
# ============================================================================

function New-Content {
    param(
        [Parameter(Mandatory)]
        [hashtable]$ContentData
    )

    try {
        $requiredFields = @('content_id', 'type', 'platform', 'title')
        foreach ($field in $requiredFields) {
            if (-not $ContentData.ContainsKey($field)) {
                throw "Missing required field: $field"
            }
        }

        $result = New-DatabaseRecord -Table 'content' -Data $ContentData
        return $result
    }
    catch {
        Write-DatabaseLog -Level ERROR -Message "Failed to create content: $_"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Get-Content {
    param(
        [string]$Type,
        [string]$Platform,
        [string]$Status,
        [int]$Limit = 50
    )

    $where = @{}
    if ($Type) { $where['type'] = $Type }
    if ($Platform) { $where['platform'] = $Platform }
    if ($Status) { $where['status'] = $Status }

    return Get-DatabaseRecord -Table 'content' -Where $where -OrderBy 'created_at DESC' -Limit $Limit
}

function Update-ContentStatus {
    param(
        [Parameter(Mandatory)]
        [string]$ContentId,

        [Parameter(Mandatory)]
        [string]$Status,

        [hashtable]$AdditionalData = @{}
    )

    $data = @{
        status = $Status
        updated_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }

    if ($Status -eq 'PUBLISHED' -and -not $AdditionalData.ContainsKey('published_at')) {
        $data['published_at'] = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }

    foreach ($key in $AdditionalData.Keys) {
        $data[$key] = $AdditionalData[$key]
    }

    return Update-DatabaseRecord -Table 'content' -Data $data -Where @{ content_id = $ContentId }
}

function Update-ContentMetrics {
    param(
        [Parameter(Mandatory)]
        [string]$ContentId,

        [int]$Views = 0,
        [int]$Clicks = 0,
        [int]$Conversions = 0,
        [decimal]$Revenue = 0
    )

    $query = @"
UPDATE content
SET views = views + @views,
    clicks = clicks + @clicks,
    conversions = conversions + @conversions,
    revenue = revenue + @revenue,
    roi = CASE WHEN cost > 0 THEN ((revenue + @revenue) - cost) / cost * 100 ELSE 0 END,
    updated_at = CURRENT_TIMESTAMP
WHERE content_id = @content_id;
"@

    $parameters = @{
        '@content_id' = $ContentId
        '@views' = $Views
        '@clicks' = $Clicks
        '@conversions' = $Conversions
        '@revenue' = $Revenue
    }

    return Invoke-DatabaseQuery -Query $query -Parameters $parameters -NonQuery
}

# ============================================================================
# REVENUE OPERATIONS
# ============================================================================

function New-Revenue {
    param(
        [Parameter(Mandatory)]
        [hashtable]$RevenueData
    )

    try {
        $requiredFields = @('revenue_id', 'source', 'category', 'amount')
        foreach ($field in $requiredFields) {
            if (-not $RevenueData.ContainsKey($field)) {
                throw "Missing required field: $field"
            }
        }

        $result = New-DatabaseRecord -Table 'revenue' -Data $RevenueData
        return $result
    }
    catch {
        Write-DatabaseLog -Level ERROR -Message "Failed to create revenue record: $_"
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Get-RevenueByDateRange {
    param(
        [Parameter(Mandatory)]
        [DateTime]$StartDate,

        [Parameter(Mandatory)]
        [DateTime]$EndDate,

        [string]$Source
    )

    try {
        $whereClause = "transaction_date >= '$(Get-Date $StartDate -Format 'yyyy-MM-dd')' AND transaction_date <= '$(Get-Date $EndDate -Format 'yyyy-MM-dd')'"

        if ($Source) {
            $whereClause += " AND source = '$Source'"
        }

        $query = @"
SELECT
    source,
    COUNT(*) as transaction_count,
    SUM(amount) as total_amount,
    AVG(amount) as avg_amount,
    MIN(amount) as min_amount,
    MAX(amount) as max_amount
FROM revenue
WHERE $whereClause AND status = 'COMPLETED'
GROUP BY source;
"@

        return Invoke-DatabaseQuery -Query $query
    }
    catch {
        Write-DatabaseLog -Level ERROR -Message "Failed to get revenue data: $_"
        return @()
    }
}

function Get-DailyRevenue {
    param(
        [int]$Days = 30
    )

    try {
        $query = @"
SELECT
    DATE(transaction_date) as date,
    source,
    SUM(amount) as daily_revenue,
    COUNT(*) as transaction_count
FROM revenue
WHERE transaction_date >= DATE('now', '-$Days days')
  AND status = 'COMPLETED'
GROUP BY DATE(transaction_date), source
ORDER BY date DESC, source;
"@

        return Invoke-DatabaseQuery -Query $query
    }
    catch {
        Write-DatabaseLog -Level ERROR -Message "Failed to get daily revenue: $_"
        return @()
    }
}

# ============================================================================
# API USAGE TRACKING
# ============================================================================

function New-APIUsageRecord {
    param(
        [Parameter(Mandatory)]
        [string]$Service,

        [Parameter(Mandatory)]
        [string]$Endpoint,

        [Parameter(Mandatory)]
        [string]$Method,

        [int]$StatusCode,
        [int]$ResponseTimeMs,
        [int]$TokensUsed = 0,
        [decimal]$Cost = 0,
        [bool]$Success = $true,
        [string]$ErrorMessage
    )

    $data = @{
        service = $Service
        endpoint = $Endpoint
        method = $Method
        status_code = $StatusCode
        response_time_ms = $ResponseTimeMs
        tokens_used = $TokensUsed
        cost = $Cost
        success = $Success
        error_message = $ErrorMessage
    }

    return New-DatabaseRecord -Table 'api_usage' -Data $data
}

function Get-APIUsageStatistics {
    param(
        [string]$Service,
        [int]$Hours = 24
    )

    try {
        $whereClause = "created_at >= DATETIME('now', '-$Hours hours')"

        if ($Service) {
            $whereClause += " AND service = '$Service'"
        }

        $query = @"
SELECT
    service,
    endpoint,
    COUNT(*) as total_requests,
    SUM(CASE WHEN success = 1 THEN 1 ELSE 0 END) as successful_requests,
    SUM(CASE WHEN success = 0 THEN 1 ELSE 0 END) as failed_requests,
    AVG(response_time_ms) as avg_response_time,
    SUM(tokens_used) as total_tokens,
    SUM(cost) as total_cost
FROM api_usage
WHERE $whereClause
GROUP BY service, endpoint;
"@

        return Invoke-DatabaseQuery -Query $query
    }
    catch {
        Write-DatabaseLog -Level ERROR -Message "Failed to get API usage statistics: $_"
        return @()
    }
}

# ============================================================================
# SYSTEM HEALTH OPERATIONS
# ============================================================================

function New-HealthCheckRecord {
    param(
        [Parameter(Mandatory)]
        [string]$Component,

        [Parameter(Mandatory)]
        [string]$Status,

        [hashtable]$Metrics = @{}
    )

    $data = @{
        component = $Component
        status = $Status
    }

    foreach ($key in $Metrics.Keys) {
        $data[$key] = $Metrics[$key]
    }

    return New-DatabaseRecord -Table 'system_health' -Data $data
}

function Get-SystemHealthStatus {
    param(
        [string]$Component,
        [int]$Hours = 1
    )

    $where = @{}
    if ($Component) {
        $where['component'] = $Component
    }

    $query = "SELECT * FROM system_health WHERE checked_at >= DATETIME('now', '-$Hours hours')"

    if ($Component) {
        $query += " AND component = '$Component'"
    }

    $query += " ORDER BY checked_at DESC;"

    return Invoke-DatabaseQuery -Query $query
}

# ============================================================================
# EXPORT FUNCTIONS
# ============================================================================

Export-ModuleMember -Function @(
    # Generic CRUD
    'Invoke-DatabaseQuery',
    'New-DatabaseRecord',
    'Get-DatabaseRecord',
    'Update-DatabaseRecord',
    'Remove-DatabaseRecord',
    'New-BatchDatabaseRecords',

    # Trades
    'New-Trade',
    'Get-Trades',
    'Update-TradeStatus',
    'Get-TradeStatistics',

    # Content
    'New-Content',
    'Get-Content',
    'Update-ContentStatus',
    'Update-ContentMetrics',

    # Revenue
    'New-Revenue',
    'Get-RevenueByDateRange',
    'Get-DailyRevenue',

    # API Usage
    'New-APIUsageRecord',
    'Get-APIUsageStatistics',

    # Health
    'New-HealthCheckRecord',
    'Get-SystemHealthStatus'
)
