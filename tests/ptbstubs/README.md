# Psychtoolbox stand-ins for tests

Minimal fakes of the Psychtoolbox functions the task helpers call, so their input
handling can be tested without a screen, mouse or keyboard. Only `TestEscape` adds
this folder to the path, for the duration of the test. Scripted input lives in the
global `PTBSTUB`: `buttons` (one mouse-button row per `GetMouse` call, the last row
repeats), `escAt` (`KbCheck` reports Esc from that call on; `Inf` never), and
counters `t` (fake clock, +10 ms per `GetSecs`), `nMouse`, `nKb`, `nFlip`.
