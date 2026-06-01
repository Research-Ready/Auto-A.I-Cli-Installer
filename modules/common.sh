#!/usr/bin/env bash
# modules/common.sh
#
# Shared library for install.sh and all per-tool module scripts.
# Source this file; do NOT execute it directly.
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/modules/common.sh"
#
# Note: This file intentionally does NOT call `set -euo pipefail`.
#       Shell options must be controlled by the sourcing script.

# ── Source guard ─────────────────────────────────────────────────────────────
# Safe to source multiple times; subsequent sources are no-ops.
[[ -n "${_COMMON_LOADED:-}" ]] && return
_COMMON_LOADED=1

# =============================================================================
# 1. color_setup
#
# Initialises terminal colour/style variables. Uses tput when a terminal is
# available and the tput binary exists; falls back to raw ANSI escape codes so
# the variables are always defined (empty strings would break printf/echo calls
# that embed them).
# Variables exported into the calling shell's namespace:
#   RED  GREEN  YELLOW  BLUE  CYAN  BOLD  RESET
# =============================================================================
color_setup() {
    if command -v tput &>/dev/null && tput colors &>/dev/null 2>&1; then
        RED=$(tput setaf 1)
        GREEN=$(tput setaf 2)
        YELLOW=$(tput setaf 3)
        BLUE=$(tput setaf 4)
        CYAN=$(tput setaf 6)
        BOLD=$(tput bold)
        RESET=$(tput sgr0)
    else
        # ANSI fallback — works in virtually every modern terminal / CI log.
        RED=$'\033[0;31m'
        GREEN=$'\033[0;32m'
        YELLOW=$'\033[0;33m'
        BLUE=$'\033[0;34m'
        CYAN=$'\033[0;36m'
        BOLD=$'\033[1m'
        RESET=$'\033[0m'
    fi
}

# Initialise colours immediately when this file is sourced.
color_setup

# =============================================================================
# 2. log_info MSG
#
# Prints an informational message to stdout in BLUE.
# =============================================================================
log_info() {
    printf '%s[INFO]%s %s\n' "${BLUE}" "${RESET}" "$*"
}

# =============================================================================
# 3. log_ok MSG
#
# Prints a success message to stdout in GREEN.
# =============================================================================
log_ok() {
    printf '%s[ OK ]%s %s\n' "${GREEN}" "${RESET}" "$*"
}

# =============================================================================
# 4. log_warn MSG
#
# Prints a warning message to stdout in YELLOW.
# =============================================================================
log_warn() {
    printf '%s[WARN]%s %s\n' "${YELLOW}" "${RESET}" "$*"
}

# =============================================================================
# 5. log_err MSG
#
# Prints an error message to stderr in RED.
# =============================================================================
log_err() {
    printf '%s[ERR ]%s %s\n' "${RED}" "${RESET}" "$*" >&2
}

# =============================================================================
# 6. detect_os
#
# Detects the host operating system and sets two global variables:
#   OS_TYPE     — one of: debian | arch | fedora | macos | unknown
#   PKG_MANAGER — one of: apt   | pacman | dnf  | brew  | unknown
#
# Detection order:
#   1. macOS via `uname`
#   2. Linux via /etc/os-release ID field
# =============================================================================
detect_os() {
    OS_TYPE="unknown"
    PKG_MANAGER="unknown"

    local uname_out
    uname_out="$(uname -s 2>/dev/null)"

    if [[ "${uname_out}" == "Darwin" ]]; then
        OS_TYPE="macos"
        PKG_MANAGER="brew"
    elif [[ -f /etc/os-release ]]; then
        # Source only the ID variable to avoid polluting the environment.
        local os_id=""
        os_id="$(. /etc/os-release && echo "${ID:-}")"
        local os_id_like=""
        os_id_like="$(. /etc/os-release && echo "${ID_LIKE:-}")"

        case "${os_id}" in
            debian|ubuntu|linuxmint|pop|kali|elementary|zorin)
                OS_TYPE="debian";  PKG_MANAGER="apt"  ;;
            arch|manjaro|endeavouros|garuda)
                OS_TYPE="arch";    PKG_MANAGER="pacman" ;;
            fedora|rhel|centos|rocky|almalinux)
                OS_TYPE="fedora";  PKG_MANAGER="dnf"  ;;
            *)
                # Fall back to ID_LIKE when the primary ID is not matched.
                case "${os_id_like}" in
                    *debian*|*ubuntu*)
                        OS_TYPE="debian";  PKG_MANAGER="apt"    ;;
                    *arch*)
                        OS_TYPE="arch";    PKG_MANAGER="pacman" ;;
                    *fedora*|*rhel*)
                        OS_TYPE="fedora";  PKG_MANAGER="dnf"    ;;
                esac
                ;;
        esac
    fi

    log_info "Detected OS: ${OS_TYPE}  (package manager: ${PKG_MANAGER})"
}

