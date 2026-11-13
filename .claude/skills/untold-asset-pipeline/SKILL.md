---
name: untold-asset-pipeline
description: Use when importing or converting 3D assets for Untold Engine — exporting a Blender/USD/USDZ model to the engine's .untold format, exporting animation clips, linking Gaussian-splat (.untoldgs) payloads to an entity, or exporting tiled/streamed scenes. Triggers on "export this model", "convert my Blender file", "load this asset in the engine", "attach a splat to this mesh". Not for runtime scene/entity editing (see untold-entity-scene) or project scaffolding (see untold-new-project).
version: 0.1.0
---

# Untold Engine Asset Pipeline

Source assets are authored in Blender (or any DCC that exports USD/USDZ) and converted to the engine's native binary formats — `.untold` (meshes/materials/scene data), `.untoldanim` (animation clips), `.untoldgs` (Gaussian splats) — via the `untoldengine` CLI, which runs Blender in background mode for you. **Never hand-author or hand-edit these binary files.**

## 1. Prerequisites

- The `untoldengine` CLI installed (`./scripts/install-untoldengine-create.sh` from the engine repo root). If it was recently edited, reinstall before trusting its behavior — it runs the last-installed build, not live source.
- Blender installed and discoverable, in this resolution order: `--blender /path/to/Blender`, `BLENDER_BIN` env var, `/Applications/Blender.app/Contents/MacOS/Blender`, or `blender` on `PATH`. If Blender can't be found the command prints an install message and exits — don't debug further than checking this.

## 2. Export a single asset

```bash
untoldengine export \
  --input GameData/Models/robot/robot.usdz \
  --output GameData/Models/robot/robot.untold \
  --convert-orientation
```

- `--input`: `.usd`/`.usda`/`.usdc`/`.usdz`/`.blend` source.
- `--output`: destination `.untold` (or `.untoldanim` with `--animation`); a multi-model scene writes a `.untoldpack`.
- `--convert-orientation`: convert Blender space into engine space — include this unless the source is already engine-oriented (`--source-orientation engine-oriented`).
- `--file-type {tile|lod|hlod|shared|animation}`: defaults to `tile`.
- `--compress-geometry` (needs `pip install lz4`) / `--optimize` (compress + texture bake/patch) for shipping builds.
- `--animation`: export clips only, no geometry — requires a `.untoldanim` output path.
- `--validate`: also writes a `<name>.validation.json` report.
- `--color-grade-lut <path.cube>`: stage an externally authored LUT as a post-tonemap grade.

Relative paths resolve from the working directory, so run this from inside the project with paths relative to `GameData/`. Textures land in a `Textures/` folder beside the output; an environment HDR (if the Blender scene has a World texture) lands in `HDR/` beside it too — but the engine only loads HDRs from the project's `GameData/HDR/`, so copy them there manually if needed.

Full flag reference and exactly what does/doesn't survive the Blender→engine conversion (materials, transparency, procedural-material baking, height/parallax textures): `docs/API/UsingTheExporter.md`. Don't guess at conversion fidelity — that doc (and the exporter's own `--validate` report) is the source of truth, not assumption.

## 3. Tiled / large streamed scenes

```bash
untoldengine export-tiles ...   # CLI tiled-scene export, output goes under GameData/StreamModels
```

An equivalent repository script (`export-untold-tiles`) exists for engine-internal development; game developers should use the `untoldengine export-tiles` CLI command. See `untoldengine export-tiles --help` and `docs/API/UsingTheExporter.md`.

## 4. Gaussian splats (`.untoldgs`)

Once a mesh asset exists as `.untold` and you have a cooked splat payload, attach them:

```bash
untoldengine gaussian-link --untold Chair/chair.untold --entity 0 \
  --payload Chair/chair.untoldgs --swap-distance 8 --occluder-shrink 0.02 --in-place
untoldengine gaussian-link --untold Chair/chair.untold --list      # inspect existing links
untoldengine gaussian-link --untold Chair/chair.untold --entity 0 --remove --output Chair/chair_plain.untold
```

The payload path is stored relative to whatever file is written (`--in-place` target, or `--output`) — keep the `.untoldgs` file in or beside that same directory. Linking to a mesh-less root entity (common on multi-node assets) warns and lists which entities actually carry a mesh.

## 5. Load the result at runtime

- `setEntityMesh(entityId:filename:withExtension:assetName:)` — sync, `.untold` only.
- `setEntityMeshAsync(entityId:filename:withExtension:assetName:completion:)` — async, broader format support.
- `setEntityAnimations(entityId:filename:withExtension:name:)` — `.untoldanim` clips.
- `setEntityGaussian`/`setEntityGaussianAsync` — `.untoldgs` payloads.
- `loadSceneAuthored(...)` — also pulls Blender-authored lights/cameras/color-management LUT baked into the `.untold`, not just geometry.

Point the loader at the right base folder first via `setEngine(.assetBasePath(url))` if it isn't already the project's `GameData`.

## 6. Common pitfalls to call out proactively

- Editing a custom Metal shader as part of this work (not asset content) still requires `./buildkernels.sh` — `swift build` does not recompile `.metal` files.
- A stale CLI install silently tests old exporter behavior — reinstall after any `Tools/UntoldEngineCLI` change.
- Don't try to "fix" a bad export by hand-patching the `.untold` binary — re-export from source instead.
