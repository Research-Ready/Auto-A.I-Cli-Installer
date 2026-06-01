#!/usr/bin/env bash
# tests/test_opencode.sh
#
# Unit tests for modules/opencode.sh.
# These tests validate module structure and configuration logic only —
# no real API key, curl installer, or opencode binary is required.
#
# Usage:
#   bash tests/test_opencode.sh

set -uo pipefail

# ── Resolve paths ─────────────────────────────────────────────────────────────
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${TESTS_DIR}/.." && pwd)"

# ── Source the test framework ─────────────────────────────────────────────────
# shellcheck source=tests/framework.sh
source "${TESTS_DIR}/framework.sh"

# =============================================================================
# test_opencode_module_loads
#
# Pre-sets the source guard variable to confirm that sourcing the module a
# second time is a safe no-op (exits 0 immediately without re-executing body).
# =============================================================================
test_opencode_module_loads() {
    # Pre-arm the guard so no external commands are attempted.
    _OPENCODE_LOADED=1
    # shellcheck source=modules/opencode.sh
    source "${REPO_DIR}/modules/opencode.sh"
    local rc=$?
    assert_eq "${rc}" "0"
}

# =============================================================================
# test_opencode_functions_exist
#
# Asserts that all three required public functions are defined after the module
# has been sourced.  Clears the source guard first so the full module body
# loads cleanly.
# =============================================================================
test_opencode_functions_exist() {
    # Clear the guard so the module body is executed and functions are defined.
    unset _OPENCODE_LOADED
    # shellcheck source=modules/opencode.sh
    source "${REPO_DIR}/modules/opencode.sh"

    if declare -f install_opencode &>/dev/null; then
        _pass "function 'install_opencode' is defined"
    else
        _fail "function 'install_opencode' is NOT defined"
    fi

    if declare -f configure_opencode &>/dev/null; then
        _pass "function 'configure_opencode' is defined"
    else
        _fail "function 'configure_opencode' is NOT defined"
    fi

    if declare -f verify_opencode &>/dev/null; then
        _pass "function 'verify_opencode' is defined"
    else
        _fail "function 'verify_opencode' is NOT defined"
    fi
}

# =============================================================================
# test_configure_uses_openrouter_first
#
# Verifies that configure_opencode selects the OpenRouter backend when
# OPENROUTER_API_KEY is set, even when ANTHROPIC_API_KEY is also present.
# Runs in a subshell with a temporary HOME so that writes to ~/.bashrc are
# isolated from the real user environment.
# Asserts that the OPENROUTER_API_KEY export appears in the fake ~/.bashrc.
# =============================================================================
test_configure_uses_openrouter_first() {
    # Run the entire assertion inside a subshell so that the fake HOME and
    # env vars are fully isolated and do not leak into other tests.
    (
        # Set up a temporary home directory with a blank .bashrc.
        local fake_home
        fake_home="$(mktemp -d)"
        touch "${fake_home}/.bashrc"
        export HOME="${fake_home}"

        # Supply both keys — OpenRouter must win.
        export OPENROUTER_API_KEY="or-test-key-12345"
        export ANTHROPIC_API_KEY="sk-ant-test"

        # Ensure the module functions are available in this subshell.
        unset _OPENCODE_LOADED
        # shellcheck source=modules/opencode.sh
        source "${REPO_DIR}/modules/opencode.sh"

        configure_opencode

        # The OPENROUTER_API_KEY export must have been written to fake ~/.bashrc.
        if grep -qF "OPENROUTER_API_KEY" "${fake_home}/.bashrc"; then
            _pass "OPENROUTER_API_KEY written to ~/.bashrc (OpenRouter backend selected)"
        else
            _fail "OPENROUTER_API_KEY NOT found in ~/.bashrc — OpenRouter priority check failed"
        fi

        # The alias must also be present.
        if grep -qF "alias opencode=" "${fake_home}/.bashrc"; then
            _pass "alias opencode written to ~/.bashrc"
        else
            _fail "alias opencode NOT found in ~/.bashrc"
        fi

        # Clean up.
        rm -rf "${fake_home}"
    )
}

# =============================================================================
# test_verify_sets_status
#
# Calls verify_opencode and asserts that VERIFY_STATUS is set to either "ok"
# or "fail".  The function is expected to set the variable regardless of
# whether the opencode binary is installed in the current environment.
# =============================================================================
test_verify_sets_status() {
    # Ensure the module functions are available.
    unset _OPENCODE_LOADED
    # shellcheck source=modules/opencode.sh
    source "${REPO_DIR}/modules/opencode.sh"

    # Reset the variable so we can detect whether verify_opencode sets it.
    VERIFY_STATUS=""

    # Allow the function to fail without aborting the test (returns 1 when
    # opencode is not installed, which is expected in a clean environment).
    verify_opencode || true

    if [[ "${VERIFY_STATUS}" == "ok" || "${VERIFY_STATUS}" == "fail" ]]; then
        _pass "VERIFY_STATUS is '${VERIFY_STATUS}' (valid value)"
    else
        _fail "VERIFY_STATUS is '${VERIFY_STATUS:-<empty>}' — expected 'ok' or 'fail'"
    fi
}

# =============================================================================
# Run all tests
# =============================================================================
run_test test_opencode_module_loads
run_test test_opencode_functions_exist
run_test test_configure_uses_openrouter_first
run_test test_verify_sets_status

print_results
