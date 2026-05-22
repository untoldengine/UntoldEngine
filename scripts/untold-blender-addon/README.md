# Untold Engine Blender Add-on

Blender add-on for exporting objects from the current Blender scene to Untold
Engine's `.untold` runtime asset format.

## Development Install

For live development, symlink the package folder into Blender's add-ons folder,
then enable `Untold Engine Exporter` in `Edit > Preferences > Add-ons`.

Example macOS path:

```sh
mkdir -p "$HOME/Library/Application Support/Blender/4.3/scripts/addons"
ln -s /path/to/UntoldEngine/scripts/untold-blender-addon/untold_exporter \
  "$HOME/Library/Application Support/Blender/4.3/scripts/addons/untold_exporter"
```

Because the symlink points back into this repo, the add-on imports the live
exporter from `scripts/untoldexplorer.py`, so exporter fixes stay in one source
file.

## Usage

Use `File > Export > Untold (.untold)` for model assets.

Options:

- `Scope`: export the visible scene or selected objects.
- `File Type`: choose the `.untold` file type marker.
- `Convert Orientation`: convert Blender native coordinates into engine space.
- `Write Validation JSON`: write a companion validation file.
- `Compress Geometry`: use LZ4 compression for geometry chunks.
- `Bake Textures To .utex`: convert staged textures to engine-native `.utex`
  files and patch the exported `.untold` references.

Texture baking requires Pillow in Blender's Python and the `astcenc` binary:

```sh
brew install astc-encoder
```

or set `ASTCENC_BIN=/full/path/to/astcenc` before launching Blender.

Use `File > Export > Untold Animation (.untold)` for animation clips.

Animation options:

- `Armature`: export the selected armature, the armature linked to a selected mesh,
  or the only visible armature in the scene.
- `Actions`: export the current action or all Blender actions.
- `Convert Orientation`: convert Blender native coordinates into engine space.

Use `File > Export > Untold Tiled Scene` for streaming scene exports.

Tiled scene options:

- `Output Directory`: scene folder for the manifest. Tile `.untold` payloads
  are written to a `tile_exports` subfolder.
- `Visible Objects Only`: export only visible meshes.
- `Partitioning`: choose exactly one partitioning algorithm.
- `Uniform Grid: Auto Tile Size`: let the uniform-grid exporter choose tile
  dimensions from scene complexity.
- `Uniform Grid: Tile Size X/Y/Z`: manual uniform-grid tile dimensions.
- `Quadtree: Floor Count`: optional floor count override. Use `0` for auto.
- `Quadtree: Floor Band Height`: optional per-floor height override. Use `0`
  for auto.
- `Scene Profile`: auto, indoor, or outdoor streaming radius profile.
- `Generate HLOD` / `Generate LOD`: create simplified distance assets.
- `Compress Geometry`: LZ4-compress tile vertex/index chunks.
- `Dry Run`: plan the partition without writing payload files.

The plugin runs tiled export in sequential mode. Use
`scripts/export-untold-tiles` for parallel worker exports.

Partitioning rules:

- `Uniform Grid` uses the auto/manual tile-size controls.
- `Quadtree` uses the floor controls and ignores uniform-grid tile sizing.
- Only one partitioning algorithm is active for a given export.

Example tiled scene layout:

```text
CityBlender/
  CityBlender.json
  tile_exports/
    tile_0_0_0.untold
    tile_0_0_1.untold
    Textures/
```

In the plugin file picker, select `CityBlender`. The plugin creates
`tile_exports` automatically.

## Current Scope

This add-on currently exports single `.untold` model assets, animation assets,
and tiled streaming scenes from Blender scene objects.

## Packaging

Run:

```sh
scripts/untold-blender-addon/package.sh
```

The package script creates an installable zip with bundled copies of
`scripts/untoldexplorer.py`, `scripts/texbake.py`, and
`scripts/tilestreamingpartition.py` under `untold_exporter/vendor/`.
