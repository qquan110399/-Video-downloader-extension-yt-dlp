@echo off
set "SCRIPT_DIR=%~dp0"
powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%SCRIPT_DIR%uninstall.ps1\"' -Verb RunAs"
