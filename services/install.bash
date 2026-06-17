#!/bin/bash
# Install the tplink-manager systemd service.
#
# Copies the unit into the system unit directory, installs the config into a
# root-owned location, reloads systemd, and enables + starts the service.
# Run with root privileges, e.g.:
#
#   sudo services/install.bash
#
# Install targets can be overridden via environment variables (used by the
# test suite): SYSTEMD_DIR, CONFIG_DIR, SYSTEMCTL.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"
UNIT_NAME="tplink-manager.service"
UNIT_SRC="${SCRIPT_DIR}/${UNIT_NAME}"

SYSTEMD_DIR="${SYSTEMD_DIR:-/etc/systemd/system}"
CONFIG_DIR="${CONFIG_DIR:-/etc/tplink-manager}"
SYSTEMCTL="${SYSTEMCTL:-systemctl}"

# User the service runs as. Defaults to the user invoking the installer
# (SUDO_USER when run via sudo), and can be overridden with RUN_USER.
RUN_USER="${RUN_USER:-${SUDO_USER:-$(id -un)}}"

UNIT_DEST="${SYSTEMD_DIR}/${UNIT_NAME}"
CONFIG_SRC="${REPO_DIR}/config.toml"
CONFIG_DEST="${CONFIG_DIR}/config.toml"

# True if we can create/modify entries in $1: the dir itself must be writable,
# or (if it doesn't exist yet) its parent must be.
can_write_into() {
    local dir="$1"
    if [[ -d "${dir}" ]]; then
        [[ -w "${dir}" ]]
    else
        [[ -w "$(dirname "${dir}")" ]]
    fi
}

# --- Pre-flight checks -----------------------------------------------------

# 1. systemd must be available.
if ! command -v "${SYSTEMCTL}" >/dev/null 2>&1; then
    echo "Error: ${SYSTEMCTL} not found; this system does not appear to use systemd." >&2
    exit 1
fi

# 2. The unit file and source config must exist.
if [[ ! -f "${UNIT_SRC}" ]]; then
    echo "Error: unit file not found at ${UNIT_SRC}" >&2
    exit 1
fi
if [[ ! -f "${CONFIG_SRC}" ]]; then
    echo "Error: config file not found at ${CONFIG_SRC}" >&2
    exit 1
fi

# 2b. The target run-user must exist.
if ! id "${RUN_USER}" >/dev/null 2>&1; then
    echo "Error: target user '${RUN_USER}' does not exist." >&2
    exit 1
fi

# 3. We need permission to write to both install locations.
if ! can_write_into "${SYSTEMD_DIR}" || ! can_write_into "${CONFIG_DIR}"; then
    echo "Error: insufficient permissions to write to ${SYSTEMD_DIR} and/or ${CONFIG_DIR}." >&2
    if [[ "${EUID}" -ne 0 ]]; then
        echo "Re-run with root privileges:" >&2
        echo "  sudo ${BASH_SOURCE[0]}" >&2
    fi
    exit 1
fi

# --- Install ---------------------------------------------------------------

# Install the config into a root-owned, write-protected location.
echo "Installing config -> ${CONFIG_DEST}"
install -d -m 0755 "${CONFIG_DIR}"
if [[ -f "${CONFIG_DEST}" ]]; then
    if ! diff -q "${CONFIG_SRC}" "${CONFIG_DEST}" >/dev/null 2>&1; then
        echo "  ${CONFIG_DEST} differs from the project config."
        read -rp "  Overwrite with the newer project config? [y/N] " answer
        if [[ "${answer}" =~ ^[Yy]$ ]]; then
            install -m 0644 "${CONFIG_SRC}" "${CONFIG_DEST}"
            echo "  Config updated."
        else
            echo "  Keeping existing config."
        fi
    else
        echo "  ${CONFIG_DEST} is already up to date."
    fi
else
    install -m 0644 "${CONFIG_SRC}" "${CONFIG_DEST}"
fi

echo "Installing ${UNIT_NAME} -> ${UNIT_DEST} (User=${RUN_USER})"
sed -e "s|__RUN_USER__|${RUN_USER}|g" -e "s|__REPO_DIR__|${REPO_DIR}|g" "${UNIT_SRC}" \
    | install -m 0644 /dev/stdin "${UNIT_DEST}"

echo "Reloading systemd unit files..."
"${SYSTEMCTL}" daemon-reload

echo "Enabling and starting ${UNIT_NAME}..."
"${SYSTEMCTL}" enable --now "${UNIT_NAME}"

echo
echo "Waiting 5 seconds for service to start..."
sleep 5

if "${SYSTEMCTL}" is-active --quiet "${UNIT_NAME}"; then
    echo "Service is running."
else
    echo "Service failed to start."
    "${SYSTEMCTL}" status "${UNIT_NAME}" --no-pager || true
    echo
    echo "Check logs with:  journalctl -u ${UNIT_NAME} -f"
    exit 1
fi
