# ============================================================================
# LuxRig Global Error Handler
# Circuit breaker, retry logic, and error tracking
# ============================================================================

$Script:CircuitBreakers = @{}
$Script:ErrorCounts = @{}

class CircuitBreaker {
    [string]$Name
    [int]$Threshold = 5
    [int]$TimeoutSeconds = 60
    [int]$FailureCount = 0
    [DateTime]$LastFailure
    [string]$State = 'CLOSED'  # CLOSED, OPEN, HALF_OPEN

    CircuitBreaker([string]$name) {
        $this.Name = $name
        $this.LastFailure = Get-Date
    }

    [bool] ShouldAllow() {
        if ($this.State -eq 'CLOSED') {
            return $true
        }
        elseif ($this.State -eq 'OPEN') {
            if (((Get-Date) - $this.LastFailure).TotalSeconds -gt $this.TimeoutSeconds) {
                $this.State = 'HALF_OPEN'
                return $true
            }
            return $false
        }
        else {
            return $true
        }
    }

    [void] RecordSuccess() {
        $this.FailureCount = 0
        $this.State = 'CLOSED'
    }

    [void] RecordFailure() {
        $this.FailureCount++
        $this.LastFailure = Get-Date

        if ($this.FailureCount -ge $this.Threshold) {
            $this.State = 'OPEN'
            Write-Host "⚠️  Circuit breaker OPEN for $($this.Name)" -ForegroundColor Red
        }
    }
}

function Invoke-WithCircuitBreaker {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [int]$MaxRetries = 3,

        [int]$RetryDelaySeconds = 5
    )

    if (-not $Script:CircuitBreakers.ContainsKey($Name)) {
        $Script:CircuitBreakers[$Name] = [CircuitBreaker]::new($Name)
    }

    $breaker = $Script:CircuitBreakers[$Name]

    if (-not $breaker.ShouldAllow()) {
        throw "Circuit breaker is OPEN for $Name"
    }

    $attempt = 0
    while ($attempt -lt $MaxRetries) {
        try {
            $attempt++
            $result = & $ScriptBlock
            $breaker.RecordSuccess()
            return $result
        }
        catch {
            Write-Host "❌ Attempt $attempt/$MaxRetries failed for $Name : $_" -ForegroundColor Red

            if ($attempt -lt $MaxRetries) {
                Start-Sleep -Seconds $RetryDelaySeconds
            }
            else {
                $breaker.RecordFailure()
                Track-Error -Component $Name -Message $_.Exception.Message
                throw
            }
        }
    }
}

function Track-Error {
    param(
        [string]$Component,
        [string]$Message
    )

    if (-not $Script:ErrorCounts.ContainsKey($Component)) {
        $Script:ErrorCounts[$Component] = 0
    }

    $Script:ErrorCounts[$Component]++

    $logPath = Join-Path $PSScriptRoot '../Logs/errors.log'
    if (Test-Path (Split-Path $logPath)) {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Component] $Message" | Add-Content -Path $logPath
    }
}

function Get-ErrorStatistics {
    return @{
        Errors = $Script:ErrorCounts
        CircuitBreakers = $Script:CircuitBreakers
    }
}

Export-ModuleMember -Function @(
    'Invoke-WithCircuitBreaker',
    'Track-Error',
    'Get-ErrorStatistics'
)
