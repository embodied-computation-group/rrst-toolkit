# Contributing

This handbook lives in the `handbook/` folder of the
[rrst-toolkit repository](https://github.com/embodied-computation-group/rrst-toolkit) and is built with
[MkDocs Material](https://squidfunk.github.io/mkdocs-material/).

## Placeholders

Unfinished content is marked with greppable tags, so a person or a coding agent can
find every open item with `grep -rn "TODO(" handbook/`:

| Tag | Who resolves it |
|---|---|
| `TODO(Martin)` | The device engineer: hardware, firmware and build details |
| `TODO(parts)` | Anyone: availability checks and replacements (include the URL and date checked) |
| `TODO(photo)` | Whoever has the device: photos to take |
| `TODO(bench)` | Bench-testing procedures and tolerances |
| `TODO(toolkit)` | Task-software features not yet built |

Replace a placeholder with the real content in the same place, and remove the tag. If
something is unknown, keep the tag and say what's missing; don't fill it with a guess.

## Preview locally

```bash
python -m venv .venv-docs
.venv-docs/Scripts/pip install -r requirements-docs.txt   # Windows (on macOS/Linux: .venv-docs/bin/pip)
.venv-docs/Scripts/mkdocs serve                           # http://127.0.0.1:8000
```

`mkdocs build` runs in strict mode, so broken links and missing images fail the build.

## Photos

Put images in `handbook/assets/img/<section>/` with descriptive file names, resized to
at most 1600 px on the long edge. Reference them with relative links.
