# One-time Docker + WSL setup for VPP on Windows
# Run this script as Administrator if WSL install fails

$ErrorActionPreference = "Continue"

Write-Host "=== VPP Docker Installer ===" -ForegroundColor Cyan

# 1. Install WSL2 if missing
$wslOk = $false
try {
    $ver = wsl --version 2>&1
    if ($ver -match "WSL version") { $wslOk = $true }
} catch {}

if (-not $wslOk) {
    Write-Host "`nInstalling WSL2 (required by Docker Desktop)..." -ForegroundColor Yellow
    wsl --install --no-distribution
    Write-Host "`nWSL installed. You MUST reboot before continuing." -ForegroundColor Yellow
    $reboot = Read-Host "Reboot now? (y/n)"
    if ($reboot -eq "y") { Restart-Computer }
    exit 0
}

# 2. Install Docker Desktop if missing
$dockerExe = "C:\Program Files\Docker\Docker\resources\bin\docker.exe"
if (-not (Test-Path $dockerExe)) {
    Write-Host "`nInstalling Docker Desktop via winget..." -ForegroundColor Yellow
    winget install Docker.DockerDesktop --accept-package-agreements --accept-source-agreements --disable-interactivity
}

# 3. Start Docker Desktop
Write-Host "`nStarting Docker Desktop..." -ForegroundColor Yellow
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"

Write-Host "`nWaiting for Docker engine (up to 3 minutes)..." -ForegroundColor Yellow
$docker = $dockerExe
for ($i = 1; $i -le 36; $i++) {
    & $docker info 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Docker is ready!" -ForegroundColor Green
        Write-Host "`nNext step:  .\setup.ps1" -ForegroundColor Cyan
        exit 0
    }
    Start-Sleep -Seconds 5
}

Write-Host "Docker Desktop is starting. Open it from the system tray and wait until it shows 'Running', then run:" -ForegroundColor Yellow
Write-Host "  .\setup.ps1" -ForegroundColor Cyan
