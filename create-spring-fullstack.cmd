@echo off
setlocal enabledelayedexpansion

REM ================================================
REM ALTERNATIVE WRAPPER - .CMD VERSION
REM ================================================
REM This is equivalent to the .bat file
REM Can be used interchangeably

set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%create-spring-fullstack-FIXED.ps1"

if not exist "!PS_SCRIPT!" (
    color 0C
    echo.
    echo   ERROR: PowerShell script not found
    echo   Expected: !PS_SCRIPT!
    echo.
    pause
    exit /b 1
)

pwsh -NoProfile -ExecutionPolicy Bypass -Command "& '!PS_SCRIPT!'"
exit /b !errorlevel!