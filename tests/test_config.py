import pytest

from TPlinkManager import DEFAULT_POLL_INTERVAL, load_config


def write_config(tmp_path, text):
    path = tmp_path / "config.toml"
    path.write_text(text)
    return path


def test_load_config_parses_servers_and_interval(tmp_path):
    path = write_config(
        tmp_path,
        """
        poll_interval = 5.0

        [[server]]
        name = "bedroom"
        switch = "192.168.0.10"
        lights = ["192.168.0.11", "192.168.0.12"]
        """,
    )

    servers, poll_interval = load_config(path)

    assert poll_interval == 5.0
    assert len(servers) == 1
    assert servers[0]["name"] == "bedroom"
    assert servers[0]["switch"] == "192.168.0.10"
    assert servers[0]["lights"] == ["192.168.0.11", "192.168.0.12"]


def test_load_config_defaults_poll_interval(tmp_path):
    path = write_config(
        tmp_path,
        """
        [[server]]
        switch = "192.168.0.10"
        """,
    )

    _, poll_interval = load_config(path)

    assert poll_interval == DEFAULT_POLL_INTERVAL


def test_load_config_supports_multiple_servers(tmp_path):
    path = write_config(
        tmp_path,
        """
        [[server]]
        name = "bedroom"
        switch = "192.168.0.10"

        [[server]]
        name = "living-room"
        switch = "192.168.0.20"
        """,
    )

    servers, _ = load_config(path)

    assert [s["name"] for s in servers] == ["bedroom", "living-room"]


def test_load_config_raises_without_servers(tmp_path):
    path = write_config(tmp_path, "poll_interval = 2.0\n")

    with pytest.raises(ValueError):
        load_config(path)