# =============================================================================
# 7. has_cmd CMD
#
# Silent test: returns 0 if CMD is available on PATH, 1 otherwise.
# Produces no output.
# =============================================================================
has_cmd() {
    command -v "$1" &>/dev/null
}

# =============================================================================
# 8. require_cmd CMD
#
# Exits the process with status 1 if CMD is not found on PATH.
# Logs an error before exiting.
# =============================================================================
require_cmd() {
    if ! has_cmd "$1"; then
        log_err "Required command '$1' not found."
        exit 1
    fi
}

# =============================================================================
# 9. install_pkg PKG
#
# Installs a system package using the package manager identified by detect_os.
# Requires PKG_MANAGER to be set (call detect_os first).
# Returns 1 and logs an error if the package manager is unknown.
# =============================================================================
install_pkg() {
    local pkg="$1"
    case "${PKG_MANAGER:-unknown}" in
        apt)
            sudo apt-get install -y "${pkg}"
            ;;
        pacman)
            sudo pacman -S --noconfirm "${pkg}"
            ;;
        dnf)
            sudo dnf install -y "${pkg}"
            ;;
        brew)
            brew install "${pkg}"
            ;;
        *)
            log_err "Unknown package manager '${PKG_MANAGER:-unset}'. Cannot install '${pkg}'."
            return 1
            ;;
    esac
}

# =============================================================================
# 10. check_node
#
# Ensures Node.js >= 18 is available.
#   - If `node` is not found, attempts installation via the system package manager.
#   - If the installed version is < 18, logs a warning with nvm install instructions
#     (package-manager node is often outdated; nvm is the recommended upgrade path).
#   - Prints the discovered version with log_ok on success.
# =============================================================================
check_node() {
    if ! has_cmd node; then
        log_info "node not found — attempting system install..."
        install_pkg nodejs || {
            log_warn "Could not install Node.js automatically."
            log_warn "Install Node.js >= 18 via nvm: https://github.com/nvm-sh/nvm"
            log_warn "  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash"
            log_warn "  nvm install 18 && nvm use 18"
            return 1
        }
    fi

    # Verify minimum version requirement (>= 18).
    local node_version major
    node_version="$(node --version 2>/dev/null)"          # e.g. v20.11.0
    major="${node_version#v}"                              # strip leading 'v'
    major="${major%%.*}"                                   # keep major only

    if [[ -z "${major}" || "${major}" -lt 18 ]]; then
        log_warn "Node.js ${node_version:-unknown} is older than the required v18."
        log_warn "Upgrade via nvm: https://github.com/nvm-sh/nvm"
        log_warn "  nvm install 18 && nvm use 18"
        return 1
    fi

    log_ok "node ${node_version}"
}

# =============================================================================
# 11. check_npm
#
# Ensures npm is available. Installs the 'npm' package via the system package
# manager if not found. Prints the discovered version with log_ok.
# =============================================================================
check_npm() {
    if ! has_cmd npm; then
        log_info "npm not found — attempting system install..."
        install_pkg npm
    fi
    log_ok "npm $(npm --version 2>/dev/null)"
}

# =============================================================================
# 12. check_python
#
# Ensures python3 is available. Installs the 'python3' package via the system
# package manager if not found. Prints the discovered version with log_ok.
# =============================================================================
check_python() {
    if ! has_cmd python3; then
        log_info "python3 not found — attempting system install..."
        install_pkg python3
    fi
    log_ok "python3 $(python3 --version 2>/dev/null)"
}

# =============================================================================
# 13. check_pip
#
# Ensures pip3 is available. Attempts to install 'python3-pip' via the system
# package manager if not found. Prints the discovered version with log_ok.
# =============================================================================
check_pip() {
    if ! has_cmd pip3; then
        log_info "pip3 not found — attempting system install (python3-pip)..."
        install_pkg python3-pip
    fi
    log_ok "pip3 $(pip3 --version 2>/dev/null)"
}

# =============================================================================
# 14. check_curl
#
# Ensures curl is available. Installs it via the system package manager if not
# found. Prints the discovered version with log_ok.
# =============================================================================
check_curl() {
    if ! has_cmd curl; then
        log_info "curl not found — attempting system install..."
        install_pkg curl
    fi
    log_ok "curl $(curl --version 2>/dev/null | head -1)"
}

# =============================================================================
# 15. check_git
#
# Ensures git is available. Installs it via the system package manager if not
# found. Prints the discovered version with log_ok.
# =============================================================================
check_git() {
    if ! has_cmd git; then
        log_info "git not found — attempting system install..."
        install_pkg git
    fi
    log_ok "git $(git --version 2>/dev/null)"
}

# =============================================================================
# 16. check_core_deps
#
# Convenience wrapper that runs all core dependency checks in the recommended
# order: curl → git → node → npm → python3 → pip3.
# =============================================================================
check_core_deps() {
    log_info "Checking core dependencies..."
    check_curl
    check_git
    check_node
    check_npm
    check_python
    check_pip
}

