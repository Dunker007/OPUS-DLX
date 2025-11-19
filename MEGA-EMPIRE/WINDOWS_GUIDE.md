# MEGA-EMPIRE Windows Installation & Usage Guide

**Ultimate Passive Income Automation System - Windows Edition**

Version 1.0.0 | DLX-Phoenix Team

---

## 📋 Table of Contents

- [System Requirements](#system-requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Windows-Specific Features](#windows-specific-features)
- [Troubleshooting](#troubleshooting)
- [Performance Optimization](#performance-optimization)
- [Firewall and Antivirus](#firewall-and-antivirus)

---

## 💻 System Requirements

### Minimum Requirements
- **OS**: Windows 10 (64-bit) or Windows 11
- **CPU**: 2 cores (Intel Core i3 or AMD equivalent)
- **RAM**: 4GB
- **Disk**: 20GB free space
- **Python**: 3.8 or higher
- **Internet**: 10 Mbps download/upload

### Recommended Requirements
- **OS**: Windows 11 (64-bit)
- **CPU**: 4+ cores (Intel Core i5/i7 or AMD Ryzen 5/7)
- **RAM**: 8GB or more
- **Disk**: 50GB SSD free space
- **Python**: 3.11 or higher
- **Internet**: 50+ Mbps download/upload

---

## 🔧 Installation

### Step 1: Install Python

1. Download Python from [python.org](https://www.python.org/downloads/)
2. **IMPORTANT**: During installation, check **"Add Python to PATH"**
3. Click "Install Now"
4. Verify installation:
   ```cmd
   python --version
   ```

### Step 2: Download MEGA-EMPIRE

```cmd
cd C:\
git clone https://github.com/YourOrg/MEGA-EMPIRE.git
cd MEGA-EMPIRE
```

Or download and extract the ZIP file to `C:\MEGA-EMPIRE`

### Step 3: Run Installer

**Option A: Batch Script (Recommended for beginners)**
```cmd
install.bat
```

**Option B: PowerShell (Advanced users)**
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\install.ps1
```

The installer will:
- ✅ Verify Python installation
- ✅ Create virtual environment
- ✅ Install all dependencies
- ✅ Create necessary directories
- ✅ Configure system settings

---

## 🚀 Quick Start

### Using Batch Scripts (Easiest)

**Start Everything:**
```cmd
launcher.bat
```

**Start Master Control Only:**
```cmd
launcher.bat --master
```

**Check Status:**
```cmd
launcher.bat --status
```

**Start Specific Category:**
```cmd
launcher.bat --category ContentFactory
```

**Stop All Modules:**
```cmd
launcher.bat --stop
```

### Using PowerShell (Advanced)

**Start Everything:**
```powershell
.\launcher.ps1
```

**Start with Parameters:**
```powershell
.\launcher.ps1 -Master              # Master Control only
.\launcher.ps1 -Status              # Check status
.\launcher.ps1 -Category ContentFactory
.\launcher.ps1 -Module 1            # Start Module 1
.\launcher.ps1 -Stop                # Stop all
```

### Using Python Directly

```cmd
python launcher.py
python launcher.py --master
python launcher.py --status
python launcher.py --category ContentFactory
python launcher.py --module 1
python launcher.py --stop
```

---

## 🎯 Windows-Specific Features

### 1. **Windows Process Management**

The system uses Windows-specific process handling:
- Graceful shutdown with `CTRL_C_EVENT`
- Force kill with `taskkill` when needed
- Proper child process termination

### 2. **Path Handling**

All paths use `pathlib.Path` for Windows compatibility:
- Automatic conversion of `/` to `\`
- Support for UNC paths
- Long path support (>260 characters)

### 3. **Virtual Environment**

Automatically created in `venv\` directory:
```
MEGA-EMPIRE\
├── venv\
│   ├── Scripts\
│   │   ├── activate.bat
│   │   ├── python.exe
│   │   └── ...
│   └── Lib\
```

### 4. **Console Colors**

Uses `colorama` for colored output in Windows Command Prompt and PowerShell.

---

## 🔍 Troubleshooting

### Python Not Found

**Error**: `'python' is not recognized as an internal or external command`

**Solution**:
1. Reinstall Python and check "Add Python to PATH"
2. Or add Python manually to PATH:
   - Search "Environment Variables" in Windows
   - Edit "Path" in System variables
   - Add: `C:\Users\YourName\AppData\Local\Programs\Python\Python311`

### Permission Denied

**Error**: `PermissionError: [WinError 5] Access is denied`

**Solution**:
1. Run Command Prompt or PowerShell as Administrator
2. Right-click → "Run as administrator"

### Module Import Errors

**Error**: `ModuleNotFoundError: No module named 'xxx'`

**Solution**:
```cmd
venv\Scripts\activate
pip install -r requirements.txt
```

### Port Already in Use

**Error**: `OSError: [WinError 10048] Only one usage of each socket address`

**Solution**:
```cmd
# Find and kill process using port
netstat -ano | findstr :8000
taskkill /PID <PID> /F
```

### PowerShell Execution Policy

**Error**: `cannot be loaded because running scripts is disabled`

**Solution**:
```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

### Antivirus Blocking

**Issue**: Antivirus flags Python scripts

**Solution**:
1. Add `C:\MEGA-EMPIRE` to antivirus exclusions
2. Whitelist `python.exe` and `pythonw.exe`

---

## ⚡ Performance Optimization

### 1. **Windows Defender Exclusions**

Add these to Windows Defender exclusions for better performance:

1. Open Windows Security
2. Virus & threat protection → Manage settings
3. Exclusions → Add an exclusion → Folder
4. Add: `C:\MEGA-EMPIRE`
5. Add: `C:\Users\YourName\AppData\Local\Programs\Python`

### 2. **Power Settings**

Set to **High Performance**:
1. Control Panel → Power Options
2. Select "High performance" plan
3. Or create custom plan with:
   - Turn off display: Never (when plugged in)
   - Put computer to sleep: Never

### 3. **Startup Optimization**

**Run on Windows Startup** (optional):

Create shortcut in Startup folder:
```
Win + R → shell:startup
```

Create shortcut to:
```
C:\MEGA-EMPIRE\launcher.bat
```

Right-click → Properties → Run: Minimized

### 4. **Resource Monitor**

Monitor system resources:
```cmd
# Task Manager
Ctrl + Shift + Esc

# Resource Monitor
resmon

# Performance Monitor
perfmon
```

### 5. **SSD Optimization**

If using SSD:
- Ensure TRIM is enabled: `fsutil behavior query DisableDeleteNotify`
- Result should be `0`

---

## 🛡️ Firewall and Antivirus

### Windows Firewall Rules

Allow MEGA-EMPIRE through firewall:

```powershell
# Run as Administrator
New-NetFirewallRule -DisplayName "MEGA-EMPIRE Python" `
                    -Direction Inbound `
                    -Program "C:\Users\YourName\AppData\Local\Programs\Python\Python311\python.exe" `
                    -Action Allow
```

### Antivirus Configuration

**Windows Defender**:
1. Add folder exclusion: `C:\MEGA-EMPIRE`
2. Add process exclusion: `python.exe`

**Third-Party Antivirus**:
- Check "Application Control" or "HIPS" settings
- Whitelist `C:\MEGA-EMPIRE\`
- Whitelist Python executable

---

## 📁 Directory Structure

```
C:\MEGA-EMPIRE\
├── venv\                    # Virtual environment (auto-created)
├── Config\                  # Configuration files
│   └── system_config.json
├── Data\                    # Databases
├── Logs\                    # Log files
├── MasterControl\           # Control center
├── ContentFactory\          # Content modules
├── RevenueEngines\          # Revenue modules
├── TrafficDomination\       # Traffic modules
├── AutomationCore\          # Automation modules
├── AIBrainNetwork\          # AI modules
├── Tools\                   # Utilities
├── launcher.bat             # Windows batch launcher
├── launcher.ps1             # PowerShell launcher
├── launcher.py              # Python launcher
├── install.bat              # Installation script
├── requirements.txt         # Python dependencies
└── README.md               # Main documentation
```

---

## 🔧 Advanced Configuration

### Environment Variables

Create `.env` file in `C:\MEGA-EMPIRE\.env`:

```env
# API Keys (optional)
OPENAI_API_KEY=your_key_here
ANTHROPIC_API_KEY=your_key_here

# System Settings
MAX_WORKERS=10
MAX_CONCURRENT_MODULES=25

# Paths
DATA_DIR=C:\MEGA-EMPIRE\Data
LOGS_DIR=C:\MEGA-EMPIRE\Logs
```

### Custom Configuration

Edit `Config\system_config.json`:

```json
{
  "system": {
    "max_concurrent": 25,
    "auto_start": true
  },
  "revenue": {
    "target_daily": 1000.0
  }
}
```

---

## 📊 Monitoring and Logs

### View Logs

**Real-time monitoring:**
```cmd
# Windows Command Prompt
type Logs\mega_empire_YYYYMMDD.log

# PowerShell
Get-Content Logs\mega_empire_YYYYMMDD.log -Wait -Tail 50
```

### Log Locations

- **System logs**: `Logs\mega_empire_YYYYMMDD.log`
- **Error logs**: `Logs\errors_YYYYMMDD.log`
- **Module logs**: `Logs\module_XX_YYYYMMDD.log`

---

## 🆘 Support

### Common Issues

1. **Slow Performance**: Check antivirus exclusions
2. **Network Errors**: Check Windows Firewall
3. **Import Errors**: Reinstall dependencies
4. **Process Won't Stop**: Use Task Manager to force quit

### Getting Help

1. Check logs in `Logs\` directory
2. Review configuration in `Config\`
3. See main documentation in `README.md`

---

## 🎓 Best Practices

### 1. **Run as Standard User**
- Don't run as Administrator unless necessary
- Use UAC for elevated tasks

### 2. **Regular Updates**
```cmd
git pull
pip install -r requirements.txt --upgrade
```

### 3. **Backup Configuration**
```cmd
xcopy Config Config_backup\ /E /I /Y
xcopy Data Data_backup\ /E /I /Y
```

### 4. **Monitor Resources**
- Keep Task Manager open
- Watch CPU, RAM, disk usage
- Close unnecessary applications

### 5. **Schedule Maintenance**
- Use Windows Task Scheduler
- Run backups daily
- Check logs weekly

---

## 🚀 Production Deployment

For 24/7 operation:

1. **Windows Server** (recommended for production)
2. **Task Scheduler** for auto-start
3. **Windows Service** (advanced)
4. **Remote Desktop** for monitoring
5. **Automated backups**

---

## ✅ Checklist

Before first run:

- [ ] Python 3.8+ installed with PATH
- [ ] Virtual environment created
- [ ] Dependencies installed
- [ ] Antivirus exclusions added
- [ ] Firewall rules configured
- [ ] Configuration reviewed
- [ ] Logs directory accessible

---

## 📞 Contact

DLX-Phoenix Team
Version: 1.0.0
Date: 2025-01-19

---

*For complete documentation, see README.md*
*For technical details, see source code comments*
