# VPP Project Setup Script (Windows PowerShell)
# Run from vpp-full-project/vpp/  AFTER Docker Desktop is running

$ErrorActionPreference = "Continue"
$Root = $PSScriptRoot
$Docker = "C:\Program Files\Docker\Docker\resources\bin\docker.exe"

function Wait-Docker {
    for ($i = 1; $i -le 60; $i++) {
        try {
            & $Docker info 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { return $true }
        } catch {}
        Write-Host "  Waiting for Docker engine... ($i/60)"
        Start-Sleep -Seconds 5
    }
    return $false
}

Write-Host "=== VPP Production Setup ===" -ForegroundColor Cyan

# 0. Verify Docker
if (-not (Test-Path $Docker)) {
    Write-Host "Docker not found. Install Docker Desktop first." -ForegroundColor Red
    exit 1
}

if (-not (Wait-Docker)) {
    Write-Host "Docker engine not ready. Open Docker Desktop, wait until it says 'Running', then retry." -ForegroundColor Red
    exit 1
}
Write-Host "Docker engine ready." -ForegroundColor Green

# 1. Infrastructure
Write-Host "`n[1/6] Starting Docker infrastructure..." -ForegroundColor Yellow
Set-Location "$Root\sprint-1"
& $Docker compose up -d
Start-Sleep -Seconds 35

# Create Kafka topic
& $Docker exec vpp_redpanda rpk topic create gps.events -p 3 2>$null

# Create MinIO buckets (via minio container network)
& $Docker run --rm --network sprint-1_default minio/mc alias set local http://minio:9000 vpp_admin vpp_secret123 2>$null
& $Docker run --rm --network sprint-1_default minio/mc mb local/mlflow-artifacts --ignore-existing 2>$null
& $Docker run --rm --network sprint-1_default minio/mc mb local/raw-gps --ignore-existing 2>$null

# 2. Python dependencies
Write-Host "`n[2/6] Installing Python dependencies..." -ForegroundColor Yellow
Set-Location $Root
python -m pip install -r requirements.txt -q 2>&1 | Out-Null

# 3. Bootstrap data
Write-Host "`n[3/6] Seeding historical data..." -ForegroundColor Yellow
python scripts/bootstrap_data.py

# 4. Export features
Write-Host "`n[4/6] Exporting features..." -ForegroundColor Yellow
$env:FEATURE_DATA_PATH = "$Root\sprint-3\training\data\zone_demand_features.parquet"
python scripts/export_features.py

# 5. Train models
Write-Host "`n[5/6] Training models..." -ForegroundColor Yellow
Set-Location "$Root\sprint-3\training"
$env:USE_MLFLOW = "auto"
python train.py

# 6. Summary
Write-Host "`n[6/6] Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Infrastructure:"
Write-Host "  Postgres:   localhost:5432"
Write-Host "  Redpanda:   localhost:9092  (console: localhost:8080)"
Write-Host "  MinIO:      localhost:9000  (console: localhost:9001)"
Write-Host "  MLflow:     localhost:5000"
Write-Host "  Prometheus: localhost:9090"
Write-Host "  Grafana:    localhost:3000  (admin / vpp_admin)"
Write-Host ""
Write-Host "Start app services:  .\run.ps1"
Write-Host ""

Set-Location $Root
