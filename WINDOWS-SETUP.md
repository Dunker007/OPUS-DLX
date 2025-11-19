# 🪟 LuxRig Windows Setup Guide

## Quick Start (5 Minutes)

### Prerequisites

**1. PowerShell 7.0+** (Required)
```powershell
# Check your version
$PSVersionTable.PSVersion

# If less than 7.0, download from:
# https://github.com/PowerShell/PowerShell/releases
```

**2. Git** (if cloning from repository)
- Download: https://git-scm.com/download/win

---

## Installation Steps

### Option 1: Clone from Repository

```powershell
# 1. Open PowerShell 7
# 2. Navigate to your desired location
cd C:\

# 3. Clone the repository
git clone https://github.com/yourusername/OPUS-DLX.git
cd OPUS-DLX

# 4. Launch LuxRig
.\START-LUXRIG.ps1
```

### Option 2: Extract from ZIP

```powershell
# 1. Extract OPUS-DLX.zip to C:\OPUS-DLX
# 2. Open PowerShell 7 as Administrator
# 3. Navigate to directory
cd C:\OPUS-DLX

# 4. Unblock scripts (first time only)
Get-ChildItem -Recurse -Filter *.ps1 | Unblock-File

# 5. Set execution policy (first time only)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# 6. Launch LuxRig
.\START-LUXRIG.ps1
```

---

## First Run

When you run `START-LUXRIG.ps1`, it will:

1. ✅ Check prerequisites (PowerShell version, internet)
2. ✅ Create necessary directories (Data, Logs, Backups)
3. ✅ Generate default `config.json` (DEMO MODE)
4. ✅ Run system health check
5. ✅ Show main menu

### Main Menu Options

```
1. Launch Master Control Center (CLI)
   - Full trading interface
   - Strategy management
   - Portfolio view
   - Real-time analytics

2. View System Status
   - Module status
   - Health metrics
   - Active strategies

3. Open Configuration Editor
   - Edit config.json
   - Add API keys
   - Adjust risk limits

4. View Logs
   - Recent activity
   - Error logs
   - Trade history

5. Run Health Check
   - System diagnostics
   - Module verification

6. Documentation
   - Quick reference
   - Full docs index

7. Setup Wizard
   - Interactive configuration
   - First-time setup

0. Exit
```

---

## Configuration (config.json)

Default configuration is created in **DEMO MODE** (no real money):

```json
{
  "version": "4.0",
  "mode": "demo",
  "budgetMode": "bootstrapper",

  "exchanges": {
    "binance": { "enabled": false, "apiKey": "", "apiSecret": "" },
    "coinbase": { "enabled": false, "apiKey": "", "apiSecret": "" }
  },

  "aiProviders": {
    "local": { "enabled": true, "endpoint": "http://localhost:11434" }
  },

  "risk": {
    "maxPositionSize": 1000,
    "maxDailyLoss": 50,
    "maxDrawdown": 100,
    "leverage": 1
  },

  "strategies": {
    "scalper": { "enabled": true, "allocation": 20 },
    "grid": { "enabled": true, "allocation": 20 },
    "swing": { "enabled": true, "allocation": 20 }
  }
}
```

---

## Modes

### 🎮 DEMO MODE (Default)
- **No real money or API keys required**
- Perfect for learning and testing
- Simulated trading with fake data
- All features available

**To use:**
```json
{ "mode": "demo" }
```

### 📝 PAPER TRADING MODE
- **Real market data, simulated trades**
- Requires exchange API keys (read-only)
- Test strategies with real prices
- No real money at risk

**To use:**
```json
{ "mode": "paper" }
```

### 💰 LIVE TRADING MODE
- **REAL MONEY - USE WITH CAUTION**
- Requires exchange API keys (full access)
- Real trades on real exchanges
- All risk management active

**To use:**
```json
{ "mode": "live" }
```

---

## Adding Exchange API Keys

### Binance Example

1. **Get API Keys:**
   - Go to: https://www.binance.com/en/my/settings/api-management
   - Create new API key
   - Enable "Enable Spot & Margin Trading" (for live mode)
   - Copy API Key and Secret Key

2. **Add to config.json:**
```json
{
  "exchanges": {
    "binance": {
      "enabled": true,
      "apiKey": "YOUR_API_KEY_HERE",
      "apiSecret": "YOUR_SECRET_KEY_HERE"
    }
  }
}
```

3. **Restart LuxRig**

⚠️ **SECURITY WARNING:**
- NEVER commit API keys to git
- NEVER share your API keys
- Use API key restrictions (IP whitelist, withdrawal disabled)
- Store keys in environment variables for production

---

## Budget Modes

### Bootstrapper ($50/month)
```json
{ "budgetMode": "bootstrapper" }
```
- Local AI models (Ollama)
- Google Gemini (free tier)
- Single exchange
- Basic strategies

### Growth ($200/month)
```json
{ "budgetMode": "growth" }
```
- Claude + GPT-4 (limited)
- Multi-exchange
- All strategies
- Full analytics

### Blitzkrieg ($500/month)
```json
{ "budgetMode": "blitzkrieg" }
```
- Claude + GPT-4 (unlimited)
- All exchanges
- Maximum automation
- Real-time optimization

