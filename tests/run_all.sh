#!/usr/bin/env bash
# tests/run_all.sh — execute every test_*.sh file in the tests/ directory.
#
# Usage:
#   bash tests/run_all.sh
#
# Exit codes:
#   0 — all test files passed
#   1 — one or more test files exited non-zero

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Color setup (inline so run_all.sh is self-contained) ─────────────────────
if command -v tput &>/dev/null && tput colors &>/dev/null 2>&1; then
    _RED=$(tput setaf 1)
    _GREEN=$(tput setaf 2)
    _YELLOW=$(tput setaf 3)
    _BOLD=$(tput bold)
    _RESET=$(tput sgr0)
else
    _RED=$'\033[0;31m'
    _GREEN=$'\033[0;32m'
    _YELLOW=$'\033[0;33m'
    _BOLD=$'\033[1m'
    _RESET=$'\033[0m'
fi

# ── Discover test files ───────────────────────────────────────────────────────
# Collect all files matching test_*.sh in the tests/ directory (non-recursive).
mapfile -t TEST_FILES < <(find "${TESTS_DIR}" -maxdepth 1 -name 'test_*.sh' | sort)

if [[ "${#TEST_FILES[@]}" -eq 0 ]]; then
    printf '%s[WARN]%s No test files matching test_*.sh found in %s\n' \
        "${_YELLOW}" "${_RESET}" "${TESTS_DIR}"
    exit 0
fi

# ── Run each test file ────────────────────────────────────────────────────────
overall_failed=0
file_results=()   # "PASS" or "FAIL" per file (parallel to TEST_FILES)

for test_file in "${TEST_FILES[@]}"; do
    filename="$(basename "${test_file}")"

    # Header banner for this file.
    printf '\n'
    printf '%s════════════════════════════════════════════════════════%s\n' "${_BOLD}" "${_RESET}"
    printf '%s  Running: %s%s\n' "${_BOLD}" "${filename}" "${_RESET}"
    printf '%s════════════════════════════════════════════════════════%s\n' "${_BOLD}" "${_RESET}"

    # Execute the test file in a child process so its `exit` calls do not
    # terminate this runner script.
    if bash "${test_file}"; then
        file_results+=( "PASS" )
        printf '\n%s[PASS]%s %s completed with no failures.\n' \
            "${_GREEN}" "${_RESET}" "${filename}"
    else
        file_results+=( "FAIL" )
        printf '\n%s[FAIL]%s %s reported one or more failures.\n' \
            "${_RED}" "${_RESET}" "${filename}"
        overall_failed=$(( overall_failed + 1 ))
    fi
done

# ── Final summary ─────────────────────────────────────────────────────────────
total="${#TEST_FILES[@]}"
passed=$(( total - overall_failed ))

printf '\n'
printf '%s════════════════════════════════════════════════════════%s\n' "${_BOLD}" "${_RESET}"
printf '%s  Suite Summary%s\n' "${_BOLD}" "${_RESET}"
printf '%s════════════════════════════════════════════════════════%s\n\n' "${_BOLD}" "${_RESET}"

for (( i = 0; i < total; i++ )); do
    fname="$(basename "${TEST_FILES[$i]}")"
    result="${file_results[$i]}"
    if [[ "${result}" == "PASS" ]]; then
        printf '  %sPASS%s  %s\n' "${_GREEN}" "${_RESET}" "${fname}"
    else
        printf '  %sFAIL%s  %s\n' "${_RED}" "${_RESET}" "${fname}"
    fi
done

printf '\n──────────────────────────────────────────────────────\n'
printf 'Files: %d  |  ' "${total}"
printf '%sPassed: %d%s  |  ' "${_GREEN}" "${passed}" "${_RESET}"
printf '%sFailed: %d%s\n' "${_RED}" "${overall_failed}" "${_RESET}"
printf '════════════════════════════════════════════════════════\n\n'

if [[ "${overall_failed}" -gt 0 ]]; then
    exit 1
fi

exit 0
