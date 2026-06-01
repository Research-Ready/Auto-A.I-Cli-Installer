#!/usr/bin/env bash
# modules/claude_code.sh
#
# Install, configure, and verify Claude Code (Anthropic's official CLI).
#
# Exposed functions (called by run_tool in install.sh):
#   install_claude_code
#   configure_claude_code
#   verify_claude_code

# ── Source guard ──────────────────────────────────────────────────────────────
[[ -n "${_CLAUDE_CODE_LOADED:-}" ]] && return
_CLAUDE_CODE_LOADED=1

# ── Load shared utilities ─────────────────────────────────────────────────────
MODULES_DIR="${BASH_SOURCE[0]%/*}"
# shellcheck source=modules/common.sh
source "${MODULES_DIR}/common.sh"

# =============================================================================
# install_claude_code
#
# Ensures npm is available, then installs the @anthropic-ai/claude-code package
# globally.
# =============================================================================
install_claude_code() {
    log_info "Installing Claude Code via npm..."

    require_cmd npm

    npm install -g @anthropic-ai/claude-code

    log_ok "Claude Code installed"
}

# =============================================================================
# configure_claude_code
#
# Writes the following to ~/.bashrc and ~/.zshrc (idempotent):
#   • export ANTHROPIC_API_KEY='<value from env>'  (when the key is set)
#   • alias claude='claude --auto'                  (safe autonomous default)
#
# Also appends a commented-out full-bypass alias as a shell RC comment so the
# user can easily enable it in sandboxed environments.
#
# When ANTHROPIC_API_KEY is absent a warning is printed reminding the user
# where to obtain one and that API credits are billed separately from a
# claude.ai Pro subscription.
# =============================================================================
configure_claude_code() {
    # ── API key export ────────────────────────────────────────────────────────
    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        write_env_export ANTHROPIC_API_KEY
    else
        log_warn "ANTHROPIC_API_KEY not set. Get it at console.anthropic.com → API Keys"
        printf 'Note: your claude.ai Pro subscription does NOT include API credits — billing is separate.\n'
    fi

    # ── Safe autonomous alias ─────────────────────────────────────────────────
    write_alias "claude" "claude --auto"

    # ── Commented-out full-bypass alias ──────────────────────────────────────
    write_shell_rc "# alias claude='claude --dangerously-skip-permissions'  # full bypass — use in sandboxed environments only"
}

# =============================================================================
# verify_claude_code
#
# Runs `claude --version` to confirm the CLI is on PATH and operational.
# Sets VERIFY_STATUS to "ok" on success or "fail" on failure.
# =============================================================================
verify_claude_code() {
    local output exit_code

    output="$(claude --version 2>/dev/null)"
    exit_code=$?

    if [[ ${exit_code} -eq 0 && -n "${output}" ]]; then
        log_ok "${output}"
        VERIFY_STATUS="ok"
    else
        log_err "Could not verify claude"
        VERIFY_STATUS="fail"
        return 1
    fi
}
