#Requires -Version 7.0

<#
.SYNOPSIS
    LuxRig White-Label Branding Engine

.DESCRIPTION
    Complete brand customization system for selling LuxRig as your own product:
    - Custom colors, logos, fonts
    - Custom domain configuration
    - Email template branding
    - App rebranding (mobile, desktop)
    - Multi-tenant brand isolation

.NOTES
    Part of LuxRig Enterprise White-Label Edition
    Transform LuxRig into YOUR branded product
#>

$script:Config = @{
    DatabasePath = "$PSScriptRoot/../../Data/brands.json"
    AssetsPath = "$PSScriptRoot/../../Assets"
    DefaultBrand = "LuxRig"
}

$script:Brands = @{}

function Initialize-BrandingEngine {
    try {
        # Create directories
        foreach ($dir in @($script:Config.AssetsPath, "$($script:Config.AssetsPath)/logos", "$($script:Config.AssetsPath)/themes")) {
            if (-not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
        }

        # Load brands
        if (Test-Path $script:Config.DatabasePath) {
            $data = Get-Content $script:Config.DatabasePath | ConvertFrom-Json
            $script:Brands = @{}
            foreach ($brand in $data) {
                $script:Brands[$brand.brandId] = $brand
            }
            Write-Host "[Branding] Loaded $($script:Brands.Count) brand configurations" -ForegroundColor Green
        }

        # Ensure default brand exists
        if (-not $script:Brands.Values | Where-Object { $_.name -eq $script:Config.DefaultBrand }) {
            New-Brand -Name $script:Config.DefaultBrand -IsDefault $true | Out-Null
        }
    }
    catch {
        Write-Warning "[Branding] Initialization error: $_"
    }
}

function Save-BrandDatabase {
    try {
        $script:Brands.Values | ConvertTo-Json -Depth 10 | Out-File $script:Config.DatabasePath -Force
    }
    catch {
        Write-Warning "[Branding] Save error: $_"
    }
}

function New-Brand {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [string]$TenantId = $null,
        [bool]$IsDefault = $false
    )

    $brandId = [guid]::NewGuid().ToString()

    $brand = @{
        brandId = $brandId
        tenantId = $TenantId
        name = $Name
        isDefault = $IsDefault
        created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        # Visual identity
        colors = @{
            primary = "#6366F1"       # Indigo
            secondary = "#8B5CF6"     # Purple
            accent = "#EC4899"        # Pink
            success = "#10B981"       # Green
            warning = "#F59E0B"       # Amber
            danger = "#EF4444"        # Red
            background = "#FFFFFF"    # White
            surface = "#F3F4F6"       # Gray 100
            text = "#111827"          # Gray 900
            textSecondary = "#6B7280" # Gray 500
        }

        # Typography
        typography = @{
            fontFamily = "Inter, system-ui, -apple-system, sans-serif"
            headingFont = "Inter, sans-serif"
            monoFont = "JetBrains Mono, monospace"
            baseFontSize = "16px"
            scaleRatio = 1.25  # Type scale
        }

        # Logos
        logos = @{
            main = $null         # Main logo (light background)
            dark = $null         # Dark theme logo
            icon = $null         # App icon/favicon
            email = $null        # Email header logo
        }

        # Domain & URLs
        domain = @{
            primary = "luxrig.io"
            app = "app.luxrig.io"
            api = "api.luxrig.io"
            docs = "docs.luxrig.io"
        }

        # Email branding
        email = @{
            fromName = $Name
            fromEmail = "noreply@luxrig.io"
            replyTo = "support@luxrig.io"
            footerText = "© 2025 $Name. All rights reserved."
            supportLink = "https://luxrig.io/support"
            unsubscribeLink = "https://luxrig.io/unsubscribe"
        }

        # App metadata
        app = @{
            name = $Name
            shortName = $Name
            description = "AI-Powered Autonomous Wealth Generation Platform"
            keywords = @("crypto", "trading", "automation", "AI")
            copyright = "© 2025 $Name"
        }

        # Social links
        social = @{
            twitter = $null
            linkedin = $null
            github = $null
            discord = $null
            telegram = $null
        }

        # Custom CSS
        customCSS = ""

        # Custom JavaScript
        customJS = ""
    }

    $script:Brands[$brandId] = $brand
    Save-BrandDatabase

    Write-Host "[Branding] Brand created: $Name" -ForegroundColor Green
    return @{ success = $true; brandId = $brandId; brand = $brand }
}

