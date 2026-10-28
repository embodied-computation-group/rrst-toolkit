"""A small hover tooltip for any Tkinter widget - no built-in
equivalent exists in tkinter/ttk."""

import tkinter as tk

DELAY_MS = 500
WRAP_LENGTH = 320


class Tooltip:
    """Shows `text` in a small popup near `widget` after DELAY_MS of
    hovering, hides on leave or click. Standard Toplevel + overrideredirect
    idiom - the delay avoids flicker on quick mouse-overs while scanning
    the UI, and the scheduled-show timer is always cancelled on leave so
    rapid enter/leave never leaks a pending popup."""

    def __init__(self, widget, text):
        self.widget = widget
        self.text = text
        self._after_id = None
        self._tip_window = None
        widget.bind("<Enter>", self._schedule, add="+")
        widget.bind("<Leave>", self._hide, add="+")
        widget.bind("<ButtonPress>", self._hide, add="+")

    def _schedule(self, _event=None):
        self._cancel_scheduled()
        self._after_id = self.widget.after(DELAY_MS, self._show)

    def _cancel_scheduled(self):
        if self._after_id is not None:
            self.widget.after_cancel(self._after_id)
            self._after_id = None

    def _show(self):
        self._after_id = None
        if self._tip_window is not None:
            return
        x = self.widget.winfo_rootx() + 12
        y = self.widget.winfo_rooty() + self.widget.winfo_height() + 6
        self._tip_window = tw = tk.Toplevel(self.widget)
        tw.wm_overrideredirect(True)
        tw.wm_geometry(f"+{x}+{y}")
        # foreground is pinned explicitly, not left to the system default -
        # ttk's default Label text color follows the OS appearance (light
        # text in dark mode), which is nearly invisible against this
        # fixed pale-yellow background. Both colors are hardcoded together
        # so contrast holds regardless of the system theme.
        tk.Label(
            tw, text=self.text, justify="left", background="#ffffe0",
            foreground="#1a1a1a", relief="solid", borderwidth=1,
            wraplength=WRAP_LENGTH, font=("TkDefaultFont", 10), padx=6, pady=4,
        ).pack()

    def _hide(self, _event=None):
        self._cancel_scheduled()
        if self._tip_window is not None:
            self._tip_window.destroy()
            self._tip_window = None