# =============================================================================
# 17. load_api_keys FILE
#
# Sources the given FILE so that API key variables are available in the calling
# shell. If FILE does not exist the user is offered the chance to create it from
# the bundled example template.
#
# After sourcing, validates all 19 expected key names and reports each one as
# either set (log_ok) or absent (log_warn).
# =============================================================================
load_api_keys() {
    local file="$1"

    # ── File-not-found handling ───────────────────────────────────────────────
    if [[ ! -f "${file}" ]]; then
        log_warn "API keys file '${file}' not found."

        if [[ -f "api_keys.env.example" ]]; then
            printf 'Copy api_keys.env.example to %s? [y/N] ' "${file}"
            local answer
            read -r answer
            if [[ "${answer}" =~ ^[Yy]$ ]]; then
                cp api_keys.env.example "${file}"
                log_warn "Please edit ${file} and re-run."
                exit 0
            fi
        else
            log_warn "api_keys.env.example not found either; skipping key loading."
        fi
        return 1
    fi

    # ── Source the file ───────────────────────────────────────────────────────
    # shellcheck source=/dev/null
    source "${file}"

    # ── Validate all 19 expected key names ───────────────────────────────────
    local all_keys=(
        ANTHROPIC_API_KEY
        OPENAI_API_KEY
        GOOGLE_API_KEY
        OPENROUTER_API_KEY
        GROQ_API_KEY
        CEREBRAS_API_KEY
        SAMBANOVA_API_KEY
        FIREWORKS_API_KEY
        DEEPSEEK_API_KEY
        MISTRAL_API_KEY
        HUGGINGFACE_TOKEN
        COHERE_API_KEY
        PERPLEXITY_API_KEY
        GITHUB_TOKEN
        CLOUDFLARE_ACCOUNT_ID
        CLOUDFLARE_API_KEY
        AWS_ACCESS_KEY_ID
        AWS_SECRET_ACCESS_KEY
        AWS_DEFAULT_REGION
    )

    local key
    for key in "${all_keys[@]}"; do
        if [[ -n "${!key:-}" ]]; then
            log_ok "${key} is set"
        else
            log_warn "${key} is not set (empty)"
        fi
    done
}

# =============================================================================
# 18. write_shell_rc LINE
#
# Appends LINE to ~/.bashrc and ~/.zshrc (when each file exists) if and only if
# the line is not already present in that file (idempotency). Logs every action.
# =============================================================================
write_shell_rc() {
    local line="$1"
    local rc_file

    for rc_file in "${HOME}/.bashrc" "${HOME}/.zshrc"; do
        [[ -f "${rc_file}" ]] || continue

        if grep -qF "${line}" "${rc_file}" 2>/dev/null; then
            log_info "Already present in ${rc_file}: ${line}"
        else
            printf '\n%s\n' "${line}" >> "${rc_file}"
            log_ok "Wrote to ${rc_file}: ${line}"
        fi
    done
}

# =============================================================================
# 19. write_env_export VAR
#
# Looks up VAR in the current environment via indirect expansion and, if non-
# empty, appends `export VAR='value'` to the shell RC files via write_shell_rc.
# Logs a warning and skips when the variable is unset or empty.
# =============================================================================
write_env_export() {
    local var="$1"
    local value="${!var:-}"

    if [[ -n "${value}" ]]; then
        write_shell_rc "export ${var}='${value}'"
    else
        log_warn "Skipping export of ${var} — not set in api_keys.env"
    fi
}

# =============================================================================
# 20. write_alias NAME CMD
#
# Appends `alias NAME='CMD'` to the shell RC files. Idempotency is delegated to
# write_shell_rc, which skips the line when it already exists.
# =============================================================================
write_alias() {
    local name="$1"
    local cmd="$2"
    write_shell_rc "alias ${name}='${cmd}'"
}

# =============================================================================
# 21. verify_cmd CMD
#
# Attempts to obtain a version string from CMD using conventional flags:
#   1. CMD --version
#   2. CMD version   (fallback for tools like docker, kubectl, etc.)
#
# On success:  prints the output with log_ok and sets VERIFY_STATUS="ok".
# On failure:  logs an error with log_err and sets VERIFY_STATUS="fail".
# Returns 0 on success, non-zero on failure.
# =============================================================================
verify_cmd() {
    local cmd="$1"
    local output exit_code

    output="$("${cmd}" --version 2>/dev/null || "${cmd}" version 2>/dev/null)"
    exit_code=$?

    if [[ ${exit_code} -eq 0 && -n "${output}" ]]; then
        log_ok "${output}"
        VERIFY_STATUS="ok"
    else
        log_err "Could not verify ${cmd}"
        VERIFY_STATUS="fail"
    fi

    return ${exit_code}
}
