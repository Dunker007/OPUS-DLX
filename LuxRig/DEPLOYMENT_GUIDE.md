# 🚀 LuxRig Complete Deployment Guide

## **From Zero to Autonomous Passive Income in 30 Minutes**

---

## 📋 Prerequisites

### **Required**
- Windows 11 Server (LuxRig)
- PowerShell 5.1 or later
- Internet connection
- Git installed

### **API Keys Needed**
- **Anthropic** (Claude): https://console.anthropic.com/
- **OpenAI** (GPT-4): https://platform.openai.com/
- **Google AI** (Gemini): https://makersuite.google.com/
- **Stripe** (Billing): https://stripe.com/
- **Resend** (Email): https://resend.com/ (or AWS SES)

### **Optional (Recommended)**
- **Ollama** or **LM Studio** for local/free AI processing
- **Vercel/Netlify CLI** for automated deployments
- **Twitter API** for social posting
- **LinkedIn API** for professional networking

---

## ⚡ Quick Start (30 Minutes)

### **Step 1: Clone & Deploy (5 min)**

```powershell
# On LuxRig server, open PowerShell as Administrator

# Clone repository
cd C:\
git clone https://github.com/Dunker007/OPUS-DLX.git
cd OPUS-DLX

# Checkout the complete build branch
git checkout claude/build-phase-1-foundation-016PXJabGHeCPpTRL1FanGH3

# Deploy to C:\LuxRig\
Copy-Item -Path ".\LuxRig" -Destination "C:\" -Recurse -Force

# Verify deployment
Test-Path C:\LuxRig\Orchestrator\master-orchestrator.ps1
```

### **Step 2: Configure API Keys (10 min)**

```powershell
cd C:\LuxRig\Configs

# Copy template
Copy-Item api-keys.json.template api-keys.json

# Edit with your keys
notepad api-keys.json
```

**Add your actual API keys:**

```json
{
  "anthropic_api_key": "sk-ant-api03-YOUR_REAL_KEY_HERE",
  "openai_api_key": "sk-YOUR_REAL_KEY_HERE",
  "google_ai_api_key": "AIzaYOUR_REAL_KEY_HERE",
  "xai_api_key": "xai-YOUR_KEY_HERE",

  "stripe": {
    "secret_key": "sk_test_YOUR_STRIPE_KEY",
    "publishable_key": "pk_test_YOUR_STRIPE_KEY",
    "webhook_secret": "whsec_YOUR_WEBHOOK_SECRET"
  },

  "resend_api_key": "re_YOUR_RESEND_KEY",

  "reddit": {
    "client_id": "YOUR_REDDIT_CLIENT",
    "client_secret": "YOUR_REDDIT_SECRET"
  }
}
```

**Set environment variables (alternative to file):**

```powershell
[System.Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY", "sk-ant-...", "User")
[System.Environment]::SetEnvironmentVariable("OPENAI_API_KEY", "sk-...", "User")
[System.Environment]::SetEnvironmentVariable("GOOGLE_AI_API_KEY", "AIza...", "User")
[System.Environment]::SetEnvironmentVariable("STRIPE_SECRET_KEY", "sk_test...", "User")
[System.Environment]::SetEnvironmentVariable("RESEND_API_KEY", "re_...", "User")
```

### **Step 3: Install Local Models (Optional, 5 min)**

**Option A: Ollama (Recommended)**

```powershell
# Download from https://ollama.ai/download
# Or use winget:
winget install Ollama.Ollama

# Pull a model
ollama pull llama2
ollama pull mistral

# Verify
Invoke-RestMethod -Uri "http://localhost:11434/api/tags"
```

**Option B: LM Studio**

1. Download from https://lmstudio.ai/
2. Install and load a model (Mistral 7B recommended)
3. Start local server on port 1234

### **Step 4: Run Tests (5 min)**

```powershell
cd C:\LuxRig\Tests

# Run comprehensive test suite
.\test-phase1.ps1

# Expected output: "✓ All tests passed! Phase 1 foundation is ready."
```

**If tests fail:**
- Check API keys are correct
- Verify file paths
- Ensure PowerShell execution policy: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

