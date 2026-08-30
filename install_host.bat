@echo off
setlocal EnableDelayedExpansion
title yt-dlp Universal Native Messaging Host Installer

echo ==================================================================
echo   yt-dlp Native Messaging Host - Universal Browser Setup
echo ==================================================================
echo.

set "SCRIPT_DIR=%~dp0"
set "HOST_DIR=%SCRIPT_DIR%native_host"
set "BAT_PATH=%HOST_DIR%\ytdlp_host_runner.bat"
set "JSON_FF=%HOST_DIR%\ytdlp_native_host_firefox.json"
set "JSON_CHROME=%HOST_DIR%\ytdlp_native_host_chrome.json"

:: Check if runner script exists
if not exist "%BAT_PATH%" (
    echo [ERROR] ytdlp_host_runner.bat was not found in %HOST_DIR%!
    pause
    exit /b 1
)

:: Escape backslashes for JSON
set "ESCAPED_BAT_PATH=%BAT_PATH:\=\\%"

echo [1/3] Generating Native Host manifests for Firefox and Chromium...
(
    echo {
    echo   "name": "ytdlp_native_host",
    echo   "description": "yt-dlp Native Host for Firefox Extension",
    echo   "path": "%ESCAPED_BAT_PATH%",
    echo   "type": "stdio",
    echo   "allowed_extensions": [
    echo     "ytdlp-downloader@antigravity.local"
    echo   ]
    echo }
) > "%JSON_FF%"

(
    echo {
    echo   "name": "ytdlp_native_host",
    echo   "description": "yt-dlp Native Host for Chrome/Edge/Brave Extension",
    echo   "path": "%ESCAPED_BAT_PATH%",
    echo   "type": "stdio",
    echo   "allowed_origins": [
    echo     "chrome-extension://bnmhkcjfihcofbkimncbfgofgjlhjenb/"
    echo   ]
    echo }
) > "%JSON_CHROME%"

:: Create default fallback
copy "%JSON_FF%" "%HOST_DIR%\ytdlp_native_host.json" >nul

echo [2/3] Registering Native Host in Windows Registry for all browsers...

:: Mozilla Firefox
reg add "HKCU\Software\Mozilla\NativeMessagingHosts\ytdlp_native_host" /ve /t REG_SZ /d "%JSON_FF%" /f >nul
if %ERRORLEVEL% EQU 0 (
    echo       [+] Mozilla Firefox registered.
) else (
    echo       [-] Failed to register Firefox.
)

:: Google Chrome
reg add "HKCU\Software\Google\Chrome\NativeMessagingHosts\ytdlp_native_host" /ve /t REG_SZ /d "%JSON_CHROME%" /f >nul
if %ERRORLEVEL% EQU 0 (
    echo       [+] Google Chrome registered.
) else (
    echo       [-] Failed to register Chrome.
)

:: Microsoft Edge
reg add "HKCU\Software\Microsoft\Edge\NativeMessagingHosts\ytdlp_native_host" /ve /t REG_SZ /d "%JSON_CHROME%" /f >nul
if %ERRORLEVEL% EQU 0 (
    echo       [+] Microsoft Edge registered.
) else (
    echo       [-] Failed to register Edge.
)

:: Brave Browser
reg add "HKCU\Software\BraveSoftware\Brave-Browser\NativeMessagingHosts\ytdlp_native_host" /ve /t REG_SZ /d "%JSON_CHROME%" /f >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo       [+] Brave Browser registered.
)

echo [3/3] Verifying Python and yt-dlp installation...
where python >nul 2>nul
if %ERRORLEVEL% EQU 0 goto :has_python

where py >nul 2>nul
if %ERRORLEVEL% EQU 0 goto :has_py

echo [WARNING] Python was not found in system PATH. Please make sure Python is installed.
goto :done

:has_python
echo       [+] Python found in system PATH.
python -c "import yt_dlp; print('      [+] yt-dlp version:', yt_dlp.version.__version__)" 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [NOTICE] yt-dlp is not installed yet in Python!
    echo          Run: pip install yt-dlp imageio-ffmpeg
)
goto :done

:has_py
echo       [+] Python Launcher (py) found.
py -3 -c "import yt_dlp; print('      [+] yt-dlp version:', yt_dlp.version.__version__)" 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [NOTICE] yt-dlp is not installed yet in Python!
    echo          Run: py -3 -m pip install yt-dlp imageio-ffmpeg
)
goto :done

:done
echo.
echo ==================================================================
echo   Setup completed! Native Host is ready for ALL browsers.
echo ==================================================================
echo.
pause
