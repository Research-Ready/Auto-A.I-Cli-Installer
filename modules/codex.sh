#!/usr/bin/env bash
# modules/codex.sh
#
# Install, configure, and verify OpenAI Codex CLI.
#
# Exposed functions (called by run_tool in install.sh):
#   install_codex
#   configure_codex
#   verify_codex

# ── Source guard ──────────────────────────────────────────────────────────────
[[ -n "${_CODEX_LOADED:-}" ]] && return
_CODEX_LOADED=1

# ── Load shared utilities ─────────────────────────────────────────────────────
MODULES_DIR="${BASH_SOURCE[0]%/*}"
# shellcheck source=modules/common.sh
source "${MODULES_DIR}/common.sh"

# =============================================================================
# install_codex
#
# Ensures npm is available, then installs the @openai/codex package globally.
# =============================================================================
install_codex() {
    log_info "Installing OpenAI Codex CLI via npm..."

    require_cmd npm

    npm install -g @openai/codex

    log_ok "OpenAI Codex CLI installed"
}

# =============================================================================
# configure_codex
#
# Writes the following to ~/.bashrc and ~/.zshrc (idempotent):
#   • export OPENAI_API_KEY='<value from env>'  (when the key is set)
#   • alias codex='codex --approval-policy full-auto'
#
# When OPENAI_API_KEY is absent a warning is printed reminding the user
# where to obtain one.
# =============================================================================
configure_codex() {
    # ── API key export ────────────────────────────────────────────────────────
    if [[ -n "${OPENAI_API_KEY:-}" ]]; then
        write_env_export OPENAI_API_KEY
    else
        log_warn "OPENAI_API_KEY not set. Get it at platform.openai.com → API Keys"
    fi

    # ── Full-auto alias ───────────────────────────────────────────────────────
    write_alias "codex" "codex --approval-policy full-auto"
}

# =============================================================================
# verify_codex
#
# Runs `codex --version` to confirm the CLI is on PATH and operational.
# Sets VERIFY_STATUS to "ok" on success or "fail" on failure.
# =============================================================================
verify_codex() {
    local output exit_code

    output="$(codex --version 2>/dev/null)"
    exit_code=$?

    if [[ ${exit_code} -eq 0 && -n "${output}" ]]; then
        log_ok "${output}"
        VERIFY_STATUS="ok"
    else
        log_err "Could not verify codex"
        VERIFY_STATUS="fail"
        return 1
    fi
}
