#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

############################################
# 02_science_research.sh
# Fedora 41+ Science & Research Stack
# Builds on 01_base_system.sh
############################################

LOG_FILE="/var/log/fedora_02_science_research.log"

############################
# Helpers
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

log "=== 02_science_research starting ==="
log "Using package manager: $(dnf_cmd)"
log "Log file: $LOG_FILE"

############################
# Fedora Science group
############################
log "Installing Fedora Science group..."

if command -v dnf5 >/dev/null 2>&1; then
  if ! run sudo dnf5 install -y @science; then
    log "Science group install failed or not found; continuing with explicit packages."
  fi
else
  run sudo dnf groupinstall -y "Fedora Science" || \
    log "Science group install failed; continuing with explicit packages."
fi

############################
# Core scientific languages
############################
log "Installing core scientific languages and runtimes..."
dnf_install \
  python3 python3-devel python3-pip python3-virtualenv \
  R R-devel \
  julia \
  octave \
  java-21-openjdk

############################
# Scientific tooling & math
############################
log "Installing scientific tooling and math libraries..."
dnf_install \
  gnuplot \
  graphviz \
  lapack lapack-devel \
  blas blas-devel \
  fftw fftw-devel \
  gsl gsl-devel

############################
# Data & file formats
############################
log "Installing data and file format tooling..."
dnf_install \
  hdf5 hdf5-devel \
  netcdf netcdf-devel \
  sqlite sqlite-devel \
  postgresql postgresql-server postgresql-contrib \
  libxml2 libxml2-devel \
  libxslt libxslt-devel

############################
# Notebooks & publishing
############################
log "Installing notebooks and publishing tools..."
dnf_install \
  jupyterlab \
  pandoc \
  texlive-scheme-basic \
  texlive-collection-latex \
  texlive-collection-fontsrecommended

############################
# Quarto
############################
log "Installing Quarto..."
if ! command -v quarto >/dev/null 2>&1; then
  if "$(dnf_cmd)" repoquery quarto >/dev/null 2>&1; then
    dnf_install quarto
  else
    log "Quarto not available via repos; skipping (can be installed later)."
  fi
else
  log "Quarto already installed."
fi

############################
# Research utilities
############################
log "Installing research utilities..."
dnf_install \
  rclone \
  syncthing \
  imagemagick \
  poppler-utils \
  ghostscript

############################
# Cleanup
############################
log "Cleaning package manager caches..."
run sudo "$(dnf_cmd)" clean all

log "=== 02_science_research completed successfully ==="
exit 0
