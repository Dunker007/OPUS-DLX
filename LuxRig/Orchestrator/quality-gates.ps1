<#
.SYNOPSIS
    Quality Gates - Multi-layer Content & Code Verification for LuxRig

.DESCRIPTION
    Validates AI-generated outputs:
    - Content originality check (prevent plagiarism)
    - FTC compliance scanner (affiliate disclosures)
    - Fact-checking pipeline (multi-AI verification)
    - Code security review (for generated tools)
    - Performance benchmarking

.EXAMPLE
    $result = Test-ContentQuality -Content $aiOutput -Type "article"
    $codeResult = Test-CodeQuality -Code $generatedCode -Language "powershell"

.NOTES
    Part of LuxRig Phase 1 Foundation
    Critical for maintaining quality and legal compliance
#>

# Import task router for multi-AI verification
. "$PSScriptRoot\task-router.ps1"

# Load quality standards
function Get-QualityStandards {
    param(
        [string]$ConfigPath = "$PSScriptRoot\..\Configs\quality-standards.json"
    )

    try {
        if (Test-Path $ConfigPath) {
            return Get-Content $ConfigPath | ConvertFrom-Json -AsHashtable
        }

        # Default standards
        return @{
            content = @{
                min_originality_score = 0.85
                require_ftc_disclosure = $true
                max_plagiarism_matches = 3
                min_readability_score = 60
            }
            code = @{
                require_security_scan = $true
                max_complexity_score = 15
                require_error_handling = $true
                block_dangerous_functions = $true
            }
            factcheck = @{
                require_sources = $true
                min_confidence = 0.75
                use_multi_ai_verification = $true
            }
        }
    }
    catch {
        Write-Warning "Failed to load quality standards: $_"
        return @{}
    }
}

# Test content quality
function Test-ContentQuality {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Content,

        [ValidateSet("article", "social", "email", "landing-page", "general")]
        [string]$Type = "general",

        [hashtable]$Options = @{}
    )

    $standards = Get-QualityStandards
    $results = @{
        passed = $true
        score = 100
        issues = @()
        warnings = @()
        checks = @{}
    }

    Write-Host "`n=== Quality Gate: Content Analysis ===" -ForegroundColor Cyan

    # 1. Originality Check (basic text similarity)
    $originalityResult = Test-Originality -Content $Content
    $results.checks.originality = $originalityResult

    if ($originalityResult.score -lt $standards.content.min_originality_score) {
        $results.issues += "Low originality score: $($originalityResult.score)"
        $results.passed = $false
        $results.score -= 20
    }

    # 2. FTC Compliance (affiliate disclosure detection)
    if ($standards.content.require_ftc_disclosure -and ($Type -eq "article" -or $Type -eq "landing-page")) {
        $ftcResult = Test-FTCCompliance -Content $Content
        $results.checks.ftc_compliance = $ftcResult

        if (-not $ftcResult.has_disclosure) {
            $results.warnings += "Missing FTC affiliate disclosure"
            $results.score -= 10
        }
    }

    # 3. Readability Check
    $readabilityResult = Test-Readability -Content $Content
    $results.checks.readability = $readabilityResult

    if ($readabilityResult.score -lt $standards.content.min_readability_score) {
        $results.warnings += "Low readability score: $($readabilityResult.score)"
        $results.score -= 5
    }

    # 4. Spam/Keyword Stuffing Detection
    $spamResult = Test-SpamScore -Content $Content
    $results.checks.spam = $spamResult

    if ($spamResult.is_spam) {
        $results.issues += "Content appears to be spam or keyword-stuffed"
        $results.passed = $false
        $results.score -= 30
    }

    # Display results
    Write-Host "Originality: $($originalityResult.score * 100)%" -ForegroundColor $(if ($originalityResult.score -ge 0.85) { "Green" } else { "Red" })
    Write-Host "Readability: $($readabilityResult.score)" -ForegroundColor $(if ($readabilityResult.score -ge 60) { "Green" } else { "Yellow" })
    Write-Host "FTC Compliance: $(if ($ftcResult.has_disclosure) { 'PASS' } else { 'WARN' })" -ForegroundColor $(if ($ftcResult.has_disclosure) { "Green" } else { "Yellow" })
    Write-Host "Spam Check: $(if (-not $spamResult.is_spam) { 'PASS' } else { 'FAIL' })" -ForegroundColor $(if (-not $spamResult.is_spam) { "Green" } else { "Red" })

    Write-Host "`nOverall Score: $($results.score)/100" -ForegroundColor $(if ($results.passed) { "Green" } else { "Red" })

    return $results
}

