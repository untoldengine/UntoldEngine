# Using The Exporter

UntoldEngine ships global CLI commands for both individual-asset and tiled
scene exports, plus a repository script wrapper for tiled exports:

- `untoldengine export` — single asset
- `untoldengine export-tiles` — tiled scene (CLI equivalent of the script below)
- `export-untold-tiles` — repository script wrapper for tiled scene exports

All of these launch Blender in background mode and run the Python exporters
for you. Users do not need to invoke Blender or the Python scripts directly.
See [Using the UntoldEngine CLI](UsingUntoldEngineCLI.md) for the full CLI
subcommand reference, including `untoldengine export-tiles --help`.

## Install The Export Command

From the UntoldEngine repository root, install the CLI:

```bash
./scripts/install-untoldengine-create.sh
```

The installer places `untoldengine` on the system `PATH` and installs its
exporter support files. After installation, `untoldengine export` works from a
game project directory or any other directory; it does not depend on the
current working directory or require navigating back to the engine repository.

Confirm that the command is available:

```bash
untoldengine export --help
```

## Prerequisites

Blender must be installed.

The wrappers resolve Blender in this order:

1. `--blender /path/to/Blender`
2. `BLENDER_BIN=/path/to/Blender`
3. `/Applications/Blender.app/Contents/MacOS/Blender`
4. `blender` on `PATH`

If Blender cannot be found, the wrapper prints an install message and exits.

## Export A Single Asset

Use `untoldengine export` from any directory to convert one USD/USDZ or
`.blend` asset into one `.untold` runtime file.

Basic usage:

```bash
untoldengine export \
  --input /path/model.usdz \
  --output /path/model.untold
```

Absolute paths work as shown above. Relative paths are resolved from the
directory in which the command is run, which is convenient when working from a
generated game project:

```bash
cd /path/to/MyGame

untoldengine export \
  --input Sources/MyGame/GameData/Models/robot/robot.usdz \
  --output Sources/MyGame/GameData/Models/robot/robot.untold \
  --convert-orientation
```

Common options:

- `--input <path>`: required source `.usd`, `.usda`, `.usdc`, `.usdz`, or `.blend`
- `--output <path>`: required destination `.untold`
- `--file-type <tile|lod|hlod|shared|animation>`: optional, defaults to `tile`
- `--mesh-name <name>`: optional, export only one mesh from a multi-mesh asset
- `--convert-orientation`: optional, convert the export into engine space
- `--source-orientation <blender-native|engine-oriented>`: optional, defaults to `blender-native`
- `--validate`: optional, also writes `<name>.validation.json`
- `--compress-geometry`: optional, LZ4-compress vertex and index chunks (requires `pip install lz4`)
- `--optimize`: optional, compress geometry and bake/patch textures after export (implies `--compress-geometry`)
- `--bake-materials`: optional, bake node-graph materials the engine cannot evaluate (Mix, Math, procedural textures, ...) into flat textures so the export matches Blender. See [Using Bake Materials](UsingBakeMaterials.md)
- `--bake-resolution <pixels>`: optional, fallback square resolution for baked material textures, defaults to `1024`. Each material's actual bake resolution is normally auto-detected from the largest source texture feeding it (rounded up to a power of two, never below this fallback) — this flag only matters when a material has no source texture to detect from (e.g. a procedural/solid-color material). Override a specific material explicitly via a `material["untold_bake_resolution"]` custom property
- `--no-bake-cache`: optional, disable the persistent bake cache and force every divergent material to be re-baked
- `--bake-color-management`: optional, bake the scene's active View Transform/Look/Exposure/Gamma (e.g. Blender's AgX) into an `NxNxN` color-grading LUT so the engine can reproduce Blender's display transform instead of its default ACES Filmic tonemap. The LUT is scene-wide, not per-material — see [Using Color Management](UsingColorManagement.md) for how to actually apply it at runtime; it is not loaded by a normal mesh import
- `--color-lut-size <N>`: optional, grid size for the `NxNxN` color-grading LUT, defaults to `32`
- `--animation`: optional, export animation clips only — no mesh geometry is written
- `--blender <path>`: optional Blender executable override

Example using absolute paths and geometry compression:

```bash
untoldengine export \
  --input /Users/haroldserrano/Downloads/FloorPlanA/floorplanA.usdz \
  --output /Users/haroldserrano/Downloads/FloorPlanA/floorplanA.untold \
  --convert-orientation \
  --compress-geometry
```

Expected output:

- `floorplanA.untold`
- `Textures/...` beside the `.untold` file if the asset uses textures
- `floorplanA.validation.json` only when `--validate` is passed

The older `./scripts/export-untold` repository wrapper remains available for
engine development and compatibility. Game developers should prefer
`untoldengine export` because it can be called directly from their project.

## Bake Textures To `.utex`

The CLI also exposes the ASTC texture baker, so it can be used without locating
`scripts/texbake.py` in the engine repository.

Bake every supported image in a texture directory:

```bash
untoldengine texbake --dir GameData/Models/robot/Textures
```

Bake one texture with an explicit material slot:

```bash
untoldengine texbake \
  --input GameData/Models/robot/Textures/surface_data.png \
  --slot roughness
```

Patch an exported asset to reference the generated `.utex` files:

```bash
untoldengine texbake --patch-refs GameData/Models/robot/robot.untold
```

Texture baking requires Python 3 with Pillow and the `astcenc` executable.
Download the appropriate macOS release from the
[`astc-encoder` releases page](https://github.com/ARM-software/astc-encoder/releases),
extract it, and make sure the encoder binary is executable:

```bash
chmod +x /full/path/to/astcenc
```

Set `ASTCENC_BIN` to the absolute path of that executable before running the
texture baker:

```bash
export ASTCENC_BIN="/full/path/to/astcenc"
untoldengine texbake --dir /path/to/Textures
```

For example, an encoder stored in UntoldEngineStudio's shared `Tools` directory
can be used with:

```bash
ASTCENC_BIN="/path/to/UntoldEngineStudio/Tools/astcenc/astcenc" \
  untoldengine texbake --dir /path/to/Textures
```

Add the `export ASTCENC_BIN=...` line to `~/.zshrc` when that custom location
should be used for every terminal session. Alternatively, place a binary named
`astcenc`, `astcenc-native`, `astcenc-avx2`, or `astcenc-sse4.2` on `PATH`. The
CLI uses `python3` from `PATH`; set `PYTHON3_BIN` only when a different Python
installation is required.

Available options:

- `--input <path>`: bake one PNG, JPEG, TGA, or BMP image
- `--output <path>`: destination `.utex` path for a single image
- `--slot <slot>`: override automatic texture-slot detection
- `--dir <path>`: bake all supported images in a directory
- `--quality <level>`: `fastest`, `fast`, `medium`, `thorough`, or `exhaustive`
- `--keep-temp`: retain intermediate mip and ASTC files
- `--patch-refs <path>`: patch one `.untold` file or every `.untold` file in a directory

## Export A Scene Into Tiles

Use `export-untold-tiles` (found in `scripts/`), or the equivalent `untoldengine export-tiles` CLI command, to partition a USD/USDZ or `.blend` scene into tile payloads and generate a manifest JSON file.

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

- `--input <path>`: required source `.usd`, `.usda`, `.usdc`, `.usdz`, or `.blend`
- `--output-dir <path>`: required destination directory for tile payloads
- `--tile-size-x <number>`: optional tile width in world units (ignored in `--quadtree`/`--kdtree` mode)
- `--tile-size-y <number>`: optional tile height in world units, defaults to `10000`
- `--tile-size-z <number>`: optional tile depth in world units (ignored in `--quadtree`/`--kdtree` mode)
- `--auto-tile-size`: optional automatic tile sizing
- `--generate-hlod`: optional HLOD generation
- `--generate-lod`: optional per-tile LOD generation
- `--lod-level <distance:ratio>`: optional override for a per-tile LOD level. May be repeated.
- `--hlod-level <suffix:distance:ratio>`: optional override for an HLOD level. May be repeated.
- `--dry-run`: optional planning pass without writing payload files
- `--write-manifest-in-dry-run`: optional manifest write during dry run
- `--visible-only`: optional export only visible meshes
- `--all-meshes`: optional include hidden meshes
- `--debug-aabb-only`: optional emit debug AABB payloads instead of geometry
- `--quadtree`: optional partition tiles using a quadtree instead of a uniform grid
- `--kdtree`: optional partition tiles using a KD-tree instead of a quadtree (inline annotation only). Splits each floor's XY plane on the longer axis at the median object center, producing better-balanced tiles in scenes where geometry is unevenly distributed. Produces `partitioning_mode: "kdtree_floor"` in the manifest. Ignored if the input is pre-annotated (quadtree metadata takes precedence)
- `--scene-profile <auto|indoor|outdoor>`: optional streaming radius profile, defaults to `auto`. Radii are always proportional to scene size — no fixed distances to hand-tune. Use `outdoor` for cities, terrain, and large exterior scenes if auto-detection misses.
- `--tier-radius <Tier=stream,unload[,priority]>`: optional quadtree semantic-tier radius override in world units. May be repeated.
- `--min-objects-per-tile-tier <count>`: optional, collapse underfilled tile-tiers upward until reaching this many objects, defaults to `4`
- `--untagged-semantic-tier <Auto|ExteriorShell|StructuralInterior|RoomContents|FineProps>`: optional semantic tier for meshes without an explicit override, defaults to `Auto`
- `--floor-count <number>`: optional number of vertical floors to split each tile into (for quadtree/KD-tree mode)
- `--floor-band-height <number>`: optional per-floor height in world units (overrides auto-detection from scene Z extent)
- `--sample`: optional, export only a small tile patch near the world origin for fast iteration
- `--sample-fraction <fraction>`: optional fraction of total tiles to keep in sample mode, defaults to `0.10`
- `--perimeter`: optional, export only the outer shell of tiles, skipping interior tiles
- `--perimeter-depth <count>`: optional number of tiles inward from the boundary to keep, defaults to `1`
- `--parallel-workers <number>`: optional number of parallel Blender worker processes (`0` = auto-detect CPU count, `1` = sequential)
- `--compress-geometry`: optional LZ4-compress vertex and index chunks in every exported tile payload (requires `pip install lz4`)
- `--optimize`: optional, compress geometry and bake/patch textures after export (implies `--compress-geometry`)
- `--bake-materials`: optional, bake node-graph materials the engine cannot evaluate into flat textures. See [Using Bake Materials](UsingBakeMaterials.md)
- `--bake-resolution <pixels>`: optional, fallback square resolution for baked material textures, defaults to `1024`. Each material's actual bake resolution is normally auto-detected from the largest source texture feeding it (rounded up to a power of two, never below this fallback) — this flag only matters when a material has no source texture to detect from (e.g. a procedural/solid-color material). Override a specific material explicitly via a `material["untold_bake_resolution"]` custom property
- `--no-bake-cache`: optional, disable the persistent bake cache and force every divergent material to be re-baked
- `--bake-color-management`: optional, bake the scene's active View Transform/Look/Exposure/Gamma into a scene-wide color-grading LUT, referenced from the manifest's `colorLUT` key. See [Using Color Management](UsingColorManagement.md) — it is only applied via an explicit `loadSceneAuthored(url:)` call, not by normal tile loading
- `--color-lut-size <N>`: optional, grid size for the `NxNxN` color-grading LUT, defaults to `32`
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

### Quadtree Tier Radius Overrides

Quadtree exports assign each tile group to a semantic tier:

- `ExteriorShell`
- `StructuralInterior`
- `RoomContents`
- `FineProps`

`--scene-profile` chooses default stream/unload bands for these tiers. Use
`--tier-radius` when a scene needs tighter or wider bands than the selected
profile.

Syntax:

```bash
--tier-radius TierName=streaming_radius,unload_radius[,priority]
```

Example:

```bash
./scripts/export-untold-tiles \
  --input GameData/Models/building/building.usdz \
  --output-dir GameData/Models/building/tile_exports \
  --quadtree \
  --scene-profile indoor \
  --tier-radius ExteriorShell=55,80,15 \
  --tier-radius StructuralInterior=10,18,12 \
  --tier-radius RoomContents=4,7,8 \
  --tier-radius FineProps=1.5,3,5
```

`ExteriorShell=55,80,15` means:

- `55`: `streaming_radius` in world units. The tile becomes eligible to load
  when the camera enters this distance band.
- `80`: `unload_radius` in world units. Once loaded, the tile stays resident
  until the camera moves beyond this distance.
- `15`: optional load priority. Higher values are considered more important
  when multiple tile candidates compete for load slots.

`unload_radius` must be greater than `streaming_radius`. The gap is the
hysteresis band that prevents rapid load/unload oscillation near the boundary.

Expected output layout:

- `dungeon.json` beside the tile payload directory
- `tile_exports/tile_*.untold`
- optional HLOD and LOD `.untold` files in `tile_exports/`
- `tile_exports/Textures/...` for staged textures

The manifest stores relative runtime paths so it remains portable across machines, repos, and app bundles.

### KD-tree Partitioning

Use `--kdtree` instead of `--quadtree` when geometry is unevenly distributed across the scene floor — for example, when most objects cluster in corridors or specific rooms while other areas are sparse. The KD-tree splits each floor on the longer axis at the median object center, producing tiles that reflect actual geometry density rather than equal-area subdivisions.

```bash
./scripts/export-untold-tiles \
  --input GameData/Models/building/building.usdz \
  --output-dir GameData/Models/building/tile_exports \
  --kdtree \
  --scene-profile indoor \
  --floor-count 10
```

The `--tier-radius` and `--scene-profile` flags work identically for `--kdtree` and `--quadtree`. The manifest will contain `"partitioning_mode": "kdtree_floor"` and tile node IDs use the `F{nn}_K_...` naming convention (e.g. `"F02_K_0_1_0"`).

**When to choose KD-tree vs. quadtree:**

| | Quadtree | KD-tree |
|---|---|---|
| Geometry distribution | Uniform across floor | Clustered in sub-regions |
| Tile balance | Equal-area (can produce empty tiles) | Object-count balanced |
| Hierarchy culling | Yes | Yes |
| Pre-annotated input (phase12) | Yes | No (inline annotation only) |

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

At runtime, `NM_` objects default to `.selectableGeometry` and `.preserveIdentity` scene channels. Regular render/streaming geometry defaults to `.contextGeometry`. This lets an app hide context geometry with `setSceneChannel(.contextGeometry, .renderMode(.hidden))` while keeping `NM_` objects visible and selectable. See [Scene Channels](UsingSceneChannels.md).

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
