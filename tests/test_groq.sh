#!/usr/bin/env bash
# tests/test_groq.sh
#
# Unit tests for modules/groq.sh.
# These tests validate module structure and configuration logic only —
# no real API key or pip installation is required.
#
# Usage:
#   bash tests/test_groq.sh

set -uo pipefail

# ── Resolve paths ─────────────────────────────────────────────────────────────
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${TESTS_DIR}/.." && pwd)"

# ── Source the test framework ─────────────────────────────────────────────────
# shellcheck source=tests/framework.sh
source "${TESTS_DIR}/framework.sh"

# =============================================================================
# test_groq_module_loads
#
# Pre-sets the source guard variable to confirm that sourcing the module a
# second time is a safe no-op (exits 0 immediately without re-executing body).
# =============================================================================
test_groq_module_loads() {
    # Pre-arm the guard so no external commands are attempted.
    _GROQ_LOADED=1
    # shellcheck source=modules/groq.sh
    source "${REPO_DIR}/modules/groq.sh"
    local rc=$?
    assert_eq "${rc}" "0"
}

# =============================================================================
# test_groq_functions_exist
#
# Asserts that all three required public functions are defined after the module
# has been sourced.  Clears the source guard first so the full module body
# loads cleanly.
# =============================================================================
test_groq_functions_exist() {
    # Clear the guard so the module body is executed and functions are defined.
    unset _GROQ_LOADED
    # shellcheck source=modules/groq.sh
    source "${REPO_DIR}/modules/groq.sh"

    if declare -f install_groq &>/dev/null; then
        _pass "function 'install_groq' is defined"
    else
        _fail "function 'install_groq' is NOT defined"
    fi

    if declare -f configure_groq &>/dev/null; then
        _pass "function 'configure_groq' is defined"
    else
        _fail "function 'configure_groq' is NOT defined"
    fi

    if declare -f verify_groq &>/dev/null; then
        _pass "function 'verify_groq' is defined"
    else
        _fail "function 'verify_groq' is NOT defined"
    fi
}

# =============================================================================
# test_configure_exports_key
#
# Redirects HOME to a temporary directory containing a .bashrc, sets a fake
# GROQ_API_KEY, then calls configure_groq and asserts that the export line was
# written to the fake ~/.bashrc.
# =============================================================================
test_configure_exports_key() {
    # ── Set up a disposable HOME ──────────────────────────────────────────────
    local fake_home
    fake_home="$(mktemp -d)"
    touch "${fake_home}/.bashrc"

    local original_home="${HOME}"
    HOME="${fake_home}"

    # ── Provide a fake API key so the export branch is exercised ─────────────
    local original_key="${GROQ_API_KEY:-}"
    GROQ_API_KEY="gsk_test_fake_key_12345"

    # Ensure the module functions are available.
    unset _GROQ_LOADED
    # shellcheck source=modules/groq.sh
    source "${REPO_DIR}/modules/groq.sh"

    configure_groq

    # ── Assert export was written ─────────────────────────────────────────────
    local bashrc_content
    bashrc_content="$(< "${fake_home}/.bashrc")"
    assert_contains "${bashrc_content}" "GROQ_API_KEY"

    # ── Tear down ─────────────────────────────────────────────────────────────
    HOME="${original_home}"
    GROQ_API_KEY="${original_key}"
    rm -rf "${fake_home}"
}

# =============================================================================
# test_configure_warns_if_no_key
#
# Calls configure_groq with GROQ_API_KEY unset and verifies that the function
# exits with status 0 (i.e. it only warns, never aborts).
# =============================================================================
test_configure_warns_if_no_key() {
    # ── Set up a disposable HOME ──────────────────────────────────────────────
    local fake_home
    fake_home="$(mktemp -d)"
    touch "${fake_home}/.bashrc"

    local original_home="${HOME}"
    HOME="${fake_home}"

    # Ensure GROQ_API_KEY is absent for this test.
    local original_key="${GROQ_API_KEY:-}"
    unset GROQ_API_KEY

    # Ensure the module functions are available.
    unset _GROQ_LOADED
    # shellcheck source=modules/groq.sh
    source "${REPO_DIR}/modules/groq.sh"

    # Call configure_groq; it must not exit non-zero.
    configure_groq
    local rc=$?
    assert_eq "${rc}" "0"

    # ── Tear down ─────────────────────────────────────────────────────────────
    HOME="${original_home}"
    # Restore the key if it was originally set.
    if [[ -n "${original_key}" ]]; then
        GROQ_API_KEY="${original_key}"
    fi
    rm -rf "${fake_home}"
}

# =============================================================================
# test_verify_sets_status
#
# Calls verify_groq and asserts that VERIFY_STATUS is set to either "ok" or
# "fail" — i.e. the function always communicates a result regardless of whether
# the groq package is installed in the current environment.
# =============================================================================
test_verify_sets_status() {
    # Ensure the module functions are available.
    unset _GROQ_LOADED
    # shellcheck source=modules/groq.sh
    source "${REPO_DIR}/modules/groq.sh"

    # Reset the variable so we can detect whether verify_groq sets it.
    VERIFY_STATUS=""

    # Allow the function to fail without aborting the test (it returns 1 when
    # the package is absent, which is expected behaviour in a CI environment).
    verify_groq || true

    if [[ "${VERIFY_STATUS}" == "ok" || "${VERIFY_STATUS}" == "fail" ]]; then
        _pass "VERIFY_STATUS is '${VERIFY_STATUS}' (valid value)"
    else
        _fail "VERIFY_STATUS is '${VERIFY_STATUS:-<empty>}' — expected 'ok' or 'fail'"
    fi
}

# =============================================================================
# Run all tests
# =============================================================================
run_test test_groq_module_loads
run_test test_groq_functions_exist
run_test test_configure_exports_key
run_test test_configure_warns_if_no_key
run_test test_verify_sets_status

print_results
