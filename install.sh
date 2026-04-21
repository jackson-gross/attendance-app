#!/usr/bin/env bash
# =============================================================================
#  Attendance Tracker — One-line installer (Mac & Linux)
#  Usage:
#    curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/attendance-tracker/main/install.sh | bash
# =============================================================================
set -e

REPO_URL="https://github.com/YOUR_USERNAME/attendance-tracker"
INSTALL_DIR="$HOME/attendance-tracker"
PORT=5000

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log()     { echo -e "${BLUE}[attendance]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  📋  Attendance Tracker — Installer${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

OS="$(uname -s)"

# ── 1. Check / install Docker ─────────────────────────────────────────────────
log "Checking for Docker..."
if command -v docker &>/dev/null; then
  success "Docker already installed ($(docker --version | cut -d' ' -f3 | tr -d ','))"
else
  warn "Docker not found. Installing..."
  if [[ "$OS" == "Darwin" ]]; then
    if command -v brew &>/dev/null; then
      brew install --cask docker
      open /Applications/Docker.app
      log "Waiting for Docker Desktop to start..."
      until docker info &>/dev/null 2>&1; do sleep 2; done
      success "Docker installed via Homebrew"
    else
      error "Homebrew not found. Install Docker Desktop manually from https://www.docker.com/products/docker-desktop and re-run this script."
    fi
  elif [[ "$OS" == "Linux" ]]; then
    if command -v apt-get &>/dev/null; then
      sudo apt-get update -qq
      sudo apt-get install -y -qq ca-certificates curl gnupg lsb-release
      sudo install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      sudo chmod a+r /etc/apt/keyrings/docker.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
      sudo apt-get update -qq
      sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
      sudo systemctl enable docker
      sudo systemctl start docker
      sudo usermod -aG docker "$USER"
      success "Docker installed"
    elif command -v dnf &>/dev/null; then
      sudo dnf -y install dnf-plugins-core
      sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
      sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
      sudo systemctl enable docker
      sudo systemctl start docker
      sudo usermod -aG docker "$USER"
      success "Docker installed"
    else
      error "Unsupported Linux distro. Install Docker manually: https://docs.docker.com/engine/install/"
    fi
  else
    error "Unsupported OS: $OS"
  fi
fi

# ── 2. Check / install Docker Compose ────────────────────────────────────────
log "Checking for Docker Compose..."
if docker compose version &>/dev/null 2>&1; then
  success "Docker Compose available"
elif command -v docker-compose &>/dev/null; then
  success "docker-compose (legacy) available"
  COMPOSE_CMD="docker-compose"
else
  warn "Docker Compose plugin not found — installing..."
  if [[ "$OS" == "Linux" ]]; then
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
    sudo curl -SL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
      -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    COMPOSE_CMD="docker-compose"
    success "docker-compose installed"
  fi
fi
COMPOSE_CMD="${COMPOSE_CMD:-docker compose}"

# ── 3. Check port availability ────────────────────────────────────────────────
log "Checking port $PORT..."
if lsof -i ":$PORT" &>/dev/null 2>&1; then
  warn "Port $PORT is in use. Switching to 5001..."
  PORT=5001
fi
success "Using port $PORT"

# ── 4. Clone or update the repo ───────────────────────────────────────────────
if [[ -d "$INSTALL_DIR/.git" ]]; then
  log "Existing installation found — updating..."
  cd "$INSTALL_DIR"
  git pull --quiet
  success "Updated to latest version"
else
  log "Cloning repository to $INSTALL_DIR..."
  git clone --quiet "$REPO_URL" "$INSTALL_DIR"
  success "Repository cloned"
fi
cd "$INSTALL_DIR"

# ── 5. Update port in docker-compose.yml if needed ───────────────────────────
if [[ "$PORT" != "5000" ]]; then
  sed -i.bak "s|\"5000:5000\"|\"${PORT}:5000\"|g" docker-compose.yml
  rm -f docker-compose.yml.bak
fi

# ── 6. Build & start ──────────────────────────────────────────────────────────
log "Building and starting the app (this may take a minute on first run)..."
$COMPOSE_CMD down --remove-orphans 2>/dev/null || true
$COMPOSE_CMD up -d --build
success "App is running on http://localhost:$PORT"

# ── 7. Configure start on boot ───────────────────────────────────────────────
log "Configuring start on boot..."

if [[ "$OS" == "Darwin" ]]; then
  # macOS — launchd plist
  PLIST_DIR="$HOME/Library/LaunchAgents"
  PLIST_FILE="$PLIST_DIR/com.attendance-tracker.plist"
  mkdir -p "$PLIST_DIR"
  COMPOSE_BIN=$(command -v docker || echo "/usr/local/bin/docker")

  cat > "$PLIST_FILE" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.attendance-tracker</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-c</string>
    <string>cd $INSTALL_DIR &amp;&amp; $COMPOSE_BIN compose up -d</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <false/>
  <key>StandardOutPath</key>
  <string>$HOME/Library/Logs/attendance-tracker.log</string>
  <key>StandardErrorPath</key>
  <string>$HOME/Library/Logs/attendance-tracker-error.log</string>
</dict>
</plist>
PLIST

  launchctl unload "$PLIST_FILE" 2>/dev/null || true
  launchctl load "$PLIST_FILE"
  success "Boot startup configured (launchd)"

elif [[ "$OS" == "Linux" ]]; then
  if command -v systemctl &>/dev/null; then
    # systemd service
    DOCKER_COMPOSE_PATH=$(command -v docker || echo "/usr/bin/docker")
    sudo tee /etc/systemd/system/attendance-tracker.service > /dev/null <<SERVICE
[Unit]
Description=Attendance Tracker
Requires=docker.service
After=docker.service network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$INSTALL_DIR
ExecStart=$DOCKER_COMPOSE_PATH compose up -d --build
ExecStop=$DOCKER_COMPOSE_PATH compose down
Restart=on-failure

[Install]
WantedBy=multi-user.target
SERVICE

    sudo systemctl daemon-reload
    sudo systemctl enable attendance-tracker.service
    success "Boot startup configured (systemd)"
  else
    # Fallback: crontab @reboot
    CRON_CMD="@reboot cd $INSTALL_DIR && $COMPOSE_CMD up -d >> $HOME/attendance-tracker.log 2>&1"
    (crontab -l 2>/dev/null | grep -v attendance-tracker; echo "$CRON_CMD") | crontab -
    success "Boot startup configured (cron @reboot)"
  fi
fi

# ── 8. Done ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}  ✅  Installation complete!${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  🌐  Open:     ${BOLD}http://localhost:$PORT${NC}"
echo -e "  👤  Username: ${BOLD}admin${NC}"
echo -e "  🔑  Password: ${BOLD}admin${NC}  ← change this after first login"
echo ""
echo -e "  📁  Installed to: $INSTALL_DIR"
echo -e "  🔄  Auto-starts on boot: yes"
echo ""
echo -e "  To stop:    cd $INSTALL_DIR && $COMPOSE_CMD down"
echo -e "  To update:  cd $INSTALL_DIR && git pull && $COMPOSE_CMD up -d --build"
echo ""
