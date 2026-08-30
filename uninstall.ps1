# Check for Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[NOTICE] Uninstaller requires Administrator privileges to modify Firefox directory." -ForegroundColor Yellow
    Write-Host "Relaunching with Administrator privileges..." -ForegroundColor Cyan
    $scriptPath = $MyInvocation.MyCommand.Path
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
    Exit
}

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "          yt-dlp Video Downloader - Uninstaller                   " -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Remove registry keys
Write-Host "[1/2] Removing Native Host Registry keys..." -ForegroundColor Yellow
$regPaths = @(
    "HKCU:\Software\Mozilla\NativeMessagingHosts\ytdlp_native_host",
    "HKCU:\Software\Google\Chrome\NativeMessagingHosts\ytdlp_native_host",
    "HKCU:\Software\Microsoft\Edge\NativeMessagingHosts\ytdlp_native_host",
    "HKCU:\Software\BraveSoftware\Brave-Browser\NativeMessagingHosts\ytdlp_native_host"
)

foreach ($reg in $regPaths) {
    if (Test-Path $reg) {
        Remove-Item -Path $reg -Force -Recurse
        Write-Host "      Removed: $reg" -ForegroundColor Green
    }
}

# 2. Remove Firefox Enterprise Policy
Write-Host "[2/2] Removing Firefox Enterprise Policy..." -ForegroundColor Yellow
$firefoxPaths = @(
    "C:\Program Files\Mozilla Firefox",
    "C:\Program Files (x86)\Mozilla Firefox",
    "$env:LOCALAPPDATA\Mozilla Firefox"
)

foreach ($path in $firefoxPaths) {
    $policyPath = Join-Path $path "distribution\policies.json"
    if (Test-Path $policyPath) {
        try {
            $existing = Get-Content $policyPath -Raw | ConvertFrom-Json
            if ($existing.policies -and $existing.policies.ExtensionSettings -and $existing.policies.ExtensionSettings."ytdlp-downloader@antigravity.local") {
                $existing.policies.ExtensionSettings.PSObject.Properties.Remove("ytdlp-downloader@antigravity.local")
                if ($existing.policies.ExtensionSettings.PSObject.Properties.Count -eq 0) {
                    $existing.policies.PSObject.Properties.Remove("ExtensionSettings")
                }
                $newJson = $existing | ConvertTo-Json -Depth 10
                Set-Content -Path $policyPath -Value $newJson -Encoding UTF8
                Write-Host "      Policy removed from $policyPath." -ForegroundColor Green
            }
        } catch {
            Write-Host "      Could not update $policyPath: $_" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "  Uninstallation complete! Restart your browser.                 " -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Window will close in 5 seconds..." -ForegroundColor Gray
Start-Sleep -Seconds 5
