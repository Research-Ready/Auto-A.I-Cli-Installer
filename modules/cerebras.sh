#!/usr/bin/env bash
# modules/cerebras.sh
#
# Install, configure, and verify the Cerebras Cloud SDK.
#
# Exposed functions (called by run_tool in install.sh):
#   install_cerebras
#   configure_cerebras
#   verify_cerebras

# ── Source guard ──────────────────────────────────────────────────────────────
[[ -n "${_CEREBRAS_LOADED:-}" ]] && return
_CEREBRAS_LOADED=1

# ── Load shared utilities ─────────────────────────────────────────────────────
MODULES_DIR="${BASH_SOURCE[0]%/*}"
# shellcheck source=modules/common.sh
source "${MODULES_DIR}/common.sh"

# =============================================================================
# install_cerebras
#
# Ensures pip3 is available, then installs/upgrades the cerebras-cloud-sdk
# Python package.
# =============================================================================
install_cerebras() {
    log_info "Installing Cerebras Cloud SDK via pip3..."

    require_cmd pip3

    pip3 install --upgrade cerebras-cloud-sdk

    log_ok "Cerebras Cloud SDK installed"
}

# =============================================================================
# configure_cerebras
#
# Writes `export CEREBRAS_API_KEY='<value>'` to the shell RC files when the
# key is set in the current environment.  Logs a warning with signup
# instructions when it is absent.
# =============================================================================
configure_cerebras() {
    if [[ -n "${CEREBRAS_API_KEY:-}" ]]; then
        write_env_export CEREBRAS_API_KEY
    else
        log_warn "CEREBRAS_API_KEY not set. Get it FREE at cloud.cerebras.ai → API Keys (2nd fastest cloud inference)"
    fi
}

# =============================================================================
# verify_cerebras
#
# Imports the cerebras.cloud.sdk package inside Python and prints a
# confirmation string.  Sets VERIFY_STATUS to "ok" on success or "fail" on
# failure.
# =============================================================================
verify_cerebras() {
    local output exit_code

    output="$(python3 -c "import cerebras.cloud.sdk; print('cerebras-cloud-sdk ok')" 2>/dev/null)"
    exit_code=$?

    if [[ ${exit_code} -eq 0 && -n "${output}" ]]; then
        log_ok "${output}"
        VERIFY_STATUS="ok"
    else
        log_err "Could not verify Cerebras Cloud SDK"
        VERIFY_STATUS="fail"
        return 1
    fi
}
