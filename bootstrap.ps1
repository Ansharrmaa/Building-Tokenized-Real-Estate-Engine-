# bootstrap.ps1 — One-command setup for Tokenized Real Estate Search & Ingestion Engine
# Usage: powershell -ExecutionPolicy Bypass -File bootstrap.ps1

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DataDir = Join-Path $ScriptDir "data"
$ScriptsDir = Join-Path $ScriptDir "scripts"
$BackendDir = Join-Path $ScriptDir "backend"
$DbPath = Join-Path $DataDir "real_estate.db"
$MeiliVersion = "v1.12.3"
$MeiliPort = 7700
$MeiliMasterKey = "masterKey"
$MeiliDir = Join-Path $ScriptDir ".meilisearch"
$MeiliBinary = Join-Path $MeiliDir "meilisearch.exe"
$MeiliData = Join-Path $MeiliDir "data.ms"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Tokenized Real Estate Search Engine"       -ForegroundColor Cyan
Write-Host "  Bootstrap Script (Windows)"                -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# --------------------------------------------------
# Step 1: Download Meilisearch if not present
# --------------------------------------------------
if (-Not (Test-Path $MeiliBinary)) {
    Write-Host ""
    Write-Host "[1/6] Downloading Meilisearch ${MeiliVersion}..." -ForegroundColor Yellow

    if (-Not (Test-Path $MeiliDir)) {
        New-Item -ItemType Directory -Path $MeiliDir -Force | Out-Null
    }

    $DownloadUrl = "https://github.com/meilisearch/meilisearch/releases/download/${MeiliVersion}/meilisearch-windows-amd64.exe"
    Write-Host "  URL: $DownloadUrl"

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $MeiliBinary -UseBasicParsing

    Write-Host "  ✓ Meilisearch downloaded to $MeiliBinary" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "[1/6] Meilisearch binary already present. Skipping download." -ForegroundColor Green
}

# --------------------------------------------------
# Step 2: Start Meilisearch
# --------------------------------------------------
Write-Host ""
Write-Host "[2/6] Starting Meilisearch on port ${MeiliPort}..." -ForegroundColor Yellow

# Kill any existing Meilisearch process on the port
$existingProcess = Get-NetTCPConnection -LocalPort $MeiliPort -ErrorAction SilentlyContinue
if ($existingProcess) {
    Write-Host "  Port ${MeiliPort} is in use. Attempting to stop existing process..."
    $existingProcess | ForEach-Object {
        Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 1
}

if (-Not (Test-Path $MeiliData)) {
    New-Item -ItemType Directory -Path $MeiliData -Force | Out-Null
}

$MeiliLogPath = Join-Path $MeiliDir "meilisearch.log"
$MeiliProcess = Start-Process -FilePath $MeiliBinary `
    -ArgumentList "--http-addr", "127.0.0.1:${MeiliPort}", `
                  "--master-key", $MeiliMasterKey, `
                  "--db-path", $MeiliData, `
                  "--env", "development" `
    -PassThru `
    -RedirectStandardOutput $MeiliLogPath `
    -RedirectStandardError (Join-Path $MeiliDir "meilisearch_err.log") `
    -WindowStyle Hidden

Write-Host "  PID: $($MeiliProcess.Id)"

# --------------------------------------------------
# Step 3: Wait for Meilisearch to be ready
# --------------------------------------------------
Write-Host ""
Write-Host "[3/6] Waiting for Meilisearch to be ready..." -ForegroundColor Yellow

$MaxRetries = 30
$RetryCount = 0
$Ready = $false

while (-Not $Ready -and $RetryCount -lt $MaxRetries) {
    try {
        $response = Invoke-RestMethod -Uri "http://127.0.0.1:${MeiliPort}/health" -Method Get -ErrorAction Stop
        if ($response.status -eq "available") {
            $Ready = $true
        }
    } catch {
        $RetryCount++
        Start-Sleep -Seconds 1
    }
}

if (-Not $Ready) {
    Write-Host "  ✗ Meilisearch failed to start after ${MaxRetries} attempts." -ForegroundColor Red
    Write-Host "  Check logs: $MeiliLogPath"
    exit 1
}

Write-Host "  ✓ Meilisearch is ready." -ForegroundColor Green

# --------------------------------------------------
# Step 4: Create SQLite database and run migrations
# --------------------------------------------------
Write-Host ""
Write-Host "[4/6] Setting up SQLite database..." -ForegroundColor Yellow

if (-Not (Test-Path $DataDir)) {
    New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
}

if (Test-Path $DbPath) {
    Write-Host "  Database already exists. Removing for fresh setup..."
    Remove-Item $DbPath -Force
}

# Check for sqlite3
if (-Not (Get-Command sqlite3 -ErrorAction SilentlyContinue)) {
    Write-Host "  ✗ sqlite3 is not installed or not in PATH." -ForegroundColor Red
    Write-Host "  Install SQLite from https://www.sqlite.org/download.html"
    Write-Host "  Or install via: winget install SQLite.SQLite"
    exit 1
}

$MigrateSql = Join-Path $ScriptsDir "migrate.sql"
sqlite3 $DbPath ".read '$MigrateSql'"
Write-Host "  ✓ Schema migration complete." -ForegroundColor Green

# --------------------------------------------------
# Step 5: Seed the database
# --------------------------------------------------
Write-Host ""
Write-Host "[5/6] Seeding database with initial data..." -ForegroundColor Yellow

$SeedSql = Join-Path $ScriptsDir "seed.sql"
sqlite3 $DbPath "PRAGMA foreign_keys = ON;"
sqlite3 $DbPath ".read '$SeedSql'"

$GeoCount = sqlite3 $DbPath "SELECT COUNT(*) FROM geo_entities;"
$PropCount = sqlite3 $DbPath "SELECT COUNT(*) FROM properties;"
Write-Host "  ✓ Seeded ${GeoCount} geo entities and ${PropCount} properties." -ForegroundColor Green

# --------------------------------------------------
# Step 6: Build and start the Rust backend
# --------------------------------------------------
Write-Host ""
Write-Host "[6/6] Building and starting the Rust backend..." -ForegroundColor Yellow

if (-Not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    Write-Host "  ✗ Rust/Cargo is not installed. Install from https://rustup.rs" -ForegroundColor Red
    exit 1
}

Push-Location $BackendDir
try {
    cargo build --release
    Write-Host "  ✓ Build complete." -ForegroundColor Green

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  Starting server on http://0.0.0.0:3000"    -ForegroundColor Cyan
    Write-Host "  Meilisearch: http://127.0.0.1:${MeiliPort}" -ForegroundColor Cyan
    Write-Host "  SQLite DB:   ${DbPath}"                     -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""

    cargo run --release
} finally {
    Pop-Location
    # Cleanup: stop Meilisearch when the backend exits
    if (-Not $MeiliProcess.HasExited) {
        Stop-Process -Id $MeiliProcess.Id -Force -ErrorAction SilentlyContinue
        Write-Host "Meilisearch stopped." -ForegroundColor Gray
    }
}