### **Step 5: Start the System (5 min)**

**Option A: Single Test Cycle**

```powershell
cd C:\LuxRig\Orchestrator

# Run one complete cycle
.\master-orchestrator.ps1 -Mode "test"
```

**Option B: Continuous Autonomous Mode**

```powershell
# Run forever (every hour)
.\master-orchestrator.ps1 -Mode "auto" -Interval 3600 -Continuous
```

**Option C: Monitor Dashboard**

```powershell
cd C:\LuxRig\Analytics

# Real-time monitoring (refreshes every 10 seconds)
.\dashboard.ps1 -Continuous -RefreshInterval 10
```

---

## 🔧 Advanced Configuration

### **Adjust AI Budgets**

Edit `C:\LuxRig\Configs\budget-rules.yaml`:

```yaml
# Switch spending mode
active_mode: growth  # Options: bootstrapper, growth, blitzkrieg

# Custom per-model budgets
model_limits:
  claude:
    monthly_max: 150  # Increase Claude budget

  gpt4:
    monthly_max: 100

  gemini:
    monthly_max: 50

  local:
    monthly_max: 0  # Always free
```

### **Quality Standards**

Edit `C:\LuxRig\Configs\quality-standards.json`:

```json
{
  "content": {
    "min_originality_score": 0.90,  // Stricter originality
    "require_ftc_disclosure": true,
    "min_readability_score": 70
  },
  "code": {
    "require_security_scan": true,
    "max_complexity_score": 12
  }
}
```

### **AI Model Preferences**

Edit `C:\LuxRig\Configs\ai-models.json`:

```json
{
  "claude": {
    "model": "claude-opus-4-1",
    "monthly_budget": 150,  // Increase for more usage
    "tier": 1
  }
}
```

---

## 📊 Running as Windows Service

**Create a scheduled task to run on startup:**

```powershell
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-File C:\LuxRig\Orchestrator\master-orchestrator.ps1 -Mode auto -Interval 3600"

$trigger = New-ScheduledTaskTrigger -AtStartup

$principal = New-ScheduledTaskPrincipal -UserId "$env:USERNAME" -LogonType Interactive

Register-ScheduledTask -TaskName "LuxRig Master Orchestrator" `
    -Action $action -Trigger $trigger -Principal $principal `
    -Description "Autonomous passive income orchestrator"
```

**Verify task:**

```powershell
Get-ScheduledTask -TaskName "LuxRig Master Orchestrator"
```

---

## 🔒 Security Hardening

### **1. Protect API Keys**

```powershell
# Set restrictive permissions on api-keys.json
icacls "C:\LuxRig\Configs\api-keys.json" /inheritance:r /grant:r "$env:USERNAME:(R)"
```

### **2. Enable Windows Firewall**

```powershell
# Block external access to local AI endpoints
New-NetFirewallRule -DisplayName "Block External AI Access" `
    -Direction Inbound -LocalPort 11434,1234 -Protocol TCP -Action Block
```

### **3. Regular Backups**

```powershell
# Schedule weekly backups
$backupScript = @"
Copy-Item -Path "C:\LuxRig\Analytics" -Destination "C:\LuxRig-Backups\Analytics-`$(Get-Date -Format 'yyyy-MM-dd')" -Recurse
Copy-Item -Path "C:\LuxRig\Products" -Destination "C:\LuxRig-Backups\Products-`$(Get-Date -Format 'yyyy-MM-dd')" -Recurse
"@

$backupScript | Set-Content "C:\LuxRig\backup.ps1"

# Create scheduled task for weekly backups
$backupAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File C:\LuxRig\backup.ps1"
$backupTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At "2AM"
Register-ScheduledTask -TaskName "LuxRig Backup" -Action $backupAction -Trigger $backupTrigger
```

---

## 🧪 Testing Individual Components

### **Test AI Plugins**

```powershell
Import-Module "C:\LuxRig\Orchestrator\task-router.ps1"

# Simple test
$result = Invoke-TaskRouter -Task "Explain LuxRig in one sentence" -Priority "low"
Write-Host $result.response
```

### **Test Budget Manager**

```powershell
Import-Module "C:\LuxRig\Orchestrator\budget-manager.ps1"

