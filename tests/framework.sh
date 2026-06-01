#!/usr/bin/env bash
# tests/framework.sh — tiny bash test framework for Auto A.I CLI Installer
#
# Usage (in a test file):
#   source "$(dirname "${BASH_SOURCE[0]}")/framework.sh"
#
#   my_test() {
#       assert_cmd bash
#       assert_eq "$(echo hello)" "hello"
#   }
#   run_test my_test
#   print_results

# ── Source guard ──────────────────────────────────────────────────────────────
[[ -n "${_FRAMEWORK_LOADED:-}" ]] && return
_FRAMEWORK_LOADED=1

# ── Color setup (inline — framework must be self-contained) ──────────────────
if command -v tput &>/dev/null && tput colors &>/dev/null 2>&1; then
    _FW_RED=$(tput setaf 1)
    _FW_GREEN=$(tput setaf 2)
    _FW_YELLOW=$(tput setaf 3)
    _FW_BOLD=$(tput bold)
    _FW_RESET=$(tput sgr0)
else
    _FW_RED=$'\033[0;31m'
    _FW_GREEN=$'\033[0;32m'
    _FW_YELLOW=$'\033[0;33m'
    _FW_BOLD=$'\033[1m'
    _FW_RESET=$'\033[0m'
fi

# ── Parallel arrays: one slot per test that was run ───────────────────────────
TEST_NAMES=()    # name of each test
TEST_RESULTS=()  # "PASS" or "FAIL" for the corresponding test

# ── Internal counters (updated by _pass / _fail) ─────────────────────────────
_FW_PASS_COUNT=0
_FW_FAIL_COUNT=0

# ── _current_test — set by run_test before invoking the test function ─────────
_current_test=""

# =============================================================================
# _pass MSG
#
# Records a passing assertion. Prints a green PASS line and increments counter.
# =============================================================================
_pass() {
    local msg="${1:-}"
    printf '%sPASS%s: %s\n' "${_FW_GREEN}" "${_FW_RESET}" "${msg}"
    (( _FW_PASS_COUNT++ )) || true
}

# =============================================================================
# _fail MSG
#
# Records a failing assertion. Prints a red FAIL line and increments counter.
# Sets _FW_TEST_FAILED=1 so run_test can mark the whole test as failed.
# =============================================================================
_fail() {
    local msg="${1:-}"
    printf '%sFAIL%s: %s\n' "${_FW_RED}" "${_FW_RESET}" "${msg}" >&2
    (( _FW_FAIL_COUNT++ )) || true
    _FW_TEST_FAILED=1
}

# =============================================================================
# assert_cmd CMD
#
# Passes if `command -v CMD` succeeds (i.e. CMD is on PATH).
# Fails with "Command 'CMD' not found" otherwise.
# =============================================================================
assert_cmd() {
    local cmd="$1"
    if command -v "${cmd}" &>/dev/null; then
        _pass "assert_cmd: '${cmd}' found on PATH"
    else
        _fail "assert_cmd: Command '${cmd}' not found"
    fi
}

# =============================================================================
# assert_eq ACTUAL EXPECTED
#
# Passes if ACTUAL == EXPECTED (string comparison).
# Fails with a diff-style message showing both values.
# =============================================================================
assert_eq() {
    local actual="$1"
    local expected="$2"
    if [[ "${actual}" == "${expected}" ]]; then
        _pass "assert_eq: '${actual}' == '${expected}'"
    else
        _fail "assert_eq: expected '${expected}', got '${actual}'"
    fi
}

# =============================================================================
# assert_env VAR
#
# Passes if the environment variable VAR is set and non-empty.
# Fails with "Environment variable 'VAR' is not set or empty".
# =============================================================================
assert_env() {
    local var="$1"
    if [[ -n "${!var:-}" ]]; then
        _pass "assert_env: '${var}' is set and non-empty"
    else
        _fail "assert_env: Environment variable '${var}' is not set or empty"
    fi
}

