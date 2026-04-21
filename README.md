# 📋 Attendance Tracker

A self-hosted attendance web app that runs in Docker. Manage a people database, take AM and PM attendance, view reports, and export timestamped Excel files. Works great on desktop, tablet, and mobile — and can be saved to your iPhone home screen as a PWA.

---

## One-Line Install

### Mac & Linux
```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/attendance-tracker/main/install.sh | bash
```

### Windows (PowerShell — run as Administrator)
```powershell
irm https://raw.githubusercontent.com/YOUR_USERNAME/attendance-tracker/main/install.ps1 | iex
```

The installer will:
- Install Docker if it isn't already present
- Clone this repository
- Build and start the app
- Configure it to **start automatically on boot/login**

After install, open **http://localhost:5000** in your browser.

> **Default credentials:** username `admin` / password `admin`
> Change these immediately in the Settings tab after first login.

---

## Requirements

- [Docker Desktop](https://www.docker.com/products/docker-desktop) (Mac/Windows) or Docker Engine (Linux)
- Git
- An internet connection for first install

---

## Features

- **AM & PM attendance** — separate morning and afternoon records per day
- **People database** — add, edit, and delete people with optional email
- **Attendance log** — browse and filter by date and session
- **Reports** — date-range summaries with per-person AM/PM present rates
- **Excel export** — timestamped `.xlsx` with log and summary sheets
- **Admin login** — username/password with in-app credential management
- **PWA** — save to iPhone/Android home screen for a native-app feel
- **Responsive** — optimised for mobile, tablet, and desktop

---

## Manual Install

```bash
git clone https://github.com/YOUR_USERNAME/attendance-tracker.git
cd attendance-tracker
docker compose up -d --build
```

Open **http://localhost:5000**

---

## Updating

```bash
cd ~/attendance-tracker
git pull
docker compose up -d --build
```

---

## Data & Backups

Data is stored in a Docker volume that persists across restarts and rebuilds.

**Back up:**
```bash
docker cp attendance-attendance-1:/data/attendance.db ./backup_$(date +%Y%m%d).db
```

**Restore:**
```bash
docker cp ./backup.db attendance-attendance-1:/data/attendance.db
docker compose restart
```

---

## Configuration

| Setting | Default | How to change |
|---|---|---|
| Port | `5000` | Edit `ports` in `docker-compose.yml` |
| Secret key | Built-in default | Set `SECRET_KEY` env var |

**Example `docker-compose.yml` with custom port and secret:**
```yaml
ports:
  - "8080:5000"
environment:
  - SECRET_KEY=your-long-random-secret-here
  - DATABASE_URL=sqlite:////data/attendance.db
```

---

## Removing Boot Startup

**Mac:**
```bash
launchctl unload ~/Library/LaunchAgents/com.attendance-tracker.plist
rm ~/Library/LaunchAgents/com.attendance-tracker.plist
```

**Linux:**
```bash
sudo systemctl disable attendance-tracker
sudo rm /etc/systemd/system/attendance-tracker.service
sudo systemctl daemon-reload
```

**Windows:**
```powershell
Unregister-ScheduledTask -TaskName "AttendanceTracker" -Confirm:$false
```

---

## Uninstall

```bash
cd ~/attendance-tracker
docker compose down -v
cd .. && rm -rf attendance-tracker
```