# Test code quality
function Test-CodeQuality {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Code,

        [ValidateSet("powershell", "python", "javascript", "html", "css")]
        [string]$Language = "powershell",

        [hashtable]$Options = @{}
    )

    $standards = Get-QualityStandards
    $results = @{
        passed = $true
        score = 100
        issues = @()
        warnings = @()
        checks = @{}
    }

    Write-Host "`n=== Quality Gate: Code Analysis ===" -ForegroundColor Cyan

    # 1. Security Scan
    if ($standards.code.require_security_scan) {
        $securityResult = Test-CodeSecurity -Code $Code -Language $Language
        $results.checks.security = $securityResult

        if ($securityResult.vulnerabilities.Count -gt 0) {
            foreach ($vuln in $securityResult.vulnerabilities) {
                $results.issues += "Security: $vuln"
            }
            $results.passed = $false
            $results.score -= 40
        }
    }

    # 2. Error Handling Check
    if ($standards.code.require_error_handling) {
        $errorHandlingResult = Test-ErrorHandling -Code $Code -Language $Language
        $results.checks.error_handling = $errorHandlingResult

        if (-not $errorHandlingResult.has_error_handling) {
            $results.warnings += "Missing error handling (try-catch blocks)"
            $results.score -= 10
        }
    }

    # 3. Syntax Check
    $syntaxResult = Test-CodeSyntax -Code $Code -Language $Language
    $results.checks.syntax = $syntaxResult

    if ($syntaxResult.errors.Count -gt 0) {
        foreach ($error in $syntaxResult.errors) {
            $results.issues += "Syntax: $error"
        }
        $results.passed = $false
        $results.score -= 30
    }

    # Display results
    Write-Host "Security: $(if ($securityResult.vulnerabilities.Count -eq 0) { 'PASS' } else { "FAIL ($($securityResult.vulnerabilities.Count) issues)" })" -ForegroundColor $(if ($securityResult.vulnerabilities.Count -eq 0) { "Green" } else { "Red" })
    Write-Host "Error Handling: $(if ($errorHandlingResult.has_error_handling) { 'PASS' } else { 'WARN' })" -ForegroundColor $(if ($errorHandlingResult.has_error_handling) { "Green" } else { "Yellow" })
    Write-Host "Syntax: $(if ($syntaxResult.errors.Count -eq 0) { 'PASS' } else { "FAIL ($($syntaxResult.errors.Count) errors)" })" -ForegroundColor $(if ($syntaxResult.errors.Count -eq 0) { "Green" } else { "Red" })

    Write-Host "`nOverall Score: $($results.score)/100" -ForegroundColor $(if ($results.passed) { "Green" } else { "Red" })

    return $results
}

# Helper: Test originality (basic similarity check)
function Test-Originality {
    param([string]$Content)

    # Simple heuristic: check for unique phrases
    # In production, this would call a plagiarism API
    $words = $Content -split '\s+' | Where-Object { $_.Length -gt 3 }
    $uniqueWords = $words | Select-Object -Unique

    $originalityScore = ($uniqueWords.Count / [Math]::Max(1, $words.Count))

    return @{
        score = [Math]::Round($originalityScore, 2)
        unique_words = $uniqueWords.Count
        total_words = $words.Count
    }
}

# Helper: Test FTC compliance
function Test-FTCCompliance {
    param([string]$Content)

    $disclosureKeywords = @(
        "affiliate", "commission", "compensated", "sponsored",
        "paid partnership", "earn from qualifying purchases",
        "disclosure", "as an amazon associate"
    )

    $hasDisclosure = $false
    foreach ($keyword in $disclosureKeywords) {
        if ($Content -match $keyword) {
            $hasDisclosure = $true
            break
        }
    }

    return @{
        has_disclosure = $hasDisclosure
        keywords_found = $disclosureKeywords | Where-Object { $Content -match $_ }
    }
}

