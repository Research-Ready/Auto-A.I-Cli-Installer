#!/usr/bin/env bash
# modules/deepseek.sh
#
# Install, configure, and verify DeepSeek support.
# DeepSeek exposes an OpenAI-compatible API, so the openai Python SDK is the
# only dependency required.
#
# Exposed functions (called by run_tool in install.sh):
#   install_deepseek
#   configure_deepseek
#   verify_deepseek

# ── Source guard ──────────────────────────────────────────────────────────────
[[ -n "${_DEEPSEEK_LOADED:-}" ]] && return
_DEEPSEEK_LOADED=1

# ── Load shared utilities ─────────────────────────────────────────────────────
# shellcheck source=modules/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# =============================================================================
# install_deepseek
#
# Ensures pip3 is available, then installs/upgrades the openai Python SDK.
# DeepSeek's API is fully OpenAI-compatible, so no separate SDK is needed.
# =============================================================================
install_deepseek() {
    log_info "Installing DeepSeek support (openai SDK via pip3)..."

    require_cmd pip3

    pip3 install --upgrade openai

    log_ok "openai SDK installed (DeepSeek uses OpenAI-compatible API)"
}

# =============================================================================
# configure_deepseek
#
# Writes the following to ~/.bashrc and ~/.zshrc (idempotent):
#   • export DEEPSEEK_API_KEY='<value from env>'  (when the key is set)
#   • export DEEPSEEK_BASE_URL='https://api.deepseek.com/v1'
#
# When DEEPSEEK_API_KEY is absent a warning is printed reminding the user
# where to obtain one (near-free pricing at platform.deepseek.com).
# =============================================================================
configure_deepseek() {
    # ── API key export ────────────────────────────────────────────────────────
    if [[ -n "${DEEPSEEK_API_KEY:-}" ]]; then
        write_env_export DEEPSEEK_API_KEY
        write_shell_rc "export DEEPSEEK_BASE_URL='https://api.deepseek.com/v1'"
    else
        log_warn "DEEPSEEK_API_KEY not set. Get it at platform.deepseek.com (near-free: ~\$0.001/1M tokens)"
    fi
}

# =============================================================================
# verify_deepseek
#
# Imports the openai package (required for DeepSeek's OpenAI-compatible API)
# and prints a confirmation message.  Sets VERIFY_STATUS to "ok" on success
# or "fail" on failure.
# =============================================================================
verify_deepseek() {
    local output exit_code

    output="$(python3 -c "import openai; print('openai SDK ok for DeepSeek')" 2>/dev/null)"
    exit_code=$?

    if [[ ${exit_code} -eq 0 && -n "${output}" ]]; then
        log_ok "${output}"
        VERIFY_STATUS="ok"
    else
        log_err "openai SDK not importable (required for DeepSeek)"
        VERIFY_STATUS="fail"
        return 1
    fi
}
