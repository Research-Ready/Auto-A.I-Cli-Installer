#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

############################################
# 04_gpu_acceleration.sh
# Fedora 41+ GPU & Acceleration Setup
# NVIDIA-focused, safe-by-default, isolated
############################################

LOG_FILE="/var/log/fedora_04_gpu_acceleration.log"

############################
# Helpers (same pattern as 01–03)
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

log "=== 04_gpu_acceleration starting ==="
log "Using package manager: $(dnf_cmd)"
log "Log file: $LOG_FILE"

############################
# Detect GPU
############################
log "Detecting GPU hardware..."
GPU_INFO="$(lspci | grep -Ei 'vga|3d|display' || true)"
echo "$GPU_INFO" | sudo tee -a "$LOG_FILE" >/dev/null

if echo "$GPU_INFO" | grep -qi nvidia; then
  GPU_VENDOR="nvidia"
elif echo "$GPU_INFO" | grep -qi amd; then
  GPU_VENDOR="amd"
else
  GPU_VENDOR="unknown"
fi

log "Detected GPU vendor: $GPU_VENDOR"

############################
# NVIDIA stack (RPM Fusion)
############################
if [[ "$GPU_VENDOR" == "nvidia" ]]; then
  log "Installing NVIDIA drivers and CUDA support (RPM Fusion)..."

  dnf_install \
    akmod-nvidia \
    xorg-x11-drv-nvidia-cuda \
    nvidia-modprobe \
    nvidia-settings

  log "Enabling NVIDIA persistence daemon if available..."
  if systemctl list-unit-files | grep -q nvidia-persistenced; then
    run sudo systemctl enable --now nvidia-persistenced
  fi

  log "Blacklisting nouveau driver..."
  echo -e "blacklist nouveau\noptions nouveau modeset=0" | \
    sudo tee /etc/modprobe.d/blacklist-nouveau.conf >/dev/null

  log "Regenerating initramfs (required for NVIDIA)..."
  run sudo dracut --force

  log "NVIDIA installation complete. Reboot REQUIRED."
fi

############################
# AMD stack (Mesa + ROCm-light)
############################
if [[ "$GPU_VENDOR" == "amd" ]]; then
  log "Installing AMD GPU stack (Mesa + ROCm user-space)..."

  dnf_install \
    mesa-dri-drivers \
    mesa-vulkan-drivers \
    mesa-libOpenCL \
    rocm-opencl \
    rocm-runtime

  log "AMD GPU stack installed."
fi

############################
# Validation tools
############################
log "Installing GPU validation tools..."
dnf_install \
  clinfo \
  vulkan-tools \
  glx-utils

############################
# Notes & cleanup
############################
log "Cleaning package manager caches..."
run sudo "$(dnf_cmd)" clean all

log "=== 04_gpu_acceleration completed ==="

if [[ "$GPU_VENDOR" == "nvidia" ]]; then
  log "IMPORTANT: You MUST reboot before using NVIDIA CUDA."
fi

exit 0
