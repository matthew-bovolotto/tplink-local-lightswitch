#!/bin/bash
# Run the manager using the project virtualenv. Extra args (e.g. -c other.toml)
# are passed straight through.
exec venv/bin/python src/TPlinkManager.py "$@"
