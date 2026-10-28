"""PsychoPy screens and masking sound for rrst.task.session. Port of the drawing in
main.m and the helpers getResponse.m, getConfidence.m, slideScale.m and
showExpandingRingGenerated.m.

Layout follows the MATLAB task: grey background (0.537), white Arial text (28 px, 45 px
on screens over 3000 px wide), a teal ring of radius 240 px, prompts at three quarters
of the screen height, the slider on 40-60 % of the screen width. Escape raises Aborted
from every screen. Mouse responses count only a press that starts after the button has
been released (as the fixed getResponse.m and slideScale.m).
"""
import math
import random

import numpy as np
from psychopy import core, event, sound, visual
from psychopy.hardware import keyboard

from ..noise import masking_noise
from .session import Aborted

# MATLAB colours (0-1) in PsychoPy's default rgb space (-1 to 1); rgb1 breaks visual.Line.
GREY = tuple(2 * c - 1 for c in (0.537, 0.537, 0.537))
TEAL = tuple(2 * c - 1 for c in (0.14, 0.82, 0.67))
RING_RADIUS = 240


class PsychoPyUI:
    def __init__(self, cfg):
        self.cfg = cfg
        t = cfg["timing"]
        self.fixed_timing = t["fixed_timing"]
        self.keyboard_input = cfg["input_device"] == "keyboard"
        if cfg["small_window"]:
            self.win = visual.Window(size=(1280, 720), fullscr=False, units="pix", color=GREY,
                                     allowGUI=True)
        else:
            self.win = visual.Window(fullscr=True, units="pix", color=GREY, allowGUI=False)
        self.w, self.h = self.win.size
        height = 45 if max(self.w, self.h) > 3000 else 28
        self.text = visual.TextStim(self.win, color="white", height=height, font="Arial",
                                    wrapWidth=0.9 * self.w, alignText="center")
        self.ring = visual.Circle(self.win, radius=RING_RADIUS, edges=180, lineColor=TEAL,
                                  fillColor=None, lineWidth=3)
        self.disc = visual.Circle(self.win, radius=1, edges=180, fillColor=TEAL, lineColor=None)
        self.mouse = event.Mouse(win=self.win, visible=False)
        self.kb = keyboard.Keyboard()
        self.kb.clearEvents()

    # --- basics -------------------------------------------------------------------------

    def clock(self):
        return core.getTime()

    def close(self):
        self.win.close()

    def _escape(self):
        if self.kb.getKeys(keyList=["escape"], waitRelease=False, clear=True):
            raise Aborted()

    def _draw_text(self, text, lower=False):
        self.text.text = text
        self.text.pos = (0, -self.h / 4) if lower else (0, 0)
        self.text.draw()

    def show(self, text, ring=False):
        if ring:
            self.ring.draw()
        if text:
            self._draw_text(text, lower=ring)
        self.win.flip()
        self._escape()

    def wait(self, seconds):
        self.wait_until(self.clock() + seconds)

    def wait_until(self, t):
        while self.clock() < t:
            self._escape()
            core.wait(0.002, hogCPUperiod=0)

    def wait_space(self):
        self.kb.clearEvents()
        while True:
            keys = self.kb.getKeys(keyList=["space", "escape"], waitRelease=False, clear=True)
            if any(k.name == "escape" for k in keys):
                raise Aborted()
            if keys:
                return
            core.wait(0.002, hogCPUperiod=0)

    def countdown(self, prefix, seconds, unit="sec."):
        """ISI ("sec.", ring, text low, rounded as main.m) or break ("min.", centred, ceil)."""
        t0 = self.clock()
        while (elapsed := self.clock() - t0) <= seconds:
            left = seconds - elapsed
            value = math.ceil(left / 60) if unit == "min." else round(left)
            if unit == "sec.":
                self.ring.draw()
            self._draw_text(f"{prefix}{value} {unit}", lower=(unit == "sec."))
            self.win.flip()
            self._escape()

    def breath(self, text, inhale, pause):
        """Ring outline for `pause` s, then the disc grows over `inhale` s and holds for `pause` s."""
        self.ring.draw()
        self.win.flip()
        self.wait(pause)
        t0 = self.clock()
        while (elapsed := self.clock() - t0) <= inhale + pause:
            self.disc.radius = max(1.0, RING_RADIUS * min(1.0, elapsed / inhale))
            self.disc.draw()
            self.ring.draw()
            self._draw_text(text, lower=True)
            self.win.flip()
            self._escape()

    # --- responses ----------------------------------------------------------------------

    def ask_breath(self, prompt, timeout):
        """First (0) or second (1) breath: left/right mouse button or arrow key."""
        self._draw_text(prompt, lower=True)
        self.win.flip()
        t0 = self.clock()
        self.kb.clearEvents()
        choice = None
        released = not any(self.mouse.getPressed())
        while self.clock() - t0 <= timeout:
            self._escape()
            if self.keyboard_input:
                keys = self.kb.getKeys(keyList=["left", "right"], waitRelease=False, clear=True)
                if keys:
                    choice = 0 if keys[0].name == "left" else 1
                    break
            else:
                left, middle, right = self.mouse.getPressed()
                if released and (left or middle or right):
                    choice = 0 if (left and not right and not middle) else \
                        1 if (right and not left and not middle) else None
                    break                                 # any press ends the window (getResponse.m)
                released = released or not (left or middle or right)
            core.wait(0.001, hogCPUperiod=0)
        rt = self.clock() - t0
        if choice is None:
            return None, float("nan")
        if self.fixed_timing:
            self.wait_until(t0 + timeout)
        else:
            self._draw_text(prompt, lower=True)
            self.win.flip()
            self.wait(0.3 + 0.2)
        return choice, rt

    def slider(self, question, anchors, timeout):
        """0-100 scale on 40-60 % of the screen width (slideScale.m, range 2). The marker
        starts at a random point and follows the mouse; a left press records it."""
        half = 0.1 * self.w
        y = -0.1 * self.h
        line = visual.Line(self.win, start=(-half, y), end=(half, y), lineColor="white", lineWidth=10)
        ticks = [visual.Line(self.win, start=(x, y - 20), end=(x, y + 20), lineColor="white",
                             lineWidth=10) for x in (-half, half)]
        marker = visual.Line(self.win, start=(0, y - 20), end=(0, y + 20), lineColor=TEAL, lineWidth=10)
        labels = [visual.TextStim(self.win, text=a, pos=(x, y - 80), color="white",
                                  height=self.text.height, font="Arial") for a, x in zip(anchors, (-half, half))]
        x = random.uniform(-half, half)
        self.mouse.setPos((x, y))
        released = not any(self.mouse.getPressed())
        t0 = self.clock()
        answered = False
        while self.clock() - t0 <= timeout:
            self._escape()
            x = float(np.clip(self.mouse.getPos()[0], -half, half))
            self.text.text, self.text.pos = question, (0, 0.06 * self.h)
            self.text.draw()
            for s in (line, *ticks, *labels):
                s.draw()
            marker.start, marker.end = (x, y - 20), (x, y + 20)
            marker.draw()
            self.win.flip()
            pressed = self.mouse.getPressed()[0]
            if pressed and released:
                answered = True
                break
            released = released or not any(self.mouse.getPressed())
        rt = self.clock() - t0
        while any(self.mouse.getPressed()):                    # KbReleaseWait(1)
            core.wait(0.002, hogCPUperiod=0)
        if not answered:
            return None, float("nan")
        return (x + half) / (2 * half) * 100, rt


class Noise:
    """Looped masking sound: the configured wav file, or generated noise."""

    def __init__(self, cfg):
        n = cfg["noise"]
        self.enabled = n["enabled"]
        self.snd = None
        if not self.enabled:
            return
        speaker = {"speaker": n["speaker"]} if n["speaker"] else {}
        if n["source"] == "file":
            # hamming=False: PsychoPy would otherwise fade each end, a dip at every loop
            self.snd = sound.Sound(value=str(n["file"]), loops=-1, volume=n["volume"], hamming=False,
                                   **speaker)
        else:
            x = masking_noise(n["fs"], n["dur_s"], n["colour"], seed=1)
            self.snd = sound.Sound(value=np.column_stack([x, x]), sampleRate=n["fs"], loops=-1,
                                   volume=n["volume"], hamming=False, stereo=True, **speaker)

    def start(self):
        if self.snd is not None:
            self.snd.play()

    def stop(self):
        if self.snd is not None:
            self.snd.stop()
