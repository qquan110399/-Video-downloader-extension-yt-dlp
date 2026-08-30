# Check for Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[NOTICE] This setup requires Administrator rights to configure the Firefox installation directory." -ForegroundColor Yellow
    Write-Host "Relaunching with Administrator privileges (UAC prompt)..." -ForegroundColor Cyan
    $scriptPath = $MyInvocation.MyCommand.Path
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
    Exit
}

$ErrorActionPreference = "Stop"

$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }

$extensionDir = Join-Path $scriptDir "extension"
$addonXpi = Join-Path $scriptDir "yt-dlp-downloader.xpi"

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "   Firefox Enterprise Policy Setup (Permanent Installation)       " -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Package extension as XPI
Write-Host "[1/3] Packaging extension as XPI..." -ForegroundColor Yellow
if (Test-Path $addonXpi) { Remove-Item $addonXpi -Force }
$tempZip = Join-Path $scriptDir "temp_extension.zip"
if (Test-Path $tempZip) { Remove-Item $tempZip -Force }

Compress-Archive -Path "$extensionDir\*" -DestinationPath $tempZip -Force
Move-Item -Path $tempZip -Destination $addonXpi -Force
Write-Host "      XPI successfully created: $addonXpi" -ForegroundColor Green

# 2. Locate Firefox installation directory
$firefoxPaths = @(
    "C:\Program Files\Mozilla Firefox",
    "C:\Program Files (x86)\Mozilla Firefox",
    "$env:LOCALAPPDATA\Mozilla Firefox"
)

$ffDir = $null
foreach ($path in $firefoxPaths) {
    if (Test-Path (Join-Path $path "firefox.exe")) {
        $ffDir = $path
        break
    }
}

if (-not $ffDir) {
    Write-Host "[ERROR] Mozilla Firefox installation directory was not found!" -ForegroundColor Red
    Write-Host "Please adjust the installation path manually in the script."
    Read-Host "Press Enter to exit..."
    Exit 1
}

Write-Host "[2/3] Firefox found in: $ffDir" -ForegroundColor Green

$distDir = Join-Path $ffDir "distribution"
if (-not (Test-Path $distDir)) {
    New-Item -ItemType Directory -Path $distDir -Force | Out-Null
}

# 3. Create or update policies.json
$xpiUri = "file:///" + ($addonXpi -replace '\\', '/')
$policyPath = Join-Path $distDir "policies.json"

$policyData = @{
    policies = @{
        ExtensionSettings = @{
            "ytdlp-downloader@antigravity.local" = @{
                installation_mode = "force_installed"
                install_url = $xpiUri
            }
        }
    }
}

if (Test-Path $policyPath) {
    try {
        $existing = Get-Content $policyPath -Raw | ConvertFrom-Json
        if ($existing.policies) {
            if (-not $existing.policies.ExtensionSettings) {
                $existing.policies | Add-Member -NotePropertyName "ExtensionSettings" -NotePropertyValue (New-Object PSObject) -Force
            }
            $existing.policies.ExtensionSettings | Add-Member -NotePropertyName "ytdlp-downloader@antigravity.local" -NotePropertyValue @{
                installation_mode = "force_installed"
                install_url = $xpiUri
            } -Force
            $policyData = $existing
        }
    } catch {}
}

$policyJson = $policyData | ConvertTo-Json -Depth 10

Write-Host "[3/3] Writing policies.json to $policyPath..." -ForegroundColor Yellow
Set-Content -Path $policyPath -Value $policyJson -Encoding UTF8

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "  SUCCESS! The add-on is now PERMANENTLY installed in Firefox.    " -ForegroundColor Green
Write-Host "  Restart Firefox now to activate the add-on!                     " -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Window will close in 5 seconds..." -ForegroundColor Gray
Start-Sleep -Seconds 5
