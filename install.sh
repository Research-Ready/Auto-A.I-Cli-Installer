#!/usr/bin/env bash
# install.sh — Auto A.I CLI Installer — main orchestrator
#
# Usage:
#   bash install.sh
#
# To make this file directly executable, run once:
#   chmod +x install.sh
# Then invoke with:
#   ./install.sh

set -euo pipefail

# ---------------------------------------------------------------------------
# Resolve the directory that contains this script, regardless of where the
# user invoked it from (symlinks are followed by the cd + pwd trick).
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Source shared utilities — colors, logging, OS detection, dep checks, etc.
# ---------------------------------------------------------------------------
# shellcheck source=modules/common.sh
source "${SCRIPT_DIR}/modules/common.sh"

# ---------------------------------------------------------------------------
# Global state
# ---------------------------------------------------------------------------

# Associative array that stores the result for each tool that was processed.
# Values: "OK" | "FAIL" | "SKIPPED"
declare -A RESULTS

# Ordered list of tools the user selected in show_menu.
SELECTED_TOOLS=()

# ---------------------------------------------------------------------------
# print_banner — display the ASCII-art header.
# ---------------------------------------------------------------------------
print_banner() {
    printf '%s' "${BOLD}"
    cat <<'EOF'

 █████╗ ██╗      ██████╗██╗     ██╗
██╔══██╗██║     ██╔════╝██║     ██║
███████║██║     ██║     ██║     ██║
██╔══██║██║     ██║     ██║     ██║
██║  ██║██║     ╚██████╗███████╗██║
╚═╝  ╚═╝╚═╝      ╚═════╝╚══════╝╚═╝
  Auto A.I CLI Installer v0.1.0
EOF
    printf '%s\n' "${RESET}"
}

# ---------------------------------------------------------------------------
# show_menu — present a numbered list of available tools.
#
# The user may enter:
#   • One or more numbers separated by spaces   (e.g. "1 3 7")
#   • a / A                                      — select all tools
#   • q / Q                                      — quit
#
# Result is stored in the global SELECTED_TOOLS array.
# ---------------------------------------------------------------------------

# Master list of tool identifiers in display order.
# Each entry is "key:Label (description)" — the key maps to modules/<key>.sh
_TOOLS=(
    "openrouter:OpenRouter (multi-model + free models)"
    "ollama:Ollama (local models, free)"
    "aider:Aider (AI coding agent)"
    "claude_code:Claude Code (Anthropic)"
    "opencode:OpenCode"
    "codex:OpenAI Codex CLI"
    "gemini_cli:Gemini CLI (Google)"
    "goose:Goose (Block)"
    "groq:Groq"
    "huggingface:Hugging Face CLI"
    "cerebras:Cerebras"
    "deepseek:DeepSeek"
    "mistral:Mistral"
    "sambanova:SambaNova"
    "fireworks:Fireworks AI"
    "cohere:Cohere"
    "github_copilot:GitHub Copilot CLI"
    "lm_studio:LM Studio"
    "aws_bedrock:AWS Bedrock"
)

show_menu() {
    printf '\n%s=== Select tools to install ===%s\n\n' "${BOLD}" "${RESET}"

    local i=1
    for entry in "${_TOOLS[@]}"; do
        local key="${entry%%:*}"
        local label="${entry#*:}"
        printf '  %s%2d.%s %-20s — %s\n' "${BOLD}" "${i}" "${RESET}" "${key}" "${label}"
        (( i++ )) || true
    done

    printf '\n  %sa%s  — Install ALL tools\n' "${BOLD}" "${RESET}"
    printf '  %sq%s  — Quit\n\n' "${BOLD}" "${RESET}"

    while true; do
        printf 'Your choice: '
        local input
        read -r input

        # Quit
        if [[ "${input,,}" == "q" ]]; then
            log_info "Goodbye."
            exit 0
        fi

        # All tools
        if [[ "${input,,}" == "a" ]]; then
            SELECTED_TOOLS=()
            for entry in "${_TOOLS[@]}"; do
                SELECTED_TOOLS+=( "${entry%%:*}" )
            done
            log_info "Selected all ${#SELECTED_TOOLS[@]} tools."
            return
        fi

        # Numeric selection — one or more numbers separated by whitespace
        SELECTED_TOOLS=()
        local valid=1
        local num
        for num in ${input}; do
            if [[ "${num}" =~ ^[0-9]+$ ]] \
                && [[ "${num}" -ge 1 ]] \
                && [[ "${num}" -le "${#_TOOLS[@]}" ]]; then
                local idx=$(( num - 1 ))
                local entry="${_TOOLS[$idx]}"
                SELECTED_TOOLS+=( "${entry%%:*}" )
            else
                log_warn "Invalid selection: '${num}' — please enter numbers between 1 and ${#_TOOLS[@]}, 'a', or 'q'."
                valid=0
                break
            fi
        done

        if [[ "${valid}" -eq 1 ]] && [[ "${#SELECTED_TOOLS[@]}" -gt 0 ]]; then
            log_info "Selected: ${SELECTED_TOOLS[*]}"
            return
        fi

        # If we reach here the input was empty or invalid; loop again.
        if [[ "${#SELECTED_TOOLS[@]}" -eq 0 && "${valid}" -eq 1 ]]; then
            log_warn "No tools selected. Please enter at least one number, 'a', or 'q'."
        fi
    done
}

