# OPUS-DLX Hardening Plan
**Date:** November 19, 2025  
**Author:** Claude Opus 4.1  
**Objective:** Make this actually work

---

## Priority 1: Fix the Immediate Blockers (Session 1)

### Task 1.1: Fix Module Loading Architecture
**Problem:** Scripts pretending to be modules  
**Solution:** Convert to proper PowerShell modules

```powershell
# WRONG (current):
Import-Module "$PSScriptRoot\task-router.ps1"

# RIGHT (fixed):
# 1. Rename task-router.ps1 to task-router.psm1
# 2. Add at the bottom:
Export-ModuleMember -Function * -Variable * -Alias *

# 3. Import properly:
Import-Module "$PSScriptRoot\task-router.psm1" -Force
```

**Files to fix (in order):**
1. `task-router.ps1` → `task-router.psm1`
2. `budget-manager.ps1` → `budget-manager.psm1`
3. `quality-gates.ps1` → `quality-gates.psm1`
4. `roi-calculator.ps1` → `roi-calculator.psm1`
5. `auto-scaler.ps1` → `auto-scaler.psm1`

### Task 1.2: Create Module Loader
```powershell
# Create Orchestrator\Import-AllModules.ps1
$modules = @(
    "task-router",
    "budget-manager",
    "quality-gates",
    "roi-calculator",
    "auto-scaler"
)

foreach ($module in $modules) {
    $modulePath = Join-Path $PSScriptRoot "$module.psm1"
    if (Test-Path $modulePath) {
        Import-Module $modulePath -Force -Global
        Write-Host "✓ Loaded $module" -ForegroundColor Green
    } else {
        Write-Warning "Module not found: $module"
    }
}
```

### Task 1.3: Fix Import-Module Pattern
**Remove all Import-Module calls from individual files**  
**Use dot-sourcing for the loader:**
```powershell
# In master-orchestrator.ps1, replace all Import-Module with:
. "$PSScriptRoot\Import-AllModules.ps1"
```

---

## Priority 2: Stability & Resilience (Session 2)

### Task 2.1: Implement Actual Error Handling
```powershell
# Create Core\ErrorHandler.psm1
function Invoke-SafeExecution {
    param(
        [scriptblock]$ScriptBlock,
        [string]$ErrorMessage = "Operation failed",
        [switch]$ContinueOnError
    )
    
    try {
        $ErrorActionPreference = "Stop"
        & $ScriptBlock
    }
    catch {
        $errorDetails = @{
            Message = $ErrorMessage
            Exception = $_.Exception.Message
            ScriptLine = $_.InvocationInfo.ScriptLineNumber
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        
        Add-Content -Path "$PSScriptRoot\..\Logs\errors.log" -Value ($errorDetails | ConvertTo-Json)
        
        if (-not $ContinueOnError) {
            throw
        }
        
        return $null
    }
}
```

### Task 2.2: Add Proper Logging
```powershell
# Create Core\Logger.psm1
$script:LogLevel = @{
    Debug = 0
    Info = 1
    Warning = 2
    Error = 3
    Critical = 4
}

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet("Debug", "Info", "Warning", "Error", "Critical")]
        [string]$Level = "Info",
        
        [string]$Component = "System"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] [$Component] $Message"
    
    # Console output with colors
    $color = switch ($Level) {
        "Debug" { "Gray" }
        "Info" { "White" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        "Critical" { "Magenta" }
    }
    
    Write-Host $logEntry -ForegroundColor $color
    
    # File output
    $logFile = "$PSScriptRoot\..\Logs\luxrig-$(Get-Date -Format 'yyyy-MM-dd').log"
    Add-Content -Path $logFile -Value $logEntry
}
```

### Task 2.3: Add Health Checks
```powershell
# Create Monitoring\HealthCheck.psm1
function Test-ComponentHealth {
    param([string]$ComponentName)
    
    $health = @{
        Component = $ComponentName
        Status = "Unknown"
        LastCheck = Get-Date
        Issues = @()
    }
    
    # Actually test if the component loads
    try {
        Import-Module "$PSScriptRoot\..\Orchestrator\$ComponentName.psm1" -Force
        $health.Status = "Healthy"
    }
    catch {
        $health.Status = "Failed"
        $health.Issues += $_.Exception.Message
    }
    
    return $health
}
```

---

## Priority 3: Make ONE Thing Actually Work (Session 3)

### Task 3.1: Implement Basic Opportunity Scanner
```powershell
# Fix Engines\ContentEngine\opportunity-scanner.psm1
function Find-Opportunities {
    param(
        [string]$Source = "hackernews",
        [int]$Limit = 10
    )
    
    $opportunities = @()
    
    # Actually fetch from Hacker News API (no auth required)
    try {
        $topStories = Invoke-RestMethod -Uri "https://hacker-news.firebaseio.com/v0/topstories.json"
        
        foreach ($storyId in $topStories[0..($Limit-1)]) {
            $story = Invoke-RestMethod -Uri "https://hacker-news.firebaseio.com/v0/item/$storyId.json"
            
            $opportunities += @{
                id = $story.id
                title = $story.title
                url = $story.url
                score = $story.score
                source = "HackerNews"
                timestamp = Get-Date
                potential = if ($story.score -gt 100) { "high" } else { "medium" }
            }
        }
    }
    catch {
        Write-Log "Failed to fetch opportunities: $_" -Level Error
        # Return mock data as fallback
        $opportunities = @(
            @{ title = "AI Code Generator"; potential = "high"; source = "mock" }
        )
    }
    
    return $opportunities
}
```

