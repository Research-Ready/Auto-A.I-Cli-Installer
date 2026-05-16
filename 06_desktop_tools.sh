#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

############################################
# 06_desktop_tools.sh
# Fedora 41+ Desktop, Research, Knowledge & Daily Ops
# Flatpak-first, FOSS-first, safe & optional
############################################

LOG_FILE="/var/log/fedora_06_desktop_tools.log"

############################
# Helpers (same proven pattern)
############################
timestamp() { date +'%Y-%m-%d %H:%M:%S'; }

log() {
  local msg="$(timestamp) - $*"
  echo "$msg"
  echo "$msg" | sudo tee -a "$LOG_FILE" >/dev/null
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { log "Missing required command: $1"; exit 1; }
}

is_fedora() {
  [[ -r /etc/os-release ]] || return 1
  . /etc/os-release
  [[ "${ID:-}" == "fedora" ]]
}

dnf_cmd() {
  command -v dnf5 >/dev/null 2>&1 && echo "dnf5" || echo "dnf"
}

sudo_keepalive() {
  sudo -v
  ( while true; do sudo -n true; sleep 60; done ) >/dev/null 2>&1 &
  SUDO_PID=$!
  trap 'kill "${SUDO_PID:-0}" >/dev/null 2>&1 || true' EXIT
}

ensure_logfile() {
  sudo install -m 0600 -o root -g root /dev/null "$LOG_FILE" 2>/dev/null || true
}

run() {
  log "RUN: $*"
  "$@" 2>&1 | sudo tee -a "$LOG_FILE" >/dev/null
}

dnf_install() {
  local dnf; dnf="$(dnf_cmd)"
  run sudo "$dnf" install -y "$@"
}

############################
# Preconditions
############################
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  echo "Do not run as root." >&2
  exit 1
fi

if ! is_fedora; then
  echo "This script is intended for Fedora systems only." >&2
  exit 1
fi

require_cmd sudo
sudo_keepalive
ensure_logfile

log "=== 06_desktop_tools starting ==="
log "Log file: $LOG_FILE"

############################
# Flatpak base
############################
log "Installing Flatpak and enabling Flathub..."
dnf_install flatpak
run flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

############################
# Core desktop & communication
############################
log "Installing core desktop applications..."
run flatpak install -y flathub \
  org.mozilla.firefox \
  org.mozilla.Thunderbird \
  org.keepassxc.KeePassXC \
  org.signal.Signal \
  com.slack.Slack

############################
# Knowledge, research & writing
############################
log "Installing knowledge management & research tools..."
run flatpak install -y flathub \
  md.obsidian.Obsidian \
  org.zotero.Zotero \
  org.joplin.Joplin \
  org.kde.okular

############################
# Development & diagrams
############################
log "Installing development and diagramming tools..."
run flatpak install -y flathub \
  com.visualstudio.code \
  org.drawio.drawio \
  org.inkscape.Inkscape \
  org.gimp.GIMP \
  org.libreoffice.LibreOffice \
  io.github.shiftey.Desktop

############################
# Utilities & sandboxing
############################
log "Installing utilities and Flatpak permission manager..."
run flatpak install -y flathub \
  com.github.tchx84.Flatseal

############################
# Optional: media & recording (useful for teaching)
############################
log "Installing optional media tools..."
run flatpak install -y flathub \
  com.obsproject.Studio \
  org.kde.kdenlive

############################
# Cleanup
############################
log "Cleaning package manager caches..."
run sudo "$(dnf_cmd)" clean all

log "=== 06_desktop_tools completed successfully ==="
log "NOTE: Flatpak apps may require a session restart to appear in menus."
exit 0