# Check current budget
Get-BudgetReport -Period "monthly"
```

### **Test Opportunity Scanner**

```powershell
Import-Module "C:\LuxRig\Engines\ContentEngine\opportunity-scanner.ps1"

# Scan Reddit for opportunities
$opps = Find-Opportunities -Source "reddit" -Limit 10

# View top 5
$opps | Select-Object -First 5 | Format-Table title, source, @{Name="Score";Expression={$_.score.total}}
```

### **Test Product Builder**

```powershell
Import-Module "C:\LuxRig\Engines\ProductEngine\tool-builder.ps1"

# Build a mock product
$mockIdea = @{
    title = "URL Shortener Tool"
    description = "Simple URL shortening service"
    source = "test"
    score = @{demand = 8; difficulty = 3}
}

$product = Build-MicroSaaS -Idea $mockIdea
```

### **Test Content Generator**

```powershell
Import-Module "C:\LuxRig\Engines\ContentEngine\content-generator.ps1"

# Generate article
$content = Invoke-ContentGeneration -Topic "How to build passive income with AI" -WordCount 1000
```

---

## 🐛 Troubleshooting

### **Issue: "Execution Policy Error"**

```powershell
# Fix:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### **Issue: "API Key Not Found"**

```powershell
# Verify keys are set:
$env:ANTHROPIC_API_KEY
$env:OPENAI_API_KEY

# OR check config file:
Get-Content "C:\LuxRig\Configs\api-keys.json"
```

### **Issue: "Module Import Failed"**

```powershell
# Use full paths:
Import-Module "C:\LuxRig\Orchestrator\task-router.ps1" -Force
```

### **Issue: "Ollama Not Responding"**

```powershell
# Check if Ollama is running:
Get-Process ollama

# Test connection:
Invoke-RestMethod -Uri "http://localhost:11434/api/tags"

# Restart if needed:
Stop-Process -Name ollama
ollama serve
```

### **Issue: "Budget State Not Updating"**

```powershell
# Check file permissions:
Test-Path "C:\LuxRig\Analytics\budget-state.json"

# Reset if needed:
Remove-Item "C:\LuxRig\Analytics\budget-state.json" -Force
```

---

## 📈 Monitoring & Analytics

### **View Revenue**

```powershell
Import-Module "C:\LuxRig\Analytics\revenue-tracker.ps1"

# Get total revenue
$revenue = Get-TotalRevenue -Period "month"
Write-Host "Monthly Revenue: `$$($revenue.total)"
```

### **Check ROI**

```powershell
Import-Module "C:\LuxRig\Orchestrator\roi-calculator.ps1"

# Calculate ROI
$roi = Get-ROIMetrics -Period "month"
Write-Host "ROI: $($roi.roi)%"
Write-Host "Cost per `$1: `$$($roi.costPerDollar)"
```

### **View Analytics Dashboard**

```powershell
Import-Module "C:\LuxRig\Analytics\analytics-collector.ps1"

# Full dashboard
Get-AnalyticsDashboard
```

---

## 🎯 Next Steps

Once deployed and running:

1. **Monitor for 24-48 hours** - Ensure stability
2. **Review generated opportunities** - Check `C:\LuxRig\Products\ideas\`
3. **Validate first product** - Run idea-validator.ps1
4. **Deploy first micro-SaaS** - Let tool-builder.ps1 create it
5. **Publish first article** - Generate SEO content
6. **Track revenue** - Monitor Stripe dashboard
7. **Optimize budgets** - Review ROI weekly

---

## 🆘 Support & Resources

- **Documentation:** `C:\LuxRig\README.md`
- **Blueprint:** `C:\OPUS-DLX\BLUEPRINT.md`
- **Phase 2 Details:** `C:\LuxRig\PHASE2_COMPLETE.md`
- **Testing:** `C:\LuxRig\Tests\test-phase1.ps1`

---

**You're ready to generate autonomous passive income.** 🚀

*The foundation is built. The orchestrator is live. Time to scale.*
