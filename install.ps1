# =============================================================================
#  Attendance Tracker — One-line installer (Windows PowerShell)
#  Usage (run PowerShell as Administrator):
#    irm https://raw.githubusercontent.com/YOUR_USERNAME/attendance-tracker/main/install.ps1 | iex
# =============================================================================
$ErrorActionPreference = "Stop"

$REPO_URL   = "https://github.com/YOUR_USERNAME/attendance-tracker"
$INSTALL_DIR = "$env:USERPROFILE\attendance-tracker"
$PORT = 5000

function Write-Step  { Write-Host "[attendance] $args" -ForegroundColor Cyan }
function Write-Ok    { Write-Host "[ok] $args" -ForegroundColor Green }
function Write-Warn  { Write-Host "[!] $args" -ForegroundColor Yellow }
function Write-Fail  { Write-Host "[x] $args" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor White
Write-Host "  📋  Attendance Tracker — Windows Installer"       -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor White
Write-Host ""

# ── 1. Check for Docker ───────────────────────────────────────────────────────
Write-Step "Checking for Docker..."
if (Get-Command docker -ErrorAction SilentlyContinue) {
    Write-Ok "Docker already installed"
} else {
    Write-Warn "Docker not found."
    Write-Warn "Please install Docker Desktop from: https://www.docker.com/products/docker-desktop"
    Write-Warn "Then re-run this script."
    Start-Process "https://www.docker.com/products/docker-desktop"
    exit 1
}

# ── 2. Check for Git ──────────────────────────────────────────────────────────
Write-Step "Checking for Git..."
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Warn "Git not found. Installing via winget..."
    winget install --id Git.Git -e --source winget --silent
    $env:PATH += ";C:\Program Files\Git\bin"
    Write-Ok "Git installed"
} else {
    Write-Ok "Git already installed"
}

# ── 3. Check port ─────────────────────────────────────────────────────────────
Write-Step "Checking port $PORT..."
$portInUse = netstat -ano | Select-String ":$PORT " | Where-Object { $_ -match "LISTENING" }
if ($portInUse) {
    Write-Warn "Port $PORT in use — switching to 5001"
    $PORT = 5001
}
Write-Ok "Using port $PORT"

# ── 4. Clone or update ───────────────────────────────────────────────────────
if (Test-Path "$INSTALL_DIR\.git") {
    Write-Step "Existing install found — updating..."
    Set-Location $INSTALL_DIR
    git pull --quiet
    Write-Ok "Updated"
} else {
    Write-Step "Cloning repository to $INSTALL_DIR..."
    git clone --quiet $REPO_URL $INSTALL_DIR
    Write-Ok "Cloned"
}
Set-Location $INSTALL_DIR

# ── 5. Update port if needed ─────────────────────────────────────────────────
if ($PORT -ne 5000) {
    (Get-Content docker-compose.yml) -replace '"5000:5000"', "`"${PORT}:5000`"" |
        Set-Content docker-compose.yml
}

# ── 6. Build & start ─────────────────────────────────────────────────────────
Write-Step "Building and starting the app..."
docker compose down --remove-orphans 2>$null
docker compose up -d --build
Write-Ok "App running at http://localhost:$PORT"

# ── 7. Boot startup via Task Scheduler ───────────────────────────────────────
Write-Step "Configuring start on boot (Task Scheduler)..."

$taskName = "AttendanceTracker"
$dockerPath = (Get-Command docker).Source
$action = New-ScheduledTaskAction `
    -Execute $dockerPath `
    -Argument "compose up -d" `
    -WorkingDirectory $INSTALL_DIR

$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 5) -RestartCount 3

# Remove existing task if present
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Description "Start Attendance Tracker Docker container at login" | Out-Null

Write-Ok "Boot startup configured (Task Scheduler: '$taskName')"

# ── 8. Done ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "  ✅  Installation complete!"                        -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host ""
Write-Host "  Open:     http://localhost:$PORT"
Write-Host "  Username: admin"
Write-Host "  Password: admin  <- change after first login"
Write-Host ""
Write-Host "  Installed to: $INSTALL_DIR"
Write-Host "  Auto-starts on login: yes"
Write-Host ""
Write-Host "  To stop:   cd $INSTALL_DIR; docker compose down"
Write-Host "  To update: cd $INSTALL_DIR; git pull; docker compose up -d --build"
Write-Host ""
