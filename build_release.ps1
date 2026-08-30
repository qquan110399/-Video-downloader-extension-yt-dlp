$ErrorActionPreference = "Stop"

$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }

$releaseDir = Join-Path $scriptDir "release"
if (-not (Test-Path $releaseDir)) {
    New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
}

$manifestPath = Join-Path $scriptDir "extension\manifest.json"
$version = "1.0.0"
if (Test-Path $manifestPath) {
    try {
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        if ($manifest.version) { $version = $manifest.version }
    } catch {}
}

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "   yt-dlp Video Downloader - Release Builder (v$version)          " -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Create Firefox Addon .xpi
$xpiOutput = Join-Path $releaseDir "yt-dlp-downloader.xpi"
if (Test-Path $xpiOutput) { Remove-Item $xpiOutput -Force }
$tempXpiZip = Join-Path $releaseDir "temp_addon.zip"
if (Test-Path $tempXpiZip) { Remove-Item $tempXpiZip -Force }

Write-Host "[1/2] Creating Firefox Add-on XPI ($xpiOutput)..." -ForegroundColor Yellow
Compress-Archive -Path "$scriptDir\extension\*" -DestinationPath $tempXpiZip -Force
Move-Item -Path $tempXpiZip -Destination $xpiOutput -Force
Write-Host "      XPI successfully created!" -ForegroundColor Green

# 2. Create complete Release ZIP for GitHub
$zipName = "yt-dlp-downloader-v$version-windows.zip"
$zipOutput = Join-Path $releaseDir $zipName
if (Test-Path $zipOutput) { Remove-Item $zipOutput -Force }

Write-Host "[2/2] Creating GitHub Release ZIP ($zipOutput)..." -ForegroundColor Yellow
$tempStaging = Join-Path $releaseDir "yt-dlp-downloader"
if (Test-Path $tempStaging) { Remove-Item $tempStaging -Recurse -Force }
New-Item -ItemType Directory -Path $tempStaging -Force | Out-Null

# Copy all required files
Copy-Item -Path (Join-Path $scriptDir "extension") -Destination (Join-Path $tempStaging "extension") -Recurse -Force
Copy-Item -Path (Join-Path $scriptDir "native_host") -Destination (Join-Path $tempStaging "native_host") -Recurse -Force
Copy-Item -Path (Join-Path $scriptDir "install_all.bat") -Destination $tempStaging -Force
Copy-Item -Path (Join-Path $scriptDir "install_host.bat") -Destination $tempStaging -Force
Copy-Item -Path (Join-Path $scriptDir "setup_permanent.bat") -Destination $tempStaging -Force
Copy-Item -Path (Join-Path $scriptDir "setup_permanent.ps1") -Destination $tempStaging -Force
Copy-Item -Path (Join-Path $scriptDir "uninstall.bat") -Destination $tempStaging -Force
Copy-Item -Path (Join-Path $scriptDir "uninstall.ps1") -Destination $tempStaging -Force
Copy-Item -Path (Join-Path $scriptDir "README.md") -Destination $tempStaging -Force
Copy-Item -Path (Join-Path $scriptDir "LICENSE") -Destination $tempStaging -Force
if (Test-Path (Join-Path $scriptDir "assets")) {
    Copy-Item -Path (Join-Path $scriptDir "assets") -Destination (Join-Path $tempStaging "assets") -Recurse -Force
}

# Clean __pycache__ in staging
Get-ChildItem -Path $tempStaging -Recurse -Filter "__pycache__" | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

# Compress ZIP
Compress-Archive -Path "$tempStaging\*" -DestinationPath $zipOutput -Force
Remove-Item -Path $tempStaging -Recurse -Force

Write-Host "      Release ZIP successfully created!" -ForegroundColor Green
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "  DONE! Release files generated in folder 'release\':            " -ForegroundColor Green
Write-Host "  1. $zipName (Complete bundle for GitHub Releases)" -ForegroundColor White
Write-Host "  2. yt-dlp-downloader.xpi (Add-on file for Firefox / Mozilla AMO)" -ForegroundColor White
Write-Host "==================================================================" -ForegroundColor Green
Write-Host ""
