import pytest

from TPlinkManager import DeviceServer

from conftest import FakeLight, FakeSwitch


def make_server(lights, poll_interval=0):
    server = DeviceServer("test", "192.168.0.1", [], poll_interval)
    server.lights = lights
    return server


async def test_toggle_turns_all_on_when_all_off():
    lights = [FakeLight("a", is_on=False), FakeLight("b", is_on=False)]
    server = make_server(lights)

    await server.toggle_lights()

    assert all(light.is_on for light in lights)
    assert all(light.turn_on_calls == 1 for light in lights)
    assert all(light.turn_off_calls == 0 for light in lights)


async def test_toggle_turns_all_off_when_all_on():
    lights = [FakeLight("a", is_on=True), FakeLight("b", is_on=True)]
    server = make_server(lights)

    await server.toggle_lights()

    assert not any(light.is_on for light in lights)
    assert all(light.turn_off_calls == 1 for light in lights)


async def test_toggle_turns_off_only_lit_when_mixed():
    on_light = FakeLight("on", is_on=True)
    off_light = FakeLight("off", is_on=False)
    server = make_server([on_light, off_light])

    await server.toggle_lights()

    assert not on_light.is_on
    assert on_light.turn_off_calls == 1
    # Already-off light is left untouched.
    assert off_light.turn_off_calls == 0
    assert off_light.turn_on_calls == 0


@pytest.mark.parametrize("is_on, expected", [(True, "On"), (False, "Off")])
def test_state_label(is_on, expected):
    assert DeviceServer._state(is_on) == expected


class BreakLoop(Exception):
    """Used to break out of the otherwise-infinite run loop in tests."""


async def test_run_toggles_lights_on_switch_change(monkeypatch):
    # Switch starts off, flips on at the first poll, then we break the loop.
    server = DeviceServer("test", "192.168.0.1", [], poll_interval=0)
    server.switch = FakeSwitch("sw", states=[False, True])
    lights = [FakeLight("a", is_on=False)]
    server.lights = lights

    sleeps = {"count": 0}

    async def fake_sleep(_):
        sleeps["count"] += 1
        if sleeps["count"] >= 2:
            raise BreakLoop

    monkeypatch.setattr("TPlinkManager.asyncio.sleep", fake_sleep)

    with pytest.raises(BreakLoop):
        await server.run()

    # The change was detected and the (off) light was switched on.
    assert lights[0].is_on
    assert lights[0].turn_on_calls == 1


async def test_run_ignores_update_failures(monkeypatch):
    server = DeviceServer("test", "192.168.0.1", [], poll_interval=0)

    class FlakySwitch:
        def __init__(self):
            self.is_on = False
            self.calls = 0

        async def update(self):
            self.calls += 1
            if self.calls == 2:  # second call is the in-loop poll
                raise OSError("network down")

    server.switch = FlakySwitch()
    server.lights = []

    sleeps = {"count": 0}

    async def fake_sleep(_):
        sleeps["count"] += 1
        # Let the first loop iteration run (where update raises), then break.
        if sleeps["count"] >= 2:
            raise BreakLoop

    monkeypatch.setattr("TPlinkManager.asyncio.sleep", fake_sleep)

    # An update failure is logged and skipped, not raised out of run().
    with pytest.raises(BreakLoop):
        await server.run()
