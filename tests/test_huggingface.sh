#!/usr/bin/env bash
# tests/test_huggingface.sh
#
# Unit tests for modules/huggingface.sh.
# These tests validate module structure and configuration logic only —
# no real token or pip installation is required.
#
# Usage:
#   bash tests/test_huggingface.sh

set -uo pipefail

# ── Resolve paths ─────────────────────────────────────────────────────────────
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${TESTS_DIR}/.." && pwd)"

# ── Source the test framework ─────────────────────────────────────────────────
# shellcheck source=tests/framework.sh
source "${TESTS_DIR}/framework.sh"

# =============================================================================
# test_huggingface_module_loads
#
# Pre-sets the source guard variable to confirm that sourcing the module a
# second time is a safe no-op (exits 0 immediately without re-executing body).
# =============================================================================
test_huggingface_module_loads() {
    _HUGGINGFACE_LOADED=1
    # shellcheck source=modules/huggingface.sh
    source "${REPO_DIR}/modules/huggingface.sh"
    local rc=$?
    assert_eq "${rc}" "0"
}

# =============================================================================
# test_huggingface_functions_exist
#
# Asserts that all three required public functions are defined after the module
# has been sourced.  Clears the source guard first so the full module body
# loads cleanly.
# =============================================================================
test_huggingface_functions_exist() {
    unset _HUGGINGFACE_LOADED
    # shellcheck source=modules/huggingface.sh
    source "${REPO_DIR}/modules/huggingface.sh"

    if declare -f install_huggingface &>/dev/null; then
        _pass "function 'install_huggingface' is defined"
    else
        _fail "function 'install_huggingface' is NOT defined"
    fi

    if declare -f configure_huggingface &>/dev/null; then
        _pass "function 'configure_huggingface' is defined"
    else
        _fail "function 'configure_huggingface' is NOT defined"
    fi

    if declare -f verify_huggingface &>/dev/null; then
        _pass "function 'verify_huggingface' is defined"
    else
        _fail "function 'verify_huggingface' is NOT defined"
    fi
}

# =============================================================================
# test_configure_exports_key
#
# Redirects HOME to a temporary directory containing a .bashrc, sets a fake
# HUGGINGFACE_TOKEN, then calls configure_huggingface and asserts that the
# export line was written to the fake ~/.bashrc.
#
# The huggingface-cli login command is stubbed out so no real CLI is needed.
# =============================================================================
test_configure_exports_key() {
    local fake_home
    fake_home="$(mktemp -d)"
    touch "${fake_home}/.bashrc"

    local original_home="${HOME}"
    HOME="${fake_home}"

    local original_token="${HUGGINGFACE_TOKEN:-}"
    HUGGINGFACE_TOKEN="hf_test_token_12345"

    # Stub huggingface-cli so the login call does not require the real binary.
    huggingface-cli() { return 0; }

    unset _HUGGINGFACE_LOADED
    # shellcheck source=modules/huggingface.sh
    source "${REPO_DIR}/modules/huggingface.sh"

    configure_huggingface

    local bashrc_content
    bashrc_content="$(< "${fake_home}/.bashrc")"
    assert_contains "${bashrc_content}" "HUGGINGFACE_TOKEN"

    # ── Tear down ─────────────────────────────────────────────────────────────
    unset -f huggingface-cli
    HOME="${original_home}"
    if [[ -n "${original_token}" ]]; then
        HUGGINGFACE_TOKEN="${original_token}"
    else
        unset HUGGINGFACE_TOKEN
    fi
    rm -rf "${fake_home}"
}

# =============================================================================
# test_configure_warns_if_no_key
#
# Calls configure_huggingface with HUGGINGFACE_TOKEN unset and verifies that
# the function exits with status 0 (i.e. it only warns, never aborts).
# =============================================================================
test_configure_warns_if_no_key() {
    local fake_home
    fake_home="$(mktemp -d)"
    touch "${fake_home}/.bashrc"

    local original_home="${HOME}"
    HOME="${fake_home}"

    local original_token="${HUGGINGFACE_TOKEN:-}"
    unset HUGGINGFACE_TOKEN

    unset _HUGGINGFACE_LOADED
    # shellcheck source=modules/huggingface.sh
    source "${REPO_DIR}/modules/huggingface.sh"

    configure_huggingface
    local rc=$?
    assert_eq "${rc}" "0"

    # ── Tear down ─────────────────────────────────────────────────────────────
    HOME="${original_home}"
    if [[ -n "${original_token}" ]]; then
        HUGGINGFACE_TOKEN="${original_token}"
    fi
    rm -rf "${fake_home}"
}

# =============================================================================
# test_verify_sets_status
#
# Calls verify_huggingface and asserts that VERIFY_STATUS is set to either
# "ok" or "fail" — i.e. the function always communicates a result regardless
# of whether huggingface-cli is installed in the current environment.
# =============================================================================
test_verify_sets_status() {
    unset _HUGGINGFACE_LOADED
    # shellcheck source=modules/huggingface.sh
    source "${REPO_DIR}/modules/huggingface.sh"

    VERIFY_STATUS=""

    verify_huggingface || true

    if [[ "${VERIFY_STATUS}" == "ok" || "${VERIFY_STATUS}" == "fail" ]]; then
        _pass "VERIFY_STATUS is '${VERIFY_STATUS}' (valid value)"
    else
        _fail "VERIFY_STATUS is '${VERIFY_STATUS:-<empty>}' — expected 'ok' or 'fail'"
    fi
}

# =============================================================================
# Run all tests
# =============================================================================
run_test test_huggingface_module_loads
run_test test_huggingface_functions_exist
run_test test_configure_exports_key
run_test test_configure_warns_if_no_key
run_test test_verify_sets_status

print_results
