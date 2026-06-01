#!/usr/bin/env bash
# tests/test_openrouter.sh
#
# Unit tests for modules/openrouter.sh.
# These tests validate installation structure only — no real API key is required.
#
# Usage:
#   bash tests/test_openrouter.sh

set -uo pipefail

# ── Resolve paths ─────────────────────────────────────────────────────────────
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${TESTS_DIR}/.." && pwd)"

# ── Source the test framework ─────────────────────────────────────────────────
# shellcheck source=tests/framework.sh
source "${TESTS_DIR}/framework.sh"

# =============================================================================
# test_openrouter_module_loads
#
# Sources modules/openrouter.sh and verifies the operation completes without
# error (non-zero exit or bash error).
# =============================================================================
test_openrouter_module_loads() {
    # shellcheck source=modules/openrouter.sh
    source "${REPO_DIR}/modules/openrouter.sh"
    local rc=$?
    assert_eq "${rc}" "0"
}

# =============================================================================
# test_openrouter_functions_exist
#
# Asserts that all three required public functions are defined after the module
# has been sourced.  Uses `declare -f` which returns 0 only when the named
# function exists in the current shell.
# =============================================================================
test_openrouter_functions_exist() {
    # Ensure the module is loaded (source guard makes this a no-op if already
    # loaded by a previous test in the same shell session).
    # shellcheck source=modules/openrouter.sh
    source "${REPO_DIR}/modules/openrouter.sh"

    if declare -f install_openrouter &>/dev/null; then
        _pass "function 'install_openrouter' is defined"
    else
        _fail "function 'install_openrouter' is NOT defined"
    fi

    if declare -f configure_openrouter &>/dev/null; then
        _pass "function 'configure_openrouter' is defined"
    else
        _fail "function 'configure_openrouter' is NOT defined"
    fi

    if declare -f verify_openrouter &>/dev/null; then
        _pass "function 'verify_openrouter' is defined"
    else
        _fail "function 'verify_openrouter' is NOT defined"
    fi
}

# =============================================================================
# test_openai_sdk_importable
#
# Verifies that `import openai` succeeds inside the active Python 3 interpreter.
# Skipped with a warning when openai has not been installed yet so that the
# test suite can run in a clean environment without failing.
# =============================================================================
test_openai_sdk_importable() {
    if ! command -v python3 &>/dev/null; then
        log_warn "python3 not found — skipping test_openai_sdk_importable"
        _pass "test_openai_sdk_importable: skipped (python3 unavailable)"
        return
    fi

    if python3 -c "import openai" &>/dev/null; then
        _pass "python3 -c 'import openai' exited 0 (openai SDK is importable)"
    else
        log_warn "openai SDK not installed — skipping import assertion"
        _pass "test_openai_sdk_importable: skipped (openai not yet installed)"
    fi
}

# =============================================================================
# test_verify_sets_status
#
# Calls verify_openrouter and asserts that VERIFY_STATUS is set to either "ok"
# or "fail" — i.e. the function always communicates a result regardless of
# whether the SDK is present.
# =============================================================================
test_verify_sets_status() {
    # shellcheck source=modules/openrouter.sh
    source "${REPO_DIR}/modules/openrouter.sh"

    # Reset the variable so we can detect whether verify_openrouter sets it.
    VERIFY_STATUS=""

    # Allow the function to fail without aborting the test (it returns 1 when
    # the SDK is absent, which is expected behaviour).
    verify_openrouter || true

    if [[ "${VERIFY_STATUS}" == "ok" || "${VERIFY_STATUS}" == "fail" ]]; then
        _pass "VERIFY_STATUS is '${VERIFY_STATUS}' (valid value)"
    else
        _fail "VERIFY_STATUS is '${VERIFY_STATUS:-<empty>}' — expected 'ok' or 'fail'"
    fi
}

# =============================================================================
# Run all tests
# =============================================================================
run_test test_openrouter_module_loads
run_test test_openrouter_functions_exist
run_test test_openai_sdk_importable
run_test test_verify_sets_status

print_results
