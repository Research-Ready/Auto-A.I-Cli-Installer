#!/usr/bin/env bash
# modules/gemini_cli.sh
#
# Install, configure, and verify Gemini CLI (Google's official AI CLI).
#
# Exposed functions (called by run_tool in install.sh):
#   install_gemini_cli
#   configure_gemini_cli
#   verify_gemini_cli

# ── Source guard ──────────────────────────────────────────────────────────────
[[ -n "${_GEMINI_CLI_LOADED:-}" ]] && return
_GEMINI_CLI_LOADED=1

# ── Load shared utilities ─────────────────────────────────────────────────────
MODULES_DIR="${BASH_SOURCE[0]%/*}"
# shellcheck source=modules/common.sh
source "${MODULES_DIR}/common.sh"

# =============================================================================
# install_gemini_cli
#
# Ensures npm is available, then installs the @google/gemini-cli package
# globally.
# =============================================================================
install_gemini_cli() {
    log_info "Installing Gemini CLI via npm..."

    require_cmd npm

    npm install -g @google/gemini-cli

    log_ok "Gemini CLI installed"
}

# =============================================================================
# configure_gemini_cli
#
# Writes the following to ~/.bashrc and ~/.zshrc (idempotent):
#   • export GOOGLE_API_KEY='<value from env>'  (when the key is set)
#   • alias gemini='gemini --yolo'               (autonomous default)
#
# When GOOGLE_API_KEY is absent a warning is printed reminding the user
# where to obtain a free key (1,000 requests/day, no credit card required).
#
# Also prints an informational note about the Gemini CLI free tier.
# =============================================================================
configure_gemini_cli() {
    # ── API key export ────────────────────────────────────────────────────────
    if [[ -n "${GOOGLE_API_KEY:-}" ]]; then
        write_env_export GOOGLE_API_KEY
    else
        log_warn "GOOGLE_API_KEY not set. Get it FREE at aistudio.google.com → Get API Key (1,000 req/day free)"
    fi

    # ── Autonomous alias ──────────────────────────────────────────────────────
    write_alias "gemini" "gemini --yolo"

    # ── Free tier note ────────────────────────────────────────────────────────
    log_info "Gemini CLI free tier: 1,000 requests/day with Gemini 2.5 Pro/Flash — no credit card needed"
}

# =============================================================================
# verify_gemini_cli
#
# Runs `gemini --version` to confirm the CLI is on PATH and operational.
# Sets VERIFY_STATUS to "ok" on success or "fail" on failure.
# =============================================================================
verify_gemini_cli() {
    local output exit_code

    output="$(gemini --version 2>/dev/null)"
    exit_code=$?

    if [[ ${exit_code} -eq 0 && -n "${output}" ]]; then
        log_ok "${output}"
        VERIFY_STATUS="ok"
    else
        log_err "Could not verify gemini"
        VERIFY_STATUS="fail"
        return 1
    fi
}
