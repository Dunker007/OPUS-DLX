#Requires -Version 7.0

<#
.SYNOPSIS
    LuxRig Authentication System - Integration Test & Demo

.DESCRIPTION
    Tests and demonstrates the complete authentication system:
    - User registration
    - Login/logout
    - JWT tokens
    - 2FA setup
    - Password reset
    - Session management
    - RBAC integration

.NOTES
    Run this to verify auth system is working correctly
#>

# Import modules
$AuthModule = Join-Path $PSScriptRoot "LuxRig/Enterprise/Auth/user-manager.ps1"
$RBACModule = Join-Path $PSScriptRoot "LuxRig/Enterprise/RBAC/permission-system.ps1"

if (-not (Test-Path $AuthModule)) {
    Write-Error "Auth module not found at: $AuthModule"
    exit 1
}

Import-Module $AuthModule -Force
Import-Module $RBACModule -Force -ErrorAction SilentlyContinue

Write-Host "╔════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                                    ║" -ForegroundColor Cyan
Write-Host "║          LUXRIG AUTHENTICATION SYSTEM TEST & DEMO                 ║" -ForegroundColor Cyan
Write-Host "║                                                                    ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Test counter
$script:TestsPassed = 0
$script:TestsFailed = 0

function Test-Function {
    param(
        [string]$Name,
        [scriptblock]$Test
    )

    Write-Host "Testing: $Name" -ForegroundColor Yellow -NoNewline
    try {
        $result = & $Test
        if ($result) {
            Write-Host " ✓ PASSED" -ForegroundColor Green
            $script:TestsPassed++
            return $true
        } else {
            Write-Host " ✗ FAILED" -ForegroundColor Red
            $script:TestsFailed++
            return $false
        }
    }
    catch {
        Write-Host " ✗ ERROR: $_" -ForegroundColor Red
        $script:TestsFailed++
        return $false
    }
}

Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "TEST 1: USER REGISTRATION" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Test 1: Register a user
Test-Function "Register admin user" {
    $result = Register-User -Username "admin" -Email "admin@luxrig.io" -Password "SecurePassword123!" -Role "Admin"
    return $result.success -eq $true
}

Test-Function "Register trader user" {
    $result = Register-User -Username "trader1" -Email "trader1@luxrig.io" -Password "TraderPass456!" -Role "Trader"
    return $result.success -eq $true
}

Test-Function "Register analyst user" {
    $result = Register-User -Username "analyst1" -Email "analyst1@luxrig.io" -Password "AnalystPass789!" -Role "Analyst"
    return $result.success -eq $true
}

Test-Function "Reject duplicate username" {
    $result = Register-User -Username "admin" -Email "admin2@luxrig.io" -Password "SecurePassword123!" -Role "Admin"
    return $result.success -eq $false
}

