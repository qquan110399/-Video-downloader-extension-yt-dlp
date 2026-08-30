@echo off
setlocal EnableDelayedExpansion
title yt-dlp Video Downloader - Universal Browser Setup

echo ==================================================================
echo         yt-dlp Video Downloader - Universal Setup
echo         (Firefox, Chrome, Edge, Brave, Opera)
echo ==================================================================
echo.

set "SCRIPT_DIR=%~dp0"

:: 1. Install Native Host for all browsers
call "%SCRIPT_DIR%install_host.bat"

echo.
echo ==================================================================
echo   Step 2: Choose your browser setup
echo ==================================================================
echo.
echo   [1] Mozilla Firefox (Permanent Enterprise Policy, requires Admin) [RECOMMENDED]
echo   [2] Google Chrome / Brave / Opera (Developer mode instructions)
echo   [3] Microsoft Edge (Developer mode instructions)
echo   [4] Exit (Native Host is already registered for all browsers)
echo.
set /p CHOICE="Choose an option (1-4) [Default: 1]: "

if "%CHOICE%"=="2" (
    echo.
    echo ------------------------------------------------------------------
    echo Instructions for Chrome / Brave / Opera:
    echo 1. Open your browser and navigate to: chrome://extensions (or brave://extensions)
    echo 2. Enable 'Developer mode' (toggle in the top-right corner).
    echo 3. Click 'Load unpacked'.
    echo 4. Select the folder: '%SCRIPT_DIR%extension'
    echo 5. Done! The extension remains permanently active.
    echo ------------------------------------------------------------------
    echo.
    pause
    exit /b 0
)

if "%CHOICE%"=="3" (
    echo.
    echo ------------------------------------------------------------------
    echo Instructions for Microsoft Edge:
    echo 1. Open Edge and navigate to: edge://extensions
    echo 2. Enable 'Developer mode' in the left sidebar.
    echo 3. Click 'Load unpacked' and select the folder: '%SCRIPT_DIR%extension'
    echo 4. Done! The extension remains permanently active.
    echo ------------------------------------------------------------------
    echo.
    pause
    exit /b 0
)

if "%CHOICE%"=="4" (
    exit /b 0
)

echo.
echo Launching permanent setup for Firefox (Admin confirmation required)...
call "%SCRIPT_DIR%setup_permanent.bat"

exit /b 0