function Update-BrandColors {
    param(
        [Parameter(Mandatory)]
        [string]$BrandId,

        [hashtable]$Colors
    )

    $brand = $script:Brands[$BrandId]
    if (-not $brand) {
        return @{ success = $false; error = "Brand not found" }
    }

    foreach ($key in $Colors.Keys) {
        if ($brand.colors.ContainsKey($key)) {
            $brand.colors[$key] = $Colors[$key]
        }
    }

    $brand.modified = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Save-BrandDatabase

    Write-Host "[Branding] Colors updated for: $($brand.name)" -ForegroundColor Yellow
    return @{ success = $true; colors = $brand.colors }
}

function Set-BrandLogo {
    param(
        [Parameter(Mandatory)]
        [string]$BrandId,

        [Parameter(Mandatory)]
        [ValidateSet("main", "dark", "icon", "email")]
        [string]$LogoType,

        [Parameter(Mandatory)]
        [string]$FilePath
    )

    $brand = $script:Brands[$BrandId]
    if (-not $brand) {
        return @{ success = $false; error = "Brand not found" }
    }

    if (-not (Test-Path $FilePath)) {
        return @{ success = $false; error = "Logo file not found" }
    }

    # Copy logo to assets
    $extension = [System.IO.Path]::GetExtension($FilePath)
    $targetPath = Join-Path $script:Config.AssetsPath "logos/$BrandId-$LogoType$extension"
    Copy-Item -Path $FilePath -Destination $targetPath -Force

    $brand.logos[$LogoType] = $targetPath
    $brand.modified = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Save-BrandDatabase

    Write-Host "[Branding] Logo uploaded: $LogoType for $($brand.name)" -ForegroundColor Green
    return @{ success = $true; path = $targetPath }
}

function Update-BrandDomain {
    param(
        [Parameter(Mandatory)]
        [string]$BrandId,

        [hashtable]$Domain
    )

    $brand = $script:Brands[$BrandId]
    if (-not $brand) {
        return @{ success = $false; error = "Brand not found" }
    }

    foreach ($key in $Domain.Keys) {
        if ($brand.domain.ContainsKey($key)) {
            $brand.domain[$key] = $Domain[$key]
        }
    }

    $brand.modified = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Save-BrandDatabase

    return @{ success = $true; domain = $brand.domain }
}

function Update-EmailBranding {
    param(
        [Parameter(Mandatory)]
        [string]$BrandId,

        [hashtable]$EmailConfig
    )

    $brand = $script:Brands[$BrandId]
    if (-not $brand) {
        return @{ success = $false; error = "Brand not found" }
    }

    foreach ($key in $EmailConfig.Keys) {
        if ($brand.email.ContainsKey($key)) {
            $brand.email[$key] = $EmailConfig[$key]
        }
    }

    $brand.modified = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Save-BrandDatabase

    return @{ success = $true; email = $brand.email }
}

function Get-BrandCSS {
    param(
        [Parameter(Mandatory)]
        [string]$BrandId
    )

    $brand = $script:Brands[$BrandId]
    if (-not $brand) { return "" }

    $css = @"
/* $($brand.name) Brand Styles */
:root {
    /* Colors */
    --color-primary: $($brand.colors.primary);
    --color-secondary: $($brand.colors.secondary);
    --color-accent: $($brand.colors.accent);
    --color-success: $($brand.colors.success);
    --color-warning: $($brand.colors.warning);
    --color-danger: $($brand.colors.danger);
    --color-background: $($brand.colors.background);
    --color-surface: $($brand.colors.surface);
    --color-text: $($brand.colors.text);
    --color-text-secondary: $($brand.colors.textSecondary);

    /* Typography */
    --font-family: $($brand.typography.fontFamily);
    --font-heading: $($brand.typography.headingFont);
    --font-mono: $($brand.typography.monoFont);
    --font-size-base: $($brand.typography.baseFontSize);
}

/* Custom CSS */
$($brand.customCSS)
"@

    return $css
}

