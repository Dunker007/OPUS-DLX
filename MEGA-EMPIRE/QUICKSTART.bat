@echo off
REM MEGA-EMPIRE Quick Start
REM =======================
REM One-click installation and launch

echo.
echo ╔═══════════════════════════════════════════════════════════════╗
echo ║          MEGA-EMPIRE QUICK START                              ║
echo ║      Ultimate Passive Income Automation System                ║
echo ╚═══════════════════════════════════════════════════════════════╝
echo.

REM Check if already installed
if exist "venv\" (
    echo ✓ System already installed
    echo.
    echo Starting MEGA-EMPIRE...
    call launcher.bat
    goto :end
)

REM First-time installation
echo This appears to be your first time running MEGA-EMPIRE.
echo.
echo Starting installation...
echo ═══════════════════════════════════════════════════════════════
echo.

call install.bat

if errorlevel 1 (
    echo.
    echo ❌ Installation failed. Please check the errors above.
    pause
    goto :end
)

echo.
echo ═══════════════════════════════════════════════════════════════
echo ✓ Installation complete!
echo.
echo Would you like to start MEGA-EMPIRE now? (Y/N)
set /p START="Your choice: "

if /i "%START%"=="Y" (
    echo.
    echo Starting MEGA-EMPIRE...
    echo ═══════════════════════════════════════════════════════════════
    call launcher.bat
)

:end
echo.
