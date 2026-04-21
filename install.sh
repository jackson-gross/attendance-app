#!/usr/bin/env bash
# =============================================================================
#  Attendance Tracker — One-line installer (Mac, Linux, Raspberry Pi)
#  Usage:
#    curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/attendance-tracker/main/install.sh | bash
# =============================================================================
set -e

REPO_URL="https://github.com/YOUR_USERNAME/attendance-tracker"
INSTALL_DIR="$HOME/attendance-tracker"
PORT=5000

# ── Colours ───────────────────────────────────────────────────────────────────
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
ARCH="$(uname -m)"

# ── Detect Linux distro details ───────────────────────────────────────────────
# Reads /etc/os-release which exists on all modern Linux distros
if [[ "$OS" == "Linux" ]] && [[ -f /etc/os-release ]]; then
  source /etc/os-release
  DISTRO_ID="${ID,,}"           # e.g. ubuntu, debian, raspbian, fedora, centos, arch
  DISTRO_ID_LIKE="${ID_LIKE,,}" # e.g. "debian" for raspbian, "rhel fedora" for centos
  DISTRO_CODENAME="${VERSION_CODENAME:-}"
  DISTRO_VERSION="${VERSION_ID:-}"
  log "Detected: $PRETTY_NAME ($ARCH)"
else
  DISTRO_ID=""
  DISTRO_ID_LIKE=""
  DISTRO_CODENAME=""
fi

# Helper: is this distro debian-family?
is_debian_family() {
  [[ "$DISTRO_ID" == "debian"   ]] || \
  [[ "$DISTRO_ID" == "ubuntu"   ]] || \
  [[ "$DISTRO_ID" == "raspbian" ]] || \
  [[ "$DISTRO_ID" == "linuxmint" ]] || \
  [[ "$DISTRO_ID" == "pop"      ]] || \
  [[ "$DISTRO_ID" == "elementary" ]] || \
  [[ "$DISTRO_ID" == "kali"     ]] || \
  [[ "$DISTRO_ID" == "parrot"   ]] || \
  [[ "$DISTRO_ID_LIKE" == *"debian"* ]] || \
  [[ "$DISTRO_ID_LIKE" == *"ubuntu"* ]]
}

# Helper: is this distro rhel-family?
is_rhel_family() {
  [[ "$DISTRO_ID" == "rhel"     ]] || \
  [[ "$DISTRO_ID" == "centos"   ]] || \
  [[ "$DISTRO_ID" == "almalinux" ]] || \
  [[ "$DISTRO_ID" == "rocky"    ]] || \
  [[ "$DISTRO_ID" == "ol"       ]] || \
  [[ "$DISTRO_ID_LIKE" == *"rhel"* ]] || \
  [[ "$DISTRO_ID_LIKE" == *"centos"* ]]
}

# ── Install Docker ────────────────────────────────────────────────────────────
install_docker_debian() {
  # Works for: Ubuntu, Debian, Raspberry Pi OS (raspbian), Mint, Pop!_OS, Kali, etc.
  log "Installing Docker for Debian/Ubuntu family..."
  sudo apt-get update -qq
  sudo apt-get install -y -qq ca-certificates curl gnupg lsb-release git

  sudo install -m 0755 -d /etc/apt/keyrings

  # Determine the correct Docker repo to use:
  # - raspbian and Raspberry Pi OS (arm) use the "debian" repo
  # - ubuntu and ubuntu-based distros use the "ubuntu" repo
  # - pure debian uses the "debian" repo
  # Map any unreleased/unknown codename to the latest stable Docker supports
  remap_debian_codename() {
    case "$1" in
      buster|bullseye|bookworm) echo "$1" ;;
      *) echo "bookworm" ;;   # trixie, forky, or unknown -> latest stable
    esac
  }
  remap_ubuntu_codename() {
    case "$1" in
      bionic|focal|jammy|noble) echo "$1" ;;
      *) echo "noble" ;;   # unreleased or unknown -> latest stable
    esac
  }

  if [[ "$DISTRO_ID" == "ubuntu" ]] || [[ "$DISTRO_ID_LIKE" == *"ubuntu"* && "$DISTRO_ID" != "raspbian" ]]; then
    DOCKER_DISTRO="ubuntu"
    RAW_CODENAME="${UBUNTU_CODENAME:-$DISTRO_CODENAME}"
    DOCKER_CODENAME="$(remap_ubuntu_codename "$RAW_CODENAME")"
  else
    # Debian, Raspberry Pi OS, Kali, Parrot, and any other debian-like
    DOCKER_DISTRO="debian"
    if [[ "$DISTRO_ID" == "kali" ]]; then
      DOCKER_CODENAME="bookworm"
    else
      DOCKER_CODENAME="$(remap_debian_codename "$DISTRO_CODENAME")"
    fi
  fi

  log "Using Docker repo: $DOCKER_DISTRO / $DOCKER_CODENAME"

  curl -fsSL "https://download.docker.com/linux/${DOCKER_DISTRO}/gpg" \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/${DOCKER_DISTRO} ${DOCKER_CODENAME} stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt-get update -qq
  sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
  sudo systemctl enable docker
  sudo systemctl start docker
  sudo usermod -aG docker "$USER"
  success "Docker installed (debian family)"
}

