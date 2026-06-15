#!/bin/bash
# Run the test suite using the project virtualenv. Extra args (e.g. -k name,
# -v) are passed straight through to pytest.
exec venv/bin/python -m pytest "$@"