# ---------------------------------------------------------------------------
# run_tool TOOLNAME
#
# 1. Sources modules/<TOOLNAME>.sh (skips with a warning if the file is absent).
# 2. Calls install_<TOOLNAME>, configure_<TOOLNAME>, verify_<TOOLNAME> in order.
# 3. Any non-zero exit from any of those three functions marks the tool FAIL.
# 4. Stores the outcome in RESULTS[TOOLNAME].
# ---------------------------------------------------------------------------
run_tool() {
    local tool="$1"
    local module="${SCRIPT_DIR}/modules/${tool}.sh"

    # ── Missing module ────────────────────────────────────────────────────────
    if [[ ! -f "${module}" ]]; then
        log_warn "Module not found for '${tool}' (expected: ${module}) — skipping."
        RESULTS["${tool}"]="SKIPPED"
        return 0
    fi

    log_info "──────────────────────────────────────"
    log_info "Processing tool: ${tool}"
    log_info "──────────────────────────────────────"

    # ── Source the module ─────────────────────────────────────────────────────
    # shellcheck source=/dev/null
    source "${module}"

    # ── install ───────────────────────────────────────────────────────────────
    if ! "install_${tool}"; then
        log_err "install_${tool} failed"
        RESULTS["${tool}"]="FAIL"
        return 1
    fi

    # ── configure ─────────────────────────────────────────────────────────────
    if ! "configure_${tool}"; then
        log_err "configure_${tool} failed"
        RESULTS["${tool}"]="FAIL"
        return 1
    fi

    # ── verify ────────────────────────────────────────────────────────────────
    if ! "verify_${tool}"; then
        log_err "verify_${tool} failed"
        RESULTS["${tool}"]="FAIL"
        return 1
    fi

    RESULTS["${tool}"]="OK"
    log_ok "${tool} installed and verified successfully."
    return 0
}

# ---------------------------------------------------------------------------
# print_summary — tabular report of every processed tool.
#
# Columns:
#   Tool (28 chars wide)  |  Status (colored)
# ---------------------------------------------------------------------------
print_summary() {
    local col1=25   # tool name column width
    local col2=10   # status column width

    # ── Table header ──────────────────────────────────────────────────────────
    printf '\n'
    printf '┌'
    printf '─%.0s' $(seq 1 $(( col1 + 2 )))
    printf '┬'
    printf '─%.0s' $(seq 1 $(( col2 + 2 )))
    printf '┐\n'

    printf '│ %-*s │ %-*s │\n' "${col1}" "Tool" "${col2}" "Status"

    printf '├'
    printf '─%.0s' $(seq 1 $(( col1 + 2 )))
    printf '┼'
    printf '─%.0s' $(seq 1 $(( col2 + 2 )))
    printf '┤\n'

    # ── One row per selected tool ─────────────────────────────────────────────
    local tool
    for tool in "${SELECTED_TOOLS[@]}"; do
        local raw_status="${RESULTS[$tool]:-SKIPPED}"
        local colored_status

        case "${raw_status}" in
            OK)      colored_status="${GREEN}${raw_status}${RESET}" ;;
            FAIL)    colored_status="${RED}${raw_status}${RESET}" ;;
            SKIPPED) colored_status="${YELLOW}${raw_status}${RESET}" ;;
            *)       colored_status="${raw_status}" ;;
        esac

        # Print the row.  We pad the plain status to col2 chars to keep column
        # alignment consistent even when escape codes add invisible characters.
        printf '│ %-*s │ ' "${col1}" "${tool}"
        printf "%-${col2}s" "${raw_status}" | \
            sed "s/${raw_status}/${colored_status}/"
        printf ' │\n'
    done

    # ── Table footer ──────────────────────────────────────────────────────────
    printf '└'
    printf '─%.0s' $(seq 1 $(( col1 + 2 )))
    printf '┴'
    printf '─%.0s' $(seq 1 $(( col2 + 2 )))
    printf '┘\n'
    printf '\n'
}

# ---------------------------------------------------------------------------
# main — entry point
# ---------------------------------------------------------------------------
main() {
    # 1. Banner
    print_banner

    # 2. Detect OS + package manager
    detect_os

    # 3. Verify / install core dependencies (curl, git, node, npm, python3, pip3)
    check_core_deps

    # 4. Load API keys from the env file (warns if missing; non-fatal)
    load_api_keys "${SCRIPT_DIR}/api_keys.env"

    # 5. Interactive tool selection
    show_menu

    # 6. Install each selected tool
    for tool in "${SELECTED_TOOLS[@]}"; do
        run_tool "${tool}" || true   # continue to next tool even on failure
    done

    # 7. Print summary table
    print_summary

    # 8. Remind the user to reload their shell
    log_info "Restart your shell or run: source ~/.bashrc"
}

main "$@"