install_docker_fedora() {
  log "Installing Docker for Fedora..."
  sudo dnf -y install dnf-plugins-core git
  sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
  sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  sudo systemctl enable docker
  sudo systemctl start docker
  sudo usermod -aG docker "$USER"
  success "Docker installed (Fedora)"
}

install_docker_rhel() {
  log "Installing Docker for RHEL/CentOS/AlmaLinux/Rocky..."
  # Use CentOS repo — compatible with RHEL-family
  sudo dnf -y install dnf-plugins-core git 2>/dev/null || \
    sudo yum -y install yum-utils git
  sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo 2>/dev/null || \
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin 2>/dev/null || \
    sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  sudo systemctl enable docker
  sudo systemctl start docker
  sudo usermod -aG docker "$USER"
  success "Docker installed (RHEL family)"
}

install_docker_opensuse() {
  log "Installing Docker for openSUSE..."
  sudo zypper -n install docker docker-compose git
  sudo systemctl enable docker
  sudo systemctl start docker
  sudo usermod -aG docker "$USER"
  success "Docker installed (openSUSE)"
}

install_docker_arch() {
  log "Installing Docker for Arch Linux..."
  sudo pacman -Sy --noconfirm docker docker-compose git
  sudo systemctl enable docker
  sudo systemctl start docker
  sudo usermod -aG docker "$USER"
  success "Docker installed (Arch)"
}

install_docker_alpine() {
  log "Installing Docker for Alpine Linux..."
  sudo apk add --no-cache docker docker-compose git
  sudo rc-update add docker default
  sudo service docker start
  sudo addgroup "$USER" docker 2>/dev/null || true
  success "Docker installed (Alpine)"
}

install_docker_gentoo() {
  log "Installing Docker for Gentoo..."
  sudo emerge --ask=n app-containers/docker app-containers/docker-compose dev-vcs/git
  sudo rc-update add docker default
  sudo service docker start
  success "Docker installed (Gentoo)"
}

# ── 1. Check / install Docker ─────────────────────────────────────────────────
log "Checking for Docker..."
if command docker -v &>/dev/null && docker info &>/dev/null 2>&1; then
  success "Docker already installed ($(docker --version | cut -d' ' -f3 | tr -d ','))"
else
  warn "Docker not found or not running. Installing..."

  if [[ "$OS" == "Darwin" ]]; then
    if command -v brew &>/dev/null; then
      brew install --cask docker
      open /Applications/Docker.app
      log "Waiting for Docker Desktop to start (this can take ~30 seconds)..."
      WAIT=0
      until docker info &>/dev/null 2>&1; do
        sleep 3; WAIT=$((WAIT+3))
        if [[ $WAIT -gt 120 ]]; then
          error "Docker Desktop didn't start in time. Open it manually and re-run this script."
        fi
      done
      success "Docker Desktop started"
    else
      error "Homebrew not found. Install it first: https://brew.sh — or install Docker Desktop manually: https://www.docker.com/products/docker-desktop"
    fi

  elif [[ "$OS" == "Linux" ]]; then
    # Check if this is a Raspberry Pi regardless of distro
    IS_RPI=false
    if grep -qi "raspberry pi" /proc/cpuinfo 2>/dev/null || \
       grep -qi "raspberry" /proc/device-tree/model 2>/dev/null || \
       [[ "$DISTRO_ID" == "raspbian" ]]; then
      IS_RPI=true
      log "Raspberry Pi detected"
    fi

    if [[ "$DISTRO_ID" == "fedora" ]]; then
      install_docker_fedora
    elif [[ "$DISTRO_ID" == "arch" ]] || [[ "$DISTRO_ID" == "manjaro" ]] || [[ "$DISTRO_ID_LIKE" == *"arch"* ]]; then
      install_docker_arch
    elif [[ "$DISTRO_ID" == "opensuse"* ]] || [[ "$DISTRO_ID_LIKE" == *"suse"* ]]; then
      install_docker_opensuse
    elif [[ "$DISTRO_ID" == "alpine" ]]; then
      install_docker_alpine
    elif [[ "$DISTRO_ID" == "gentoo" ]]; then
      install_docker_gentoo
    elif is_rhel_family; then
      install_docker_rhel
    elif is_debian_family; then
      install_docker_debian
    else
      # Last resort: Docker's convenience script handles almost everything
      warn "Unknown distro '$DISTRO_ID' — trying Docker's universal install script..."
      curl -fsSL https://get.docker.com | sudo sh
      sudo systemctl enable docker 2>/dev/null || true
      sudo systemctl start docker 2>/dev/null || true
      sudo usermod -aG docker "$USER" 2>/dev/null || true
      success "Docker installed via convenience script"
    fi
  else
    error "Unsupported OS: $OS"
  fi
