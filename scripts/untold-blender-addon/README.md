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

Use `File > Export > Untold Animation (.untold)` for animation clips.

Animation options:

- `Armature`: export the selected armature, the armature linked to a selected mesh,
  or the only visible armature in the scene.
- `Actions`: export the current action or all Blender actions.
- `Convert Orientation`: convert Blender native coordinates into engine space.

## Current Scope

This add-on currently exports single `.untold` model assets and animation
assets from Blender scene objects. Tiled scene export is intentionally left to
`scripts/export-untold-tiles` for now.

## Packaging

Run:

```sh
scripts/untold-blender-addon/package.sh
```

The package script creates an installable zip with a bundled copy of
`scripts/untoldexplorer.py` under `untold_exporter/vendor/`.
