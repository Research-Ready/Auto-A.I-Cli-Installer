#!/usr/bin/env bash
# tests/test_common.sh — unit tests for modules/common.sh
#
# Run directly:
#   bash tests/test_common.sh
#
# Or via the suite runner:
#   bash tests/run_all.sh

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${TESTS_DIR}/.." && pwd)"

# Source the module under test and the test framework.
# shellcheck source=../modules/common.sh
source "${REPO_DIR}/modules/common.sh"

# shellcheck source=./framework.sh
source "${TESTS_DIR}/framework.sh"

# =============================================================================
# test_color_setup
#
# Verifies that color_setup (called automatically when common.sh is sourced)
# has populated RED, GREEN, and RESET with non-empty strings.
# =============================================================================
test_color_setup() {
    assert_env RED
    assert_env GREEN
    assert_env RESET
}

# =============================================================================
# test_has_cmd_found
#
# `has_cmd bash` must return exit code 0 because bash is always present when
# this test is running.
# =============================================================================
test_has_cmd_found() {
    if has_cmd bash; then
        _pass "has_cmd bash returned 0 (found)"
    else
        _fail "has_cmd bash returned non-zero — bash should always be present"
    fi
}

# =============================================================================
# test_has_cmd_missing
#
# `has_cmd totally_fake_command_xyz` must return a non-zero exit code.
# =============================================================================
test_has_cmd_missing() {
    if has_cmd totally_fake_command_xyz; then
        _fail "has_cmd totally_fake_command_xyz returned 0 — command should not exist"
    else
        _pass "has_cmd totally_fake_command_xyz returned non-zero (not found)"
    fi
}

# =============================================================================
# test_detect_os
#
# After calling detect_os, OS_TYPE must be one of the five known values.
# =============================================================================
test_detect_os() {
    detect_os

    local valid_values=("debian" "arch" "fedora" "macos" "unknown")
    local found=0
    local v
    for v in "${valid_values[@]}"; do
        if [[ "${OS_TYPE}" == "${v}" ]]; then
            found=1
            break
        fi
    done

    if [[ "${found}" -eq 1 ]]; then
        _pass "detect_os: OS_TYPE='${OS_TYPE}' is a valid value"
    else
        _fail "detect_os: OS_TYPE='${OS_TYPE}' is not a recognised value (expected one of: ${valid_values[*]})"
    fi
}

# =============================================================================
# test_write_shell_rc_idempotent
#
# Writes a unique test line twice to a temp file that simulates ~/.bashrc.
# Confirms the line appears exactly once in the file (idempotency).
# Cleans up the temp file afterwards.
# =============================================================================
test_write_shell_rc_idempotent() {
    local tmpfile
    tmpfile="$(mktemp)"

    # Override HOME so write_shell_rc targets our temp file as ~/.bashrc.
    local orig_home="${HOME}"
    # Create a fake home directory containing only a .bashrc pointing to tmpfile
    local fake_home
    fake_home="$(mktemp -d)"
    cp "${tmpfile}" "${fake_home}/.bashrc"
    HOME="${fake_home}"

    local test_line="export _TEST_IDEMPOTENCY_MARKER_XYZ=1"

    # Write the same line twice.
    write_shell_rc "${test_line}"
    write_shell_rc "${test_line}"

    # Count occurrences.
    local count
    count=$(grep -cF "${test_line}" "${fake_home}/.bashrc" 2>/dev/null || true)

    # Restore HOME before assertions so logging works normally.
    HOME="${orig_home}"

    # Clean up.
    rm -f "${tmpfile}"
    rm -rf "${fake_home}"

    if [[ "${count}" -eq 1 ]]; then
        _pass "write_shell_rc idempotency: line appears exactly once (count=${count})"
    else
        _fail "write_shell_rc idempotency: expected 1 occurrence, found ${count}"
    fi
}

# =============================================================================
# test_verify_cmd_success
#
# `verify_cmd bash` should succeed and set VERIFY_STATUS="ok".
# =============================================================================
test_verify_cmd_success() {
    VERIFY_STATUS=""
    # Disable errexit locally so the assertion handles failure gracefully.
    set +e
    verify_cmd bash
    local exit_code=$?
    set -e

    if [[ "${VERIFY_STATUS}" == "ok" && "${exit_code}" -eq 0 ]]; then
        _pass "verify_cmd bash: VERIFY_STATUS=ok, exit_code=0"
    else
        _fail "verify_cmd bash: expected VERIFY_STATUS=ok/exit 0, got VERIFY_STATUS='${VERIFY_STATUS}'/exit ${exit_code}"
    fi
}

# =============================================================================
# test_verify_cmd_fail
#
# `verify_cmd totally_fake_command_xyz` should fail and set VERIFY_STATUS="fail".
# =============================================================================
test_verify_cmd_fail() {
    VERIFY_STATUS=""
    set +e
    verify_cmd totally_fake_command_xyz
    local exit_code=$?
    set -e

    if [[ "${VERIFY_STATUS}" == "fail" && "${exit_code}" -ne 0 ]]; then
        _pass "verify_cmd totally_fake_command_xyz: VERIFY_STATUS=fail, exit_code=${exit_code}"
    else
        _fail "verify_cmd totally_fake_command_xyz: expected VERIFY_STATUS=fail/non-zero exit, got VERIFY_STATUS='${VERIFY_STATUS}'/exit ${exit_code}"
    fi
}

# =============================================================================
# Run all tests
# =============================================================================
run_test test_color_setup
run_test test_has_cmd_found
run_test test_has_cmd_missing
run_test test_detect_os
run_test test_write_shell_rc_idempotent
run_test test_verify_cmd_success
run_test test_verify_cmd_fail

print_results
