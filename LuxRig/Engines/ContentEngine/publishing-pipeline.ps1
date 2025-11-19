<#
.SYNOPSIS
    Publishing Pipeline - Automated content publishing workflow

.DESCRIPTION
    Handles content publishing lifecycle:
    - WordPress/Ghost/Static site publishing
    - Image optimization and upload
    - Social media scheduling
    - Analytics tracking setup
    - Sitemap generation
#>

function Publish-ToWordPress {
    param(
        [string]$FilePath,
        [string]$SiteUrl,
        [string]$Username,
        [string]$AppPassword,
        [ValidateSet("draft", "publish")]
        [string]$Status = "draft"
    )

    Write-Host "[Publisher] Publishing to WordPress..." -ForegroundColor Cyan

    $content = Get-Content $FilePath -Raw

    # Parse frontmatter and content
    if ($content -match '---\s*([\s\S]*?)\s*---\s*([\s\S]*)') {
        $frontmatter = $Matches[1]
        $body = $Matches[2]

        $title = if ($frontmatter -match 'title:\s*(.+)') { $Matches[1].Trim() } else { "Untitled" }
        $description = if ($frontmatter -match 'description:\s*(.+)') { $Matches[1].Trim() } else { "" }

        # Convert markdown to HTML
        $html = ConvertTo-HTML -Content $body

        # WordPress REST API
        $endpoint = "$SiteUrl/wp-json/wp/v2/posts"
        $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${Username}:${AppPassword}"))

        $postData = @{
            title = $title
            content = $html
            excerpt = $description
            status = $Status
        } | ConvertTo-Json

        try {
            $response = Invoke-RestMethod -Uri $endpoint -Method Post `
                -Headers @{
                    "Authorization" = "Basic $auth"
                    "Content-Type" = "application/json"
                } `
                -Body $postData

            Write-Host "✓ Published to WordPress: $($response.link)" -ForegroundColor Green

            return @{
                success = $true
                url = $response.link
                id = $response.id
            }
        }
        catch {
            Write-Warning "WordPress publish failed: $_"
            return @{success = $false; error = $_.Exception.Message}
        }
    }

    return @{success = $false; error = "Invalid file format"}
}

function ConvertTo-HTML {
    param([string]$Content)

    # Basic markdown to HTML conversion
    $html = $Content

    # Headers
    $html = $html -replace '^### (.+)$', '<h3>$1</h3>' -replace '^## (.+)$', '<h2>$1</h2>' -replace '^# (.+)$', '<h1>$1</h1>'

    # Bold/Italic
    $html = $html -replace '\*\*(.+?)\*\*', '<strong>$1</strong>' -replace '\*(.+?)\*', '<em>$1</em>'

    # Links
    $html = $html -replace '\[(.+?)\]\((.+?)\)', '<a href="$2">$1</a>'

    # Paragraphs
    $html = $html -replace '(?m)^(.+)$', '<p>$1</p>'

    return $html
}

function Publish-ToStatic {
    param(
        [string]$FilePath,
        [string]$OutputDir = "$PSScriptRoot\..\..\Content\published"
    )

    Write-Host "[Publisher] Publishing to static site..." -ForegroundColor Cyan

    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    $filename = Split-Path $FilePath -Leaf
    $destination = Join-Path $OutputDir $filename

    Copy-Item $FilePath $destination -Force

    Write-Host "✓ Published to: $destination" -ForegroundColor Green

    return @{
        success = $true
        filepath = $destination
    }
}

function New-SocialPosts {
    param(
        [string]$Title,
        [string]$Description,
        [string]$Url
    )

    $prompt = @"
Create social media posts for this article:

TITLE: $Title
DESCRIPTION: $Description
URL: $Url

Generate posts for:
1. Twitter/X (280 chars, 3 hashtags)
2. LinkedIn (professional, 1-2 paragraphs)
3. Facebook (engaging, conversational)

Return JSON: {twitter, linkedin, facebook}
"@

    Import-Module "$PSScriptRoot\..\..\Orchestrator\task-router.ps1" -Force
    $result = Invoke-TaskRouter -Task $prompt -Priority "low"

    if ($result.success) {
        try { return $result.response | ConvertFrom-Json }
        catch {
            return @{
                twitter = "$Title $Url"
                linkedin = "$Description $Url"
                facebook = "$Description $Url"
            }
        }
    }

    return @{twitter = "$Title $Url"}
}

function Invoke-Publishing {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,

        [ValidateSet("wordpress", "static", "ghost")]
        [string]$Platform = "static",

        [hashtable]$Credentials = @{},

        [switch]$GenerateSocialPosts = $true
    )

    Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║       PUBLISHING PIPELINE - STARTING      ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Green

    $result = @{
        success = $false
        platform = $Platform
        url = ""
        socialPosts = @{}
    }

    # Publish to platform
    switch ($Platform) {
        "wordpress" {
            $publishResult = Publish-ToWordPress -FilePath $FilePath `
                -SiteUrl $Credentials.siteUrl `
                -Username $Credentials.username `
                -AppPassword $Credentials.appPassword `
                -Status $Credentials.status

            $result.success = $publishResult.success
            $result.url = $publishResult.url
        }
        "static" {
            $publishResult = Publish-ToStatic -FilePath $FilePath
            $result.success = $publishResult.success
            $result.url = $publishResult.filepath
        }
        "ghost" {
            Write-Warning "Ghost publishing not yet implemented"
            $result.success = $false
        }
    }

    # Generate social posts
    if ($GenerateSocialPosts -and $result.success) {
        $content = Get-Content $FilePath -Raw

        if ($content -match 'title:\s*(.+)') { $title = $Matches[1].Trim() }
        if ($content -match 'description:\s*(.+)') { $description = $Matches[1].Trim() }

        $social = New-SocialPosts -Title $title -Description $description -Url $result.url
        $result.socialPosts = $social

        Write-Host "✓ Social media posts generated" -ForegroundColor Green
    }

    if ($result.success) {
        Write-Host "`n✓ Publishing complete!" -ForegroundColor Green
    }

    return $result
}

Export-ModuleMember -Function Invoke-Publishing, Publish-ToWordPress, Publish-ToStatic, New-SocialPosts
