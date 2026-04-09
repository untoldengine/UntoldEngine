# Using The Exporter

UntoldEngine ships two user-facing exporter commands in [`scripts`](/Users/haroldserrano/Desktop/UntoldEngineStudio/UntoldEngine/scripts):

- [`export-untold`](/Users/haroldserrano/Desktop/UntoldEngineStudio/UntoldEngine/scripts/export-untold)
- [`export-untold-tiles`](/Users/haroldserrano/Desktop/UntoldEngineStudio/UntoldEngine/scripts/export-untold-tiles)

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

Use [`export-untold`](/Users/haroldserrano/Desktop/UntoldEngineStudio/UntoldEngine/scripts/export-untold) to convert one USD or USDZ asset into one `.untold` runtime file.

Basic usage:

```bash
./scripts/export-untold \
  --input /path/model.usdz \
  --output /path/model.untold
```

Common options:

- `--input <path>`: required source `.usd`, `.usda`, `.usdc`, or `.usdz`
- `--output <path>`: required destination `.untold`
- `--file-type <tile|lod|hlod|shared>`: optional, defaults to `tile`
- `--mesh-name <name>`: optional, export only one mesh from a multi-mesh asset
- `--ConvertOrientation`: optional, convert the export into engine space
- `--source-orientation <blender-native|engine-oriented>`: optional, defaults to `blender-native`
- `--validate`: optional, also writes `<name>.validation.json`
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

Use [`export-untold-tiles`](/Users/haroldserrano/Desktop/UntoldEngineStudio/UntoldEngine/scripts/export-untold-tiles) to partition a USD or USDZ scene into tile payloads and generate a manifest JSON file.

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

## Using ASTC Texture Compression

ASTC is a GPU-native block-compression format supported on all Apple Silicon and A-series devices. Converting textures to ASTC reduces texture memory by 4–8× compared to uncompressed RGBA8 and eliminates CPU-side decode — the GPU receives the compressed blocks directly.

ASTC compression is a post-export step run with `texbake.py`, separate from the exporters. This keeps the exporter's Blender Python environment free of extra dependencies.

### Prerequisites

Install [`astcenc`](https://github.com/ARM-software/astc-encoder/releases). The tool is resolved in this order:

1. `ASTCENC_BIN=/path/to/astcenc`
2. `Tools/astcenc/astcenc` beside the repo root
3. `astcenc` on `PATH`

### Single asset workflow

```bash
# 1. Export the asset
./scripts/export-untold \
  --input GameData/Models/robot/robot.usdz \
  --output GameData/Models/robot/robot.untold

# 2. Bake all textures in the Textures/ directory to .utex
python3 scripts/texbake.py --dir GameData/Models/robot/Textures/

# 3. Patch the .untold file to reference the .utex files
python3 scripts/texbake.py --patch-refs GameData/Models/robot/robot.untold
```

### Tile export workflow

Tile exports produce many `.untold` files. Pass the tile output directory to `--patch-refs` and all `.untold` files inside are patched in one go:

```bash
# 1. Export tiles
./scripts/export-untold-tiles \
  --input GameData/Models/dungeon/dungeon.usdz \
  --output-dir GameData/Models/dungeon/tile_exports

# 2. Bake all textures
python3 scripts/texbake.py --dir GameData/Models/dungeon/tile_exports/Textures/

# 3. Patch all .untold files in the tile directory
python3 scripts/texbake.py --patch-refs GameData/Models/dungeon/tile_exports/
```

### What the bake step does

1. Converts every texture in the directory to `.utex` using `astcenc`:
   - Base color and emissive: ASTC 4×4 sRGB
   - Normal maps: ASTC 4×4 LDR
   - Roughness, metallic, occlusion: ASTC 6×6 LDR
2. Rewrites the `.untold` binary to point each texture reference at the new `.utex` file and sets the `textureFormat` field to the correct ASTC variant.
3. The original PNG/JPEG files are left in place. The engine loads `.utex` when present and falls back to PNG/JPEG otherwise.

### Single-file bake with slot override

For cases where filename-based slot detection is insufficient, pass `--input` and `--slot` directly:

```bash
python3 scripts/texbake.py \
  --input GameData/Models/robot/Textures/surface_data.png \
  --slot roughness
```

Available slots: `base_color`, `normal`, `roughness`, `metallic`, `occlusion`, `orm`, `emissive`, `opacity`, `data`.

## Using LZ4 Compression

Pass `--compress-geometry` to `export-untold` or `export-untold-tiles` to compress the vertex and index chunks of the output `.untold` file with LZ4.

### Prerequisites

Install the Python LZ4 package:

```bash
pip install lz4
```

### Single asset

```bash
./scripts/export-untold \
  --input GameData/Models/robot/robot.usdz \
  --output GameData/Models/robot/robot.untold \
  --compress-geometry
```

### Tile export

```bash
./scripts/export-untold-tiles \
  --input GameData/Models/dungeon/dungeon.usdz \
  --output-dir GameData/Models/dungeon/tile_exports \
  --tile-size-x 25 \
  --tile-size-y 10000 \
  --tile-size-z 25 \
  --compress-geometry
```

### What compression does

- Only the `vertex_data` and `index_data` chunks are compressed. Metadata chunks (string table, entity table, mesh table, material table, texture table) are always stored uncompressed.
- The compressed format is LZ4 raw block (`lz4.block`, not `lz4.frame`), which matches Apple's `COMPRESSION_LZ4_RAW` algorithm used by the runtime decompressor.
- Both the compressed size and the original uncompressed size are recorded in each chunk entry, so the runtime can allocate the exact decompression buffer without an extra read.
- The content hash in the file header is computed over the compressed bytes, consistent with runtime validation.

Compression is compatible with all other flags including `--validate`, `--generate-hlod`, `--generate-lod`, and the ASTC texture bake workflow.

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
loadTiledScene(manifest: "dungeon", withExtension: "json")
```

The manifest should live next to the tile payload directory. Tile, HLOD, LOD, and shared-bucket payloads are resolved relative to the manifest file.

## Notes

- `.untold` tile payloads participate in the current tiled streaming architecture, including tile-level load/unload, remote download + cache, per-tile LOD/HLOD, and large-tile OCC sub-mesh streaming when the runtime classifies a tile into the OOC path.
- The Python files in [`scripts`](/Users/haroldserrano/Desktop/UntoldEngineStudio/UntoldEngine/scripts) are implementation details. The recommended user entry points are the shell wrappers in the same folder.
