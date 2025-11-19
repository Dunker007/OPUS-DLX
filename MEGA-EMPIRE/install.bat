@echo off
REM MEGA-EMPIRE Windows Installation Script
REM =========================================

setlocal enabledelayedexpansion

echo.
echo ╔═══════════════════════════════════════════════════════════════════════════╗
echo ║                                                                           ║
echo ║                    MEGA-EMPIRE INSTALLATION                               ║
echo ║                                                                           ║
echo ║             Ultimate Passive Income Automation System                     ║
echo ║                         Windows Installer                                 ║
echo ║                                                                           ║
echo ╚═══════════════════════════════════════════════════════════════════════════╝
echo.

REM Check Python installation
echo [1/7] Checking Python installation...
python --version >nul 2>&1
if errorlevel 1 (
    echo.
    echo ❌ ERROR: Python is not installed or not in PATH
    echo.
    echo Please install Python 3.8 or higher from:
    echo https://www.python.org/downloads/
    echo.
    echo Make sure to check "Add Python to PATH" during installation!
    echo.
    pause
    exit /b 1
)

for /f "tokens=2" %%i in ('python --version 2^>^&1') do set PYVERSION=%%i
echo    ✓ Python %PYVERSION% found
echo.

REM Check pip
echo [2/7] Checking pip...
python -m pip --version >nul 2>&1
if errorlevel 1 (
    echo    ❌ pip not found, installing...
    python -m ensurepip --default-pip
    if errorlevel 1 (
        echo    ERROR: Failed to install pip
        pause
        exit /b 1
    )
)
echo    ✓ pip is available
echo.

REM Upgrade pip
echo [3/7] Upgrading pip...
python -m pip install --upgrade pip --quiet
echo    ✓ pip upgraded
echo.

REM Create virtual environment
echo [4/7] Creating virtual environment...
if exist "venv\" (
    echo    ⚠ Virtual environment already exists, skipping...
) else (
    python -m venv venv
    if errorlevel 1 (
        echo    ❌ ERROR: Failed to create virtual environment
        pause
        exit /b 1
    )
    echo    ✓ Virtual environment created
)
echo.

REM Activate virtual environment
echo [5/7] Activating virtual environment...
call venv\Scripts\activate.bat
if errorlevel 1 (
    echo    ❌ ERROR: Failed to activate virtual environment
    pause
    exit /b 1
)
echo    ✓ Virtual environment activated
echo.

REM Install dependencies
echo [6/7] Installing dependencies...
if exist "requirements.txt" (
    echo    This may take a few minutes...
    pip install -r requirements.txt
    if errorlevel 1 (
        echo.
        echo    ⚠ WARNING: Some dependencies failed to install
        echo    The system may still work with limited functionality
        echo.
    ) else (
        echo    ✓ All dependencies installed successfully
    )
) else (
    echo    ⚠ requirements.txt not found, skipping dependencies
)
echo.

REM Create necessary directories
echo [7/7] Creating system directories...
if not exist "Data\" mkdir Data
if not exist "Logs\" mkdir Logs
if not exist "Config\" mkdir Config
echo    ✓ Directories created
echo.

REM Installation complete
echo ════════════════════════════════════════════════════════════════════════════
echo.
echo ✓ INSTALLATION COMPLETE!
echo.
echo MEGA-EMPIRE is now installed and ready to use.
echo.
echo Quick Start:
echo   launcher.bat              - Start the entire system
echo   launcher.bat --master     - Start Master Control Center only
echo   launcher.bat --status     - Check system status
echo   launcher.bat --help       - Show all options
echo.
echo Documentation:
echo   README.md                 - Full system documentation
echo   Config\system_config.json - System configuration
echo.
echo ════════════════════════════════════════════════════════════════════════════
echo.
pause