# =============================================================================
# assert_file FILE
#
# Passes if FILE exists (regular file or symlink).
# Fails with "File 'FILE' does not exist".
# =============================================================================
assert_file() {
    local file="$1"
    if [[ -e "${file}" ]]; then
        _pass "assert_file: '${file}' exists"
    else
        _fail "assert_file: File '${file}' does not exist"
    fi
}

# =============================================================================
# assert_contains HAYSTACK NEEDLE
#
# Passes if NEEDLE is a substring of HAYSTACK.
# Fails with a descriptive message showing both values.
# =============================================================================
assert_contains() {
    local haystack="$1"
    local needle="$2"
    if [[ "${haystack}" == *"${needle}"* ]]; then
        _pass "assert_contains: found '${needle}' in string"
    else
        _fail "assert_contains: '${needle}' not found in '${haystack}'"
    fi
}

# =============================================================================
# run_test NAME
#
# Calls the function NAME (the test name and the function must be identical).
# Captures any non-zero exit status or bash errors via a subshell.
#
# Records the outcome in the TEST_NAMES / TEST_RESULTS parallel arrays.
# =============================================================================
run_test() {
    local name="$1"

    printf '\n%s--- %s ---%s\n' "${_FW_BOLD}" "${name}" "${_FW_RESET}"

    _current_test="${name}"
    _FW_TEST_FAILED=0

    # Run the test function in the current shell so that assert_* functions can
    # update the counters.  We catch unexpected errors (set -e triggers) by
    # temporarily disabling errexit around the call.
    local saved_opts
    saved_opts="$(set +o)"            # save current shell options as a string
    set +e                            # do not abort on non-zero return

    "${name}"
    local fn_exit=$?

    eval "${saved_opts}" 2>/dev/null  # restore shell options

    if [[ "${fn_exit}" -ne 0 && "${_FW_TEST_FAILED}" -eq 0 ]]; then
        # Function exited non-zero without calling _fail — record it anyway.
        _fail "${name}: test function exited with status ${fn_exit}"
    fi

    if [[ "${_FW_TEST_FAILED}" -eq 0 ]]; then
        TEST_NAMES+=( "${name}" )
        TEST_RESULTS+=( "PASS" )
    else
        TEST_NAMES+=( "${name}" )
        TEST_RESULTS+=( "FAIL" )
    fi
}

# =============================================================================
# print_results
#
# Prints a summary of every test that was run via run_test.
# Shows pass / fail counts.
# Exits with status 1 if any test failed.
# =============================================================================
print_results() {
    local total="${#TEST_NAMES[@]}"
    local i

    printf '\n%s══════════════════════════════════════════%s\n' "${_FW_BOLD}" "${_FW_RESET}"
    printf '%sTest Results%s\n' "${_FW_BOLD}" "${_FW_RESET}"
    printf '%s══════════════════════════════════════════%s\n\n' "${_FW_BOLD}" "${_FW_RESET}"

    for (( i = 0; i < total; i++ )); do
        local tname="${TEST_NAMES[$i]}"
        local tresult="${TEST_RESULTS[$i]}"
        if [[ "${tresult}" == "PASS" ]]; then
            printf '  %sPASS%s  %s\n' "${_FW_GREEN}" "${_FW_RESET}" "${tname}"
        else
            printf '  %sFAIL%s  %s\n' "${_FW_RED}" "${_FW_RESET}" "${tname}"
        fi
    done

    printf '\n──────────────────────────────────────────\n'
    printf 'Total: %d  |  ' "${total}"
    printf '%sPassed: %d%s  |  ' "${_FW_GREEN}" "${_FW_PASS_COUNT}" "${_FW_RESET}"
    printf '%sFailed: %d%s\n' "${_FW_RED}" "${_FW_FAIL_COUNT}" "${_FW_RESET}"
    printf '══════════════════════════════════════════\n\n'

    # Exit 1 if any test failed.
    if [[ "${_FW_FAIL_COUNT}" -gt 0 ]]; then
        exit 1
    fi
}
