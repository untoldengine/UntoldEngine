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
- `File Type`: choose the `.untold` file type marker. `Standard` is the
  default runtime asset marker; use `Shared` to mark a non-tiled export as a
  scene-wide asset so `loadSceneAuthored` picks up its lights/cameras/baked
  color-management LUT (see
  [Using Color Management](../../docs/API/UsingColorManagement.md)). `LOD`/
  `HLOD` are for manually producing distance-asset payloads outside the
  tiled scene exporter.
- `Convert Orientation`: convert Blender native coordinates into engine space.
- `Write Validation JSON`: write a companion validation file.
- `Compress Geometry`: use LZ4 compression for geometry chunks.
- `Bake Color Management`: bake the scene's active View Transform/Look/
  Exposure/Gamma into a color-grading LUT so Untold can closely reproduce
  Blender's color management, including Filmic/AgX highlight compression.
- `Color LUT Size`: grid size (N) for the NxNxN color-grading LUT.
- `Compress Textures`: convert staged textures to engine-native `.utex`
  files and patch the exported `.untold` references.

The `Untold Materials` tab in the 3D viewport sidebar (`N` panel) includes a
`Color Management` panel with a `Scan Color Management` operator that
previews the View Transform/Look/Exposure/Gamma `Bake Color Management`
would capture, without exporting, and warns about compositor grading nodes
(Color Balance, Curves, Hue Correct) that a LUT bake cannot capture.

Texture baking requires Pillow in Blender's Python and the `astcenc` binary:

Download `astcenc` from the
[ARM astc-encoder releases page](https://github.com/ARM-software/astc-encoder/releases),
then set `ASTCENC_BIN=/full/path/to/astcenc` before launching Blender.

Ensure the downloaded binary is executable with
`chmod +x /full/path/to/astcenc`.

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
- `Tree: Floor Count`: optional floor count override for quadtree/KD-tree
  partitioning. Use `0` for auto.
- `Tree: Floor Band Height`: optional per-floor height override. Use `0`
  for auto.
- `Scene Profile`: auto, indoor, or outdoor streaming radius profile.
- `Untagged Semantic`: semantic tier (`Auto`, `Exterior Shell`,
  `Structural Interior`, `Room Contents`, `Fine Props`) applied to meshes
  without an explicit Untold semantic override.
- `Custom Tier Radii`: override the profile-derived streaming/unload
  radii and priority for each semantic tier.
- `Generate HLOD` / `Generate LOD`: create simplified distance assets.
  They reuse the full-detail tile's export rather than re-baking anything.
- `Custom Rep Ranges`: override the normalized LOD1/LOD2/HLOD switch
  distances and reduction ratios instead of the scene-profile defaults.
- `Compress Geometry`: LZ4-compress tile vertex/index chunks.
- `Bake Color Management` / `Color LUT Size`: same as the model exporter,
  above; the LUT is referenced from the tiled scene manifest's `colorLUT`
  key.
- `Dry Run`: plan the partition without writing payload files.
- `Write Manifest In Dry Run`: write the manifest JSON even when `Dry Run`
  is enabled.

The plugin runs tiled export in sequential mode. Use
`scripts/export-untold-tiles` for parallel worker exports.

Partitioning rules:

- `Uniform Grid` uses the auto/manual tile-size controls.
- `Quadtree` uses the floor controls and ignores uniform-grid tile sizing.
- `KD-Tree` uses the floor controls and gives better balance than Quadtree
  in scenes with clustered geometry.
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

From the repository root, run:

```sh
untoldengine blender-addon
```

(equivalent to running `scripts/untold-blender-addon/package.sh` directly.)

The package script creates an installable zip with bundled copies of
`scripts/untoldexplorer.py`, `scripts/texbake.py`, and
`scripts/tilestreamingpartition.py` under `untold_exporter/vendor/`.
