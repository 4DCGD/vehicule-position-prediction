# VPP - Start full stack (no Docker / Maven required)
$ErrorActionPreference = "Continue"
$Root = $PSScriptRoot
$LogDir = "$Root\logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

Write-Host "=== VPP Full Stack Launcher ===" -ForegroundColor Cyan

# 1. Python deps
Write-Host "`n[1/5] Installing Python dependencies..." -ForegroundColor Yellow
python -m pip install fastapi "uvicorn[standard]" xgboost scikit-learn pandas numpy pyarrow prometheus-client pydantic requests -q 2>&1 | Out-Null

# 2. Train models if missing
$modelDir = "$Root\sprint-3\training\models"
if (-not (Test-Path "$modelDir\vpp-demand-2h.pkl")) {
    Write-Host "`n[2/5] Training models (first run, ~1 min)..." -ForegroundColor Yellow
    Set-Location "$Root\sprint-3\training"
    $env:USE_MLFLOW = "false"
    python generate_synthetic_data.py
    python train.py
    Set-Location $Root
}
else {
    Write-Host "`n[2/5] Models already trained - skipping" -ForegroundColor Green
}

# 3. Kill stale processes on our ports
Write-Host "`n[3/5] Clearing ports 8000, 8081, 8082, 5173..." -ForegroundColor Yellow
foreach ($port in @(8000, 8081, 8082, 5173)) {
    $conns = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
    foreach ($c in $conns) {
        Stop-Process -Id $c.OwningProcess -Force -ErrorAction SilentlyContinue
    }
}
Start-Sleep -Seconds 1

# 4. Start backend services
Write-Host "`n[4/5] Starting backend services..." -ForegroundColor Yellow

$env:MODEL_DIR = "$Root\sprint-3\training\models"

Start-Process python -ArgumentList "-m","uvicorn","api:app","--host","0.0.0.0","--port","8000" `
    -WorkingDirectory "$Root\sprint-3\serving" `
    -RedirectStandardOutput "$LogDir\model-api.log" `
    -RedirectStandardError "$LogDir\model-api.err" -WindowStyle Hidden

Start-Process python -ArgumentList "$Root\scripts\mock_booking_api.py" `
    -RedirectStandardOutput "$LogDir\booking-api.log" `
    -RedirectStandardError "$LogDir\booking-api.err" -WindowStyle Hidden

Start-Process python -ArgumentList "$Root\scripts\mock_decision_api.py" `
    -RedirectStandardOutput "$LogDir\decision-api.log" `
    -RedirectStandardError "$LogDir\decision-api.err" -WindowStyle Hidden

# Wait for APIs to be ready
$ready = $false
for ($i = 0; $i -lt 30; $i++) {
    try {
        $h = Invoke-RestMethod -Uri "http://127.0.0.1:8000/health" -TimeoutSec 2
        $b = Invoke-RestMethod -Uri "http://127.0.0.1:8081/actuator/health" -TimeoutSec 2
        $d = Invoke-RestMethod -Uri "http://127.0.0.1:8082/actuator/health" -TimeoutSec 2
        if ($h.status -eq "ok" -and $b.status -eq "UP" -and $d.status -eq "UP") {
            $ready = $true
            break
        }
    }
    catch {
        # not ready yet
    }
    Start-Sleep -Seconds 1
}

if (-not $ready) {
    Write-Host "WARNING: Some services may not be ready yet. Check logs in $LogDir" -ForegroundColor Red
}
else {
    Write-Host "  Model API      -> http://localhost:8000  OK" -ForegroundColor Green
    Write-Host "  Booking API    -> http://localhost:8081  OK" -ForegroundColor Green
    Write-Host "  Decision API   -> http://localhost:8082  OK" -ForegroundColor Green
}

# 5. Start dashboard
Write-Host "`n[5/5] Starting dashboard..." -ForegroundColor Yellow
Set-Location "$Root\sprint-4\dashboard"
if (-not (Test-Path "node_modules")) {
    npm install --silent
}
Start-Process npm -ArgumentList "run","dev" `
    -WorkingDirectory "$Root\sprint-4\dashboard" `
    -RedirectStandardOutput "$LogDir\dashboard.log" `
    -RedirectStandardError "$LogDir\dashboard.err" -WindowStyle Hidden

Start-Sleep -Seconds 4

Set-Location $Root
Write-Host "`n=== VPP is running ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Dashboard:     http://localhost:5173"
Write-Host "  Model API:     http://localhost:8000/docs"
Write-Host "  Booking API:   http://localhost:8081/api/v1/vehicles"
Write-Host "  Decision API:  http://localhost:8082/api/v1/decisions/health"
Write-Host ""
Write-Host "  Logs: $LogDir"
Write-Host "  To stop: .\stop.ps1"
Write-Host ""

Start-Process "http://localhost:5173"
