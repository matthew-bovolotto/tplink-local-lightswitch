"""Shared test fakes for the Kasa device interface used by DeviceServer."""


class FakeLight:
    """Minimal stand-in for a kasa light, tracking toggle calls."""

    def __init__(self, alias, is_on=False):
        self.alias = alias
        self.is_on = is_on
        self.turn_on_calls = 0
        self.turn_off_calls = 0

    async def update(self):
        pass

    async def turn_on(self):
        self.turn_on_calls += 1
        self.is_on = True

    async def turn_off(self):
        self.turn_off_calls += 1
        self.is_on = False


class FakeSwitch:
    """A switch whose is_on follows a predefined sequence of update() calls."""

    def __init__(self, alias, states):
        self.alias = alias
        self._states = list(states)
        self._index = -1
        self.is_on = self._states[0] if self._states else False

    async def update(self):
        self._index += 1
        if self._index < len(self._states):
            self.is_on = self._states[self._index]
