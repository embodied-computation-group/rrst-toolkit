from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
FIXTURES = REPO / "tests" / "fixtures"
DEVICES = REPO / "devices"


def read_fixture(name):
    """Exact text of a firmware transcript in tests/fixtures (line endings kept)."""
    return (FIXTURES / name).read_bytes().decode("utf-8")


@pytest.fixture
def devices_dir():
    return DEVICES
