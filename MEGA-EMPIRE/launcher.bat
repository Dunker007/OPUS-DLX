@echo off
REM MEGA-EMPIRE Windows Launcher
REM ============================
REM Ultimate Passive Income Automation System

setlocal enabledelayedexpansion

echo.
echo ╔═══════════════════════════════════════════════════════════════════════════╗
echo ║                                                                           ║
echo ║                    MEGA-EMPIRE MASTER LAUNCHER                            ║
echo ║                                                                           ║
echo ║             Ultimate Passive Income Automation System                     ║
echo ║                         Windows Edition                                   ║
echo ║                                                                           ║
echo ╚═══════════════════════════════════════════════════════════════════════════╝
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3.8+ from https://www.python.org/
    pause
    exit /b 1
)

REM Get Python version
for /f "tokens=2" %%i in ('python --version 2^>^&1') do set PYVERSION=%%i
echo ✓ Found Python %PYVERSION%

REM Check if virtual environment exists
if not exist "venv\" (
    echo.
    echo Creating virtual environment...
    python -m venv venv
    if errorlevel 1 (
        echo ERROR: Failed to create virtual environment
        pause
        exit /b 1
    )
    echo ✓ Virtual environment created
)

REM Activate virtual environment
echo.
echo Activating virtual environment...
call venv\Scripts\activate.bat
if errorlevel 1 (
    echo ERROR: Failed to activate virtual environment
    pause
    exit /b 1
)

REM Install/update dependencies
if exist "requirements.txt" (
    echo.
    echo Checking dependencies...
    pip install -q -r requirements.txt
    if errorlevel 1 (
        echo WARNING: Some dependencies may not have installed correctly
    ) else (
        echo ✓ Dependencies up to date
    )
)

REM Parse command line arguments
set "CMD=%~1"

if "%CMD%"=="" (
    REM Default: Start entire system
    echo.
    echo Starting MEGA-EMPIRE System...
    echo ════════════════════════════════════════════════════════════════════════════
    python launcher.py
) else if "%CMD%"=="--help" (
    echo.
    echo MEGA-EMPIRE Launcher - Command Line Options
    echo.
    echo Usage: launcher.bat [OPTION]
    echo.
    echo Options:
    echo   (no option)        Start entire system (Master Control + all modules)
    echo   --master           Start Master Control Center only
    echo   --status           Show system status
    echo   --stop             Stop all modules
    echo   --category NAME    Start specific category (ContentFactory, RevenueEngines, etc.)
    echo   --module ID        Start specific module by ID (1-50)
    echo   --help             Show this help message
    echo.
    echo Examples:
    echo   launcher.bat                           Start everything
    echo   launcher.bat --master                  Start Master Control only
    echo   launcher.bat --status                  Check system status
    echo   launcher.bat --category ContentFactory Start ContentFactory modules
    echo   launcher.bat --module 1                Start Module 1 only
    echo.
) else (
    REM Pass arguments to Python launcher
    python launcher.py %*
)

REM Check exit code
if errorlevel 1 (
    echo.
    echo ════════════════════════════════════════════════════════════════════════════
    echo ERROR: System exited with error code %errorlevel%
    echo Check logs in Logs\ directory for details
    pause
    exit /b %errorlevel%
)

echo.
echo ════════════════════════════════════════════════════════════════════════════
echo System stopped successfully
echo.

endlocal
