#!/usr/bin/env bash
# modules/huggingface.sh
#
# Install, configure, and verify the Hugging Face CLI (huggingface_hub).
#
# Exposed functions (called by run_tool in install.sh):
#   install_huggingface
#   configure_huggingface
#   verify_huggingface

# ── Source guard ──────────────────────────────────────────────────────────────
[[ -n "${_HUGGINGFACE_LOADED:-}" ]] && return
_HUGGINGFACE_LOADED=1

# ── Load shared utilities ─────────────────────────────────────────────────────
# shellcheck source=modules/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# =============================================================================
# install_huggingface
#
# Ensures pip3 is available, then installs/upgrades the huggingface_hub
# package, which provides the huggingface-cli command-line tool.
# =============================================================================
install_huggingface() {
    log_info "Installing Hugging Face CLI (huggingface_hub) via pip3..."

    require_cmd pip3

    pip3 install --upgrade huggingface_hub

    log_ok "huggingface_hub installed/upgraded"
}

# =============================================================================
# configure_huggingface
#
# Writes the following to ~/.bashrc and ~/.zshrc (idempotent):
#   • export HUGGINGFACE_TOKEN='<value from env>'  (when the token is set)
#   • alias huggingface-cli='huggingface-cli --yes'
#
# Also performs a non-interactive login when HUGGINGFACE_TOKEN is set.
# When the token is absent a warning is printed reminding the user where to
# obtain one (free at huggingface.co → Settings → Access Tokens).
# =============================================================================
configure_huggingface() {
    # ── Token export and non-interactive login ────────────────────────────────
    if [[ -n "${HUGGINGFACE_TOKEN:-}" ]]; then
        write_env_export HUGGINGFACE_TOKEN
        huggingface-cli login --token "${HUGGINGFACE_TOKEN}" 2>/dev/null || true
    else
        log_warn "HUGGINGFACE_TOKEN not set. Get it at huggingface.co → Settings → Access Tokens (free)"
    fi

    # ── Convenience alias ─────────────────────────────────────────────────────
    write_alias "huggingface-cli" "huggingface-cli --yes"
}

# =============================================================================
# verify_huggingface
#
# Runs `huggingface-cli --version` to confirm the CLI is on PATH and
# operational.  Sets VERIFY_STATUS to "ok" on success or "fail" on failure.
# =============================================================================
verify_huggingface() {
    local output exit_code

    output="$(huggingface-cli --version 2>/dev/null)"
    exit_code=$?

    if [[ ${exit_code} -eq 0 && -n "${output}" ]]; then
        log_ok "${output}"
        VERIFY_STATUS="ok"
    else
        log_err "Could not verify huggingface-cli"
        VERIFY_STATUS="fail"
        return 1
    fi
}
