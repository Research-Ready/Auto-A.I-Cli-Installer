#!/usr/bin/env bash
# modules/github_copilot.sh
#
# Install, configure, and verify the GitHub Copilot CLI.
#
# Exposed functions (called by run_tool in install.sh):
#   install_github_copilot
#   configure_github_copilot
#   verify_github_copilot

# ── Source guard ──────────────────────────────────────────────────────────────
[[ -n "${_GITHUB_COPILOT_LOADED:-}" ]] && return
_GITHUB_COPILOT_LOADED=1

# ── Load shared utilities ─────────────────────────────────────────────────────
MODULES_DIR="${BASH_SOURCE[0]%/*}"
# shellcheck source=modules/common.sh
source "${MODULES_DIR}/common.sh"

# =============================================================================
# install_github_copilot
#
# Installs the GitHub Copilot CLI npm package globally.
# Requires npm to be present on PATH.
# =============================================================================
install_github_copilot() {
    log_info "Installing GitHub Copilot CLI via npm..."

    require_cmd npm

    npm install -g @githubnext/github-copilot-cli

    log_ok "GitHub Copilot CLI installed"
}

# =============================================================================
# configure_github_copilot
#
# Writes the GITHUB_TOKEN export and convenience aliases to the shell RC files.
# When GITHUB_TOKEN is absent a warning explains where to obtain one and that a
# GitHub Copilot subscription is required.
# =============================================================================
configure_github_copilot() {
    # ── Token export ──────────────────────────────────────────────────────────
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        write_env_export GITHUB_TOKEN
    else
        log_warn "GITHUB_TOKEN not set. Get at github.com → Settings → Developer Settings → Personal Access Tokens (requires GitHub Copilot subscription)"
    fi

    # ── Convenience aliases ───────────────────────────────────────────────────
    write_alias "ghcs" "ghcs --yes"
    write_alias "ghce" "ghce --yes"
}

# =============================================================================
# verify_github_copilot
#
# Tries `github-copilot-cli --version` first, then falls back to `ghcs
# --version`.  Sets VERIFY_STATUS to "ok" on success or "fail" on failure.
# =============================================================================
verify_github_copilot() {
    local output exit_code

    # Prefer the canonical binary name; fall back to the shell wrapper.
    output="$(github-copilot-cli --version 2>/dev/null)"
    exit_code=$?

    if [[ ${exit_code} -ne 0 || -z "${output}" ]]; then
        output="$(ghcs --version 2>/dev/null)"
        exit_code=$?
    fi

    if [[ ${exit_code} -eq 0 && -n "${output}" ]]; then
        log_ok "${output}"
        VERIFY_STATUS="ok"
    else
        log_err "Could not verify GitHub Copilot CLI"
        VERIFY_STATUS="fail"
        return 1
    fi
}
