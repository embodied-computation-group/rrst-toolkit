"""Parses the device's 's' (status) command output into a dict."""


def parse_status_block(lines):
    """Parse status lines (between the --- SYSTEM STATUS --- and closing ---
    markers, exclusive of both marker lines) into a dict of label -> value.

    Each line is expected in "Label: Value" form. Label and value
    whitespace is stripped. Lines with no colon are ignored.
    """
    result = {}
    for line in lines:
        if ":" not in line:
            continue
        label, _, value = line.partition(":")
        result[label.strip()] = value.strip()
    return result
