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
- `--output <path>`: required destination `.untold` (or `.untoldanim` with `--animation`). A scene with several models is written as a `.untoldpack` of the same name; that name may be given as well
- `--file-type <tile|lod|hlod|shared|animation>`: optional, defaults to `tile`
- `--mesh-name <name>`: optional, export only one mesh from a multi-mesh asset
- `--convert-orientation`: optional, convert the export into engine space
- `--source-orientation <blender-native|engine-oriented>`: optional, defaults to `blender-native`
- `--assets-dir <path>`: optional, folder for what the export writes besides the result; defaults to the `--output` folder. The result refers to the textures, the color grade LUT and the per-model folders of a `.untoldpack` in it by relative paths, so keep both folders together. The `HDR/` copies (see below) go there as well. A result an earlier export left inside that folder is removed.
- `--include-hidden`: optional, also export objects hidden in the viewport or disabled in renders (see [What a `.blend` scene exports](#what-a-blend-scene-exports))
- `--no-material-bake`: optional, do not bake procedural materials (see [Procedural materials](#procedural-materials))
- `--material-bake-size <texels>`: optional, the size of a baked material texture; defaults to `1024`
- `--material-bake-tile <metres>`: optional, the longest stretch of surface one repeat of a baked material texture covers; defaults to `2`
- `--validate`: optional, also writes `<name>.validation.json`
- `--compress-geometry`: optional, LZ4-compress vertex and index chunks (requires `pip install lz4`)
- `--optimize`: optional, compress geometry and bake/patch textures after export (implies `--compress-geometry`)
- `--color-grade-lut <path>`: optional, stage an externally-authored standard `.cube` 3D LUT and apply it as a post-tonemap creative grade — composes with (does not replace) the default tonemap. No Blender render, no conversion. See [Using Color Management](UsingColorManagement.md)
- `--animation`: optional, export animation clips only — no mesh geometry is written; requires a `.untoldanim` `--output` path
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
- `HDR/...` beside the `.untold` file if the Blender scene has an environment
  image: the World's, or the studio light of a viewport in Material Preview
- `floorplanA.validation.json` only when `--validate` is passed

The files in `HDR/` are copies for you to use. Nothing in the export refers to
them, and the engine does not look for them there: it loads an environment by
name from your project's `GameData/HDR/` folder, so copy the ones you want into it.

A texture that cannot be exported does not stop the export. Its material is
written without that texture, and the end of the export log lists every texture
that was left out, with the material and the object that use it.

The older `./scripts/export-untold` repository wrapper remains available for
engine development and compatibility. Game developers should prefer
`untoldengine export` because it can be called directly from their project.

## What A `.blend` Scene Exports

A whole-scene export (no `--mesh-name`) follows what Blender itself shows:

- Objects in collections excluded from the view layer (the checkbox in the
  Outliner) are never exported. Blender does not evaluate them, so their
  placement would be stale.
- Objects hidden in the viewport (the eye or monitor icon, on the object or on
  a collection holding it) or disabled in renders (the camera icon) are skipped
  by default; the export log lists them. Pass `--include-hidden` to export them,
  for example when an artist hides parts of the model while working that the
  game still needs.
- Curve, surface and text objects are exported as meshes when their geometry has
  faces (a bevelled or extruded curve). Curves without faces, such as paths used
  by a Curve modifier, export nothing.
- Modifiers, Geometry Nodes and shape keys are applied, including on objects
  split into one mesh per material. Objects deformed by an Armature modifier keep
  their rest pose and skinning.
- An object whose parent is not exported (skipped, or split into one mesh per
  material) keeps its place in the scene.

Some material nodes are carried over instead of dropped:

- A Mapping node between UV coordinates and the image textures (scale and
  location, no rotation) is applied to the mesh's first UV map, so tiled textures
  keep their tiling. When textures use different Mapping nodes, the one most of
  them use is applied and the material fidelity report says so.
- Colour nodes between an image texture and its socket are written into the
  staged texture, with the same math Cycles uses: Invert, Gamma,
  Bright/Contrast, Hue/Saturation/Value, RGB Curves and ColorRamp (its Color
  output). They are applied to linear values, so an sRGB texture is decoded and
  encoded again. The texture is saved as `<name>_inverted.png` for a lone Invert,
  or as `<name>_adj<fingerprint>.png`. A node whose settings are themselves
  linked to other nodes is still dropped, and the material fidelity report says
  so.
- A material whose surface is an Emission shader exports as an emissive material
  with a black base color.
- A Base Color, Roughness, Metallic or Emission input driven by node math with no
  texture behind it (Mix, Math, RGB Curves, ColorRamp, node groups, ...) exports
  the value the chain gives for a surface seen straight on. View-dependent nodes
  such as Layer Weight and Fresnel take their straight-on value; the engine's own
  Fresnel then brightens the edges. A chain with a procedural texture in it is
  baked (see [Procedural materials](#procedural-materials)); one with an image in
  the way keeps the image.
- Each mesh exports the material of the slot its faces use, which need not be the
  first slot.
- EXR textures used by a material (a normal or metallic map, for example) are
  converted to PNG. Values above 1 are clipped.

Transparency becomes the engine's blended alpha mode:

- A constant Alpha below 1 blends the material at that opacity.
- An Alpha fed by the base color image's own Alpha output uses that alpha.
- An Alpha fed by another texture, or through colour nodes, is written into the
  alpha channel of the base color texture (a white one when the base color is a
  constant), since the engine reads alpha from the base color texture.
- Transparent BSDFs mixed in by a Mix Shader lower the opacity by their share. A
  mix driven by Geometry > Backfacing takes its front-face side.

Glass is the material's transmission, not its alpha:

- A Principled BSDF's Transmission Weight exports as the material's transmission
  (see [Using Materials](UsingMaterials.md#transmission-glass)). The surface
  itself stays whole, so glass keeps its reflections, and the engine tints what
  crosses it by the base color, texel by texel.
- The engine bends and blurs nothing behind glass. A flat pane looks as it does
  in Blender; through a thick or curved piece of glass the view is not distorted.
  Rough glass shows less of what is behind it the rougher it is (all of it up to
  a roughness of 0.05, none of it from 0.5) and glows with the light that comes
  from behind it instead, and the material fidelity report says so.
- A surface through which next to nothing would be seen exports as a solid one:
  less than 5 % of what is behind it, counting its transmission, the brightness
  of its base color, its metallic share (metal lets nothing through) and its
  roughness. Black glass is the black mirror it is in Blender, and a metal or a
  rough, dark paint with Transmission left on (an imported car's, for example)
  stays the solid surface it looks like. A base color, a metallic value or a
  roughness that comes from a texture counts as clear, as no metal and as
  polished. The report lists the surfaces kept solid.
- A Transmission driven by a texture exports its slider value for the whole
  surface.

A height texture drives the engine's parallax occlusion mapping:

- The image on a Displacement node's Height input exports as the height texture,
  with the node's Scale as its depth, and failing that the image on the Height
  input of a Bump node that feeds the Normal input, with its Distance.
- The engine's depth is a share of the texture's width, not a distance, so a
  small Scale (0.02 to 0.1) carries over well and may need tuning after import.
- A Scale or Distance above 0.2 is not a depth parallax can show. Blender leaves
  both at 1, a metre, and with its default "Bump Only" displacement draws the
  shading of a bump from them. Such a height is left out of the export, and the
  material fidelity report says so; the surface keeps its normal map.

Lights and cameras follow the same rules as objects: never from collections
excluded from the view layer, and hidden ones only with `--include-hidden`.

### Procedural materials

A Base Color, Roughness, Metallic or Normal input driven by procedural nodes
(a Noise or Brick texture, node math, a Bump from a procedural height) has no
image to export. The exporter bakes such inputs with Cycles on a flat swatch:
what the material shows on a plane.

- A pattern laid out by **object coordinates or world positions** becomes one
  set of textures per material that repeat: base color, an occlusion-roughness-
  metallic texture and a normal map, as needed, named
  `<material>_<id>_basecolor.png` and so on. The meshes that use the material
  get texture coordinates projected from their positions, so they need no UV
  map, and copies of a mesh still export as one model.
- Anything else (a pattern on UV, generated or camera coordinates, or image
  textures elsewhere in the same material) keeps the mesh's UVs. The input
  exports the value it averages to over the swatch.
- An input that is the same all over (node math on constants) exports that
  value.

How the textures are made:

- The swatch faces the way most of the material's surface does, so bricks
  written for walls are baked on a wall.
- A pattern with a period (bricks, tiles, solar cells) is cut at a whole number
  of periods, at most `--material-bake-tile` metres long. A pattern with none
  (noise) is cut at that length, and a band along the cut is blended so the
  texture repeats without a seam.
- Each texture is as large as its detail needs, up to `--material-bake-size`.
- A flat face is mapped in its own plane, without stretch: level faces by x and
  y, walls level along the wall and up. A smooth surface is mapped along the
  nearest axis.
- A pattern laid out in the world is mapped from world positions on a mesh that
  is placed once, so it continues from one object to the next as in Blender.
  Copies of one mesh share one mapping, in the mesh's own space and at the
  pattern's world size.

What a swatch cannot show, and the material fidelity report still lists where
it applies:

- A material has one swatch, facing one way. Faces that look another way show
  the same pattern, so a graph that tells top from sides (dirt on top, bricks
  that turn with the wall's normal) is right on the faces the swatch was baked
  for.
- The texture repeats.
- Edge wear from Pointiness, vertex colours and other things that need the real
  mesh are not there on a swatch. An input that reads an attribute is not baked.
- Animated node trees are not baked.

Baking takes a second or two per material. `--no-material-bake` switches it
off; the inputs then export their slider values as before. The tile pipeline
(`export-tiles`) and the Blender add-on's export do not bake.

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
- `--color-grade-lut <path>`: optional, stage an externally-authored standard `.cube` 3D LUT once for the whole scene, referenced from the manifest's `colorGradeLUT` key and applied as a post-tonemap creative grade. See [Using Color Management](UsingColorManagement.md) — it is only applied via an explicit `loadSceneAuthored(url:)` call, not by normal tile loading
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

The export scripts write a `.untoldpack` without LOD chains. `untoldengine
export` adds them as its last step; for a pack written by `scripts/export-untold`
or by the Blender add-on, run `untoldengine bake-lods --input <name>.untoldpack`
afterwards (see [LOD chains for packs](UsingUntoldEngineCLI.md#lod-chains-for-packs)).

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
