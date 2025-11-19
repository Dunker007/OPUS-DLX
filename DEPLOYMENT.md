# LuxRig Phase 1 Deployment Guide

## 🎯 Objective

Deploy the Phase 1 foundation from this repository to your LuxRig Windows 11 server at `C:\LuxRig\`.

---

## 📋 Prerequisites

1. **Windows 11 Server** (LuxRig) with PowerShell 5.1+
2. **Internet connection** for API access
3. **API Keys** for:
   - Anthropic (Claude) - https://console.anthropic.com/
   - OpenAI (GPT-4) - https://platform.openai.com/
   - Google AI (Gemini) - https://makersuite.google.com/
   - X.AI (Grok) - https://x.ai/ (optional, for future)
4. **Optional but recommended:**
   - Ollama or LM Studio for local models (zero-cost processing)

---

## 🚀 Deployment Steps

### Step 1: Clone the Repository

On your LuxRig server, open PowerShell and run:

```powershell
# Navigate to desired location
cd C:\

# Clone the repository
git clone https://github.com/Dunker007/OPUS-DLX.git
cd OPUS-DLX
```

### Step 2: Copy LuxRig Directory

```powershell
# Copy the LuxRig directory to C:\
Copy-Item -Path ".\LuxRig" -Destination "C:\" -Recurse -Force

# Verify deployment
Test-Path C:\LuxRig
```

### Step 3: Configure API Keys

```powershell
# Navigate to configs
cd C:\LuxRig\Configs

# Copy template to actual keys file
Copy-Item api-keys.json.template api-keys.json

# Edit with your favorite editor (Notepad, VS Code, etc.)
notepad api-keys.json
```

**Add your actual API keys:**

```json
{
  "anthropic_api_key": "sk-ant-api03-YOUR_ACTUAL_KEY",
  "openai_api_key": "sk-YOUR_ACTUAL_KEY",
  "google_ai_api_key": "AIzaYOUR_ACTUAL_KEY",
  "xai_api_key": "xai-YOUR_ACTUAL_KEY"
}
```

**Important:** Save the file and verify it's NOT tracked by git:

```powershell
# Should output: api-keys.json (if .gitignore is working)
git status
```

### Step 4: Install Local Models (Optional)

For zero-cost local processing, install Ollama:

```powershell
# Download and install Ollama from https://ollama.ai/download

# After installation, pull a model
ollama pull llama2

# Verify it's running
Invoke-RestMethod -Uri "http://localhost:11434/api/tags"
```

Alternatively, use LM Studio:
- Download from https://lmstudio.ai/
- Install and load a model (e.g., Mistral 7B)
- Start the local server on port 1234

### Step 5: Run Tests

Validate the deployment:

```powershell
cd C:\LuxRig\Tests

# Run all tests
.\test-phase1.ps1

# Expected output: "✓ All tests passed! Phase 1 foundation is ready."
```

If tests fail, check:
- File paths are correct
- API keys are valid
- All files were copied successfully

### Step 6: Launch the Dashboard

```powershell
cd C:\LuxRig\Analytics

# Single display
.\dashboard.ps1

# Continuous monitoring (recommended)
.\dashboard.ps1 -Continuous -RefreshInterval 10
```

You should see the LuxRig Command Center dashboard with system health, budget status, and AI performance metrics.

---

## 🧪 Quick Validation Tests

### Test 1: Route a Simple Task

```powershell
cd C:\LuxRig\Orchestrator
Import-Module .\task-router.ps1

$result = Invoke-TaskRouter -Task "Explain what LuxRig does in one sentence"

# Should route to local or mid-tier AI and return a response
Write-Host $result.response
```

### Test 2: Check Budget Status

```powershell
Import-Module .\budget-manager.ps1

Get-BudgetReport -Period "monthly"

# Should display current budget allocation and spend
```

### Test 3: Scan for Opportunities

```powershell
cd C:\LuxRig\Engines\ContentEngine
Import-Module .\opportunity-scanner.ps1

$opps = Find-Opportunities -Source "reddit" -Limit 10

# Should return 10 scored opportunities from Reddit
$opps | Select-Object -First 5 | Format-Table title, @{Name="Score";Expression={$_.score.total}}
```

---

## ⚙️ Configuration

### Budget Allocation

Edit `C:\LuxRig\Configs\budget-rules.yaml`:

```yaml
# Choose your mode
active_mode: growth  # Options: bootstrapper, growth, blitzkrieg

