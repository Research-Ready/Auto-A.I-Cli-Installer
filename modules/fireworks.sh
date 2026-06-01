#!/usr/bin/env bash
# modules/fireworks.sh
#
# Install, configure, and verify the Fireworks AI Python SDK.
#
# Exposed functions (called by run_tool in install.sh):
#   install_fireworks
#   configure_fireworks
#   verify_fireworks

# ── Source guard ──────────────────────────────────────────────────────────────
[[ -n "${_FIREWORKS_LOADED:-}" ]] && return
_FIREWORKS_LOADED=1

# ── Load shared utilities ─────────────────────────────────────────────────────
MODULES_DIR="${BASH_SOURCE[0]%/*}"
# shellcheck source=modules/common.sh
source "${MODULES_DIR}/common.sh"

# =============================================================================
# install_fireworks
#
# Installs the official fireworks-ai Python SDK.
# =============================================================================
install_fireworks() {
    log_info "Installing fireworks-ai SDK..."

    pip3 install --upgrade fireworks-ai

    log_ok "fireworks-ai SDK installed"
}

# =============================================================================
# configure_fireworks
#
# Writes the FIREWORKS_API_KEY export to the shell RC files when the variable
# is set.  Otherwise logs a warning with signup instructions.
# =============================================================================
configure_fireworks() {
    if [[ -n "${FIREWORKS_API_KEY:-}" ]]; then
        write_env_export FIREWORKS_API_KEY
    else
        log_warn "FIREWORKS_API_KEY not set. Get free key (10 RPM, no card) at fireworks.ai → API Keys"
    fi
}

# =============================================================================
# verify_fireworks
#
# Confirms the fireworks package is importable in the current Python environment.
# Sets VERIFY_STATUS to "ok" on success or "fail" on failure.
# =============================================================================
verify_fireworks() {
    local output exit_code

    output="$(python3 -c "import fireworks; print('ok')" 2>/dev/null)"
    exit_code=$?

    if [[ ${exit_code} -eq 0 && -n "${output}" ]]; then
        log_ok "fireworks SDK: ${output}"
        VERIFY_STATUS="ok"
    else
        log_err "Could not verify fireworks SDK"
        VERIFY_STATUS="fail"
        return 1
    fi
}
