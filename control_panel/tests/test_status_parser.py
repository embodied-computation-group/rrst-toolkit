import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from status_parser import parse_status_block


def test_parses_simple_block():
    lines = [
        "Software Version: Quiet-Valve (Sep 23 2026 13:10:48)",
        "Current Position: 0 steps",
        "Max Range Limit:  45000 steps",
        "Calibrated:       NO",
    ]
    result = parse_status_block(lines)
    assert result["Software Version"] == "Quiet-Valve (Sep 23 2026 13:10:48)"
    assert result["Current Position"] == "0 steps"
    assert result["Max Range Limit"] == "45000 steps"
    assert result["Calibrated"] == "NO"


def test_ignores_lines_without_colon():
    lines = ["--- SYSTEM STATUS ---", "Calibrated:       NO", "---"]
    result = parse_status_block(lines)
    assert "Calibrated" in result
    assert len(result) == 1


def test_handles_value_containing_colon():
    lines = ["Software Version: Quiet-Valve (13:10:48)"]
    result = parse_status_block(lines)
    assert result["Software Version"] == "Quiet-Valve (13:10:48)"


def test_empty_input():
    assert parse_status_block([]) == {}
