@echo off
setlocal
title iRidi Cloud Diagnostics
cd /d "%~dp0"

echo ================================================================
echo                  iRidi Cloud Diagnostics
echo ================================================================
echo.
echo Detecting Windows PowerShell...

set "PS_MAJOR="
for /f "delims=" %%V in ('powershell.exe -NoLogo -NoProfile -Command "$PSVersionTable.PSVersion.Major"') do set "PS_MAJOR=%%V"

if not defined PS_MAJOR (
    echo [ERROR] Windows PowerShell was not found.
    echo Please contact the support engineer.
    echo.
    pause
    exit /b 2
)

set "SCRIPT=check_iridi_cloud_windows_7.ps1"
if %PS_MAJOR% GEQ 5 set "SCRIPT=check_iridi_cloud_windows_10_11.ps1"

if not exist "%~dp0%SCRIPT%" (
    echo [ERROR] Required file was not found: %SCRIPT%
    echo Extract all files from the ZIP archive before running this tool.
    echo.
    pause
    exit /b 2
)

echo PowerShell version: %PS_MAJOR%
echo Diagnostic engine: %SCRIPT%
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0%SCRIPT%"
set "EXIT_CODE=%ERRORLEVEL%"

echo.
echo ================================================================
if "%EXIT_CODE%"=="0" (
    echo Diagnostics completed successfully.
) else (
    echo Diagnostics found unavailable resources or an execution error.
)
echo Log files are stored in:
echo %~dp0logs
echo ================================================================
echo.
pause
exit /b %EXIT_CODE%
