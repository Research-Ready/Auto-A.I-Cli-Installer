#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

############################################
# 05_ai_envs.sh
# Fedora 41+ AI / Data / Simulation Environments
# Python isolation, reproducible, no system pip pollution
############################################

LOG_FILE="/var/log/fedora_05_ai_envs.log"
VENVS_DIR="$HOME/.venvs"

VENV_DATA="ai-data"
VENV_LLM="ai-llm"
VENV_SIM="ai-sim"

############################
# Helpers (stable pattern)
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

log "=== 05_ai_envs starting ==="
log "Log file: $LOG_FILE"

############################
# Base Python tooling
############################
log "Installing Python tooling for isolated environments..."
dnf_install \
  python3 \
  python3-devel \
  python3-pip \
  python3-virtualenv \
  pipx

run pipx ensurepath

############################
# uv (fast modern Python package manager)
############################
if ! command -v uv >/dev/null 2>&1; then
  log "Installing uv via pipx..."
  run pipx install uv
else
  log "uv already installed."
fi

############################
# Prepare venv directory
############################
log "Preparing virtual environment directory..."
mkdir -p "$VENVS_DIR"
chmod 0700 "$VENVS_DIR"

############################
# Helpers for venvs
############################
venv_create() {
  local name="$1"
  local path="${VENVS_DIR}/${name}"
  if [[ -d "$path" ]]; then
    log "Venv already exists: $name"
  else
    log "Creating venv: $name"
    run uv venv "$path"
  fi
}

venv_install() {
  local name="$1"; shift
  local path="${VENVS_DIR}/${name}"
  log "Installing packages into $name"
  run uv pip install --python "${path}/bin/python" --upgrade pip setuptools wheel
  run uv pip install --python "${path}/bin/python" --no-cache-dir "$@"
}

register_kernel() {
  local name="$1"
  local path="${VENVS_DIR}/${name}"
  run "${path}/bin/python" -m ipykernel install --user --name "$name" --display-name "Python ($name)"
}

############################
# DATA / RESEARCH ENV
############################
venv_create "$VENV_DATA"
venv_install "$VENV_DATA" \
  numpy pandas scipy matplotlib seaborn statsmodels \
  scikit-learn scikit-image pillow opencv-python-headless \
  jupyterlab notebook ipykernel \
  plotly altair \
  duckdb polars pyarrow \
  openpyxl xlrd \
  sqlalchemy psycopg2-binary \
  requests httpx rich tqdm \
  pydantic pyyaml python-dotenv \
  networkx

register_kernel "$VENV_DATA"

############################
# LLM / NLP ENV
############################
venv_create "$VENV_LLM"
venv_install "$VENV_LLM" \
  torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
venv_install "$VENV_LLM" \
  tensorflow \
  transformers sentence-transformers tokenizers accelerate \
  datasets evaluate \
  spacy nltk gensim \
  llama-index langchain langchain-community \
  qdrant-client chromadb \
  fastapi uvicorn \
  jupyterlab ipykernel

register_kernel "$VENV_LLM"

############################
# SIMULATION / AGENT ENV
############################
venv_create "$VENV_SIM"
venv_install "$VENV_SIM" \
  mesa simpy \
  gymnasium \
  ray[rllib] \
  networkx \
  jupyterlab ipykernel

register_kernel "$VENV_SIM"

############################
# Cleanup
############################
log "Cleaning package manager caches..."
run sudo "$(dnf_cmd)" clean all

log "=== 05_ai_envs completed successfully ==="
log "Venvs created in: $VENVS_DIR"
exit 0
