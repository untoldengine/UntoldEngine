# Using The Blender Plugin

The Untold Engine Blender plugin exports assets from the current Blender scene
to the engine-native `.untold` format.

Use it when you want to import or open a model in Blender, inspect or edit it,
then export it without caring whether the original source was `.usdz`, `.fbx`,
`.glb`, `.obj`, or another Blender-supported format.

## Install

Build the plugin zip from the repo root:

```bash
scripts/untold-blender-addon/package.sh
```

In Blender:

1. Open `Edit > Preferences > Add-ons`.
2. Click `Install...`.
3. Select `scripts/untold-blender-addon/build/untold_exporter.zip`.
4. Enable `Untold Engine Exporter`.

The plugin adds:

- `File > Export > Untold (.untold)`
- `File > Export > Untold Animation (.untold)`
- `File > Export > Untold Tiled Scene`

## Export A Model

1. Open or import a model in Blender.
2. Choose `File > Export > Untold (.untold)`.
3. Pick an output filename.

If you choose:

```text
RetroCameraBlender.untold
```

the plugin writes:

```text
RetroCameraBlender/
  RetroCameraBlender.untold
  Textures/
```

By default, the plugin exports the visible scene. You can change `Scope` to
`Selected Objects` if you only want to export part of the scene.

## Export Animation

Use `File > Export > Untold Animation (.untold)`.

The animation exporter can use:

- the selected armature,
- the armature linked to a selected mesh, or
- the only visible armature in the scene.

You can export the current action or all Blender actions.

## Export A Tiled Scene

Use `File > Export > Untold Tiled Scene`.

The tiled scene exporter partitions the current Blender scene and writes a
streaming manifest plus tile `.untold` payloads.

Select a scene folder in the file picker. The plugin creates the payload
subfolder automatically.

For example, selecting:

```text
/Users/you/Downloads/CityBlender
```

writes:

```text
CityBlender/
  CityBlender.json
  tile_exports/
    tile_0_0_0.untold
    tile_0_0_1.untold
    ...
    Textures/
```

The manifest lives beside `tile_exports`, and all paths in the manifest are
relative to the manifest location.

### Tiled Scene Options

- `Visible Objects Only`: export only visible mesh objects.
- `Partitioning`: choose the tiling algorithm. Only one algorithm is active per
  export.
- `Scene Profile`: choose `auto`, `indoor`, or `outdoor` streaming radius bands.
  For CLI exports, use `--tier-radius Tier=stream,unload[,priority]` to override
  the profile's quadtree semantic-tier bands. See [Using The Exporter](UsingTheExporter.md#quadtree-tier-radius-overrides).
- `Generate HLOD`: create simplified coarse HLOD assets for eligible tiles.
- `Generate LOD`: create per-tile LOD assets for eligible tiles.
- `Compress Geometry`: LZ4-compress vertex and index chunks in tile payloads.
- `Dry Run`: analyze the partition without writing tile payloads.
- `Write Manifest In Dry Run`: write the manifest JSON even during a dry run.

### Uniform Grid

Use `Partitioning > Uniform Grid` for regular X/Y/Z grid tiles.

Uniform Grid uses:

- `Uniform Grid: Auto Tile Size`
- `Uniform Grid: Tile Size X`
- `Uniform Grid: Tile Size Y`
- `Uniform Grid: Tile Size Z`

When `Auto Tile Size` is enabled, the exporter chooses tile dimensions from the
scene complexity. When it is disabled, the manual tile size values are used.

### Quadtree

Use `Partitioning > Quadtree` for floor-aware quadtree partitioning with
semantic tiers.

Quadtree uses:

- `Quadtree: Floor Count`
- `Quadtree: Floor Band Height`

Set either value to `0` to use automatic detection.

`Quadtree: Floor Count = 0` matches the script default: the exporter estimates
floor bands from object height distribution and scene Z span.

When `Quadtree` is selected, uniform-grid tile size options are ignored.

### Plugin vs CLI

The plugin runs tiled export in sequential mode from the current Blender scene.
This is simpler and avoids reopening or re-importing the scene from inside
Blender.

For large production scenes where you want parallel worker processes, use the
CLI:

```bash
scripts/export-untold-tiles --input /path/to/scene.usdz --output-dir /path/to/Scene/tile_exports --quadtree
```

## Dependencies

The model exporter works with Blender's built-in Python environment. Optional
features require extra tools inside the environment that Blender is actually
running.

This distinction matters: installing a Python package in your terminal Python
does not necessarily install it into Blender's Python.

## LZ4 Geometry Compression

`Compress Geometry` compresses only the `.untold` vertex and index chunks. It
does not compress files in the `Textures/` folder.

It requires the `lz4` Python package in Blender's Python.

Verify inside Blender's Python console:

```python
import lz4.block
print("lz4 works")
```

Install into Blender's Python:

```python
import sys, subprocess
subprocess.check_call([sys.executable, "-m", "ensurepip"])
subprocess.check_call([sys.executable, "-m", "pip", "install", "lz4"])
```

Restart Blender after installing.

## Texture Baking To .utex

`Bake Textures To .utex` converts staged PNG/JPEG/TGA textures to the engine's
native `.utex` texture container and patches the `.untold` file to reference the
`.utex` files.

This option requires:

- `Pillow` in Blender's Python.
- `astcenc`, the ARM ASTC encoder binary.

### Pillow

Verify inside Blender's Python console:

```python
from PIL import Image
print("Pillow works")
```

Install into Blender's Python:

```python
import sys, subprocess
subprocess.check_call([sys.executable, "-m", "ensurepip"])
subprocess.check_call([sys.executable, "-m", "pip", "install", "Pillow"])
```

Restart Blender after installing.

### astcenc

The texture baker searches for `astcenc` in this order:

1. The `ASTCENC_BIN` environment variable.
2. `Tools/astcenc/astcenc` beside the repo root when running from the repo.
3. `astcenc`, `astcenc-native`, `astcenc-avx2`, or `astcenc-sse4.2` on `PATH`.

When the plugin is installed as a packaged zip, the most reliable option is to
launch Blender with `ASTCENC_BIN` set.

Example:

```bash
ASTCENC_BIN="/path/to/your/astcenc" \
/Applications/Blender.app/Contents/MacOS/Blender
```

Check that the binary exists and is executable:

```bash
ls -l /path/to/your/astcenc
/path/to/your/astcenc -help
```

If needed, make it executable:

```bash
chmod +x /path/to/your/astcenc
```

You can also download `astcenc` from:

```text
https://github.com/ARM-software/astc-encoder/releases
```

Homebrew availability may vary. If `brew install astc-encoder` reports that no
formula exists, use the downloaded binary and `ASTCENC_BIN`.

## Texture Quality

The `Texture Quality` setting maps to `astcenc` quality presets:

- `fastest`: fastest encode, lowest search quality.
- `fast`: fast encode.
- `medium`: balanced.
- `thorough`: slower, better quality. This is the default.
- `exhaustive`: slowest, highest search effort.

This does not change texture resolution or ASTC block size. Block size is chosen
by texture slot:

- base color and emissive: ASTC 4x4 sRGB
- normal: ASTC 4x4 LDR
- roughness, metallic, occlusion: ASTC 6x6 LDR

## Troubleshooting

If `Compress Geometry` appears not to reduce the full asset folder size, compare
only the `.untold` file. Texture files are separate and are not affected by LZ4
geometry compression.

If texture baking fails with `Pillow is required`, install Pillow into Blender's
Python, not only your terminal Python.

If texture baking fails with `astcenc not found on PATH`, launch Blender with
`ASTCENC_BIN=/full/path/to/astcenc`.
