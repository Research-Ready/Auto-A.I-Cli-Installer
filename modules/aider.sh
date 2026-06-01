#!/usr/bin/env bash
# modules/aider.sh
#
# Install, configure, and verify Aider — an AI pair-programming CLI.
# Aider supports multiple LLM backends and is installed via pip3.
#
# Exposed functions (called by run_tool in install.sh):
#   install_aider
#   configure_aider
#   verify_aider

# ── Source guard ──────────────────────────────────────────────────────────────
[[ -n "${_AIDER_LOADED:-}" ]] && return
_AIDER_LOADED=1

# ── Load shared utilities ─────────────────────────────────────────────────────
MODULES_DIR="${BASH_SOURCE[0]%/*}"
# shellcheck source=modules/common.sh
source "${MODULES_DIR}/common.sh"

# =============================================================================
# install_aider
#
# Ensures pip3 is available, then installs/upgrades the aider-chat package.
# =============================================================================
install_aider() {
    log_info "Installing aider-chat via pip3..."

    require_cmd pip3

    pip3 install --upgrade aider-chat

    log_ok "aider-chat installed"
}

# =============================================================================
# configure_aider
#
# Selects the LLM backend based on which API key is present in the environment,
# using this priority order:
#   1. OPENROUTER_API_KEY  → OpenRouter (free models available)
#   2. ANTHROPIC_API_KEY   → Claude (auto-detected by aider)
#   3. OPENAI_API_KEY      → OpenAI
#   4. None found          → emit a warning
#
# Writes the required exports/alias to ~/.bashrc and ~/.zshrc (idempotent via
# write_shell_rc from common.sh).
# Always appends:  alias aider='aider --yes'
# =============================================================================
configure_aider() {
    if [[ -n "${OPENROUTER_API_KEY:-}" ]]; then
        log_info "Configuring aider to use OpenRouter backend..."

        write_shell_rc "export AIDER_OPENAI_API_BASE='https://openrouter.ai/api/v1'"
        write_shell_rc "export AIDER_OPENAI_API_KEY='${OPENROUTER_API_KEY}'"
        write_shell_rc "export AIDER_MODEL='openrouter/meta-llama/llama-3.1-8b-instruct:free'"

        log_ok "aider configured for OpenRouter (model: meta-llama/llama-3.1-8b-instruct:free)"

    elif [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        log_info "Configuring aider to use Anthropic (Claude) backend..."

        write_shell_rc "export ANTHROPIC_API_KEY='${ANTHROPIC_API_KEY}'"

        log_ok "aider configured for Anthropic — ANTHROPIC_API_KEY is set (aider auto-detects Claude)"

    elif [[ -n "${OPENAI_API_KEY:-}" ]]; then
        log_info "Configuring aider to use OpenAI backend..."

        write_shell_rc "export OPENAI_API_KEY='${OPENAI_API_KEY}'"

        log_ok "aider configured for OpenAI — OPENAI_API_KEY is set"

    else
        log_warn "No API key found for aider — set OPENROUTER_API_KEY, ANTHROPIC_API_KEY, or OPENAI_API_KEY"
    fi

    # Always write the convenience alias regardless of backend selection.
    write_alias "aider" "aider --yes"
}

# =============================================================================
# verify_aider
#
# Runs `aider --version` and captures the output.
# Sets VERIFY_STATUS="ok" on success or "fail" on failure.
# =============================================================================
verify_aider() {
    local output
    output="$(aider --version 2>/dev/null)"
    local exit_code=$?

    if [[ ${exit_code} -eq 0 && -n "${output}" ]]; then
        log_ok "${output}"
        VERIFY_STATUS="ok"
    else
        log_err "Could not verify aider — 'aider --version' failed"
        VERIFY_STATUS="fail"
        return 1
    fi
}
