#!/usr/bin/env bash
# modules/sambanova.sh
#
# Install, configure, and verify SambaNova Cloud CLI access.
# SambaNova uses an OpenAI-compatible API, so the openai SDK is the client.
#
# Exposed functions (called by run_tool in install.sh):
#   install_sambanova
#   configure_sambanova
#   verify_sambanova

# ── Source guard ──────────────────────────────────────────────────────────────
[[ -n "${_SAMBANOVA_LOADED:-}" ]] && return
_SAMBANOVA_LOADED=1

# ── Load shared utilities ─────────────────────────────────────────────────────
MODULES_DIR="${BASH_SOURCE[0]%/*}"
# shellcheck source=modules/common.sh
source "${MODULES_DIR}/common.sh"

# =============================================================================
# install_sambanova
#
# Installs the openai Python SDK, which provides the OpenAI-compatible client
# used to talk to the SambaNova Cloud API endpoint.
# =============================================================================
install_sambanova() {
    log_info "Installing openai SDK (OpenAI-compatible client for SambaNova)..."

    pip3 install --upgrade openai

    log_ok "openai SDK installed for SambaNova"
}

# =============================================================================
# configure_sambanova
#
# When SAMBANOVA_API_KEY is set, writes the API key export and the SambaNova
# base-URL override to the shell RC files.  Without the key a warning is
# printed pointing the user to the signup page.
# =============================================================================
configure_sambanova() {
    if [[ -n "${SAMBANOVA_API_KEY:-}" ]]; then
        write_env_export SAMBANOVA_API_KEY
        write_shell_rc "export SAMBANOVA_BASE_URL='https://api.sambanova.ai/v1'"
    else
        log_warn "SAMBANOVA_API_KEY not set. Get free key at cloud.sambanova.ai → API Keys"
    fi
}

# =============================================================================
# verify_sambanova
#
# Confirms the openai SDK is importable in the current Python environment.
# Sets VERIFY_STATUS to "ok" on success or "fail" on failure.
# =============================================================================
verify_sambanova() {
    local output exit_code

    output="$(python3 -c "import openai; print('openai SDK ok for SambaNova')" 2>/dev/null)"
    exit_code=$?

    if [[ ${exit_code} -eq 0 && -n "${output}" ]]; then
        log_ok "${output}"
        VERIFY_STATUS="ok"
    else
        log_err "Could not verify openai SDK for SambaNova"
        VERIFY_STATUS="fail"
        return 1
    fi
}
