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
- `test_addon_bridge.py`: what the Blender add-on does with the result of an
  export (`untold-blender-addon/untold_exporter/bridge.py`): which files its
  texture bake bakes and patches. `bpy` is stubbed while the bridge loads, and
  the files are written by the exporter's own writers.

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

## Checks that need Blender

`blender/` holds checks that only a real Blender can run. They are not part of
`make testexporter` and do not run in CI. Each one makes its own images in a
temporary folder.

- `blender/texture_write_checks.py`: writing textures through
  `write_blender_image_to_path`, including a JPEG whose metadata makes
  Blender's PNG writer fail.
- `blender/material_bake_checks.py`: the procedural material bake. Tiles cut
  at whole bricks, noise that repeats without a seam, and the projected UVs:
  what Blender shows on a mesh through them is what the baked texture holds.
- `blender/material_slot_checks.py`: a multi-material object split for export
  keeps the material each slot shows, including a slot linked to the object over
  a shared mesh, for linked duplicates and for a rigged object.

Run from the repo root:

```sh
blender --background --factory-startup --python-exit-code 1 --python scripts/tests/blender/texture_write_checks.py
blender --background --factory-startup --python-exit-code 1 --python scripts/tests/blender/material_bake_checks.py
blender --background --factory-startup --python-exit-code 1 --python scripts/tests/blender/material_slot_checks.py
```
