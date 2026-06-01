#!/usr/bin/env bash
# modules/goose.sh
#
# Install, configure, and verify Goose (Block's open-source AI agent CLI).
#
# Exposed functions (called by run_tool in install.sh):
#   install_goose
#   configure_goose
#   verify_goose

# ── Source guard ──────────────────────────────────────────────────────────────
[[ -n "${_GOOSE_LOADED:-}" ]] && return
_GOOSE_LOADED=1

# ── Load shared utilities ─────────────────────────────────────────────────────
MODULES_DIR="${BASH_SOURCE[0]%/*}"
# shellcheck source=modules/common.sh
source "${MODULES_DIR}/common.sh"

# =============================================================================
# install_goose
#
# Downloads the appropriate Goose binary tarball from the Block GitHub releases
# page, extracts it to ~/.local/bin/, and ensures that directory is on PATH.
#
# Supports:
#   Linux  x86_64 / aarch64
#   macOS  x86_64 / aarch64 (Apple Silicon)
# =============================================================================
install_goose() {
    # ── Already installed? ────────────────────────────────────────────────────
    if has_cmd goose; then
        log_ok "Goose already installed"
        return 0
    fi

    log_info "Installing Goose..."

    # ── Detect architecture ───────────────────────────────────────────────────
    local ARCH
    ARCH="$(uname -m)"
    case "${ARCH}" in
        x86_64)  ARCH="x86_64"  ;;
        aarch64|arm64) ARCH="aarch64" ;;
        *)
            log_err "Unsupported architecture: ${ARCH}"
            return 1
            ;;
    esac

    # ── Detect OS ─────────────────────────────────────────────────────────────
    local OS
    OS="$(uname -s)"
    local triple
    case "${OS}" in
        Linux)
            triple="${ARCH}-unknown-linux-gnu"
            ;;
        Darwin)
            triple="${ARCH}-apple-darwin"
            ;;
        *)
            log_err "Unsupported OS: ${OS}"
            return 1
            ;;
    esac

    # ── Build download URL ────────────────────────────────────────────────────
    local url="https://github.com/block/goose/releases/latest/download/goose-${triple}.tar.gz"

    log_info "Downloading Goose from ${url}..."

    # ── Ensure curl is available ──────────────────────────────────────────────
    require_cmd curl

    curl -fsSL "${url}" -o /tmp/goose.tar.gz || {
        log_err "Failed to download Goose from ${url}"
        return 1
    }

    # ── Extract to ~/.local/bin/ ──────────────────────────────────────────────
    mkdir -p "${HOME}/.local/bin"
    tar -xzf /tmp/goose.tar.gz -C "${HOME}/.local/bin/" || {
        log_err "Failed to extract Goose tarball"
        rm -f /tmp/goose.tar.gz
        return 1
    }
    rm -f /tmp/goose.tar.gz

    chmod +x "${HOME}/.local/bin/goose"

    # ── Ensure ~/.local/bin is on PATH ────────────────────────────────────────
    write_shell_rc 'export PATH="$HOME/.local/bin:$PATH"'

    log_ok "Goose installed to ~/.local/bin/goose"
}

# =============================================================================
# configure_goose
#
# Selects the best available API key in priority order:
#   ANTHROPIC_API_KEY → OPENAI_API_KEY → OPENROUTER_API_KEY
#
# Exports the winning key to the shell RC files via write_env_export and writes
# a convenience alias that suppresses the interactive confirmation prompt.
# =============================================================================
configure_goose() {
    # ── API key export (priority order) ──────────────────────────────────────
    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        write_env_export ANTHROPIC_API_KEY
    elif [[ -n "${OPENAI_API_KEY:-}" ]]; then
        write_env_export OPENAI_API_KEY
    elif [[ -n "${OPENROUTER_API_KEY:-}" ]]; then
        write_env_export OPENROUTER_API_KEY
    else
        log_warn "No supported API key found (ANTHROPIC_API_KEY / OPENAI_API_KEY / OPENROUTER_API_KEY)."
        log_warn "Set one of those keys in api_keys.env and re-run configure."
    fi

    # ── Convenience alias ─────────────────────────────────────────────────────
    write_alias "goose" "goose --no-confirmation"
}

# =============================================================================
# verify_goose
#
# Runs `goose --version` to confirm the binary is on PATH and operational.
# Sets VERIFY_STATUS to "ok" on success or "fail" on failure.
# =============================================================================
verify_goose() {
    local output exit_code

    output="$(goose --version 2>/dev/null)"
    exit_code=$?

    if [[ ${exit_code} -eq 0 && -n "${output}" ]]; then
        log_ok "${output}"
        VERIFY_STATUS="ok"
    else
        log_err "Could not verify goose"
        VERIFY_STATUS="fail"
        return 1
    fi
}
