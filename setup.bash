#!/bin/bash
# Bootstrap the project: create the virtualenv (if missing) and install all
# dependencies (runtime + dev) from pyproject.toml. Safe to re-run.
#
#   ./setup.bash
#
# Run this as a command, not with `source`/`.`: it uses `set -e` and `exit`,
# which would terminate the caller's shell if sourced.
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    echo "Run setup.bash as a command:  ./setup.bash   (do not 'source' it)." >&2
    return 1
fi

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${SCRIPT_DIR}/venv"

# Require a new-enough Python (tomllib needs 3.11+).
PYTHON="${PYTHON:-python3}"
if ! command -v "${PYTHON}" >/dev/null 2>&1; then
    echo "Error: ${PYTHON} not found; install Python 3.11+ first." >&2
    exit 1
fi

if [[ ! -d "${VENV_DIR}" ]]; then
    echo "Creating virtualenv at ${VENV_DIR}"
    "${PYTHON}" -m venv "${VENV_DIR}"
fi

echo "Installing dependencies (runtime + dev)..."
"${VENV_DIR}/bin/pip" install --upgrade pip >/dev/null
"${VENV_DIR}/bin/pip" install -e "${SCRIPT_DIR}[dev]"

echo
echo "Done. Next steps:"
echo "  ./run-tests.bash          # run the test suite"
echo "  ./startup.bash            # run a local copy (development)"
echo "  sudo services/install.bash  # install + run as a systemd service (recommended)"