---

## Running LuxRig as a Service

### Option 1: Task Scheduler (Recommended)

```powershell
# Create scheduled task to run at startup
$action = New-ScheduledTaskAction -Execute "pwsh.exe" `
  -Argument "-NoProfile -File C:\OPUS-DLX\START-LUXRIG.ps1"

$trigger = New-ScheduledTaskTrigger -AtStartup

$principal = New-ScheduledTaskPrincipal -UserId "$env:USERNAME" `
  -LogonType Interactive -RunLevel Highest

Register-ScheduledTask -TaskName "LuxRig" `
  -Action $action `
  -Trigger $trigger `
  -Principal $principal `
  -Description "LuxRig Autonomous Trading Platform"
```

### Option 2: Windows Service (Advanced)

Use NSSM (Non-Sucking Service Manager):
```powershell
# Download NSSM: https://nssm.cc/download
nssm install LuxRig "C:\Program Files\PowerShell\7\pwsh.exe" `
  "-NoProfile -File C:\OPUS-DLX\START-LUXRIG.ps1"

nssm start LuxRig
```

---

## Troubleshooting

### "PowerShell version too old"
- Download PowerShell 7: https://github.com/PowerShell/PowerShell/releases
- Install and use `pwsh.exe` instead of `powershell.exe`

### "Execution policy error"
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "Module not found"
- Make sure you're in the OPUS-DLX directory
- Check that all files extracted correctly
- Re-clone/re-extract if needed

### "API connection failed"
- Check internet connection
- Verify API keys are correct
- Check exchange API status
- Review firewall settings

### "No trades executing"
- Check mode (demo vs paper vs live)
- Verify strategies are enabled in config.json
- Check risk limits aren't too restrictive
- Review logs for errors

---

## Directory Structure

```
C:\OPUS-DLX\
├── START-LUXRIG.ps1          ← Main launcher (START HERE)
├── config.json                ← Configuration file
├── README.md                  ← Quick start guide
├── EXECUTIVE_SUMMARY.md       ← Complete platform analysis
├── CLAUDE_CODE_MEGA_BUILD.md  ← Full documentation
│
├── LuxRig\                    ← All PowerShell modules
│   ├── master-control.ps1     ← CLI interface
│   ├── Orchestrator\          ← AI orchestration (10 modules)
│   ├── Engines\               ← Business automation (24 modules)
│   ├── Trading\               ← Trading core (15 modules)
│   ├── Charts\                ← Technical analysis (7 modules)
│   ├── AI\                    ← AI/ML systems (8 modules)
│   ├── Enterprise\            ← Enterprise features (10 modules)
│   ├── Integration\           ← Integrations (10 modules)
│   ├── Revenue\               ← Revenue streams (4 modules)
│   ├── Analytics\             ← Analytics (5 modules)
│   └── ... (110 total modules)
│
├── Data\                      ← Generated at runtime
│   ├── trades\
│   ├── analytics\
│   ├── ai-models\
│   └── backups\
│
└── Logs\                      ← Generated at runtime
    └── luxrig.log
```

---

## Performance Tips

### RAM Usage
- Minimum: 4GB
- Recommended: 8GB+
- With local AI: 16GB+

### CPU
- Minimum: Dual-core
- Recommended: Quad-core+
- With local AI: 8+ cores

### Disk Space
- Minimum: 1GB
- Recommended: 10GB+ (for logs, backups, AI models)

### Network
- Stable internet connection required
- Low latency for trading (<100ms ping to exchanges)
- Unlimited data preferred (API calls)

---

## Security Best Practices

1. **API Keys:**
   - Store in environment variables
   - Use separate keys for paper/live trading
   - Enable IP whitelist
   - Disable withdrawals

2. **System:**
   - Keep Windows updated
   - Use antivirus
   - Enable firewall
   - Use VPN for public networks

3. **Backups:**
   - Automatic backups enabled by default
   - Store backups off-site
   - Test restore regularly

4. **Monitoring:**
   - Enable alerts (email/SMS)
   - Review logs daily
   - Check health dashboard

---

## Next Steps

1. ✅ **Run START-LUXRIG.ps1** (you are here)
2. ✅ **Explore demo mode** (no API keys needed)
3. 📚 **Read documentation** (EXECUTIVE_SUMMARY.md)
4. ⚙️ **Configure for your needs** (edit config.json)
5. 🎮 **Test in paper mode** (add exchange API keys)
6. 💰 **Go live carefully** (start small!)

---

## Support

- 📖 Documentation: See all .md files in root directory
- 🐛 Issues: Check logs in `Logs/luxrig.log`
- 💬 Community: (Discord coming soon)
- 📧 Email: support@luxrig.io

---

## Legal Disclaimer

⚠️ **IMPORTANT:**
- Cryptocurrency trading is RISKY
- Past performance ≠ future results
- Only risk capital you can afford to lose
- This is educational software, not financial advice
- Consult a licensed financial advisor
- You are responsible for all trading decisions

---

**LuxRig Version:** 4.0
**Last Updated:** November 19, 2025
**Status:** Production Ready ✅

Happy trading! 🚀
