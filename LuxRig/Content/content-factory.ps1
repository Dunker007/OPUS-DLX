# ============================================================================
# LuxRig Content Factory
# Mass content generation and distribution
# ============================================================================

param(
    [int]$DailyTarget = 10,
    [string[]]$Platforms = @('wordpress', 'medium'),
    [string[]]$Topics = @('cryptocurrency', 'trading', 'blockchain'),
    [switch]$AutoPublish
)

$blogPublisher = Join-Path $PSScriptRoot 'blog-publisher.ps1'

function Start-ContentFactory {
    Write-Host "🏭 Content Factory Started" -ForegroundColor Cyan
    Write-Host "   Daily Target: $DailyTarget posts" -ForegroundColor White
    Write-Host "   Platforms: $($Platforms -join ', ')" -ForegroundColor White
    Write-Host "   Topics: $($Topics -join ', ')" -ForegroundColor White

    $produced = 0
    $failed = 0

    for ($i = 0; $i -lt $DailyTarget; $i++) {
        $topic = $Topics | Get-Random
        $platform = $Platforms | Get-Random

        Write-Host "`nGenerating content $($i+1)/$DailyTarget..." -ForegroundColor Yellow
        Write-Host "  Topic: $topic" -ForegroundColor Gray
        Write-Host "  Platform: $platform" -ForegroundColor Gray

        try {
            & $blogPublisher -Platform $platform -Topic $topic -Count 1 -AutoPublish:$AutoPublish

            $produced++
            Write-Host "✅ Content produced successfully" -ForegroundColor Green

            # Add delay
            if ($i -lt $DailyTarget - 1) {
                Start-Sleep -Seconds 30
            }
        }
        catch {
            $failed++
            Write-Host "❌ Failed: $_" -ForegroundColor Red
        }
    }

    Write-Host "`n=== Production Summary ===" -ForegroundColor Cyan
    Write-Host "  Produced: $produced" -ForegroundColor Green
    Write-Host "  Failed: $failed" -ForegroundColor Red
}

Start-ContentFactory
