#!/bin/bash
# Uninstall the tplink-manager systemd service.
#
# Stops and disables the service, removes the unit file and the installed
# config. Run with root privileges, e.g.:
#
#   sudo services/uninstall.bash
#
# Install targets can be overridden via environment variables (used by the
# test suite): SYSTEMD_DIR, CONFIG_DIR, SYSTEMCTL.
set -euo pipefail

UNIT_NAME="tplink-manager.service"

SYSTEMD_DIR="${SYSTEMD_DIR:-/etc/systemd/system}"
CONFIG_DIR="${CONFIG_DIR:-/etc/tplink-manager}"
SYSTEMCTL="${SYSTEMCTL:-systemctl}"

UNIT_DEST="${SYSTEMD_DIR}/${UNIT_NAME}"
CONFIG_DEST="${CONFIG_DIR}/config.toml"

# --- Pre-flight checks -----------------------------------------------------

if ! command -v "${SYSTEMCTL}" >/dev/null 2>&1; then
    echo "Error: ${SYSTEMCTL} not found; this system does not appear to use systemd." >&2
    exit 1
fi

if [[ "${EUID}" -ne 0 ]] && [[ ! -w "${SYSTEMD_DIR}" ]]; then
    echo "Error: insufficient permissions." >&2
    echo "Re-run with root privileges:" >&2
    echo "  sudo ${BASH_SOURCE[0]}" >&2
    exit 1
fi

# --- Uninstall -------------------------------------------------------------

if "${SYSTEMCTL}" is-active --quiet "${UNIT_NAME}" 2>/dev/null; then
    echo "Stopping ${UNIT_NAME}..."
    "${SYSTEMCTL}" stop "${UNIT_NAME}"
fi

if "${SYSTEMCTL}" is-enabled --quiet "${UNIT_NAME}" 2>/dev/null; then
    echo "Disabling ${UNIT_NAME}..."
    "${SYSTEMCTL}" disable "${UNIT_NAME}"
fi

if [[ -f "${UNIT_DEST}" ]]; then
    echo "Removing ${UNIT_DEST}"
    rm -f "${UNIT_DEST}"
    "${SYSTEMCTL}" daemon-reload
else
    echo "${UNIT_DEST} not found; skipping."
fi

if [[ -f "${CONFIG_DEST}" ]]; then
    echo "Removing ${CONFIG_DEST}"
    rm -f "${CONFIG_DEST}"
    rmdir --ignore-fail-on-non-empty "${CONFIG_DIR}" 2>/dev/null || true
else
    echo "${CONFIG_DEST} not found; skipping."
fi

echo "Done."
