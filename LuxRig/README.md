# LuxRig Phase 1 Foundation - AI Orchestration System

## 🚀 Quick Start

Welcome to **LuxRig** - the AI-powered passive income orchestration system designed by Opus and built by Claude Code.

This is **Phase 1: The Foundation** - the core infrastructure that routes tasks to optimal AI models, tracks costs, ensures quality, and discovers revenue opportunities autonomously.

---

## 📁 Directory Structure

```
C:\LuxRig\
├── Orchestrator\           # Core AI orchestration system
│   ├── ai-plugins\         # Standardized AI provider interfaces
│   │   ├── claude-plugin.ps1
│   │   ├── gpt-plugin.ps1
│   │   ├── gemini-plugin.ps1
│   │   ├── grok-plugin.ps1
│   │   └── local-plugin.ps1
│   ├── task-router.ps1     # Intelligent task routing
│   ├── budget-manager.ps1  # Real-time cost tracking
│   └── quality-gates.ps1   # Multi-layer verification
│
├── Engines\                # Revenue generation engines
│   ├── ContentEngine\
│   │   └── opportunity-scanner.ps1
│   ├── ProductEngine\      # (Phase 2)
│   └── APIEngine\          # (Phase 2)
│
├── Content\                # Generated content storage
│   ├── raw\
│   ├── processed\
│   └── published\
│
├── Products\               # Digital product storage
│   ├── ideas\
│   ├── development\
│   └── deployed\
│
├── Analytics\              # Performance tracking
│   ├── dashboard.ps1       # Real-time monitoring
│   ├── revenue\
│   ├── traffic\
│   └── ai-performance\
│
├── Configs\                # Configuration files
│   ├── ai-models.json
│   ├── budget-rules.yaml
│   ├── quality-standards.json
│   └── api-keys.json.template
│
└── Tests\                  # Test scripts
    └── test-phase1.ps1
```

---

## ⚙️ Setup Instructions

### 1. **Deploy to LuxRig Server**

Copy this entire `LuxRig` directory to `C:\LuxRig\` on your Windows 11 server.

```powershell
# From the repo directory
Copy-Item -Path "LuxRig" -Destination "C:\" -Recurse -Force
```

### 2. **Configure API Keys**

Create the API keys file from the template:

```powershell
cd C:\LuxRig\Configs
Copy-Item api-keys.json.template api-keys.json
```

Edit `api-keys.json` and add your actual API keys:

```json
{
  "anthropic_api_key": "sk-ant-api03-YOUR_KEY_HERE",
  "openai_api_key": "sk-YOUR_KEY_HERE",
  "google_ai_api_key": "AIzaYOUR_KEY_HERE",
  "xai_api_key": "xai-YOUR_KEY_HERE"
}
```

**Important:** `api-keys.json` is gitignored for security. Never commit it.

### 3. **Install Local Models (Optional but Recommended)**

For zero-cost processing, install Ollama or LM Studio:

**Option A: Ollama**
```powershell
# Download from https://ollama.ai/download
# Then pull a model:
ollama pull llama2
```

**Option B: LM Studio**
- Download from https://lmstudio.ai/
- Load a model (e.g., Mistral 7B)
- Start the local server

### 4. **Run Tests**

Validate that everything is set up correctly:

```powershell
cd C:\LuxRig\Tests
.\test-phase1.ps1
```

Expected output: `✓ All tests passed! Phase 1 foundation is ready.`

---

## 🎯 Usage Examples

### Example 1: Route a Task

```powershell
cd C:\LuxRig\Orchestrator
Import-Module .\task-router.ps1

# Simple task (will route to local models or mid-tier)
$result = Invoke-TaskRouter -Task "Summarize the benefits of AI automation"

# Complex strategic task (will route to Claude Opus or GPT-4)
$result = Invoke-TaskRouter -Task "Design a marketing strategy for a SaaS product" -Priority "high"

# Display result
Write-Host $result.response
```

### Example 2: Check Budget Status

```powershell
cd C:\LuxRig\Orchestrator
Import-Module .\budget-manager.ps1

# Get current budget status
Get-BudgetStatus

# Generate detailed report
Get-BudgetReport -Period "monthly"
```

### Example 3: Scan for Opportunities

```powershell
cd C:\LuxRig\Engines\ContentEngine
Import-Module .\opportunity-scanner.ps1

# Find opportunities from Reddit and GitHub
$opportunities = Find-Opportunities -Source "all" -Limit 50 -SaveToFile

# View top opportunities
$opportunities | Select-Object -First 10 | Format-Table title, source, @{Name="Score";Expression={$_.score.total}}
```

### Example 4: Launch the Monitoring Dashboard

```powershell
cd C:\LuxRig\Analytics

# Single display
.\dashboard.ps1

