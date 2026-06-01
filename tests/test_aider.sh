#!/usr/bin/env bash
# tests/test_aider.sh
#
# Unit tests for modules/aider.sh.
# These tests validate module structure and configuration logic only —
# no real API key, pip install, or aider binary is required.
#
# Usage:
#   bash tests/test_aider.sh

set -uo pipefail

# ── Resolve paths ─────────────────────────────────────────────────────────────
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${TESTS_DIR}/.." && pwd)"

# ── Source the test framework ─────────────────────────────────────────────────
# shellcheck source=tests/framework.sh
source "${TESTS_DIR}/framework.sh"

# =============================================================================
# test_aider_module_loads
#
# Sources modules/aider.sh with the source guard pre-set (_AIDER_LOADED=1) so
# that the pip3 install side-effect is skipped entirely.  Asserts that sourcing
# completes with exit status 0.
# =============================================================================
test_aider_module_loads() {
    # Pre-set the source guard so the body of the file is skipped — we only
    # want to confirm the file can be sourced without a syntax error.
    _AIDER_LOADED=1
    # shellcheck source=modules/aider.sh
    source "${REPO_DIR}/modules/aider.sh"
    local rc=$?
    assert_eq "${rc}" "0"
}

# =============================================================================
# test_aider_functions_exist
#
# Asserts that all three required public functions are defined after the module
# has been sourced without the guard so the function definitions are evaluated.
# =============================================================================
test_aider_functions_exist() {
    # Clear the source guard so the full file body (function definitions) is
    # evaluated on this explicit source.
    unset _AIDER_LOADED
    # shellcheck source=modules/aider.sh
    source "${REPO_DIR}/modules/aider.sh"

    if declare -f install_aider &>/dev/null; then
        _pass "function 'install_aider' is defined"
    else
        _fail "function 'install_aider' is NOT defined"
    fi

    if declare -f configure_aider &>/dev/null; then
        _pass "function 'configure_aider' is defined"
    else
        _fail "function 'configure_aider' is NOT defined"
    fi

    if declare -f verify_aider &>/dev/null; then
        _pass "function 'verify_aider' is defined"
    else
        _fail "function 'verify_aider' is NOT defined"
    fi
}

# =============================================================================
# test_aider_openrouter_priority
#
# Verifies that configure_aider chooses the OpenRouter backend when
# OPENROUTER_API_KEY is set, even if other keys are also present.
# Runs in a subshell with a temporary HOME so that writes to ~/.bashrc are
# isolated from the real user environment.
# Asserts that AIDER_OPENAI_API_BASE is written to the fake ~/.bashrc.
# =============================================================================
test_aider_openrouter_priority() {
    # Run the entire assertion inside a subshell so that the fake HOME and
    # env vars are fully isolated and do not leak into other tests.
    (
        # Set up a temporary home directory with a blank .bashrc.
        local fake_home
        fake_home="$(mktemp -d)"
        touch "${fake_home}/.bashrc"
        export HOME="${fake_home}"

        # Supply all three keys — OpenRouter must win.
        export OPENROUTER_API_KEY="or-test-key-12345"
        export ANTHROPIC_API_KEY="sk-ant-test"
        export OPENAI_API_KEY="sk-openai-test"

        # Ensure the module functions are available in this subshell.
        unset _AIDER_LOADED
        # shellcheck source=modules/aider.sh
        source "${REPO_DIR}/modules/aider.sh"

        configure_aider

        # The OpenRouter base URL must have been written to the fake ~/.bashrc.
        if grep -qF "AIDER_OPENAI_API_BASE" "${fake_home}/.bashrc"; then
            _pass "AIDER_OPENAI_API_BASE written to ~/.bashrc (OpenRouter backend selected)"
        else
            _fail "AIDER_OPENAI_API_BASE NOT found in ~/.bashrc — OpenRouter priority check failed"
        fi

        # The alias must also be present.
        if grep -qF "alias aider=" "${fake_home}/.bashrc"; then
            _pass "alias aider written to ~/.bashrc"
        else
            _fail "alias aider NOT found in ~/.bashrc"
        fi

        # Clean up.
        rm -rf "${fake_home}"
    )
}

# =============================================================================
# test_verify_sets_status
#
# Calls verify_aider and asserts that VERIFY_STATUS is set to either "ok" or
# "fail".  The function is expected to set the variable regardless of whether
# the aider binary is installed on the current machine.
# =============================================================================
test_verify_sets_status() {
    # Ensure the module is loaded.
    # shellcheck source=modules/aider.sh
    source "${REPO_DIR}/modules/aider.sh"

    # Reset the variable so we can detect whether verify_aider sets it.
    VERIFY_STATUS=""

    # Allow the function to fail without aborting the test (returns 1 when
    # aider is not installed, which is expected in a clean environment).
    verify_aider || true

    if [[ "${VERIFY_STATUS}" == "ok" || "${VERIFY_STATUS}" == "fail" ]]; then
        _pass "VERIFY_STATUS is '${VERIFY_STATUS}' (valid value)"
    else
        _fail "VERIFY_STATUS is '${VERIFY_STATUS:-<empty>}' — expected 'ok' or 'fail'"
    fi
}

# =============================================================================
# Run all tests
# =============================================================================
run_test test_aider_module_loads
run_test test_aider_functions_exist
run_test test_aider_openrouter_priority
run_test test_verify_sets_status

print_results
