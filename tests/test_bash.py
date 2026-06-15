"""Collect the bash_unit suites as individual pytest cases.

Each ``test_*`` function in ``tests/bash/test_*.sh`` is discovered and run via
bash_unit, so the whole project's tests report through a single ``pytest`` run.
"""

import re
import subprocess
from pathlib import Path

import pytest

BASH_DIR = Path(__file__).parent / "bash"
BASH_UNIT = BASH_DIR / "bash_unit"

# Matches a bash test function definition, e.g. "test_install_succeeds() {".
_TEST_DEF = re.compile(r"^\s*(test_[A-Za-z0-9_]+)\s*\(\)", re.MULTILINE)


def _discover_cases():
    cases = []
    for test_file in sorted(BASH_DIR.glob("test_*.sh")):
        for name in _TEST_DEF.findall(test_file.read_text()):
            cases.append((test_file, name))
    return cases


_CASES = _discover_cases()


@pytest.mark.skipif(not BASH_UNIT.exists(), reason="bash_unit is not vendored")
@pytest.mark.parametrize(
    "test_file, test_name",
    _CASES,
    ids=[f"{f.name}::{name}" for f, name in _CASES],
)
def test_bash_unit(test_file, test_name):
    # Anchor on the function-definition line ("name ()") so the pattern selects
    # exactly this test and not others that share its prefix.
    pattern = rf"^{re.escape(test_name)} \(\)"
    result = subprocess.run(
        [str(BASH_UNIT), "-p", pattern, str(test_file)],
        capture_output=True,
        text=True,
    )

    # bash_unit exits 0 when a pattern matches nothing, so confirm it actually ran.
    ran = f"Running {test_name} " in result.stdout
    if result.returncode != 0 or not ran:
        detail = "did not run (pattern matched nothing)" if not ran else "failed"
        pytest.fail(
            f"{test_file.name}::{test_name} {detail}\n"
            f"--- stdout ---\n{result.stdout}"
            f"--- stderr ---\n{result.stderr}",
            pytrace=False,
        )
