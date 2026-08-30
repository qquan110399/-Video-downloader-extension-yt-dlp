@echo off
:: Batch-Wrapper fuer setup_permanent.ps1 mit automatischer Admin-Erhoehung (UAC)
set "SCRIPT_DIR=%~dp0"
powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%SCRIPT_DIR%setup_permanent.ps1\"' -Verb RunAs"
