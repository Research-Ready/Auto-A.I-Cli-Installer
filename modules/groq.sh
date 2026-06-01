#!/usr/bin/env bash
# modules/groq.sh
#
# Install, configure, and verify the Groq Python SDK.
#
# Exposed functions (called by run_tool in install.sh):
#   install_groq
#   configure_groq
#   verify_groq

# ── Source guard ──────────────────────────────────────────────────────────────
[[ -n "${_GROQ_LOADED:-}" ]] && return
_GROQ_LOADED=1

# ── Load shared utilities ─────────────────────────────────────────────────────
MODULES_DIR="${BASH_SOURCE[0]%/*}"
# shellcheck source=modules/common.sh
source "${MODULES_DIR}/common.sh"

# =============================================================================
# install_groq
#
# Ensures pip3 is available, then installs/upgrades the groq Python package.
# =============================================================================
install_groq() {
    log_info "Installing Groq Python SDK via pip3..."

    require_cmd pip3

    pip3 install --upgrade groq

    log_ok "Groq Python SDK installed"
}

# =============================================================================
# configure_groq
#
# Writes `export GROQ_API_KEY='<value>'` to the shell RC files when the key is
# set in the current environment.  Logs a warning with signup instructions when
# it is absent.
# =============================================================================
configure_groq() {
    if [[ -n "${GROQ_API_KEY:-}" ]]; then
        write_env_export GROQ_API_KEY
    else
        log_warn "GROQ_API_KEY not set. Get it FREE at console.groq.com → API Keys (fastest cloud inference)"
    fi
}

# =============================================================================
# verify_groq
#
# Imports the groq package inside Python and prints its version string.
# Sets VERIFY_STATUS to "ok" on success or "fail" on failure.
# =============================================================================
verify_groq() {
    local output exit_code

    output="$(python3 -c "import groq; print(groq.__version__)" 2>/dev/null)"
    exit_code=$?

    if [[ ${exit_code} -eq 0 && -n "${output}" ]]; then
        log_ok "groq ${output}"
        VERIFY_STATUS="ok"
    else
        log_err "Could not verify groq Python SDK"
        VERIFY_STATUS="fail"
        return 1
    fi
}
