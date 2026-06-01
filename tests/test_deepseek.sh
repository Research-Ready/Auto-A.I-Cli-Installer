#!/usr/bin/env bash
# tests/test_deepseek.sh
#
# Unit tests for modules/deepseek.sh.
# These tests validate module structure and configuration logic only —
# no real API key or pip installation is required.
#
# Usage:
#   bash tests/test_deepseek.sh

set -uo pipefail

# ── Resolve paths ─────────────────────────────────────────────────────────────
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${TESTS_DIR}/.." && pwd)"

# ── Source the test framework ─────────────────────────────────────────────────
# shellcheck source=tests/framework.sh
source "${TESTS_DIR}/framework.sh"

# =============================================================================
# test_deepseek_module_loads
#
# Pre-sets the source guard variable to confirm that sourcing the module a
# second time is a safe no-op (exits 0 immediately without re-executing body).
# =============================================================================
test_deepseek_module_loads() {
    _DEEPSEEK_LOADED=1
    # shellcheck source=modules/deepseek.sh
    source "${REPO_DIR}/modules/deepseek.sh"
    local rc=$?
    assert_eq "${rc}" "0"
}

# =============================================================================
# test_deepseek_functions_exist
#
# Asserts that all three required public functions are defined after the module
# has been sourced.  Clears the source guard first so the full module body
# loads cleanly.
# =============================================================================
test_deepseek_functions_exist() {
    unset _DEEPSEEK_LOADED
    # shellcheck source=modules/deepseek.sh
    source "${REPO_DIR}/modules/deepseek.sh"

    if declare -f install_deepseek &>/dev/null; then
        _pass "function 'install_deepseek' is defined"
    else
        _fail "function 'install_deepseek' is NOT defined"
    fi

    if declare -f configure_deepseek &>/dev/null; then
        _pass "function 'configure_deepseek' is defined"
    else
        _fail "function 'configure_deepseek' is NOT defined"
    fi

    if declare -f verify_deepseek &>/dev/null; then
        _pass "function 'verify_deepseek' is defined"
    else
        _fail "function 'verify_deepseek' is NOT defined"
    fi
}

# =============================================================================
# test_configure_exports_key_and_base_url
#
# Redirects HOME to a temporary directory containing a .bashrc, sets a fake
# DEEPSEEK_API_KEY, then calls configure_deepseek and asserts that both the
# API key export and the DEEPSEEK_BASE_URL export were written to ~/.bashrc.
# =============================================================================
test_configure_exports_key_and_base_url() {
    local fake_home
    fake_home="$(mktemp -d)"
    touch "${fake_home}/.bashrc"

    local original_home="${HOME}"
    HOME="${fake_home}"

    local original_key="${DEEPSEEK_API_KEY:-}"
    DEEPSEEK_API_KEY="ds-test-key-12345"

    unset _DEEPSEEK_LOADED
    # shellcheck source=modules/deepseek.sh
    source "${REPO_DIR}/modules/deepseek.sh"

    configure_deepseek

    local bashrc_content
    bashrc_content="$(< "${fake_home}/.bashrc")"
    assert_contains "${bashrc_content}" "DEEPSEEK_API_KEY"
    assert_contains "${bashrc_content}" "DEEPSEEK_BASE_URL"
    assert_contains "${bashrc_content}" "https://api.deepseek.com/v1"

    # ── Tear down ─────────────────────────────────────────────────────────────
    HOME="${original_home}"
    if [[ -n "${original_key}" ]]; then
        DEEPSEEK_API_KEY="${original_key}"
    else
        unset DEEPSEEK_API_KEY
    fi
    rm -rf "${fake_home}"
}

# =============================================================================
# test_configure_warns_if_no_key
#
# Calls configure_deepseek with DEEPSEEK_API_KEY unset and verifies that the
# function exits with status 0 (i.e. it only warns, never aborts).
# =============================================================================
test_configure_warns_if_no_key() {
    local fake_home
    fake_home="$(mktemp -d)"
    touch "${fake_home}/.bashrc"

    local original_home="${HOME}"
    HOME="${fake_home}"

    local original_key="${DEEPSEEK_API_KEY:-}"
    unset DEEPSEEK_API_KEY

    unset _DEEPSEEK_LOADED
    # shellcheck source=modules/deepseek.sh
    source "${REPO_DIR}/modules/deepseek.sh"

    configure_deepseek
    local rc=$?
    assert_eq "${rc}" "0"

    # ── Tear down ─────────────────────────────────────────────────────────────
    HOME="${original_home}"
    if [[ -n "${original_key}" ]]; then
        DEEPSEEK_API_KEY="${original_key}"
    fi
    rm -rf "${fake_home}"
}

# =============================================================================
# test_verify_sets_status
#
# Calls verify_deepseek and asserts that VERIFY_STATUS is set to either "ok"
# or "fail" — i.e. the function always communicates a result regardless of
# whether the openai SDK is present.
# =============================================================================
test_verify_sets_status() {
    unset _DEEPSEEK_LOADED
    # shellcheck source=modules/deepseek.sh
    source "${REPO_DIR}/modules/deepseek.sh"

    VERIFY_STATUS=""

    verify_deepseek || true

    if [[ "${VERIFY_STATUS}" == "ok" || "${VERIFY_STATUS}" == "fail" ]]; then
        _pass "VERIFY_STATUS is '${VERIFY_STATUS}' (valid value)"
    else
        _fail "VERIFY_STATUS is '${VERIFY_STATUS:-<empty>}' — expected 'ok' or 'fail'"
    fi
}

# =============================================================================
# Run all tests
# =============================================================================
run_test test_deepseek_module_loads
run_test test_deepseek_functions_exist
run_test test_configure_exports_key_and_base_url
run_test test_configure_warns_if_no_key
run_test test_verify_sets_status

print_results
