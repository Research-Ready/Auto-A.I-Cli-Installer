#!/usr/bin/env bash
# tests/test_gemini_cli.sh
#
# Unit tests for modules/gemini_cli.sh.
# These tests validate module structure and configuration logic only —
# no real API key or npm installation is required.
#
# Usage:
#   bash tests/test_gemini_cli.sh

set -uo pipefail

# ── Resolve paths ─────────────────────────────────────────────────────────────
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${TESTS_DIR}/.." && pwd)"

# ── Source the test framework ─────────────────────────────────────────────────
# shellcheck source=tests/framework.sh
source "${TESTS_DIR}/framework.sh"

# =============================================================================
# test_gemini_cli_module_loads
#
# Pre-sets the source guard variable to confirm that sourcing the module a
# second time is a safe no-op (exits 0 immediately without re-executing body).
# =============================================================================
test_gemini_cli_module_loads() {
    # Pre-arm the guard so no external commands are attempted.
    _GEMINI_CLI_LOADED=1
    # shellcheck source=modules/gemini_cli.sh
    source "${REPO_DIR}/modules/gemini_cli.sh"
    local rc=$?
    assert_eq "${rc}" "0"
}

# =============================================================================
# test_gemini_cli_functions_exist
#
# Asserts that all three required public functions are defined after the module
# has been sourced.  Clears the source guard first so the full module body
# loads cleanly.
# =============================================================================
test_gemini_cli_functions_exist() {
    # Clear the guard so the module body is executed and functions are defined.
    unset _GEMINI_CLI_LOADED
    # shellcheck source=modules/gemini_cli.sh
    source "${REPO_DIR}/modules/gemini_cli.sh"

    if declare -f install_gemini_cli &>/dev/null; then
        _pass "function 'install_gemini_cli' is defined"
    else
        _fail "function 'install_gemini_cli' is NOT defined"
    fi

    if declare -f configure_gemini_cli &>/dev/null; then
        _pass "function 'configure_gemini_cli' is defined"
    else
        _fail "function 'configure_gemini_cli' is NOT defined"
    fi

    if declare -f verify_gemini_cli &>/dev/null; then
        _pass "function 'verify_gemini_cli' is defined"
    else
        _fail "function 'verify_gemini_cli' is NOT defined"
    fi
}

# =============================================================================
# test_configure_writes_yolo_alias
#
# Redirects HOME to a temporary directory containing a .bashrc, sets a fake
# GOOGLE_API_KEY, then calls configure_gemini_cli and asserts that the
# --yolo alias (`gemini --yolo`) was written to the fake ~/.bashrc.
# =============================================================================
test_configure_writes_yolo_alias() {
    # ── Set up a disposable HOME ──────────────────────────────────────────────
    local fake_home
    fake_home="$(mktemp -d)"
    touch "${fake_home}/.bashrc"

    local original_home="${HOME}"
    HOME="${fake_home}"

    # ── Provide a fake API key so the export branch is exercised ─────────────
    local original_key="${GOOGLE_API_KEY:-}"
    GOOGLE_API_KEY="AIzaSy-test-key-12345"

    # Ensure the module functions are available.
    unset _GEMINI_CLI_LOADED
    # shellcheck source=modules/gemini_cli.sh
    source "${REPO_DIR}/modules/gemini_cli.sh"

    configure_gemini_cli

    # ── Assert alias was written ──────────────────────────────────────────────
    local bashrc_content
    bashrc_content="$(< "${fake_home}/.bashrc")"
    assert_contains "${bashrc_content}" "gemini --yolo"

    # ── Tear down ─────────────────────────────────────────────────────────────
    HOME="${original_home}"
    GOOGLE_API_KEY="${original_key}"
    rm -rf "${fake_home}"
}

# =============================================================================
# test_configure_warns_if_no_key
#
# Calls configure_gemini_cli with GOOGLE_API_KEY unset and verifies that
# the function exits with status 0 (i.e. it only warns, never aborts).
# =============================================================================
test_configure_warns_if_no_key() {
    # ── Set up a disposable HOME ──────────────────────────────────────────────
    local fake_home
    fake_home="$(mktemp -d)"
    touch "${fake_home}/.bashrc"

    local original_home="${HOME}"
    HOME="${fake_home}"

    # Ensure GOOGLE_API_KEY is absent for this test.
    local original_key="${GOOGLE_API_KEY:-}"
    unset GOOGLE_API_KEY

    # Ensure the module functions are available.
    unset _GEMINI_CLI_LOADED
    # shellcheck source=modules/gemini_cli.sh
    source "${REPO_DIR}/modules/gemini_cli.sh"

    # Call configure_gemini_cli; it must not exit non-zero.
    configure_gemini_cli
    local rc=$?
    assert_eq "${rc}" "0"

    # ── Tear down ─────────────────────────────────────────────────────────────
    HOME="${original_home}"
    # Restore the key if it was originally set.
    if [[ -n "${original_key}" ]]; then
        GOOGLE_API_KEY="${original_key}"
    fi
    rm -rf "${fake_home}"
}

# =============================================================================
# test_verify_sets_status
#
# Calls verify_gemini_cli and asserts that VERIFY_STATUS is set to either
# "ok" or "fail" — i.e. the function always communicates a result regardless
# of whether gemini is installed in the current environment.
# =============================================================================
test_verify_sets_status() {
    # Ensure the module functions are available.
    unset _GEMINI_CLI_LOADED
    # shellcheck source=modules/gemini_cli.sh
    source "${REPO_DIR}/modules/gemini_cli.sh"

    # Reset the variable so we can detect whether verify_gemini_cli sets it.
    VERIFY_STATUS=""

    # Allow the function to fail without aborting the test (it returns 1 when
    # the CLI is absent, which is expected behaviour in a CI environment).
    verify_gemini_cli || true

    if [[ "${VERIFY_STATUS}" == "ok" || "${VERIFY_STATUS}" == "fail" ]]; then
        _pass "VERIFY_STATUS is '${VERIFY_STATUS}' (valid value)"
    else
        _fail "VERIFY_STATUS is '${VERIFY_STATUS:-<empty>}' — expected 'ok' or 'fail'"
    fi
}

# =============================================================================
# Run all tests
# =============================================================================
run_test test_gemini_cli_module_loads
run_test test_gemini_cli_functions_exist
run_test test_configure_writes_yolo_alias
run_test test_configure_warns_if_no_key
run_test test_verify_sets_status

print_results
