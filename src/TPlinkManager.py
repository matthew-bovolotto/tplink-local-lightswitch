"""Monitor TP-Link/Kasa switches and toggle their associated lights.

When a monitored switch's on/off state changes, its lights are toggled
together: if any light is on, all are turned off; otherwise all are turned
on. Multiple independent switch/light groups ("servers") can be monitored
concurrently, configured via a TOML file.
"""

import argparse
import asyncio
import datetime
import tomllib
from pathlib import Path

from kasa import Discover

BREAK = "#=============================================#"
DEFAULT_CONFIG = "config.toml"
DEFAULT_POLL_INTERVAL = 2.0


def load_config(path):
    """Load servers and the default poll interval from a TOML config file."""
    with open(path, "rb") as f:
        config = tomllib.load(f)

    servers = config.get("server", [])
    if not servers:
        raise ValueError(f"No [[server]] entries found in {path}")

    poll_interval = config.get("poll_interval", DEFAULT_POLL_INTERVAL)
    return servers, poll_interval


class DeviceServer:
    """A single switch and the lights it controls."""

    def __init__(self, name, switch_host, light_hosts, poll_interval):
        self.name = name
        self.switch_host = switch_host
        self.light_hosts = light_hosts
        self.poll_interval = poll_interval
        self.switch = None
        self.lights = []

    async def setup(self):
        print(f"[{self.name}] Starting setup:")
        self.switch = await Discover.discover_single(self.switch_host)
        await self.switch.update()
        print(f"[{self.name}] {self.switch.alias}: switch ready")

        self.lights = []
        for host in self.light_hosts:
            light = await Discover.discover_single(host)
            await light.update()
            self.lights.append(light)
            print(f"[{self.name}] {light.alias}: light ready")

    async def run(self):
        await self.switch.update()
        switch_state = self.switch.is_on
        print(f"{self._stamp()} [{self.name}] switch is {self._state(switch_state)}")

        while True:
            await asyncio.sleep(self.poll_interval)
            try:
                await self.switch.update()
            except Exception as exc:  # network hiccup / device offline
                print(f"{self._stamp()} [{self.name}] update failed: {exc}")
                continue

            if self.switch.is_on != switch_state:
                switch_state = self.switch.is_on
                print(BREAK)
                print(
                    f"{self._stamp()} [{self.name}] switch changed: "
                    f"{self._state(switch_state)}"
                )
                await self.toggle_lights()
                print(BREAK)

    async def toggle_lights(self):
        """Toggle the group: off if any light is on, otherwise all on."""
        for light in self.lights:
            await light.update()
        any_on = any(light.is_on for light in self.lights)

        verb = "Off" if any_on else "On"
        for light in self.lights:
            if any_on and not light.is_on:
                continue  # already off, nothing to do
            if any_on:
                await light.turn_off()
            else:
                await light.turn_on()
            await light.update()
            print(f"[{self.name}] Turning light {verb}: {light.alias}")

    @staticmethod
    def _stamp():
        return datetime.datetime.now().strftime("%c")

    @staticmethod
    def _state(is_on):
        return "On" if is_on else "Off"


async def main():
    parser = argparse.ArgumentParser(
        description="Monitor Kasa switches and toggle their lights."
    )
    parser.add_argument(
        "-c",
        "--config",
        default=DEFAULT_CONFIG,
        type=Path,
        help=f"Path to the TOML config file (default: {DEFAULT_CONFIG})",
    )
    args = parser.parse_args()

    server_configs, poll_interval = load_config(args.config)
    servers = [
        DeviceServer(
            name=s.get("name", s["switch"]),
            switch_host=s["switch"],
            light_hosts=s.get("lights", []),
            poll_interval=s.get("poll_interval", poll_interval),
        )
        for s in server_configs
    ]

    print(BREAK)
    await asyncio.gather(*(server.setup() for server in servers))
    print(BREAK)
    await asyncio.gather(*(server.run() for server in servers))


def run_cli():
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nShutting down.")


if __name__ == "__main__":
    run_cli()
