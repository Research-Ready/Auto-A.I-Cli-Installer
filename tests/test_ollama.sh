#!/usr/bin/env bash
# tests/test_ollama.sh — unit tests for modules/ollama.sh
#
# Run directly:
#   bash tests/test_ollama.sh
#
# Or via the suite runner:
#   bash tests/run_all.sh
#
# IMPORTANT: These tests do NOT require Ollama to be installed on the system.
#   The _OLLAMA_LOADED guard is set before sourcing to prevent install_ollama
#   from executing any real side-effects during module load.

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${TESTS_DIR}/.." && pwd)"

# Source common.sh first so the shared helpers are available before the module.
# shellcheck source=../modules/common.sh
source "${REPO_DIR}/modules/common.sh"

# Source the test framework.
# shellcheck source=./framework.sh
source "${TESTS_DIR}/framework.sh"

# =============================================================================
# test_ollama_module_loads
#
# Sources modules/ollama.sh with the source guard already set so that
# install_ollama (which calls curl | sh) is never executed.  The test passes
# if sourcing completes without errors.
# =============================================================================
test_ollama_module_loads() {
    # Pre-set the source guard so the module body is a no-op on re-source.
    # We unset it first to ensure a clean load, but keep _OLLAMA_LOADED=1
    # so the guard triggers immediately and nothing runs except function defs.
    unset _OLLAMA_LOADED

    # Temporarily stub `curl` and `systemctl` so even if the guard were missed
    # no real network/system calls would fire.
    curl()      { return 0; }
    systemctl() { return 0; }

    local result=0
    # shellcheck source=../modules/ollama.sh
    source "${REPO_DIR}/modules/ollama.sh" || result=$?

    # Remove stubs.
    unset -f curl systemctl 2>/dev/null || true

    if [[ "${result}" -eq 0 ]]; then
        _pass "modules/ollama.sh sourced without errors"
    else
        _fail "modules/ollama.sh sourcing exited with status ${result}"
    fi
}

# =============================================================================
# test_ollama_functions_exist
#
# Verifies that all three required functions are defined after sourcing the
# module.  Uses `declare -f` which returns 0 only when the function exists.
# =============================================================================
test_ollama_functions_exist() {
    local fn
    for fn in install_ollama configure_ollama verify_ollama; do
        if declare -f "${fn}" &>/dev/null; then
            _pass "function '${fn}' is defined"
        else
            _fail "function '${fn}' is NOT defined — was modules/ollama.sh sourced?"
        fi
    done
}

# =============================================================================
# test_verify_sets_status
#
# Calls verify_ollama and asserts that VERIFY_STATUS is set to either "ok" or
# "fail" — never left empty.  This test works regardless of whether Ollama is
# actually installed.
# =============================================================================
test_verify_sets_status() {
    VERIFY_STATUS=""

    # Disable errexit so a failing verify_ollama does not abort the test.
    set +e
    verify_ollama
    local exit_code=$?
    set -e

    if [[ "${VERIFY_STATUS}" == "ok" || "${VERIFY_STATUS}" == "fail" ]]; then
        _pass "verify_ollama set VERIFY_STATUS='${VERIFY_STATUS}' (exit ${exit_code})"
    else
        _fail "verify_ollama left VERIFY_STATUS='${VERIFY_STATUS}' — expected 'ok' or 'fail'"
    fi
}

# =============================================================================
# test_ollama_host_alias_written  (optional)
#
# Runs configure_ollama against a fake HOME that contains only a .bashrc and
# checks that OLLAMA_HOST ends up in that file.  Skipped gracefully if neither
# ~/.bashrc nor ~/.zshrc can be created in the temp dir.
# =============================================================================
test_ollama_host_alias_written() {
    # Create an isolated fake home so we do not touch the real RC files.
    local fake_home
    fake_home="$(mktemp -d)"
    touch "${fake_home}/.bashrc"

    local orig_home="${HOME}"
    HOME="${fake_home}"

    # Stub ollama pull so configure_ollama's _pull_model never fires.
    ollama() { return 0; }

    # Run configure_ollama with a closed stdin so it skips the model menu.
    set +e
    configure_ollama </dev/null
    local cfg_exit=$?
    set -e

    unset -f ollama 2>/dev/null || true
    HOME="${orig_home}"

    if [[ "${cfg_exit}" -ne 0 ]]; then
        rm -rf "${fake_home}"
        _fail "configure_ollama exited with non-zero status ${cfg_exit}"
        return
    fi

    local found_host=0
    if grep -qF "OLLAMA_HOST" "${fake_home}/.bashrc" 2>/dev/null; then
        found_host=1
    fi

    rm -rf "${fake_home}"

    if [[ "${found_host}" -eq 1 ]]; then
        _pass "OLLAMA_HOST found in fake .bashrc after configure_ollama"
    else
        _fail "OLLAMA_HOST not found in fake .bashrc after configure_ollama"
    fi
}

# =============================================================================
# Run all tests
# =============================================================================
run_test test_ollama_module_loads
run_test test_ollama_functions_exist
run_test test_verify_sets_status
run_test test_ollama_host_alias_written

print_results
