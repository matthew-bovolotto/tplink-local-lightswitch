#!/bin/bash
# Run the project test suites: Python (pytest) and bash (bash_unit).
# Extra args (e.g. -k name, -v) are passed straight through to pytest.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "== Python tests (pytest) =="
"${SCRIPT_DIR}/venv/bin/python" -m pytest "$@"

echo
echo "== Bash tests (bash_unit) =="
"${SCRIPT_DIR}/tests/bash/bash_unit" "${SCRIPT_DIR}"/tests/bash/test_*.sh
