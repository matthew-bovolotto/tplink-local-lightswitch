#!/bin/bash
# Run a LOCAL copy of the manager (e.g. for development or a quick try-out)
# using the project virtualenv. Extra args (e.g. -c other.toml) are passed
# straight through.
#
# For normal/production use this tool is meant to run as a systemd service —
# install it with services/install.bash instead of using this script.
exec venv/bin/python src/TPlinkManager.py "$@"
