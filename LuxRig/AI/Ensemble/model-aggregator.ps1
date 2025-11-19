#Requires -Version 7.0
<#
.SYNOPSIS
    Multi-Model Aggregator - Ensemble AI trading
.DESCRIPTION
    Combines predictions from multiple models:
    - Weighted voting
    - Stacking
    - Model confidence scoring
    - Consensus building
.NOTES
    Part of Phase 4: Advanced AI Systems
#>

function New-EnsemblePredictor {
    param(
        [Parameter(Mandatory)][array]$Models,
        [ValidateSet("Voting","Weighted","Stacking")][string]$Method = "Weighted"
    )

    return @{
        models = $Models
        method = $Method
        weights = $null
    }
}

function Get-EnsemblePrediction {
    param(
        [Parameter(Mandatory)][hashtable]$Ensemble,
        [Parameter(Mandatory)][hashtable]$MarketData
    )

    $predictions = @()

    # Get predictions from all models
    foreach ($model in $Ensemble.models) {
        $pred = & $model.predict -Data $MarketData

        $predictions += @{
            model = $model.name
            signal = $pred.signal
            confidence = $pred.confidence
            weight = if ($Ensemble.weights) { $Ensemble.weights[$model.name] } else { 1.0 }
        }
    }

    # Aggregate based on method
    switch ($Ensemble.method) {
        "Voting" {
            # Simple majority vote
            $buyVotes = ($predictions | Where-Object { $_.signal -eq "BUY" }).Count
            $sellVotes = ($predictions | Where-Object { $_.signal -eq "SELL" }).Count

            $finalSignal = if ($buyVotes -gt $sellVotes) { "BUY" }
                          elseif ($sellVotes -gt $buyVotes) { "SELL" }
                          else { "HOLD" }

            $confidence = [Math]::Max($buyVotes, $sellVotes) / $predictions.Count
        }

        "Weighted" {
            # Weighted by model confidence
            $buyScore = 0
            $sellScore = 0

            foreach ($pred in $predictions) {
                if ($pred.signal -eq "BUY") {
                    $buyScore += $pred.confidence * $pred.weight
                }
                elseif ($pred.signal -eq "SELL") {
                    $sellScore += $pred.confidence * $pred.weight
                }
            }

            $finalSignal = if ($buyScore -gt $sellScore) { "BUY" }
                          elseif ($sellScore -gt $buyScore) { "SELL" }
                          else { "HOLD" }

            $confidence = [Math]::Max($buyScore, $sellScore) / ($buyScore + $sellScore + 0.001)
        }

        "Stacking" {
            # Meta-learner combines base predictions
            # Simplified: use confidence-weighted average
            $avgConfidence = ($predictions.confidence | Measure-Object -Average).Average
            $consensus = ($predictions | Group-Object signal | Sort-Object Count -Descending | Select-Object -First 1).Name

            $finalSignal = $consensus
            $confidence = $avgConfidence
        }
    }

    Write-Host "`n🤖 ENSEMBLE PREDICTION:" -ForegroundColor Cyan
    Write-Host "   Method: $($Ensemble.method)" -ForegroundColor White
    Write-Host "   Models: $($predictions.Count)" -ForegroundColor White
    foreach ($pred in $predictions) {
        $color = switch ($pred.signal) {
            "BUY" { "Green" }
            "SELL" { "Red" }
            default { "Gray" }
        }
        Write-Host "   - $($pred.model): $($pred.signal) (conf: $([Math]::Round($pred.confidence, 2)))" -ForegroundColor $color
    }
    Write-Host "`n   🎯 FINAL: $finalSignal (confidence: $([Math]::Round($confidence, 2)))`n" -ForegroundColor $(if ($finalSignal -eq "BUY") { 'Green' } elseif ($finalSignal -eq "SELL") { 'Red' } else { 'Yellow' })

    return @{
        signal = $finalSignal
        confidence = $confidence
        predictions = $predictions
    }
}

function Optimize-EnsembleWeights {
    param(
        [Parameter(Mandatory)][hashtable]$Ensemble,
        [Parameter(Mandatory)][array]$ValidationData
    )

    Write-Host "Optimizing ensemble weights..." -ForegroundColor Cyan

    # Track model performance
    $performance = @{}
    foreach ($model in $Ensemble.models) {
        $performance[$model.name] = @{ correct = 0; total = 0 }
    }

    # Evaluate each model
    foreach ($sample in $ValidationData) {
        foreach ($model in $Ensemble.models) {
            $pred = & $model.predict -Data $sample.data

            if ($pred.signal -eq $sample.actual) {
                $performance[$model.name].correct++
            }
            $performance[$model.name].total++
        }
    }

    # Calculate weights based on accuracy
    $weights = @{}
    $totalAccuracy = 0

    foreach ($modelName in $performance.Keys) {
        $accuracy = $performance[$modelName].correct / [Math]::Max(1, $performance[$modelName].total)
        $weights[$modelName] = $accuracy
        $totalAccuracy += $accuracy
    }

    # Normalize weights
    foreach ($modelName in $weights.Keys) {
        $weights[$modelName] /= $totalAccuracy
    }

    $Ensemble.weights = $weights

    Write-Host "✅ Weights optimized:`n" -ForegroundColor Green
    foreach ($modelName in $weights.Keys) {
        Write-Host "   $modelName`: $([Math]::Round($weights[$modelName], 3))" -ForegroundColor White
    }
    Write-Host ""

    return $weights
}

Export-ModuleMember -Function New-EnsemblePredictor, Get-EnsemblePrediction, Optimize-EnsembleWeights

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Model Aggregator ready. Ensemble AI predictions with multi-model consensus" -ForegroundColor Yellow
}