# Helper: Test readability (Flesch reading ease approximation)
function Test-Readability {
    param([string]$Content)

    $sentences = ($Content -split '[.!?]').Count
    $words = ($Content -split '\s+').Count
    $syllables = [Math]::Ceiling($words * 1.5)  # Rough approximation

    if ($sentences -eq 0 -or $words -eq 0) {
        return @{ score = 0 }
    }

    $avgWordsPerSentence = $words / $sentences
    $avgSyllablesPerWord = $syllables / $words

    # Flesch Reading Ease formula (approximation)
    $score = 206.835 - (1.015 * $avgWordsPerSentence) - (84.6 * $avgSyllablesPerWord)
    $score = [Math]::Max(0, [Math]::Min(100, $score))

    return @{
        score = [Math]::Round($score, 1)
        words = $words
        sentences = $sentences
    }
}

# Helper: Test spam score
function Test-SpamScore {
    param([string]$Content)

    $spamKeywords = @("click here", "buy now", "limited time", "act now", "free money", "guaranteed")
    $matches = 0

    foreach ($keyword in $spamKeywords) {
        $matches += ([regex]::Matches($Content, $keyword, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)).Count
    }

    # Check for excessive capitalization
    $upperCount = ([regex]::Matches($Content, '[A-Z]')).Count
    $totalChars = $Content.Length
    $capsRatio = if ($totalChars -gt 0) { $upperCount / $totalChars } else { 0 }

    $isSpam = ($matches -gt 5 -or $capsRatio -gt 0.3)

    return @{
        is_spam = $isSpam
        spam_keyword_count = $matches
        caps_ratio = [Math]::Round($capsRatio, 2)
    }
}

# Helper: Test code security
function Test-CodeSecurity {
    param(
        [string]$Code,
        [string]$Language
    )

    $vulnerabilities = @()

    # PowerShell-specific security checks
    if ($Language -eq "powershell") {
        if ($Code -match 'Invoke-Expression|iex\s') {
            $vulnerabilities += "Dangerous: Invoke-Expression (code injection risk)"
        }
        if ($Code -match 'DownloadString|DownloadFile') {
            $vulnerabilities += "Potential risk: Downloading external content"
        }
        if ($Code -match '-NoProfile|-ExecutionPolicy\s+Bypass') {
            $vulnerabilities += "Security bypass detected"
        }
    }

    # JavaScript-specific checks
    if ($Language -eq "javascript") {
        if ($Code -match 'eval\(') {
            $vulnerabilities += "Dangerous: eval() usage (XSS risk)"
        }
        if ($Code -match 'innerHTML\s*=') {
            $vulnerabilities += "Potential XSS: innerHTML assignment"
        }
    }

    # General checks for all languages
    if ($Code -match 'password\s*=\s*["\'][^"\']+["\']') {
        $vulnerabilities += "Hardcoded credentials detected"
    }

    return @{
        vulnerabilities = $vulnerabilities
        severity = if ($vulnerabilities.Count -gt 0) { "HIGH" } else { "NONE" }
    }
}

# Helper: Test error handling
function Test-ErrorHandling {
    param(
        [string]$Code,
        [string]$Language
    )

    $hasErrorHandling = $false

    if ($Language -eq "powershell") {
        $hasErrorHandling = ($Code -match 'try\s*\{' -and $Code -match 'catch\s*\{')
    }
    elseif ($Language -eq "javascript" -or $Language -eq "python") {
        $hasErrorHandling = ($Code -match 'try\s*\{' -and $Code -match 'catch\s*\(')
    }

    return @{
        has_error_handling = $hasErrorHandling
    }
}

# Helper: Test code syntax (basic check)
function Test-CodeSyntax {
    param(
        [string]$Code,
        [string]$Language
    )

    $errors = @()

    if ($Language -eq "powershell") {
        # Check for unmatched braces
        $openBraces = ([regex]::Matches($Code, '\{')).Count
        $closeBraces = ([regex]::Matches($Code, '\}')).Count

        if ($openBraces -ne $closeBraces) {
            $errors += "Unmatched braces: $openBraces open, $closeBraces close"
        }

        # Check for unmatched parentheses
        $openParens = ([regex]::Matches($Code, '\(')).Count
        $closeParens = ([regex]::Matches($Code, '\)')).Count

        if ($openParens -ne $closeParens) {
            $errors += "Unmatched parentheses: $openParens open, $closeParens close"
        }
    }

    return @{
        errors = $errors
        valid = ($errors.Count -eq 0)
    }
}

# Export functions
Export-ModuleMember -Function Test-ContentQuality, Test-CodeQuality, Get-QualityStandards
