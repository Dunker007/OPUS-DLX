# ============================================================================
# LuxRig Cloud Deployment Script
# VPS setup, Docker deployment, and HTTPS configuration
# ============================================================================

param(
    [Parameter(Mandatory)]
    [string]$ServerIP,

    [string]$SSHUser = 'root',

    [string]$Domain,

    [switch]$SetupHTTPS
)

Write-Host "🚀 LuxRig Cloud Deployment" -ForegroundColor Cyan
Write-Host "   Server: $ServerIP" -ForegroundColor White
Write-Host "   User: $SSHUser" -ForegroundColor White

# Generate deployment script
$deployScript = @"
#!/bin/bash
set -e

echo "📦 Installing dependencies..."
apt-get update
apt-get install -y docker.io docker-compose git curl

echo "🐳 Starting Docker..."
systemctl start docker
systemctl enable docker

echo "📥 Cloning LuxRig..."
cd /opt
if [ -d "LuxRig" ]; then
    cd LuxRig
    git pull
else
    git clone https://github.com/yourusername/LuxRig.git
    cd LuxRig
fi

echo "🔧 Setting up environment..."
mkdir -p Data Logs Configs

echo "🏗️  Building Docker images..."
docker-compose build

echo "🚀 Starting LuxRig..."
docker-compose up -d

echo "✅ Deployment complete!"
docker-compose ps

echo "📊 LuxRig is running at http://$ServerIP:8080"
"@

# Save deployment script
$deployScript | Out-File -FilePath "$PSScriptRoot/remote-deploy.sh" -Encoding UTF8

Write-Host "`n✅ Deployment script generated: remote-deploy.sh" -ForegroundColor Green
Write-Host "`nTo deploy, run:" -ForegroundColor Yellow
Write-Host "  scp deploy/remote-deploy.sh $SSHUser@${ServerIP}:/tmp/" -ForegroundColor White
Write-Host "  ssh $SSHUser@$ServerIP 'bash /tmp/remote-deploy.sh'" -ForegroundColor White

if ($SetupHTTPS -and $Domain) {
    Write-Host "`n🔒 HTTPS Setup (after deployment):" -ForegroundColor Yellow
    Write-Host "  ssh $SSHUser@$ServerIP" -ForegroundColor White
    Write-Host "  apt-get install -y certbot python3-certbot-nginx" -ForegroundColor White
    Write-Host "  certbot --nginx -d $Domain" -ForegroundColor White
}

Write-Host "`n📝 Post-Deployment Steps:" -ForegroundColor Yellow
Write-Host "  1. Configure API keys via secrets manager" -ForegroundColor White
Write-Host "  2. Update configs for production" -ForegroundColor White
Write-Host "  3. Set up monitoring and alerts" -ForegroundColor White
Write-Host "  4. Configure backups" -ForegroundColor White
Write-Host "  5. Test all components" -ForegroundColor White