# Continuous monitoring (refreshes every 10 seconds)
.\dashboard.ps1 -Continuous -RefreshInterval 10
```

### Example 5: Test Content Quality

```powershell
cd C:\LuxRig\Orchestrator
Import-Module .\quality-gates.ps1

$content = "Your AI-generated article here..."
$result = Test-ContentQuality -Content $content -Type "article"

if ($result.passed) {
    Write-Host "✓ Content passed quality gates!"
} else {
    Write-Host "✗ Issues found:"
    $result.issues | ForEach-Object { Write-Host "  - $_" }
}
```

---

## 🧪 Testing Individual Components

Each component can be tested independently:

```powershell
# Test just the AI plugins
.\Tests\test-phase1.ps1 -Component "plugins"

# Test the task router
.\Tests\test-phase1.ps1 -Component "router"

# Test budget manager
.\Tests\test-phase1.ps1 -Component "budget"

# Test quality gates
.\Tests\test-phase1.ps1 -Component "quality"

# Test opportunity scanner
.\Tests\test-phase1.ps1 -Component "scanner"
```

---

## 📊 Budget Configuration

Edit `Configs\budget-rules.yaml` to change spending limits:

```yaml
# Switch between modes
active_mode: growth  # Options: bootstrapper, growth, blitzkrieg

# Or customize per-model budgets
model_limits:
  claude:
    monthly_max: 150  # Increase Claude budget to $150/month
```

See `budget-rules.yaml` for full configuration options including:
- Auto-scaling based on revenue
- Fallback strategies
- Off-peak optimization
- Cost alerts

---

## 🔧 Advanced Configuration

### Customize Task Complexity Analysis

Edit `Orchestrator\task-router.ps1`:

```powershell
# Add custom keywords that trigger premium AI routing
$tier1Keywords = @(
    "strategy", "strategic", "creative", "design",
    "YOUR_CUSTOM_KEYWORD"  # Add here
)
```

### Adjust Quality Standards

Edit `Configs\quality-standards.json`:

```json
{
  "content": {
    "min_originality_score": 0.90,  # Stricter originality
    "require_ftc_disclosure": true
  }
}
```

---

## 🚨 Troubleshooting

### Issue: "API key not found"
- **Solution:** Ensure `Configs\api-keys.json` exists and contains valid keys

### Issue: Task router fails
- **Solution:** Check that AI plugins are properly loaded:
  ```powershell
  Get-Module | Where-Object { $_.Name -like "*plugin*" }
  ```

### Issue: Budget not tracking
- **Solution:** Ensure `Analytics\budget-state.json` is writable:
  ```powershell
  Test-Path C:\LuxRig\Analytics\budget-state.json
  ```

### Issue: Local models not responding
- **Solution:** Verify Ollama/LM Studio is running:
  ```powershell
  Invoke-RestMethod -Uri "http://localhost:11434/api/tags"  # For Ollama
  ```

---

## 📈 Next Steps (Phase 2)

Once Phase 1 is validated and running:

1. **Build Product Engine** - Auto-generate micro-SaaS tools
2. **Deploy Content Network** - Launch niche sites with auto-SEO
3. **Implement API Engine** - Wrap AI capabilities with billing
4. **Revenue Integration** - Connect Stripe, track actual earnings
5. **Auto-Scaling** - Let the system grow budget as revenue increases

See `IMPLEMENTATION_PHASES.md` for the full roadmap.

---

## 📝 Logs & Analytics

All AI requests are logged to:
- `Analytics\ai-performance\{model}-requests-YYYY-MM.jsonl`

Budget state is tracked in:
- `Analytics\budget-state.json`

Generated opportunities saved to:
- `Products\ideas\opportunities-YYYY-MM-DD-HHmm.json`

---

## 🔐 Security Notes

- **Never commit `api-keys.json`** - it's gitignored but double-check
- **Restrict file permissions** on `Configs\api-keys.json`:
  ```powershell
  icacls "C:\LuxRig\Configs\api-keys.json" /inheritance:r /grant:r "$env:USERNAME:(R)"
  ```
- **Review quality gates** before publishing any AI-generated content
- **Monitor budget alerts** to prevent runaway costs

---

## 🤝 Support

For issues, refer to:
- `BLUEPRINT.md` - Full architecture details
- `RISK_COMPLIANCE.md` - Legal and technical safeguards
- `QUICK_START.md` - Quick reference commands

---

## 🎉 You're Ready!

Phase 1 foundation is complete. This infrastructure can now:
- ✅ Route tasks to optimal AI models
- ✅ Track and enforce budget limits
- ✅ Verify content and code quality
- ✅ Discover revenue opportunities
- ✅ Monitor system performance in real-time

**Run the dashboard and watch your AI orchestra in action:**

```powershell
C:\LuxRig\Analytics\dashboard.ps1 -Continuous
```

---

*Built with ❤️ by the AI-for-AI project*
*Architecture: Claude Opus | Implementation: Claude Sonnet 4.5 | Execution: LuxRig*
