# Optimizations

Untold Engine supports optional asset optimization workflows that reduce runtime
memory, file size, and streaming cost. These steps are usually applied after
exporting assets to `.untold`.

For exporter commands, flags, and expected output layout, see
[Using The Exporter](UsingTheExporter.md).

## ASTC Texture Compression

ASTC is a GPU-native block-compression format supported on all Apple Silicon and A-series devices. Converting textures to ASTC reduces texture memory by 4-8x compared to uncompressed RGBA8 and eliminates CPU-side decode. The GPU receives the compressed blocks directly.

ASTC compression is a post-export step run with `untoldengine texbake`, separate from the exporters. This keeps the exporter's Blender Python environment free of extra dependencies.

### Prerequisites

Install everything `texbake` needs — `astcenc`, and the `Pillow`/`lz4` Python
packages — with:

```bash
untoldengine bootstrap
```

This downloads the pinned, checksum-verified `astcenc` release into
`~/.untoldengine/tools/astcenc/astcenc` and `pip install`s `Pillow`/`lz4` for
whichever `python3` `untoldengine texbake` will itself resolve. Nothing to set
by hand. Re-running `bootstrap` is a no-op once everything is present; pass
`--force` to reinstall.

If you'd rather manage `astcenc` yourself, download the appropriate build from the
[`astcenc` releases page](https://github.com/ARM-software/astc-encoder/releases),
make it executable, and set `ASTCENC_BIN` to its absolute path:

```bash
chmod +x /full/path/to/astcenc
export ASTCENC_BIN="/full/path/to/astcenc"
```

The tool is resolved in this order:

1. `ASTCENC_BIN=/path/to/astcenc`
2. `~/.untoldengine/tools/astcenc/astcenc` (where `bootstrap` installs it; override the home directory with `UNTOLDENGINE_HOME`)
3. `Tools/astcenc/astcenc` beside the repo root
4. `astcenc` on `PATH`

### Single asset workflow

```bash
# 1. Export the asset
./scripts/export-untold \
  --input GameData/Models/robot/robot.usdz \
  --output GameData/Models/robot/robot.untold

# 2. Bake all textures in the Textures/ directory to .utex
untoldengine texbake --dir GameData/Models/robot/Textures/

# 3. Patch the .untold file to reference the .utex files
untoldengine texbake --patch-refs GameData/Models/robot/robot.untold
```

### Tile export workflow

Tile exports produce many `.untold` files. Pass the tile output directory to `--patch-refs` and all `.untold` files inside are patched in one go:

```bash
# 1. Export tiles
./scripts/export-untold-tiles \
  --input GameData/Models/dungeon/dungeon.usdz \
  --output-dir GameData/Models/dungeon/tile_exports

# 2. Bake all textures
untoldengine texbake --dir GameData/Models/dungeon/tile_exports/Textures/

# 3. Patch all .untold files in the tile directory
untoldengine texbake --patch-refs GameData/Models/dungeon/tile_exports/
```

### What the bake step does

1. Converts every texture in the directory to `.utex` using `astcenc`:
   - Base color and emissive: ASTC 4x4 sRGB
   - Normal maps: ASTC 4x4 LDR
   - Roughness, metallic, occlusion: ASTC 6x6 LDR
2. Rewrites the `.untold` binary to point each texture reference at the new `.utex` file and sets the `textureFormat` field to the correct ASTC variant.
3. The original PNG/JPEG files are left in place. The engine loads `.utex` when present and falls back to PNG/JPEG otherwise.

### Single-file bake with slot override

For cases where filename-based slot detection is insufficient, pass `--input` and `--slot` directly:

```bash
untoldengine texbake \
  --input GameData/Models/robot/Textures/surface_data.png \
  --slot roughness
```

Available slots: `base_color`, `normal`, `roughness`, `metallic`, `occlusion`, `orm`, `emissive`, `opacity`, `data`.

## LZ4 Geometry Compression

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
