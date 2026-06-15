#!/bin/bash
# Run the full test suite via pytest. This includes the Python unit tests and
# the bash_unit installer tests (collected as pytest cases in test_bash.py).
# Extra args (e.g. -k name) are passed straight through to pytest.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/venv/bin/python" -m pytest -v "$@"
