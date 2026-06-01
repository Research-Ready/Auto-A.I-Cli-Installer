#!/usr/bin/env bash
# modules/mistral.sh
#
# Install, configure, and verify the Mistral AI Python SDK (mistralai).
#
# Exposed functions (called by run_tool in install.sh):
#   install_mistral
#   configure_mistral
#   verify_mistral

# ── Source guard ──────────────────────────────────────────────────────────────
[[ -n "${_MISTRAL_LOADED:-}" ]] && return
_MISTRAL_LOADED=1

# ── Load shared utilities ─────────────────────────────────────────────────────
# shellcheck source=modules/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# =============================================================================
# install_mistral
#
# Ensures pip3 is available, then installs/upgrades the mistralai Python SDK.
# =============================================================================
install_mistral() {
    log_info "Installing Mistral AI SDK (mistralai) via pip3..."

    require_cmd pip3

    pip3 install --upgrade mistralai

    log_ok "mistralai SDK installed/upgraded"
}

# =============================================================================
# configure_mistral
#
# Writes the following to ~/.bashrc and ~/.zshrc (idempotent):
#   • export MISTRAL_API_KEY='<value from env>'  (when the key is set)
#
# When MISTRAL_API_KEY is absent a warning is printed reminding the user
# where to obtain one (free tier available at console.mistral.ai).
# =============================================================================
configure_mistral() {
    # ── API key export ────────────────────────────────────────────────────────
    if [[ -n "${MISTRAL_API_KEY:-}" ]]; then
        write_env_export MISTRAL_API_KEY
    else
        log_warn "MISTRAL_API_KEY not set. Get it at console.mistral.ai (free tier available)"
    fi
}

# =============================================================================
# verify_mistral
#
# Imports the mistralai package and prints its version.  Sets VERIFY_STATUS
# to "ok" on success or "fail" on failure.
# =============================================================================
verify_mistral() {
    local output exit_code

    output="$(python3 -c "import mistralai; print(mistralai.__version__)" 2>/dev/null)"
    exit_code=$?

    if [[ ${exit_code} -eq 0 && -n "${output}" ]]; then
        log_ok "mistralai ${output}"
        VERIFY_STATUS="ok"
    else
        log_err "mistralai SDK not importable"
        VERIFY_STATUS="fail"
        return 1
    fi
}
