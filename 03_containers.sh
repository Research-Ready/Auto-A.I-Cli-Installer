#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

############################################
# 03_containers.sh
# Fedora 41+ Containers & Infrastructure
# Builds on 01_base_system.sh and 02_science_research.sh
# Focus: Podman-first, Docker optional, secure defaults
############################################

LOG_FILE="/var/log/fedora_03_containers.log"

############################
# Helpers (learned + stable)
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
  echo "Do not run as root. Run as a normal user with sudo access." >&2
  exit 1
fi

if ! is_fedora; then
  echo "This script is intended for Fedora systems only." >&2
  exit 1
fi

require_cmd sudo
sudo_keepalive
ensure_logfile

log "=== 03_containers starting ==="
log "Using package manager: $(dnf_cmd)"
log "Log file: $LOG_FILE"

############################
# Podman (rootless-first)
############################
log "Installing Podman and rootless container stack..."
dnf_install \
  podman \
  podman-compose \
  buildah \
  skopeo \
  slirp4netns \
  fuse-overlayfs \
  uidmap \
  containers-common

############################
# Enable user namespaces (defensive)
############################
log "Ensuring user namespaces are enabled..."
if ! sysctl user.max_user_namespaces >/dev/null 2>&1; then
  log "user.max_user_namespaces sysctl not present; skipping."
else
  CURRENT_NS="$(sysctl -n user.max_user_namespaces || echo 0)"
  if [[ "$CURRENT_NS" -lt 15000 ]]; then
    log "Raising user.max_user_namespaces to 15000..."
    run sudo sysctl -w user.max_user_namespaces=15000
    echo "user.max_user_namespaces=15000" | sudo tee /etc/sysctl.d/99-containers.conf >/dev/null
  else
    log "user.max_user_namespaces already sufficient."
  fi
fi

############################
# Podman sanity checks
############################
log "Running Podman sanity checks..."
podman info >/dev/null 2>&1 || log "WARNING: podman info failed (may still work rootless after relogin)"

############################
# Docker (optional but common)
############################
log "Installing Docker Engine and Compose plugin..."
dnf_install \
  docker \
  docker-compose-plugin

log "Enabling Docker daemon..."
run sudo systemctl enable --now docker

############################
# Docker group (non-root usage)
############################
if getent group docker >/dev/null 2>&1; then
  if id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
    log "User already in docker group."
  else
    log "Adding user to docker group (requires logout/login)..."
    run sudo usermod -aG docker "$USER"
  fi
else
  log "Docker group not found (unexpected)."
fi

############################
# Container networking tools
############################
log "Installing container networking and debugging tools..."
dnf_install \
  netavark \
  aardvark-dns \
  dnsmasq \
  socat

############################
# Container security defaults
############################
log "Applying container security defaults..."

# Ensure linger for rootless containers (allows user services)
if loginctl show-user "$USER" | grep -q "Linger=no"; then
  log "Enabling user linger for rootless containers..."
  run sudo loginctl enable-linger "$USER"
else
  log "User linger already enabled."
fi

############################
# Cleanup
############################
log "Cleaning package manager caches..."
run sudo "$(dnf_cmd)" clean all

log "=== 03_containers completed successfully ==="
log "NOTE: Logout/login recommended for docker group & rootless podman stability."
exit 0
