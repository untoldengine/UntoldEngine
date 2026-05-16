# Using The Exporter

UntoldEngine ships two user-facing exporter commands in the `scripts/` folder at the repo root:

- `export-untold`
- `export-untold-tiles`

These wrappers launch Blender in background mode and run the Python exporters for you. Users should run the shell wrappers, not the raw Blender commands.

## Prerequisites

Blender must be installed.

The wrappers resolve Blender in this order:

1. `--blender /path/to/Blender`
2. `BLENDER_BIN=/path/to/Blender`
3. `/Applications/Blender.app/Contents/MacOS/Blender`
4. `blender` on `PATH`

If Blender cannot be found, the wrapper prints an install message and exits.

## Export A Single Asset

Use `export-untold` (found in `scripts/`) to convert one USD or USDZ asset into one `.untold` runtime file.

Basic usage:

```bash
./scripts/export-untold \
  --input /path/model.usdz \
  --output /path/model.untold
```

Common options:

- `--input <path>`: required source `.usd`, `.usda`, `.usdc`, or `.usdz`
- `--output <path>`: required destination `.untold`
- `--file-type <tile|lod|hlod|shared|animation>`: optional, defaults to `tile`
- `--mesh-name <name>`: optional, export only one mesh from a multi-mesh asset
- `--ConvertOrientation`: optional, convert the export into engine space
- `--source-orientation <blender-native|engine-oriented>`: optional, defaults to `blender-native`
- `--validate`: optional, also writes `<name>.validation.json`
- `--compress-geometry`: optional, LZ4-compress vertex and index chunks (requires `pip install lz4`)
- `--animation`: optional, export animation clips only — no mesh geometry is written
- `--blender <path>`: optional wrapper-level Blender override

Example:

```bash
./scripts/export-untold \
  --input GameData/Models/robot/robot.usdz \
  --output GameData/Models/robot/robot.untold \
  --ConvertOrientation \
  --source-orientation blender-native \
  --validate
```

Expected output:

- `robot.untold`
- `Textures/...` beside the `.untold` file if the asset uses textures
- `robot.validation.json` only when `--validate` is passed

## Export A Scene Into Tiles

Use `export-untold-tiles` (found in `scripts/`) to partition a USD or USDZ scene into tile payloads and generate a manifest JSON file.

Basic usage:

```bash
./scripts/export-untold-tiles \
  --input /path/scene.usdz \
  --output-dir /path/tile_exports \
  --tile-size-x 25 \
  --tile-size-y 10000 \
  --tile-size-z 25
```

Common options:

- `--input <path>`: required source `.usd`, `.usda`, `.usdc`, or `.usdz`
- `--output-dir <path>`: required destination directory for tile payloads
- `--tile-size-x <number>`: optional tile width in world units
- `--tile-size-y <number>`: optional tile height in world units, defaults to `10000`
- `--tile-size-z <number>`: optional tile depth in world units
- `--auto-tile-size`: optional automatic tile sizing
- `--generate-hlod`: optional HLOD generation
- `--generate-lod`: optional per-tile LOD generation
- `--dry-run`: optional planning pass without writing payload files
- `--write-manifest-in-dry-run`: optional manifest write during dry run
- `--visible-only`: optional export only visible meshes
- `--all-meshes`: optional include hidden meshes
- `--debug-aabb-only`: optional emit debug AABB payloads instead of geometry
- `--quadtree`: optional partition tiles using a quad-tree instead of a uniform grid
- `--scene-profile <auto|indoor|outdoor>`: optional streaming radius profile, defaults to `auto`. Radii are always proportional to scene size — no fixed distances to hand-tune. Use `outdoor` for cities, terrain, and large exterior scenes if auto-detection misses.
- `--floor-count <number>`: optional number of vertical floors to split each tile into (for quadtree mode)
- `--floor-band-height <number>`: optional per-floor height in world units (overrides auto-detection from scene Z extent)
- `--parallel-workers <number>`: optional number of parallel Blender worker processes (`0` = auto-detect CPU count, `1` = sequential)
- `--compress-geometry`: optional LZ4-compress vertex and index chunks in every exported tile payload (requires `pip install lz4`)
- `--blender <path>`: optional wrapper-level Blender override

Example:

```bash
./scripts/export-untold-tiles \
  --input GameData/Models/dungeon/dungeon.usdz \
  --output-dir GameData/Models/dungeon/tile_exports \
  --tile-size-x 25 \
  --tile-size-y 10000 \
  --tile-size-z 25 \
  --generate-hlod \
  --generate-lod
```

Dry-run example:

```bash
./scripts/export-untold-tiles \
  --input GameData/Models/dungeon/dungeon.usdz \
  --output-dir GameData/Models/dungeon/tile_exports \
  --tile-size-x 25 \
  --tile-size-y 10000 \
  --tile-size-z 25 \
  --dry-run \
  --write-manifest-in-dry-run
```

Expected output layout:

- `dungeon.json` beside the tile payload directory
- `tile_exports/tile_*.untold`
- optional HLOD and LOD `.untold` files in `tile_exports/`
- `tile_exports/Textures/...` for staged textures

The manifest stores relative runtime paths so it remains portable across machines, repos, and app bundles.

## Selective Merging With The NM_ Prefix

When `MERGE_BY_MATERIAL` is enabled (the default), objects that share the same material within a tile are joined into a single mesh entity before export. This reduces draw calls significantly, but means multiple original objects collapse into one exported entity — losing their individual names.

If you need certain objects to remain as separate identifiable entities (for example, to support tap-to-select workflows or per-object JSON lookups at runtime), prefix their name in Blender with `NM_`.

Objects whose name starts with `NM_` are excluded from the merge step and exported individually, preserving their original name in the `.untold` file. All other objects are still merged normally.

Example naming in Blender:

- `NM_Pipe_001` — exported as its own entity, name survives into `.untold`
- `NM_LightFixture_A` — exported as its own entity
- `Wall_North` — merged with other same-material walls, one entity for the group
- `Door_Main` — merged with same-material doors

This lets you keep background geometry (walls, floors, ceilings) optimized while still being able to identify and interact with specific objects at runtime:

To change the prefix or disable selective merging, edit `NO_MERGE_PREFIX` at the top of `scripts/tilestreamingpartition.py`. Set it to `""` to merge all objects regardless of name.

## Optimization Workflows

After exporting assets, use [Optimizations](Optimizations.md) for optional
workflows such as ASTC texture compression and LZ4 geometry compression.

## Loading The Result In The Engine

Single asset:

```swift
setEntityMeshAsync(
    entityId: entityId,
    filename: "robot",
    withExtension: "untold"
)
```

Tiled scene:

```swift
let sceneRoot = createEntity()
setEntityName(entityId: sceneRoot, name: "dungeon")
setEntityStreamScene(entityId: sceneRoot, manifest: "dungeon", withExtension: "json")
```

The manifest should live next to the tile payload directory. Tile, HLOD, LOD, and shared-bucket payloads are resolved relative to the manifest file.

## Notes

- `.untold` tile payloads participate in the current tiled streaming architecture, including tile-level load/unload, remote download + cache, per-tile LOD/HLOD, and large-tile OCC sub-mesh streaming when the runtime classifies a tile into the OOC path.
- The Python files in `scripts/` are implementation details. The recommended user entry points are the shell wrappers in the same folder.
