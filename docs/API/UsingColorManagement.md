# Using Color Management

Blender scenes are displayed through a View Transform (e.g. `Standard`,
`AgX`, `Filmic`), plus optional Look, Exposure, and Gamma settings. By
default, the engine ignores all of that and renders through its own fixed
ACES Filmic tonemap — so a scene authored and graded in Blender with `AgX`
can look noticeably different once loaded in the engine.

`--bake-color-management` closes that gap by baking the scene's active
display transform into an `NxNxN` color-grading LUT (lookup table) at export
time. Loading that LUT at runtime makes the engine reproduce Blender's
display transform instead of its default tonemap.

Unlike per-material texture baking (a separate, third-party step you'd run
before export), this is **scene-wide, not per-mesh** — one LUT applies to
the whole scene's final output, not to individual materials.

## Exporting With Baked Color Management

Add `--bake-color-management` to either `untoldengine export` or
`untoldengine export-tiles`:

```bash
untoldengine export \
  --input GameData/Models/office/office.usdz \
  --output GameData/Models/office/office.untold \
  --bake-color-management
```

```bash
untoldengine export-tiles \
  --input GameData/Models/city/city.usdz \
  --output-dir GameData/Models/city/tile_exports \
  --tile-size-x 25 --tile-size-y 10000 --tile-size-z 25 \
  --bake-color-management
```

### Options

- `--bake-color-management`: bake the scene's active View Transform/Look/
  Exposure/Gamma into a color-grading LUT.
- `--color-lut-size <N>`: grid size for the `NxNxN` LUT, defaults to `32`.

For a single-asset export, the LUT is embedded in the `.untold` file (use
`--file-type shared` for a scene-wide asset, as opposed to `tile`/`lod`/
`hlod`/`animation`). For a tiled export, the LUT is referenced from the
manifest's `colorLUT` key instead of any individual tile payload.

## Loading The Result In The Engine

The baked LUT is scene-authored data, like scene lights and cameras — it is
**not** registered by a normal mesh load. `setEntityMesh`/
`setEntityMeshAsync` only bring in geometry and materials. Load it explicitly
with `loadSceneAuthored`:

```swift
// From a single .untold asset (file-type: shared)
loadSceneAuthored(filename: "office", withExtension: "untold") { success in
    // Scene-authored lights/cameras and the baked color-grading LUT are now registered.
}

// From a tile manifest
loadSceneAuthored(url: manifestURL) { success in
    // Same, sourced from the manifest's colorLUT key.
}
```

See [Using the Registration System](UsingRegistrationSystem.md#loading-scene-authored-data)
for the full behavior of `loadSceneAuthored`, including scene-authored lights
and cameras.

### Behavior Notes

- Calling `loadSceneAuthored` clears any previously-loaded color-grading LUT
  first, then re-populates it only if the asset/manifest actually has one
  baked in.
- Scenes saved through the Untold scene serializer remember the
  scene-authored source asset/manifest. Loading that `.untoldscene` re-applies
  the baked color-grading LUT without duplicating the serialized
  scene-authored light and camera entities.
- If the source wasn't exported with `--bake-color-management`, the engine
  silently falls back to its default ACES Filmic tonemap — this is not an
  error, and nothing needs to be toggled off manually.
- IBL and scene lighting are unrelated to color management — see
  [Use Image-Based Lighting (IBL)](UsageExamples.md#use-image-based-lighting-ibl)
  if a scene also needs an HDR environment; loading one does not require or
  imply the other.

## Comparing Against The Default Tonemap

`setPostFX` exposes a toggle-only property for the baked LUT — there is
nothing to author here, since the LUT itself is asset-derived:

```swift
setPostFX(.colorLUT(.enabled(false))) // compare against the default ACES Filmic tonemap
setPostFX(.colorLUT(.enabled(true)))  // re-enable the baked LUT
```

This is a no-op if no LUT has been loaded yet (i.e. `loadSceneAuthored` was
never called, or the source asset had no baked color management). See
[Using Post-Effects](UsingPostFX.md) for the full `PostFXProperty` reference.
