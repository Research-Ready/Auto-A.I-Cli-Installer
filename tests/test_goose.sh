#!/usr/bin/env bash
# tests/test_goose.sh
#
# Unit tests for modules/goose.sh.
# These tests validate module structure and configuration logic only —
# no real API key or network access is required.
#
# Usage:
#   bash tests/test_goose.sh

set -uo pipefail

# ── Resolve paths ─────────────────────────────────────────────────────────────
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${TESTS_DIR}/.." && pwd)"

# ── Source the test framework ─────────────────────────────────────────────────
# shellcheck source=tests/framework.sh
source "${TESTS_DIR}/framework.sh"

# =============================================================================
# test_goose_module_loads
#
# Pre-sets the source guard variable to confirm that sourcing the module a
# second time is a safe no-op (exits 0 immediately without re-executing body).
# =============================================================================
test_goose_module_loads() {
    # Pre-arm the guard so no external commands are attempted.
    _GOOSE_LOADED=1
    # shellcheck source=modules/goose.sh
    source "${REPO_DIR}/modules/goose.sh"
    local rc=$?
    assert_eq "${rc}" "0"
}

# =============================================================================
# test_goose_functions_exist
#
# Asserts that all three required public functions are defined after the module
# has been sourced.  Clears the source guard first so the full module body
# loads cleanly.
# =============================================================================
test_goose_functions_exist() {
    # Clear the guard so the module body is executed and functions are defined.
    unset _GOOSE_LOADED
    # shellcheck source=modules/goose.sh
    source "${REPO_DIR}/modules/goose.sh"

    if declare -f install_goose &>/dev/null; then
        _pass "function 'install_goose' is defined"
    else
        _fail "function 'install_goose' is NOT defined"
    fi

    if declare -f configure_goose &>/dev/null; then
        _pass "function 'configure_goose' is defined"
    else
        _fail "function 'configure_goose' is NOT defined"
    fi

    if declare -f verify_goose &>/dev/null; then
        _pass "function 'verify_goose' is defined"
    else
        _fail "function 'verify_goose' is NOT defined"
    fi
}

# =============================================================================
# test_configure_writes_no_confirmation_alias
#
# Redirects HOME to a temporary directory containing a .bashrc, sets a fake
# API key, then calls configure_goose and asserts that the alias containing
# '--no-confirmation' was written to the fake ~/.bashrc.
# =============================================================================
test_configure_writes_no_confirmation_alias() {
    # ── Set up a disposable HOME ──────────────────────────────────────────────
    local fake_home
    fake_home="$(mktemp -d)"
    touch "${fake_home}/.bashrc"

    local original_home="${HOME}"
    HOME="${fake_home}"

    # ── Provide a fake API key so the export branch is exercised ─────────────
    local original_key="${ANTHROPIC_API_KEY:-}"
    ANTHROPIC_API_KEY="sk-ant-test-key-12345"

    # Ensure the module functions are available.
    unset _GOOSE_LOADED
    # shellcheck source=modules/goose.sh
    source "${REPO_DIR}/modules/goose.sh"

    configure_goose

    # ── Assert alias was written with --no-confirmation ───────────────────────
    local bashrc_content
    bashrc_content="$(< "${fake_home}/.bashrc")"
    assert_contains "${bashrc_content}" "--no-confirmation"

    # ── Tear down ─────────────────────────────────────────────────────────────
    HOME="${original_home}"
    ANTHROPIC_API_KEY="${original_key}"
    rm -rf "${fake_home}"
}

# =============================================================================
# test_verify_sets_status
#
# Calls verify_goose and asserts that VERIFY_STATUS is set to either "ok" or
# "fail" — i.e. the function always communicates a result regardless of whether
# goose is installed in the current environment.
# =============================================================================
test_verify_sets_status() {
    # Ensure the module functions are available.
    unset _GOOSE_LOADED
    # shellcheck source=modules/goose.sh
    source "${REPO_DIR}/modules/goose.sh"

    # Reset the variable so we can detect whether verify_goose sets it.
    VERIFY_STATUS=""

    # Allow the function to fail without aborting the test (it returns 1 when
    # the CLI is absent, which is expected behaviour in a CI environment).
    verify_goose || true

    if [[ "${VERIFY_STATUS}" == "ok" || "${VERIFY_STATUS}" == "fail" ]]; then
        _pass "VERIFY_STATUS is '${VERIFY_STATUS}' (valid value)"
    else
        _fail "VERIFY_STATUS is '${VERIFY_STATUS:-<empty>}' — expected 'ok' or 'fail'"
    fi
}

# =============================================================================
# Run all tests
# =============================================================================
run_test test_goose_module_loads
run_test test_goose_functions_exist
run_test test_configure_writes_no_confirmation_alias
run_test test_verify_sets_status

print_results