fi

# ── 2. Check / install Git ────────────────────────────────────────────────────
log "Checking for Git..."
if command -v git &>/dev/null; then
  success "Git already installed"
else
  warn "Git not found — installing..."
  if [[ "$OS" == "Darwin" ]]; then
    xcode-select --install 2>/dev/null || brew install git
  elif [[ "$OS" == "Linux" ]]; then
    if is_debian_family; then sudo apt-get install -y -qq git
    elif [[ "$DISTRO_ID" == "fedora" ]]; then sudo dnf install -y git
    elif is_rhel_family; then sudo yum install -y git
    elif [[ "$DISTRO_ID" == "arch"* ]] || [[ "$DISTRO_ID_LIKE" == *"arch"* ]]; then sudo pacman -Sy --noconfirm git
    elif [[ "$DISTRO_ID" == "alpine" ]]; then sudo apk add --no-cache git
    elif [[ "$DISTRO_ID" == "opensuse"* ]]; then sudo zypper -n install git
    else curl -fsSL https://get.docker.com | sudo sh  # usually pulls git too
    fi
  fi
  success "Git installed"
fi

# ── 3. Confirm Docker Compose is available ────────────────────────────────────
log "Checking for Docker Compose..."
if docker compose version &>/dev/null 2>&1; then
  COMPOSE_CMD="docker compose"
  success "Docker Compose plugin available"
elif command -v docker-compose &>/dev/null; then
  COMPOSE_CMD="docker-compose"
  success "docker-compose (legacy) available"
else
  warn "Docker Compose not found — installing standalone binary..."
  COMPOSE_VERSION=$(curl -fsSL https://api.github.com/repos/docker/compose/releases/latest \
    | grep '"tag_name"' | cut -d'"' -f4)
  COMPOSE_ARCH="$ARCH"
  # Normalise arm names for the compose binary filenames
  [[ "$ARCH" == "armv7l" ]] && COMPOSE_ARCH="armv7"
  [[ "$ARCH" == "aarch64" ]] && COMPOSE_ARCH="aarch64"
  sudo curl -fsSL \
    "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-${COMPOSE_ARCH}" \
    -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
  COMPOSE_CMD="docker-compose"
  success "docker-compose $COMPOSE_VERSION installed"
fi

# ── 4. Check port availability ────────────────────────────────────────────────
log "Checking port $PORT..."
if command -v lsof &>/dev/null; then
  PORT_CHECK=$(lsof -i ":$PORT" 2>/dev/null)
elif command -v ss &>/dev/null; then
  PORT_CHECK=$(ss -tlnp 2>/dev/null | grep ":$PORT ")
else
  PORT_CHECK=""
fi
if [[ -n "$PORT_CHECK" ]]; then
  warn "Port $PORT is in use — switching to 5001"
  PORT=5001
fi
success "Using port $PORT"

# ── 5. Clone or update repo ───────────────────────────────────────────────────
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

# ── 6. Patch port in docker-compose.yml if needed ────────────────────────────
if [[ "$PORT" != "5000" ]]; then
  sed -i.bak "s|\"5000:5000\"|\"${PORT}:5000\"|g" docker-compose.yml
  rm -f docker-compose.yml.bak
fi

# ── 7. Build & start ──────────────────────────────────────────────────────────
log "Building and starting the app (first run may take a few minutes)..."

# If we added user to docker group but haven't relogged, run via sudo for this session
if ! docker info &>/dev/null 2>&1; then
  warn "Docker requires elevated permissions for this session (user was just added to docker group)."
  warn "Using sudo for this run — you won't need it after logging out and back in."
  DOCKER_PREFIX="sudo"
