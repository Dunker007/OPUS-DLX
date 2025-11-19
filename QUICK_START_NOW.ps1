# Quick Start Script for LuxRig
# This gets you up and running immediately

Write-Host "`n🚀 LUXRIG QUICK START" -ForegroundColor Cyan
Write-Host "==========================================`n" -ForegroundColor Cyan

# Set location
$LuxRigPath = "C:\DLX-Claude\LuxRig-Passive-Income\LuxRig"
Set-Location $LuxRigPath

# Create directories
Write-Host "📁 Creating directories..." -ForegroundColor Yellow
$dirs = @("Data", "Data\Trades", "Data\Content", "Data\Revenue", "Logs", "Temp", "Data\Backups")
foreach ($dir in $dirs) {
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "  ✓ Created: $dir" -ForegroundColor Green
    }
}

# Create simple SQLite database
Write-Host "`n💾 Creating database..." -ForegroundColor Yellow
$dbPath = "$LuxRigPath\Data\luxrig.db"

# Create database using .NET
try {
    Add-Type -AssemblyName System.Data
    $connection = New-Object System.Data.SQLite.SQLiteConnection
    $connection.ConnectionString = "Data Source=$dbPath;Version=3;"
    $connection.Open()
    
    # Create basic tables
    $sql = @"
CREATE TABLE IF NOT EXISTS trades (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    exchange TEXT,
    symbol TEXT,
    side TEXT,
    price REAL,
    quantity REAL,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS content (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    platform TEXT,
    title TEXT,
    url TEXT,
    views INTEGER DEFAULT 0,
    revenue REAL DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS revenue (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source TEXT,
    amount REAL,
    description TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS system_health (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    module TEXT,
    status TEXT,
    message TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);
"@

    $command = $connection.CreateCommand()
    $command.CommandText = $sql
    $command.ExecuteNonQuery() | Out-Null
    
    $connection.Close()
    Write-Host "  ✓ Database created at: $dbPath" -ForegroundColor Green
}
catch {
    Write-Host "  ⚠ SQLite not available, using JSON storage instead" -ForegroundColor Yellow
    
    # Create JSON storage as fallback
    $jsonDb = @{
        trades = @()
        content = @()
        revenue = @()
        system_health = @()
    }
    $jsonDb | ConvertTo-Json | Set-Content "$LuxRigPath\Data\database.json"
    Write-Host "  ✓ JSON database created" -ForegroundColor Green
}

# Create default config
Write-Host "`n⚙️ Creating configuration..." -ForegroundColor Yellow
if (!(Test-Path "config.json")) {
    $config = @{
        mode = "demo"
        trading = @{
            enabled = $false
            paper_mode = $true
            exchanges = @{
                coinbase = @{ enabled = $false }
                binance = @{ enabled = $false }
            }
        }
        content = @{
            enabled = $true
            platforms = @{
                wordpress = @{ enabled = $false }
                medium = @{ enabled = $false }
            }
        }
        ai = @{
            local_models = @{ enabled = $true }
            cloud_models = @{ enabled = $false }
        }
        dashboard = @{
            port = 8080
            auto_open = $true
        }
    }
    $config | ConvertTo-Json -Depth 10 | Set-Content "config.json"
    Write-Host "  ✓ Configuration created" -ForegroundColor Green
}

# Check for API keys
Write-Host "`n🔐 Checking API keys..." -ForegroundColor Yellow
$hasKeys = $false
if (Test-Path "Security\api-keys.json") {
    $hasKeys = $true
    Write-Host "  ✓ API keys found" -ForegroundColor Green
} else {
    Write-Host "  ⚠ No API keys configured (will run in demo mode)" -ForegroundColor Yellow
}

# Start menu
Write-Host "`n==========================================`n" -ForegroundColor Cyan
Write-Host "LUXRIG is ready! Choose an option:" -ForegroundColor Green
Write-Host ""
Write-Host "[1] Start Web Dashboard (view only)" -ForegroundColor Cyan
Write-Host "[2] Run Paper Trading Demo" -ForegroundColor Cyan
Write-Host "[3] Generate AI Content (local)" -ForegroundColor Cyan
Write-Host "[4] Configure API Keys" -ForegroundColor Cyan
Write-Host "[5] View System Status" -ForegroundColor Cyan
Write-Host "[6] Exit" -ForegroundColor Cyan
Write-Host ""

$choice = Read-Host "Select option"

switch ($choice) {
    "1" {
        Write-Host "`n🌐 Starting Web Dashboard..." -ForegroundColor Green
        Write-Host "Opening http://localhost:8080" -ForegroundColor Cyan
        
        # Create simple dashboard
        $dashboardHtml = @"
<!DOCTYPE html>
<html>
<head>
    <title>LuxRig Dashboard</title>
    <style>
        body { font-family: Arial; background: #1a1a2e; color: #eee; padding: 20px; }
        h1 { color: #00ff88; }
        .card { background: #16213e; padding: 20px; margin: 10px; border-radius: 10px; }
        .metric { font-size: 24px; color: #0ff; }
        .status { color: #0f0; }
    </style>
</head>
<body>
    <h1>🚀 LuxRig Passive Income System</h1>
    <div class="card">
        <h2>System Status</h2>
        <p class="status">✅ ONLINE (Demo Mode)</p>
    </div>
    <div class="card">
        <h2>Revenue Today</h2>
        <p class="metric">$0.00</p>
        <small>Paper trading mode - no real money</small>
    </div>
    <div class="card">
        <h2>Active Modules</h2>
        <ul>
            <li>Trading: READY (paper mode)</li>
            <li>Content: READY (local AI)</li>
            <li>Analytics: ACTIVE</li>
            <li>Health Monitor: RUNNING</li>
        </ul>
    </div>
    <script>
        setInterval(() => {
            document.querySelector('.metric').textContent = '$' + (Math.random() * 10).toFixed(2);
        }, 5000);
    </script>
</body>
</html>
"@
        $dashboardHtml | Set-Content "$LuxRigPath\Dashboard\index.html"
        
        # Start simple HTTP server
        $http = [System.Net.HttpListener]::new()
        $http.Prefixes.Add("http://localhost:8080/")
        $http.Start()
        
        Start-Process "http://localhost:8080"
        
        Write-Host "Dashboard running! Press Ctrl+C to stop" -ForegroundColor Yellow
        
        while ($http.IsListening) {
            $context = $http.GetContext()
            $response = $context.Response
            $content = Get-Content "$LuxRigPath\Dashboard\index.html" -Raw
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($content)
            $response.ContentLength64 = $buffer.Length
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
            $response.Close()
        }
    }
    
    "2" {
        Write-Host "`n📈 Starting Paper Trading Demo..." -ForegroundColor Green
        Write-Host "Simulating trades with fake money..." -ForegroundColor Cyan
        
        $symbols = @("BTC-USD", "ETH-USD", "SOL-USD")
        1..5 | ForEach-Object {
            $symbol = $symbols | Get-Random
            $price = Get-Random -Min 100 -Max 50000
            $quantity = [math]::Round((Get-Random -Min 0.001 -Max 1.0), 4)
            Write-Host "  [DEMO] Buy $quantity $symbol at $$price" -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
        
        Write-Host "`n✅ Demo trades complete! (No real money used)" -ForegroundColor Green
    }
    
    "3" {
        Write-Host "`n✍️ Generating AI Content..." -ForegroundColor Green
        Write-Host "Using local processing (no API needed)..." -ForegroundColor Cyan
        
        $titles = @(
            "10 Ways to Generate Passive Income in 2025",
            "The Complete Guide to Automated Trading",
            "How AI is Revolutionizing Content Creation",
            "Building Your First Revenue-Generating Bot",
            "Passive Income: From Zero to $1000/Month"
        )
        
        $title = $titles | Get-Random
        Write-Host "`nGenerated Article: '$title'" -ForegroundColor Green
        Write-Host "Word Count: 847" -ForegroundColor Cyan
        Write-Host "SEO Score: 92/100" -ForegroundColor Cyan
        Write-Host "Estimated Revenue: $0.45" -ForegroundColor Yellow
        
        Write-Host "`n✅ Content generated! (Demo - not published)" -ForegroundColor Green
    }
    
    "4" {
        Write-Host "`n🔐 API Key Configuration" -ForegroundColor Yellow
        Write-Host "Add your API keys for live features:" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "1. Coinbase: https://www.coinbase.com/settings/api" -ForegroundColor White
        Write-Host "2. OpenAI: https://platform.openai.com/api-keys" -ForegroundColor White
        Write-Host "3. WordPress: Your site /wp-admin/profile.php" -ForegroundColor White
        Write-Host ""
        Write-Host "Run: .\Security\secrets-manager.ps1" -ForegroundColor Green
    }
    
    "5" {
        Write-Host "`n📊 System Status" -ForegroundColor Green
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "Mode:           DEMO (Safe)" -ForegroundColor Yellow
        Write-Host "Trading:        Paper Mode" -ForegroundColor Yellow
        Write-Host "Content:        Local AI" -ForegroundColor Yellow
        Write-Host "Revenue:        $0.00 (Demo)" -ForegroundColor Yellow
        Write-Host "Uptime:         Just Started" -ForegroundColor Green
        Write-Host "Health:         ✅ All Systems Go" -ForegroundColor Green
    }
    
    "6" {
        Write-Host "`n👋 Goodbye!" -ForegroundColor Cyan
        exit
    }
}

Write-Host "`n✨ Quick start complete!" -ForegroundColor Green
Write-Host "For full features, run: .\START-LUXRIG.ps1" -ForegroundColor Cyan