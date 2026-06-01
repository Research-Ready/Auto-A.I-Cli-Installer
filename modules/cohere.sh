#!/usr/bin/env bash
# modules/cohere.sh
#
# Install, configure, and verify the Cohere Python SDK.
#
# Exposed functions (called by run_tool in install.sh):
#   install_cohere
#   configure_cohere
#   verify_cohere

# ── Source guard ──────────────────────────────────────────────────────────────
[[ -n "${_COHERE_LOADED:-}" ]] && return
_COHERE_LOADED=1

# ── Load shared utilities ─────────────────────────────────────────────────────
MODULES_DIR="${BASH_SOURCE[0]%/*}"
# shellcheck source=modules/common.sh
source "${MODULES_DIR}/common.sh"

# =============================================================================
# install_cohere
#
# Installs the official Cohere Python SDK.
# =============================================================================
install_cohere() {
    log_info "Installing Cohere SDK..."

    pip3 install --upgrade cohere

    log_ok "Cohere SDK installed"
}

# =============================================================================
# configure_cohere
#
# Writes the COHERE_API_KEY export to the shell RC files when the variable is
# set.  Otherwise logs a warning pointing the user to the dashboard.
# =============================================================================
configure_cohere() {
    if [[ -n "${COHERE_API_KEY:-}" ]]; then
        write_env_export COHERE_API_KEY
    else
        log_warn "COHERE_API_KEY not set. Get key at dashboard.cohere.com (free trial tier)"
    fi
}

# =============================================================================
# verify_cohere
#
# Imports the cohere package and prints its version string.
# Sets VERIFY_STATUS to "ok" on success or "fail" on failure.
# =============================================================================
verify_cohere() {
    local output exit_code

    output="$(python3 -c "import cohere; print(cohere.__version__)" 2>/dev/null)"
    exit_code=$?

    if [[ ${exit_code} -eq 0 && -n "${output}" ]]; then
        log_ok "cohere ${output}"
        VERIFY_STATUS="ok"
    else
        log_err "Could not verify Cohere SDK"
        VERIFY_STATUS="fail"
        return 1
    fi
}
