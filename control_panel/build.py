"""Builds a standalone executable for the current OS via PyInstaller.

Run this on each target OS separately - PyInstaller does not
cross-compile. Produces the app under dist/.

Uses --onedir, not --onefile: on macOS, --onefile + --windowed bundles
the whole app as one large, unsigned, self-extracting blob inside the
.app - Gatekeeper scanning that on launch is a well-known cause of the
app appearing to hang (sometimes for a long time) on first run.
--onedir avoids this, and it's also required going forward regardless -
PyInstaller deprecated --onefile + --windowed on macOS specifically
because it "clashes with macOS's security," and turns it into a hard
error starting in PyInstaller v7.0.
"""

import subprocess
import sys


def main():
    # PyInstaller's --add-data separator is OS-specific: ':' on
    # macOS/Linux, ';' on Windows (os.pathsep covers both correctly).
    add_data_sep = ";" if sys.platform.startswith("win") else ":"
    subprocess.check_call([
        sys.executable, "-m", "PyInstaller",
        "--onedir",
        "--windowed",
        "--name", "RRST_Control_Panel",
        "--add-data", f"firmware{add_data_sep}firmware",
        "app.py",
    ])


if __name__ == "__main__":
    main()
