#!/usr/bin/env bash
# modules/lm_studio.sh
#
# Install, configure, and verify LM Studio (local LLM runner with lms CLI).
#
# Exposed functions (called by run_tool in install.sh):
#   install_lm_studio
#   configure_lm_studio
#   verify_lm_studio

# ── Source guard ──────────────────────────────────────────────────────────────
[[ -n "${_LM_STUDIO_LOADED:-}" ]] && return
_LM_STUDIO_LOADED=1

# ── Load shared utilities ─────────────────────────────────────────────────────
MODULES_DIR="${BASH_SOURCE[0]%/*}"
# shellcheck source=modules/common.sh
source "${MODULES_DIR}/common.sh"

# =============================================================================
# install_lm_studio
#
# Installs the LM Studio CLI (`lms`).  If `lms` is already on PATH the step is
# skipped.  Otherwise attempts the official installer script; if that fails a
# warning is printed with manual download instructions.
# =============================================================================
install_lm_studio() {
    log_info "Checking for LM Studio CLI (lms)..."

    if has_cmd lms; then
        log_ok "lms is already installed — skipping"
        return 0
    fi

    log_info "lms not found — attempting official installer..."

    if curl -fsSL https://files.lmstudio.ai/lms/install | bash; then
        log_ok "LM Studio CLI installed via installer script"
    else
        log_warn "Automatic install failed."
        log_warn "Download LM Studio from lmstudio.ai — it includes the lms CLI"
    fi
}

# =============================================================================
# configure_lm_studio
#
# Writes the local server host variable and a convenience alias to the shell RC
# files.  No API key is required — LM Studio runs entirely on-device.
# =============================================================================
configure_lm_studio() {
    write_shell_rc "export LM_STUDIO_HOST=\"http://localhost:1234\""
    write_alias "lms-code" "lms run qwen3-coder:3b"
}

# =============================================================================
# verify_lm_studio
#
# Runs `lms --version` to confirm the CLI is on PATH and operational.
# Sets VERIFY_STATUS to "ok" on success or "fail" on failure.
# =============================================================================
verify_lm_studio() {
    local output exit_code

    output="$(lms --version 2>/dev/null)"
    exit_code=$?

    if [[ ${exit_code} -eq 0 && -n "${output}" ]]; then
        log_ok "lms ${output}"
        VERIFY_STATUS="ok"
    else
        log_err "Could not verify lms"
        VERIFY_STATUS="fail"
        return 1
    fi
}
