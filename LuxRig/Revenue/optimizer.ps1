# ============================================================================
# LuxRig Revenue Optimizer
# Analyze and optimize revenue streams
# ============================================================================

param([int]$Days = 30, [switch]$Optimize, [switch]$Report)

$dataAccessModule = Join-Path $PSScriptRoot '../Database/data-access.ps1'
if (Test-Path $dataAccessModule) { . $dataAccessModule }

function Get-RevenueAnalysis {
    param([int]$Days)

    Write-Host "📊 Analyzing Revenue Streams (Last $Days days)..." -ForegroundColor Cyan

    $startDate = (Get-Date).AddDays(-$Days)
    $endDate = Get-Date

    $revenue = Get-RevenueByDateRange -StartDate $startDate -EndDate $endDate

    if (-not $revenue) {
        Write-Host "No revenue data found" -ForegroundColor Yellow
        return
    }

    $analysis = @{}

    foreach ($source in $revenue) {
        $analysis[$source.source] = @{
            Total = [double]$source.total_amount
            Transactions = [int]$source.transaction_count
            Average = [double]$source.avg_amount
            Min = [double]$source.min_amount
            Max = [double]$source.max_amount
        }
    }

    return $analysis
}

function Get-OptimizationRecommendations {
    param($Analysis)

    Write-Host "`n💡 Optimization Recommendations:" -ForegroundColor Yellow

    # Find highest performing source
    $topSource = $Analysis.GetEnumerator() | Sort-Object { $_.Value.Total } -Descending | Select-Object -First 1

    if ($topSource) {
        Write-Host "`n✅ Top Performer: $($topSource.Key)" -ForegroundColor Green
        Write-Host "   Total Revenue: `$$($topSource.Value.Total)" -ForegroundColor Cyan
        Write-Host "   Recommendation: Scale this revenue stream by 50%" -ForegroundColor White
    }

    # Find underperformers
    $avgRevenue = ($Analysis.Values | Measure-Object -Property Total -Average).Average

    foreach ($source in $Analysis.GetEnumerator()) {
        if ($source.Value.Total -lt ($avgRevenue * 0.5)) {
            Write-Host "`n⚠️  Underperformer: $($source.Key)" -ForegroundColor Yellow
            Write-Host "   Total Revenue: `$$($source.Value.Total)" -ForegroundColor Red
            Write-Host "   Recommendation: Review strategy or reallocate resources" -ForegroundColor White
        }
    }

    # ROI suggestions
    Write-Host "`n📈 Growth Strategies:" -ForegroundColor Cyan
    Write-Host "   1. Increase allocation to top-performing sources" -ForegroundColor White
    Write-Host "   2. Diversify revenue streams" -ForegroundColor White
    Write-Host "   3. Optimize underperforming sources" -ForegroundColor White
    Write-Host "   4. Test new revenue channels" -ForegroundColor White
}

function Export-RevenueReport {
    param($Analysis)

    $report = @{
        GeneratedAt = Get-Date
        Period = "$Days days"
        Analysis = $Analysis
        TotalRevenue = ($Analysis.Values | Measure-Object -Property Total -Sum).Sum
    }

    $reportPath = Join-Path $PSScriptRoot '../Data/Reports/revenue-optimization-$(Get-Date -Format "yyyyMMdd-HHmmss").json'

    if (-not (Test-Path (Split-Path $reportPath))) {
        New-Item -ItemType Directory -Path (Split-Path $reportPath) -Force | Out-Null
    }

    $report | ConvertTo-Json -Depth 10 | Set-Content -Path $reportPath -Encoding UTF8

    Write-Host "`n✅ Report saved: $reportPath" -ForegroundColor Green
}

# Main execution
Write-Host "`n=== LuxRig Revenue Optimizer ===" -ForegroundColor Cyan

$analysis = Get-RevenueAnalysis -Days $Days

if ($analysis) {
    Write-Host "`n📊 Revenue Breakdown:" -ForegroundColor Yellow

    foreach ($source in $analysis.GetEnumerator() | Sort-Object { $_.Value.Total } -Descending) {
        Write-Host "`n$($source.Key)" -ForegroundColor Cyan
        Write-Host "  Total: `$$($source.Value.Total)" -ForegroundColor Green
        Write-Host "  Transactions: $($source.Value.Transactions)" -ForegroundColor White
        Write-Host "  Average: `$$([math]::Round($source.Value.Average, 2))" -ForegroundColor White
    }

    if ($Optimize) {
        Get-OptimizationRecommendations -Analysis $analysis
    }

    if ($Report) {
        Export-RevenueReport -Analysis $analysis
    }
}

Write-Host ""