Test-Function "Reject weak password" {
    $result = Register-User -Username "weakuser" -Email "weak@luxrig.io" -Password "weak" -Role "Trader"
    return $result.success -eq $false
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "TEST 2: USER LOGIN" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Test 2: Login
$script:AdminToken = $null
Test-Function "Admin login with correct password" {
    $result = Invoke-UserLogin -Username "admin" -Password "SecurePassword123!"
    if ($result.success) {
        $script:AdminToken = $result.token
        Write-Host "  Token: $($result.token.Substring(0, 50))..." -ForegroundColor Gray
        return $true
    }
    return $false
}

$script:TraderToken = $null
Test-Function "Trader login with correct password" {
    $result = Invoke-UserLogin -Username "trader1" -Password "TraderPass456!"
    if ($result.success) {
        $script:TraderToken = $result.token
        return $true
    }
    return $false
}

Test-Function "Reject login with wrong password" {
    $result = Invoke-UserLogin -Username "admin" -Password "WrongPassword123!"
    return $result.success -eq $false
}

Test-Function "Reject login for non-existent user" {
    $result = Invoke-UserLogin -Username "nonexistent" -Password "AnyPassword123!"
    return $result.success -eq $false
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "TEST 3: SESSION MANAGEMENT" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Test 3: Sessions
Test-Function "Verify admin session is valid" {
    $session = Test-UserSession -Token $script:AdminToken
    if ($session) {
        Write-Host "  User: $($session.username) | Role: $($session.role)" -ForegroundColor Gray
        return $true
    }
    return $false
}

Test-Function "Verify trader session is valid" {
    $session = Test-UserSession -Token $script:TraderToken
    return $session -ne $null
}

Test-Function "Reject invalid token" {
    $session = Test-UserSession -Token "invalid.token.here"
    return $session -eq $null
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "TEST 4: USER INFORMATION" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Test 4: User info
Test-Function "Get admin user info" {
    $session = Test-UserSession -Token $script:AdminToken
    if ($session) {
        $userInfo = Get-UserInfo -UserId $session.userId
        if ($userInfo) {
            Write-Host "  Username: $($userInfo.username)" -ForegroundColor Gray
            Write-Host "  Email: $($userInfo.email)" -ForegroundColor Gray
            Write-Host "  Role: $($userInfo.role)" -ForegroundColor Gray
            Write-Host "  Created: $($userInfo.created)" -ForegroundColor Gray
            return $true
        }
    }
    return $false
}

Test-Function "List all users (admin function)" {
    $users = Get-AllUsers
    Write-Host "  Total users: $($users.Count)" -ForegroundColor Gray
    foreach ($user in $users) {
        Write-Host "    - $($user.username) ($($user.role))" -ForegroundColor Gray
    }
    return $users.Count -ge 3
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "TEST 5: 2FA (TWO-FACTOR AUTHENTICATION)" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Test 5: 2FA
Test-Function "Enable 2FA for admin user" {
    $session = Test-UserSession -Token $script:AdminToken
    if ($session) {
        $result = Enable-TwoFactor -UserId $session.userId
        if ($result.success) {
            Write-Host "  Secret: $($result.secret)" -ForegroundColor Gray
            Write-Host "  QR Code URL: $($result.qrCodeUrl.Substring(0, 80))..." -ForegroundColor Gray
            $script:Admin2FASecret = $result.secret
            return $true
        }
    }
    return $false
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "TEST 6: PASSWORD RESET" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Test 6: Password reset
$script:ResetToken = $null
Test-Function "Request password reset" {
    $result = Request-PasswordReset -Email "trader1@luxrig.io"
    if ($result.success) {
        $script:ResetToken = $result.resetToken
        Write-Host "  Reset token: $($result.resetToken)" -ForegroundColor Gray
        return $true
    }
    return $false
}

Test-Function "Reset password with valid token" {
    if ($script:ResetToken) {
        $result = Reset-Password -ResetToken $script:ResetToken -NewPassword "NewTraderPass999!"
        return $result.success -eq $true
    }
    return $false
}

Test-Function "Login with new password" {
    $result = Invoke-UserLogin -Username "trader1" -Password "NewTraderPass999!"
    return $result.success -eq $true
}

Test-Function "Old password no longer works" {
    $result = Invoke-UserLogin -Username "trader1" -Password "TraderPass456!"
    return $result.success -eq $false
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "TEST 7: LOGOUT" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Test 7: Logout
Test-Function "Logout admin user" {
    $result = Invoke-UserLogout -Token $script:AdminToken
    return $result.success -eq $true
}

Test-Function "Verify admin session is now invalid" {
    $session = Test-UserSession -Token $script:AdminToken
    return $session -eq $null
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "TEST 8: RBAC INTEGRATION (if available)" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

if (Get-Command Test-Permission -ErrorAction SilentlyContinue) {
    # Login trader again for RBAC tests
    $traderLogin = Invoke-UserLogin -Username "trader1" -Password "NewTraderPass999!"
    $session = Test-UserSession -Token $traderLogin.token

    Test-Function "Trader can execute trades" {
        $canTrade = Test-Permission -UserId $session.userId -Permission "trade.execute.spot" -Context @{ user = $session }
        return $canTrade -eq $true
    }

    Test-Function "Trader cannot manage users" {
        $canManageUsers = Test-Permission -UserId $session.userId -Permission "users.create" -Context @{ user = $session }
        return $canManageUsers -eq $false
    }

    Test-Function "Get all available roles" {
        $roles = Get-AllRoles
        Write-Host "  Available roles: $($roles.Count)" -ForegroundColor Gray
        foreach ($role in $roles) {
            Write-Host "    - $($role.name): $($role.description)" -ForegroundColor Gray
        }
        return $roles.Count -ge 5
    }

    Test-Function "Get trader permissions" {
        $permissions = Get-RolePermissions -RoleName "Trader"
        Write-Host "  Trader has $($permissions.Count) permissions" -ForegroundColor Gray
        return $permissions.Count -gt 0
    }
} else {
    Write-Host "  RBAC module not loaded - skipping integration tests" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "                        TEST SUMMARY                                " -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""

$total = $script:TestsPassed + $script:TestsFailed
$passRate = if ($total -gt 0) { [math]::Round(($script:TestsPassed / $total) * 100, 1) } else { 0 }

Write-Host "  Total Tests:   $total" -ForegroundColor White
Write-Host "  Passed:        $($script:TestsPassed) ✓" -ForegroundColor Green
Write-Host "  Failed:        $($script:TestsFailed) ✗" -ForegroundColor $(if ($script:TestsFailed -eq 0) { "Green" } else { "Red" })
Write-Host "  Pass Rate:     $passRate%" -ForegroundColor $(if ($passRate -ge 80) { "Green" } elseif ($passRate -ge 50) { "Yellow" } else { "Red" })
Write-Host ""

if ($script:TestsFailed -eq 0) {
    Write-Host "🎉 ALL TESTS PASSED! Authentication system is working correctly!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Database files created:" -ForegroundColor Cyan
    Write-Host "  • LuxRig/Data/users.json" -ForegroundColor Gray
    Write-Host "  • LuxRig/Data/sessions.json" -ForegroundColor Gray
    Write-Host "  • LuxRig/Data/permissions.json" -ForegroundColor Gray
    Write-Host ""
    exit 0
} else {
    Write-Host "⚠️  Some tests failed. Please review the output above." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}
