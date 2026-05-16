# Python Script Tests

This directory contains plain Python unit tests for script logic that can run
outside Blender.

Current scope:
- `test_untoldexplorer.py`: coverage for Blender-free helpers in
  `scripts/untoldexplorer.py` — packing, binary serialization, record sizes,
  matrix math, AABB helpers, argument parsing, and `main()` input validation.
- `test_tilestreamingpartition.py`: coverage for Blender-free helpers in
  `scripts/tilestreamingpartition.py` — tile coordinate math, overlap queries,
  tile bounds, coordinate space conversion, mesh classification, output helpers,
  and argument parsing. `bpy`/`bmesh`/`mathutils` are stubbed with `MagicMock`
  so these tests run without Blender installed.

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
