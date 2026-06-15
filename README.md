# tplink-manager

Monitor TP-Link/Kasa smart switches and toggle their associated lights.

When a monitored switch's on/off state changes, its lights are toggled
together: if any light in the group is on, all are turned off; otherwise all
are turned on. Multiple independent switch/light groups ("servers") can be
monitored concurrently.

## Requirements

- Python 3.11+ (uses the built-in `tomllib`)
- TP-Link/Kasa devices reachable on your local network
- [`python-kasa`](https://github.com/python-kasa/python-kasa) (installed below)

## Setup

```bash
python3 -m venv venv
venv/bin/pip install -e .
```

## Configuration

Devices are configured in `config.toml`. Each `[[server]]` block is an
independent group: one switch and the lights it controls.

```toml
# Seconds to wait between switch state checks. Can be overridden per server.
poll_interval = 2.0

[[server]]
name = "bedroom"
switch = "192.168.0.10"
lights = ["192.168.0.11", "192.168.0.12"]

# Add more groups to monitor them concurrently:
# [[server]]
# name = "living-room"
# switch = "192.168.0.20"
# lights = ["192.168.0.21"]
```

| Key             | Scope          | Description                                              |
| --------------- | -------------- | ------------------------------------------------------- |
| `poll_interval` | top-level      | Default seconds between switch checks.                   |
| `name`          | per `[[server]]` | Label used in log output (defaults to the switch IP). |
| `switch`        | per `[[server]]` | IP address of the switch to monitor.                  |
| `lights`        | per `[[server]]` | IP addresses of the lights to toggle.                 |
| `poll_interval` | per `[[server]]` | Optional per-group override of the default interval.  |

## Running as a service (recommended)

This tool is designed to run continuously as a **systemd service**. First
complete [Setup](#setup) so the virtualenv exists, then install it with the
helper in the `services/` folder:

```bash
sudo services/install.bash
```

This installs the unit, copies `config.toml` to a root-owned location
(`/etc/tplink-manager/config.toml`), and enables + starts the service running
as the installing user. See [`services/`](services/) for details.

## Running a local copy (development)

To run a local copy directly — for development or a quick try-out — use
`startup.bash` (this does **not** install a service):

```bash
./startup.bash                 # uses config.toml in the current directory
./startup.bash -c other.toml   # use a different config file
```

Or run the module directly:

```bash
venv/bin/python src/TPlinkManager.py -c config.toml
```

Stop with `Ctrl-C`.

## Testing

Install the dev dependencies and run the suite:

```bash
venv/bin/pip install -e '.[dev]'
venv/bin/python -m pytest
```

Tests use lightweight fakes (`tests/conftest.py`) in place of real devices, so
no hardware or network access is required.

## How it works

On startup the manager discovers and connects to every configured device, then
polls each switch on its interval. When a switch's state changes, the group's
lights are read and toggled as a unit. Transient device/network errors during a
poll are logged and skipped rather than crashing the program.
