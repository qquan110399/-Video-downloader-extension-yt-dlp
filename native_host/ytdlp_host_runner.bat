@echo off
setlocal
set SCRIPT_DIR=%~dp0

:: Try standard python in PATH
where python >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    python -u "%SCRIPT_DIR%ytdlp_native_host.py" %*
    exit /b %ERRORLEVEL%
)

:: Try Python launcher (py)
where py >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    py -3 -u "%SCRIPT_DIR%ytdlp_native_host.py" %*
    exit /b %ERRORLEVEL%
)

:: Fallback to common default installation paths
if exist "C:\Python314\python.exe" (
    "C:\Python314\python.exe" -u "%SCRIPT_DIR%ytdlp_native_host.py" %*
    exit /b %ERRORLEVEL%
)
if exist "C:\Python313\python.exe" (
    "C:\Python313\python.exe" -u "%SCRIPT_DIR%ytdlp_native_host.py" %*
    exit /b %ERRORLEVEL%
)
if exist "C:\Python312\python.exe" (
    "C:\Python312\python.exe" -u "%SCRIPT_DIR%ytdlp_native_host.py" %*
    exit /b %ERRORLEVEL%
)
if exist "%LOCALAPPDATA%\Programs\Python\Python312\python.exe" (
    "%LOCALAPPDATA%\Programs\Python\Python312\python.exe" -u "%SCRIPT_DIR%ytdlp_native_host.py" %*
    exit /b %ERRORLEVEL%
)
if exist "%LOCALAPPDATA%\Programs\Python\Python313\python.exe" (
    "%LOCALAPPDATA%\Programs\Python\Python313\python.exe" -u "%SCRIPT_DIR%ytdlp_native_host.py" %*
    exit /b %ERRORLEVEL%
)

echo "Python could not be found. Please install Python and add it to PATH." >&2
exit /b 1