# Or customize limits
model_limits:
  claude:
    monthly_max: 100  # Adjust as needed
```

### Quality Standards

Edit `C:\LuxRig\Configs\quality-standards.json`:

```json
{
  "content": {
    "min_originality_score": 0.85,  # Adjust threshold
    "require_ftc_disclosure": true
  }
}
```

### AI Model Preferences

Edit `C:\LuxRig\Configs\ai-models.json`:

```json
{
  "claude": {
    "monthly_budget": 100,  # Increase/decrease budget
    "model": "claude-opus-4-1"
  }
}
```

---

## 🔒 Security Best Practices

1. **Protect API Keys:**
   ```powershell
   # Set restrictive permissions on api-keys.json
   icacls "C:\LuxRig\Configs\api-keys.json" /inheritance:r /grant:r "$env:USERNAME:(R)"
   ```

2. **Use Environment Variables (Alternative):**
   ```powershell
   # Instead of api-keys.json, set environment variables:
   [System.Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY", "sk-ant-...", "User")
   [System.Environment]::SetEnvironmentVariable("OPENAI_API_KEY", "sk-...", "User")
   ```

3. **Enable Windows Firewall:**
   ```powershell
   # Restrict external access to local AI endpoints
   New-NetFirewallRule -DisplayName "Block External AI Access" -Direction Inbound -LocalPort 11434,1234 -Protocol TCP -Action Block
   ```

4. **Regular Backups:**
   ```powershell
   # Backup critical data weekly
   Copy-Item -Path "C:\LuxRig\Analytics" -Destination "C:\LuxRig-Backups\Analytics-$(Get-Date -Format 'yyyy-MM-dd')" -Recurse
   ```

---

## 🐛 Troubleshooting

### Issue: PowerShell Execution Policy Error

```powershell
# Run as Administrator:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Issue: Module Import Fails

```powershell
# Use full path for imports:
Import-Module "C:\LuxRig\Orchestrator\task-router.ps1" -Force
```

### Issue: API Connection Timeout

```powershell
# Test connectivity:
Test-NetConnection -ComputerName api.anthropic.com -Port 443
Test-NetConnection -ComputerName api.openai.com -Port 443
```

### Issue: Local Models Not Found

```powershell
# Verify Ollama is running:
Get-Process ollama

# Restart if needed:
Stop-Process -Name ollama
ollama serve
```

---

## 📊 Monitoring

### Set Up Task Scheduler for Auto-Start

Create a scheduled task to run the dashboard on startup:

```powershell
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File C:\LuxRig\Analytics\dashboard.ps1 -Continuous"
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERNAME" -LogonType Interactive
Register-ScheduledTask -TaskName "LuxRig Dashboard" -Action $action -Trigger $trigger -Principal $principal
```

### Enable Logging

All AI requests are automatically logged to:
- `C:\LuxRig\Analytics\ai-performance\`

Budget state is persisted to:
- `C:\LuxRig\Analytics\budget-state.json`

---

## 🎯 Next Steps

Once Phase 1 is deployed and validated:

1. **Monitor for 24-48 hours** - Ensure stability
2. **Run opportunity scanner daily** - Build idea pipeline
3. **Review budget reports weekly** - Optimize spending
4. **Begin Phase 2** - Build Product Engine (see IMPLEMENTATION_PHASES.md)

---

## 📞 Support

- Review `LuxRig/README.md` for usage examples
- Check `BLUEPRINT.md` for architecture details
- See `RISK_COMPLIANCE.md` for legal guidelines

---

## ✅ Deployment Checklist

- [ ] Repository cloned to LuxRig server
- [ ] LuxRig directory copied to `C:\LuxRig\`
- [ ] API keys configured in `Configs\api-keys.json`
- [ ] Local models installed (Ollama/LM Studio)
- [ ] All tests passing (`.\Tests\test-phase1.ps1`)
- [ ] Dashboard running (`.\Analytics\dashboard.ps1 -Continuous`)
- [ ] Budget limits configured
- [ ] Quality standards reviewed
- [ ] API keys secured with proper permissions
- [ ] Monitoring/logging verified

---

**You're ready to run the AI orchestration system!** 🚀

*The foundation is built. Time to generate passive income.*
