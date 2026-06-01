#!/usr/bin/env bash
# modules/openrouter.sh
#
# Install, configure, and verify OpenRouter support.
# OpenRouter provides a unified API gateway (OpenAI-compatible) with access to
# many models, including several that are permanently free.
#
# Exposed functions (called by run_tool in install.sh):
#   install_openrouter
#   configure_openrouter
#   verify_openrouter

# ── Source guard ──────────────────────────────────────────────────────────────
[[ -n "${_OPENROUTER_LOADED:-}" ]] && return
_OPENROUTER_LOADED=1

# ── Load shared utilities ─────────────────────────────────────────────────────
# shellcheck source=modules/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# =============================================================================
# install_openrouter
#
# Ensures pip3 is available, then installs/upgrades the openai Python SDK.
# OpenRouter's API is fully OpenAI-compatible, so the openai package is the
# only dependency required.
# =============================================================================
install_openrouter() {
    log_info "Installing OpenRouter support (openai SDK via pip3)..."

    if ! has_cmd pip3; then
        require_cmd pip3
    fi

    pip3 install --upgrade openai

    log_ok "openai SDK installed/upgraded (OpenRouter backend ready)."
}

# =============================================================================
# configure_openrouter
#
# Writes the following to ~/.bashrc and ~/.zshrc (idempotent):
#   • export OPENROUTER_API_KEY='<value from env>'
#   • export OPENROUTER_BASE_URL='https://openrouter.ai/api/v1'
#   • alias or-chat='...'
#
# Also prints a note listing permanently-free models available on OpenRouter.
# =============================================================================
configure_openrouter() {
    # ── Environment exports ───────────────────────────────────────────────────
    write_env_export OPENROUTER_API_KEY

    # Always write the base URL — it is a static value, not a secret.
    OPENROUTER_BASE_URL="https://openrouter.ai/api/v1"
    write_shell_rc "export OPENROUTER_BASE_URL='https://openrouter.ai/api/v1'"

    # ── Convenience alias ─────────────────────────────────────────────────────
    # or-chat <prompt>  — sends a one-shot chat request to OpenRouter and prints
    # the model's reply.  Uses meta-llama/llama-3.1-8b-instruct:free by default
    # so it works without spending any credits.
    # shellcheck disable=SC2016
    write_alias "or-chat" 'python3 -c "import openai,os,sys; c=openai.OpenAI(api_key=os.environ[\"OPENROUTER_API_KEY\"],base_url=\"https://openrouter.ai/api/v1\"); r=c.chat.completions.create(model=\"meta-llama/llama-3.1-8b-instruct:free\",messages=[{\"role\":\"user\",\"content\":\" \".join(sys.argv[1:])}]); print(r.choices[0].message.content)"'

    # ── Informational note ────────────────────────────────────────────────────
    log_info "Permanently-free models available on OpenRouter:"
    log_info "  • meta-llama/llama-3.1-8b-instruct:free"
    log_info "  • mistralai/mistral-7b-instruct:free"
    log_info "  • google/gemma-2-9b-it:free"
    log_info "  • deepseek/deepseek-r1:free"
}

# =============================================================================
# verify_openrouter
#
# Imports the openai package and prints its version.  Sets VERIFY_STATUS to
# "ok" on success or "fail" on failure.
# =============================================================================
verify_openrouter() {
    local version
    version="$(python3 -c "import openai; print(openai.__version__)" 2>/dev/null)"

    if [[ $? -eq 0 && -n "${version}" ]]; then
        log_ok "openai SDK ${version} (OpenRouter backend ready)"
        VERIFY_STATUS="ok"
    else
        log_err "openai SDK not importable"
        VERIFY_STATUS="fail"
        return 1
    fi
}
