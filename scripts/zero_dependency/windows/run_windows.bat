@echo off
chcp 65001 > nul
setlocal

REM ==================================================================================
REM  Volcengine Ark Platform - Quickstart Launcher (Windows)
REM  This script launches the PowerShell implementation to bypass execution policies.
REM ==================================================================================

echo Launching Volcengine Ark Quickstart...
echo.

REM Check if PowerShell is available
where powershell >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: PowerShell not found.
    echo Please ensure you are running Windows 7 SP1 or later.
    pause
    exit /b 1
)

REM Change to the script's directory
cd /d "%~dp0"

REM Launch the PowerShell script
REM -NoProfile: Faster startup, no user profile loaded
REM -ExecutionPolicy Bypass: Allow running the script without changing system-wide policy
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "quickstart.ps1"

if %errorlevel% neq 0 goto Error
goto Success

:Error
echo.
echo The script encountered an error.
pause
exit /b 1

:Success
echo.
echo Script executed successfully.
echo Follow-up options are available inside the PowerShell menu.
pause
exit /b 0