else
  DOCKER_PREFIX=""
fi

$DOCKER_PREFIX $COMPOSE_CMD down --remove-orphans 2>/dev/null || true
$DOCKER_PREFIX $COMPOSE_CMD up -d --build
success "App is running on http://localhost:$PORT"

# ── 8. Configure start on boot ───────────────────────────────────────────────
log "Configuring start on boot..."
DOCKER_BIN=$(command -v docker)

if [[ "$OS" == "Darwin" ]]; then
  # macOS — launchd plist
  PLIST_DIR="$HOME/Library/LaunchAgents"
  PLIST_FILE="$PLIST_DIR/com.attendance-tracker.plist"
  mkdir -p "$PLIST_DIR"
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
    <string>cd ${INSTALL_DIR} &amp;&amp; ${DOCKER_BIN} compose up -d</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <false/>
  <key>StandardOutPath</key>
  <string>${HOME}/Library/Logs/attendance-tracker.log</string>
  <key>StandardErrorPath</key>
  <string>${HOME}/Library/Logs/attendance-tracker-error.log</string>
</dict>
</plist>
PLIST
  launchctl unload "$PLIST_FILE" 2>/dev/null || true
  launchctl load "$PLIST_FILE"
  success "Boot startup configured (launchd)"

elif [[ "$OS" == "Linux" ]]; then
  if command -v systemctl &>/dev/null && systemctl is-system-running &>/dev/null 2>&1; then
    # systemd — covers Raspberry Pi OS, Ubuntu, Debian, Fedora, Arch, etc.
    sudo tee /etc/systemd/system/attendance-tracker.service > /dev/null <<SERVICE
[Unit]
Description=Attendance Tracker
Requires=docker.service
After=docker.service network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${INSTALL_DIR}
ExecStart=${DOCKER_BIN} compose up -d
ExecStop=${DOCKER_BIN} compose down
User=${USER}
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE
    sudo systemctl daemon-reload
    sudo systemctl enable attendance-tracker.service
    success "Boot startup configured (systemd)"

  elif command -v rc-update &>/dev/null; then
    # OpenRC — Alpine, Gentoo
    INIT_SCRIPT="/etc/init.d/attendance-tracker"
    sudo tee "$INIT_SCRIPT" > /dev/null <<OPENRC
#!/sbin/openrc-run
description="Attendance Tracker"
depend() { need docker net; }
start() {
  cd ${INSTALL_DIR} && ${DOCKER_BIN} compose up -d
}
stop() {
  cd ${INSTALL_DIR} && ${DOCKER_BIN} compose down
}
OPENRC
    sudo chmod +x "$INIT_SCRIPT"
    sudo rc-update add attendance-tracker default
    success "Boot startup configured (OpenRC)"

  else
    # Fallback — crontab @reboot (works everywhere)
    CRON_CMD="@reboot sleep 10 && cd ${INSTALL_DIR} && ${DOCKER_BIN} compose up -d >> ${HOME}/attendance-tracker.log 2>&1"
    ( crontab -l 2>/dev/null | grep -v attendance-tracker; echo "$CRON_CMD" ) | crontab -
    success "Boot startup configured (cron @reboot)"
  fi
fi

# ── 9. Done ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}  ✅  Installation complete!${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  🌐  Open:     ${BOLD}http://localhost:$PORT${NC}"

# On Pi/headless Linux, show the LAN IP as well
if [[ "$OS" == "Linux" ]]; then
  LAN_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
  if [[ -n "$LAN_IP" ]]; then
    echo -e "  📡  On network: ${BOLD}http://${LAN_IP}:${PORT}${NC}"
  fi
fi

echo -e "  👤  Username: ${BOLD}admin${NC}"
echo -e "  🔑  Password: ${BOLD}admin${NC}  ← change this after first login"
echo ""
echo -e "  📁  Installed to: $INSTALL_DIR"
echo -e "  🔄  Auto-starts on boot: yes"
echo ""
echo -e "  To stop:   cd $INSTALL_DIR && $COMPOSE_CMD down"
echo -e "  To update: cd $INSTALL_DIR && git pull && $COMPOSE_CMD up -d --build"
echo ""

# Remind user to re-login if they were just added to the docker group
if groups "$USER" 2>/dev/null | grep -qv docker; then
  echo -e "${YELLOW}  ⚠️  Log out and back in (or run 'newgrp docker') to use Docker without sudo.${NC}"
  echo ""
fi
