# Python Script Tests

This directory contains plain Python unit tests for script logic that can run
outside Blender.

Current scope:
- `test_untoldexplorer.py`: coverage for Blender-free helpers in
  `scripts/untoldexplorer.py`

Run locally from the repo root:

```sh
make testexporter
```

Direct `unittest` invocation:

```sh
python3 -m unittest discover -s scripts/tests -t . -v
```

Notes:
- These tests intentionally avoid Blender-only paths such as `bpy` scene import,
  mesh extraction, and USD export.
- If future tests need Blender, keep them separate from this suite so
  `make testexporter` stays fast and CI-friendly.
