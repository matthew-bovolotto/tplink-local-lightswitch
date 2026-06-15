#!/usr/bin/env bash
# bash_unit tests for services/install.bash
#
# Run with:  tests/bash/bash_unit tests/bash/test_install.sh

INSTALL_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../services" && pwd)/install.bash"
UNIT_NAME="tplink-manager.service"

# Invoke the installer with the test environment (set up per test).
run_install() {
    "${INSTALL_SCRIPT}"
}

setup() {
    TESTDIR="$(mktemp -d)"
    export SYSTEMD_DIR="${TESTDIR}/systemd"
    export CONFIG_DIR="${TESTDIR}/etc/tplink-manager"

    # Destination dirs must be creatable: the unit dir exists, and the config
    # dir's parent exists (the installer creates the config dir itself).
    mkdir -p "${SYSTEMD_DIR}"
    mkdir -p "$(dirname "${CONFIG_DIR}")"

    # A fake systemctl that just records its invocations.
    SYSTEMCTL_LOG="${TESTDIR}/systemctl.log"
    export SYSTEMCTL="${TESTDIR}/systemctl"
    cat > "${SYSTEMCTL}" <<EOF
#!/bin/bash
echo "\$@" >> "${SYSTEMCTL_LOG}"
EOF
    chmod +x "${SYSTEMCTL}"
}

teardown() {
    # Restore write perms so read-only test dirs can be removed.
    chmod -R u+w "${TESTDIR}" 2>/dev/null || true
    rm -rf "${TESTDIR}"
}

# --- Happy path ------------------------------------------------------------

test_install_succeeds() {
    assert "run_install >/dev/null 2>&1" "installer should exit 0"
}

test_installs_unit_file() {
    run_install >/dev/null 2>&1
    assert "[ -f '${SYSTEMD_DIR}/${UNIT_NAME}' ]" "unit file not installed"
}

test_installs_config_file() {
    run_install >/dev/null 2>&1
    assert "[ -f '${CONFIG_DIR}/config.toml' ]" "config file not installed"
}

test_config_is_write_protected_0644() {
    run_install >/dev/null 2>&1
    assert_equals "644" "$(stat -c '%a' "${CONFIG_DIR}/config.toml")"
}

test_reloads_and_enables_via_systemctl() {
    run_install >/dev/null 2>&1
    assert "grep -q 'daemon-reload' '${SYSTEMCTL_LOG}'" "daemon-reload not called"
    assert "grep -q 'enable --now ${UNIT_NAME}' '${SYSTEMCTL_LOG}'" \
        "enable --now not called"
}

test_preserves_existing_config() {
    mkdir -p "${CONFIG_DIR}"
    echo "SENTINEL" > "${CONFIG_DIR}/config.toml"

    run_install >/dev/null 2>&1

    assert_equals "SENTINEL" "$(cat "${CONFIG_DIR}/config.toml")" \
        "existing config should not be overwritten"
}

# --- Run-user substitution -------------------------------------------------

test_substitutes_default_run_user() {
    run_install >/dev/null 2>&1
    local user
    user="$(id -un)"
    assert "grep -q '^User=${user}$' '${SYSTEMD_DIR}/${UNIT_NAME}'" \
        "unit should run as the invoking user by default"
    assert_fail "grep -q '__RUN_USER__' '${SYSTEMD_DIR}/${UNIT_NAME}'" \
        "placeholder should not remain in the installed unit"
}

test_respects_run_user_override() {
    export RUN_USER="root"
    run_install >/dev/null 2>&1
    assert "grep -q '^User=root$' '${SYSTEMD_DIR}/${UNIT_NAME}'" \
        "RUN_USER override should be honored"
}

test_fails_for_nonexistent_run_user() {
    export RUN_USER="no-such-user-zzz"
    assert_fail "run_install >/dev/null 2>&1" "should reject a missing user"
    assert "[ ! -f '${SYSTEMD_DIR}/${UNIT_NAME}' ]" "nothing should be installed"
}

# --- Failure paths ---------------------------------------------------------

test_fails_when_systemctl_missing() {
    export SYSTEMCTL="definitely-not-a-real-command-xyz"
    assert_fail "run_install >/dev/null 2>&1" "should fail without systemctl"
    assert "[ ! -f '${SYSTEMD_DIR}/${UNIT_NAME}' ]" "nothing should be installed"
}

test_fails_when_unit_dir_not_writable() {
    chmod 0500 "${SYSTEMD_DIR}"
    assert_fail "run_install >/dev/null 2>&1" "should fail on read-only unit dir"
}

test_fails_when_config_parent_not_writable() {
    chmod 0500 "$(dirname "${CONFIG_DIR}")"
    assert_fail "run_install >/dev/null 2>&1" "should fail on read-only config parent"
}

test_permission_error_suggests_sudo_when_nonroot() {
    if [[ "${EUID}" -eq 0 ]]; then
        # Running as root: the sudo hint is intentionally not shown.
        return 0
    fi
    chmod 0500 "${SYSTEMD_DIR}"
    assert_matches "sudo" "$(run_install 2>&1 || true)"
}
