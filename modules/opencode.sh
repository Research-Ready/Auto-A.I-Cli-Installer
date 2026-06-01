#!/usr/bin/env bash
# modules/opencode.sh
#
# Install, configure, and verify OpenCode — an open-source AI coding CLI.
# Primary install uses the official curl installer; npm is the fallback.
#
# Exposed functions (called by run_tool in install.sh):
#   install_opencode
#   configure_opencode
#   verify_opencode

# ── Source guard ──────────────────────────────────────────────────────────────
[[ -n "${_OPENCODE_LOADED:-}" ]] && return
_OPENCODE_LOADED=1

# ── Load shared utilities ─────────────────────────────────────────────────────
MODULES_DIR="${BASH_SOURCE[0]%/*}"
# shellcheck source=modules/common.sh
source "${MODULES_DIR}/common.sh"

# =============================================================================
# install_opencode
#
# Attempts to install OpenCode via the official curl installer:
#   curl -fsSL https://opencode.ai/install | bash
#
# If that fails (non-zero exit), falls back to:
#   npm install -g opencode-ai
# (requires npm to be present; validated with require_cmd before the attempt).
# =============================================================================
install_opencode() {
    log_info "Installing OpenCode via official installer..."

    if curl -fsSL https://opencode.ai/install | bash; then
        log_ok "OpenCode installed via curl installer"
    else
        log_warn "curl installer failed — falling back to npm..."
        require_cmd npm
        npm install -g opencode-ai
        log_ok "OpenCode installed via npm"
    fi
}

# =============================================================================
# configure_opencode
#
# Selects the LLM backend based on which API key is present in the environment,
# using this priority order:
#   1. OPENROUTER_API_KEY  → OpenRouter (many models available via one key)
#   2. ANTHROPIC_API_KEY   → Anthropic Claude
#   3. OPENAI_API_KEY      → OpenAI
#   4. GOOGLE_API_KEY      → Google Gemini
#   5. None found          → emit a warning
#
# Writes the required export(s) and the convenience alias to ~/.bashrc and
# ~/.zshrc (idempotent via write_shell_rc from common.sh).
# Always appends:  alias opencode='opencode --auto-approve'
# =============================================================================
configure_opencode() {
    if [[ -n "${OPENROUTER_API_KEY:-}" ]]; then
        log_info "Configuring opencode to use OpenRouter backend..."

        write_env_export OPENROUTER_API_KEY
        log_ok "opencode configured for OpenRouter — OPENROUTER_API_KEY is set"
        log_info "OpenCode can use OpenRouter to access many models with a single key"

    elif [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        log_info "Configuring opencode to use Anthropic (Claude) backend..."

        write_env_export ANTHROPIC_API_KEY
        log_ok "opencode configured for Anthropic — ANTHROPIC_API_KEY is set"

    elif [[ -n "${OPENAI_API_KEY:-}" ]]; then
        log_info "Configuring opencode to use OpenAI backend..."

        write_env_export OPENAI_API_KEY
        log_ok "opencode configured for OpenAI — OPENAI_API_KEY is set"

    elif [[ -n "${GOOGLE_API_KEY:-}" ]]; then
        log_info "Configuring opencode to use Google (Gemini) backend..."

        write_env_export GOOGLE_API_KEY
        log_ok "opencode configured for Google — GOOGLE_API_KEY is set"

    else
        log_warn "No API key found for opencode — set OPENROUTER_API_KEY, ANTHROPIC_API_KEY, OPENAI_API_KEY, or GOOGLE_API_KEY"
    fi

    # Always write the convenience alias regardless of backend selection.
    write_alias "opencode" "opencode --auto-approve"
}

# =============================================================================
# verify_opencode
#
# Runs `opencode --version` and captures the output.
# Sets VERIFY_STATUS="ok" on success or "fail" on failure.
# =============================================================================
verify_opencode() {
    local output
    output="$(opencode --version 2>/dev/null)"
    local exit_code=$?

    if [[ ${exit_code} -eq 0 && -n "${output}" ]]; then
        log_ok "${output}"
        VERIFY_STATUS="ok"
    else
        log_err "Could not verify opencode — 'opencode --version' failed"
        VERIFY_STATUS="fail"
        return 1
    fi
}
