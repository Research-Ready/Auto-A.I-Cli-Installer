#!/usr/bin/env bash
# modules/ollama.sh — Ollama (local models) install/configure/verify module
#
# Exposes three functions consumed by install.sh's run_tool():
#   install_ollama
#   configure_ollama
#   verify_ollama
#
# Source this file; do NOT execute it directly.

# ── Source guard ──────────────────────────────────────────────────────────────
[[ -n "${_OLLAMA_LOADED:-}" ]] && return
_OLLAMA_LOADED=1

# ── Shared library ────────────────────────────────────────────────────────────
# shellcheck source=./common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# =============================================================================
# install_ollama
#
# Downloads and installs Ollama via the official install script if it is not
# already present on PATH.  After installation, attempts to start the Ollama
# service using whatever init system is available.
# =============================================================================
install_ollama() {
    # ── Already installed? ────────────────────────────────────────────────────
    if has_cmd ollama; then
        log_ok "Ollama already installed"
        return 0
    fi

    # ── Install via official script ───────────────────────────────────────────
    log_info "Installing Ollama via https://ollama.ai/install.sh ..."
    if ! curl -fsSL https://ollama.ai/install.sh | sh; then
        log_err "Ollama installation script failed."
        return 1
    fi

    log_ok "Ollama installation script completed."

    # ── Start the service ─────────────────────────────────────────────────────
    if has_cmd systemctl; then
        log_info "Enabling and starting Ollama service (user systemd)..."
        systemctl --user enable --now ollama 2>/dev/null || true
    else
        log_warn "systemctl not found — you may need to start the Ollama service manually."
        log_warn "  Run: ollama serve"
    fi

    return 0
}

# =============================================================================
# configure_ollama
#
# 1. Writes OLLAMA_HOST to the user's shell RC files.
# 2. Writes convenience aliases for common Ollama model invocations.
# 3. Offers an interactive menu to pull one or more starter models.
# =============================================================================
configure_ollama() {
    # ── Environment variable ──────────────────────────────────────────────────
    log_info "Writing OLLAMA_HOST environment variable..."
    write_shell_rc "export OLLAMA_HOST='http://localhost:11434'"

    # ── Aliases ───────────────────────────────────────────────────────────────
    log_info "Writing Ollama aliases..."
    write_alias "ollama-general" "ollama run llama3.2"
    write_alias "ollama-code"    "ollama run qwen3-coder:3b"
    write_alias "ollama-reason"  "ollama run deepseek-r1:7b"

    # ── Starter model pull menu ───────────────────────────────────────────────
    # Skip the prompt when stdin is not a TTY (non-interactive / CI).
    if [[ ! -t 0 ]]; then
        log_info "Non-interactive session detected — skipping model pull prompt."
        log_info "To pull models later, run: ollama pull <model>"
        return 0
    fi

    printf '\nPull starter models? (recommended for first install)\n'
    printf '  [1] llama3.2        — general purpose (4 GB)\n'
    printf '  [2] qwen3-coder:3b  — coding (2 GB)\n'
    printf '  [3] deepseek-r1:7b  — reasoning (4 GB)\n'
    printf '  [a] all three\n'
    printf '  [s] skip\n'
    printf '\nYour choice: '

    local choice
    read -r choice

    # Normalise to lowercase for case matching.
    choice="${choice,,}"

    # Helper: pull a single model and log the outcome.
    _pull_model() {
        local model="$1"
        log_info "Pulling ${model} ..."
        if ollama pull "${model}"; then
            log_ok "Pulled ${model}"
        else
            log_warn "Failed to pull ${model} — you can retry later with: ollama pull ${model}"
        fi
    }

    case "${choice}" in
        1)
            _pull_model "llama3.2"
            ;;
        2)
            _pull_model "qwen3-coder:3b"
            ;;
        3)
            _pull_model "deepseek-r1:7b"
            ;;
        a)
            _pull_model "llama3.2"
            _pull_model "qwen3-coder:3b"
            _pull_model "deepseek-r1:7b"
            ;;
        s|"")
            log_info "Skipping model pull — run 'ollama pull <model>' whenever you're ready."
            ;;
        *)
            log_warn "Unrecognised choice '${choice}' — skipping model pull."
            ;;
    esac

    return 0
}

# =============================================================================
# verify_ollama
#
# Confirms that the `ollama` binary is reachable on PATH and reports its
# version.  Sets VERIFY_STATUS to "ok" or "fail".
# =============================================================================
verify_ollama() {
    local version_output

    if version_output="$(ollama --version 2>/dev/null)" && [[ -n "${version_output}" ]]; then
        log_ok "Ollama ${version_output}"
        VERIFY_STATUS="ok"
        return 0
    else
        log_err "ollama not found on PATH"
        VERIFY_STATUS="fail"
        return 1
    fi
}
