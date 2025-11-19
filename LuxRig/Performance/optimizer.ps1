# ============================================================================
# LuxRig Performance Optimizer
# Profiling, caching, and performance monitoring
# ============================================================================

param([switch]$Profile, [switch]$OptimizeDatabase, [switch]$ClearCache)

$Script:Cache = @{}
$Script:PerformanceMetrics = @{}

function Start-PerformanceProfile {
    param([scriptblock]$ScriptBlock, [string]$Name)

    $startTime = Get-Date
    $startMemory = [GC]::GetTotalMemory($false)

    $result = & $ScriptBlock

    $duration = ((Get-Date) - $startTime).TotalMilliseconds
    $memoryUsed = [GC]::GetTotalMemory($false) - $startMemory

    $Script:PerformanceMetrics[$Name] = @{
        Duration = $duration
        MemoryUsed = $memoryUsed
        Timestamp = Get-Date
    }

    Write-Host "⚡ $Name : $([math]::Round($duration, 2))ms | $([math]::Round($memoryUsed/1MB, 2))MB" -ForegroundColor Cyan

    return $result
}

function Get-CachedValue {
    param([string]$Key, [scriptblock]$ValueProvider, [int]$TTLSeconds = 300)

    if ($Script:Cache.ContainsKey($Key)) {
        $cached = $Script:Cache[$Key]
        if (((Get-Date) - $cached.Timestamp).TotalSeconds -lt $TTLSeconds) {
            return $cached.Value
        }
    }

    $value = & $ValueProvider
    $Script:Cache[$Key] = @{
        Value = $value
        Timestamp = Get-Date
    }

    return $value
}

function Optimize-Database {
    try {
        Write-Host "🔧 Optimizing database..." -ForegroundColor Yellow

        $dbPath = Join-Path $PSScriptRoot '../Data/luxrig.db'
        if (-not (Test-Path $dbPath)) {
            Write-Host "Database not found" -ForegroundColor Red
            return
        }

        $connection = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$dbPath")
        $connection.Open()

        # Vacuum
        $cmd = $connection.CreateCommand()
        $cmd.CommandText = "VACUUM;"
        $cmd.ExecuteNonQuery() | Out-Null

        # Analyze
        $cmd.CommandText = "ANALYZE;"
        $cmd.ExecuteNonQuery() | Out-Null

        $connection.Close()

        Write-Host "✅ Database optimized" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Optimization failed: $_" -ForegroundColor Red
    }
}

function Get-PerformanceReport {
    Write-Host "`n=== Performance Report ===" -ForegroundColor Cyan

    foreach ($metric in $Script:PerformanceMetrics.GetEnumerator()) {
        $name = $metric.Key
        $data = $metric.Value
        Write-Host "$name : $([math]::Round($data.Duration, 2))ms" -ForegroundColor White
    }

    Write-Host "`nCache Entries: $($Script:Cache.Count)" -ForegroundColor Cyan
    Write-Host "Memory Usage: $([math]::Round([GC]::GetTotalMemory($false)/1MB, 2))MB`n" -ForegroundColor Cyan
}

# Main execution
if ($Profile) {
    Get-PerformanceReport
}

if ($OptimizeDatabase) {
    Optimize-Database
}

if ($ClearCache) {
    $Script:Cache.Clear()
    Write-Host "✅ Cache cleared" -ForegroundColor Green
}

Export-ModuleMember -Function @('Start-PerformanceProfile', 'Get-CachedValue', 'Optimize-Database')