function Get-BrandedEmailTemplate {
    param(
        [Parameter(Mandatory)]
        [string]$BrandId,

        [Parameter(Mandatory)]
        [string]$TemplateType,

        [hashtable]$Variables = @{}
    )

    $brand = $script:Brands[$BrandId]
    if (-not $brand) {
        return @{ success = $false; error = "Brand not found" }
    }

    $templates = @{
        welcome = @"
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: $($brand.typography.fontFamily); color: $($brand.colors.text); }
        .header { background: $($brand.colors.primary); color: white; padding: 20px; text-align: center; }
        .content { padding: 30px; }
        .footer { background: $($brand.colors.surface); padding: 20px; text-align: center; font-size: 12px; color: $($brand.colors.textSecondary); }
        .button { background: $($brand.colors.primary); color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Welcome to $($brand.name)!</h1>
    </div>
    <div class="content">
        <p>Hi {{username}},</p>
        <p>Thank you for joining $($brand.name). Your account is now active!</p>
        <p><a href="{{loginUrl}}" class="button">Get Started</a></p>
    </div>
    <div class="footer">
        <p>$($brand.email.footerText)</p>
        <p><a href="$($brand.email.supportLink)">Support</a> | <a href="$($brand.email.unsubscribeLink)">Unsubscribe</a></p>
    </div>
</body>
</html>
"@

        passwordReset = @"
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: $($brand.typography.fontFamily); color: $($brand.colors.text); }
        .header { background: $($brand.colors.primary); color: white; padding: 20px; text-align: center; }
        .content { padding: 30px; }
        .button { background: $($brand.colors.primary); color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block; }
        .footer { background: $($brand.colors.surface); padding: 20px; text-align: center; font-size: 12px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Password Reset</h1>
    </div>
    <div class="content">
        <p>Hi {{username}},</p>
        <p>We received a request to reset your password.</p>
        <p><a href="{{resetUrl}}" class="button">Reset Password</a></p>
        <p>This link expires in 1 hour. If you didn't request this, please ignore this email.</p>
    </div>
    <div class="footer">
        <p>$($brand.email.footerText)</p>
    </div>
</body>
</html>
"@

        tradeAlert = @"
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: $($brand.typography.fontFamily); color: $($brand.colors.text); }
        .header { background: $($brand.colors.primary); color: white; padding: 20px; }
        .content { padding: 30px; }
        .trade-box { background: $($brand.colors.surface); padding: 15px; border-radius: 8px; margin: 15px 0; }
        .profit { color: $($brand.colors.success); font-weight: bold; }
        .loss { color: $($brand.colors.danger); font-weight: bold; }
    </style>
</head>
<body>
    <div class="header">
        <h2>Trade Executed</h2>
    </div>
    <div class="content">
        <div class="trade-box">
            <p><strong>Symbol:</strong> {{symbol}}</p>
            <p><strong>Side:</strong> {{side}}</p>
            <p><strong>Amount:</strong> {{amount}}</p>
            <p><strong>Price:</strong> {{price}}</p>
            <p><strong>P&L:</strong> <span class="{{pnlClass}}">{{pnl}}</span></p>
        </div>
        <p><a href="{{dashboardUrl}}">View Dashboard</a></p>
    </div>
</body>
</html>
"@
    }

    $template = $templates[$TemplateType]
    if (-not $template) {
        return @{ success = $false; error = "Template not found" }
    }

    # Replace variables
    foreach ($key in $Variables.Keys) {
        $template = $template -replace "{{$key}}", $Variables[$key]
    }

    return @{ success = $true; html = $template }
}

function Get-Brand {
    param(
        [Parameter(Mandatory)]
        [string]$BrandId
    )

    return $script:Brands[$BrandId]
}

function Get-AllBrands {
    return $script:Brands.Values | ForEach-Object {
        @{
            brandId = $_.brandId
            name = $_.name
            tenantId = $_.tenantId
            isDefault = $_.isDefault
            created = $_.created
            primaryColor = $_.colors.primary
            domain = $_.domain.primary
        }
    }
}

function Export-BrandAssets {
    param(
        [Parameter(Mandatory)]
        [string]$BrandId,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    $brand = $script:Brands[$BrandId]
    if (-not $brand) {
        return @{ success = $false; error = "Brand not found" }
    }

    # Create output directory
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    # Export CSS
    $css = Get-BrandCSS -BrandId $BrandId
    $css | Out-File (Join-Path $OutputPath "brand.css") -Force

    # Export JSON config
    $brand | ConvertTo-Json -Depth 10 | Out-File (Join-Path $OutputPath "brand.json") -Force

    # Copy logos
    foreach ($logoType in $brand.logos.Keys) {
        $logoPath = $brand.logos[$logoType]
        if ($logoPath -and (Test-Path $logoPath)) {
            Copy-Item -Path $logoPath -Destination (Join-Path $OutputPath "logo-$logoType$($(Get-Item $logoPath).Extension)") -Force
        }
    }

    Write-Host "[Branding] Assets exported to: $OutputPath" -ForegroundColor Green
    return @{ success = $true; path = $OutputPath }
}

Initialize-BrandingEngine

Export-ModuleMember -Function @(
    'New-Brand',
    'Update-BrandColors',
    'Set-BrandLogo',
    'Update-BrandDomain',
    'Update-EmailBranding',
    'Get-BrandCSS',
    'Get-BrandedEmailTemplate',
    'Get-Brand',
    'Get-AllBrands',
    'Export-BrandAssets'
)