### Task 3.2: Connect to Local LM Studio
```powershell
# Fix Orchestrator\ai-plugins\local-plugin.psm1
function Invoke-LocalAI {
    param(
        [string]$Prompt,
        [string]$Endpoint = "http://localhost:5173/v1/chat/completions"
    )
    
    $headers = @{
        "Content-Type" = "application/json"
    }
    
    $body = @{
        model = "local-model"
        messages = @(
            @{
                role = "user"
                content = $Prompt
            }
        )
        temperature = 0.7
        max_tokens = 500
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri $Endpoint -Method Post -Headers $headers -Body $body
        return $response.choices[0].message.content
    }
    catch {
        Write-Log "Local AI call failed: $_" -Level Error
        return $null
    }
}
```

---

## Priority 4: Security Fixes (Session 4)

### Task 4.1: Proper Secrets Management
```powershell
# Create Security\SecretsManager.psm1
function Get-SecureCredential {
    param([string]$Name)
    
    $credPath = "$env:LOCALAPPDATA\LuxRig\Credentials\$Name.xml"
    
    if (Test-Path $credPath) {
        return Import-Clixml $credPath
    }
    
    # Prompt for credential if not found
    $cred = Get-Credential -Message "Enter credential for: $Name"
    
    # Save securely (encrypted with Windows DPAPI)
    $cred | Export-Clixml $credPath
    
    return $cred
}

function Get-APIKey {
    param([string]$Provider)
    
    $cred = Get-SecureCredential -Name "API_$Provider"
    return $cred.GetNetworkCredential().Password
}
```

### Task 4.2: Input Validation
```powershell
# Add to each module that accepts user input
function Validate-Input {
    param(
        [Parameter(Mandatory)]
        $Value,
        
        [ValidateSet("String", "Number", "Path", "Url")]
        [string]$Type
    )
    
    switch ($Type) {
        "String" {
            # Remove potential injection characters
            return $Value -replace '[;<>&|`]', ''
        }
        "Path" {
            # Validate path doesn't escape sandbox
            if ($Value -match '\.\.') {
                throw "Path traversal detected"
            }
            return [System.IO.Path]::GetFullPath($Value)
        }
        "Url" {
            # Validate URL format
            if (-not [Uri]::IsWellFormedUriString($Value, [UriKind]::Absolute)) {
                throw "Invalid URL format"
            }
            return $Value
        }
    }
}
```

---

## Quick Win Fixes (Do These First!)

### Fix #1: Comment Out All Import-Module Lines
```powershell
# In master-orchestrator.ps1, comment out lines 30-40:
# Import-Module "$PSScriptRoot\task-router.ps1" -Force
# Import-Module "$PSScriptRoot\budget-manager.ps1" -Force
# ... etc

# Replace with:
Write-Host "Skipping module imports for testing" -ForegroundColor Yellow
```

### Fix #2: Create Stub Functions
```powershell
# Add to master-orchestrator.ps1 after param block:
function Find-Opportunities { return @(@{title="Test"; score=100}) }
function Invoke-IdeaValidation { return @{decision="GO"; confidence=0.8} }
function Build-MicroSaaS { return @{success=$true; project="TestProject"} }
function Invoke-ContentGeneration { return @{success=$true; title="Test Article"} }
function Get-TotalRevenue { return @{total=100} }
function Get-ROIMetrics { return @{roi=150} }
function Invoke-AutoScale { return @{action="maintain"; targetMode="current"} }
function Get-AnalyticsDashboard { return @{} }
```

### Fix #3: Make the Test Script Honest
```powershell
# In test-phase1.ps1, change the summary output:
Write-Host "REALITY CHECK:" -ForegroundColor Red
Write-Host "Files exist: $($testResults.passed)" -ForegroundColor Yellow
Write-Host "Actually working: 0" -ForegroundColor Red
Write-Host "Modules that load: 0" -ForegroundColor Red
Write-Host "Integration tests: 0" -ForegroundColor Red
```

---

## Recommended Approach for Claude Code

### Session 1: Emergency Surgery (2 hours)
1. Apply quick fixes #1-3 above
2. Get master-orchestrator.ps1 to parse
3. Create one working function end-to-end

### Session 2: Foundation Repair (2 hours)
1. Fix module architecture
2. Add proper error handling
3. Implement logging

### Session 3: First Real Feature (2 hours)
1. Get opportunity scanner working with real API
2. Connect to local LM Studio
3. Generate one piece of actual content

### Session 4: Testing & Validation (2 hours)
1. Create real integration tests
2. Fix security issues
3. Document what actually works

---

## Success Metrics

### Phase 1 Success = These Work:
- [ ] master-orchestrator.ps1 loads without errors
- [ ] Can run Invoke-OrchestrationCycle once
- [ ] Fetches real data from at least one API
- [ ] Generates one piece of content via LM Studio
- [ ] Logs activities to file

### Phase 2 Success = These Work:
- [ ] Runs continuously for 1 hour without crashing
- [ ] All modules load properly
- [ ] Error handling prevents crashes
- [ ] Can recover from API failures

### Phase 3 Success = These Work:
- [ ] Generates actual revenue ($0.01 counts!)
- [ ] Runs for 24 hours unattended
- [ ] Auto-scales based on performance
- [ ] Produces measurable output

---

## The Hard Truth

**Stop building wide. Start building deep.**

Pick ONE revenue path:
1. Content generation → Blog → AdSense
2. API wrapper → Billing → Subscriptions  
3. Tool builder → Launch → Sales

Make that ONE path work end-to-end before adding features.

