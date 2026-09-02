# Using Color Management

Blender scenes are displayed through a View Transform (e.g. `Standard`,
`AgX`, `Filmic`), plus optional Look, Exposure, and Gamma settings. The
engine reproduces this at runtime with two independent, composable
mechanisms: a native tonemap operator that runs in the Look pass, and an
optional creative grade LUT layered on top of it.

## Native Tonemap Operator

`setPostFX(.tonemapOperator(_))` selects which built-in operator the engine
runs:

```swift
setPostFX(.tonemapOperator(.aces)) // default
setPostFX(.tonemapOperator(.agx))  // matches Blender's default View Transform since 4.0
```

AgX is a native Metal port of the widely-used "Minimal AgX" approximation
of Blender's AgX OCIO config, not a baked asset — it costs nothing at
export time and works on any scene. It has not been empirically validated
pixel-for-pixel against a real Blender AgX render; for color-critical work,
compare visually against a Blender viewport render set to AgX.

Neither operator is a substitute for a custom OCIO config, a non-stock View
Transform, or a Look — for those, use a creative grade LUT below to get
closer, or accept the approximation.

## Using An Externally-Authored Grade LUT (.cube)

If you already have (or want to hand-author, or export from DaVinci
Resolve, Nuke, or any other grading tool) a standard `.cube` 3D LUT,
`--color-grade-lut` stages it alongside the export as-is — no Blender
render, no proprietary container, no shaper encoding. It's applied as a
**creative grade on top of** whichever tonemap ran, so it operates in
ordinary display-referred `[0, 1]` space (or whatever `DOMAIN_MIN`/
`DOMAIN_MAX` the `.cube` declares):

```bash
untoldengine export \
  --input GameData/Models/office/office.usdz \
  --output GameData/Models/office/office.untold \
  --color-grade-lut GameData/LUTs/warm_grade.cube
```

```bash
untoldengine export-tiles \
  --input GameData/Models/city/city.usdz \
  --output-dir GameData/Models/city/tile_exports \
  --tile-size-x 25 --tile-size-y 10000 --tile-size-z 25 \
  --color-grade-lut GameData/LUTs/warm_grade.cube
```

The `.cube` is content-addressed and copied into the export's `Textures/`
folder, and referenced from a `colorGradeLUT` key in the `.untold` file or
tile manifest. The engine parses the `.cube` text directly and uploads it
to a native Metal 3D texture; there is no conversion step on either side,
so any standard `.cube` works, not just ones this exporter produces.

A `.cube` can also be applied without any scene export at all, via the
standalone runtime API:

```swift
setColorGradeLUT(filename: "warm_grade", withExtension: "cube")
```

This resolves the LUT the same way `LoadingSystem` resolves any other
asset — from a `LUT/` folder under `assetBasePath`, or the app bundle. See
[Using the Registration System](UsingRegistrationSystem.md) for the full
`setColorGradeLUT` reference.

## Loading The Result In The Engine

A `.cube` grade referenced from a scene export is scene-authored data, like
scene lights and cameras — it isn't registered by a normal mesh load.
`setEntityMesh`/`setEntityMeshAsync` only bring in geometry and materials.
Load it explicitly with `loadSceneAuthored`:

```swift
// From a single .untold asset (file-type: shared)
loadSceneAuthored(filename: "office", withExtension: "untold") { success in
    // Scene-authored lights/cameras and the .cube grade (colorGradeLUT)
    // are now registered.
}

// From a tile manifest
loadSceneAuthored(url: manifestURL) { success in
    // Same, sourced from the manifest's colorGradeLUT key.
}
```

See [Using the Registration System](UsingRegistrationSystem.md#loading-scene-authored-data)
for the full behavior of `loadSceneAuthored`, including scene-authored lights
and cameras.

### Behavior Notes

- Calling `loadSceneAuthored` clears any previously-loaded `.cube` grade
  first, then re-populates it based on what the asset/manifest actually
  has.
- Scenes saved through the Untold scene serializer remember the selected
  tonemap operator and the standalone `.cube` grade (if one was set via
  `setColorGradeLUT`), and restore both on load.
- If the source has no `.cube` staged, the engine silently applies no
  creative grade — this is not an error, and nothing needs to be toggled
  off manually.
- IBL and scene lighting are unrelated to color management — see
  [Use Image-Based Lighting (IBL)](UsageExamples.md#use-image-based-lighting-ibl)
  if a scene also needs an HDR environment; loading one does not require or
  imply the other.

## Comparing Against The Default Tonemap

`setPostFX(.colorGradeLUT(.enabled(_)))` toggles the `.cube` grade off and
on without unloading it, to compare against the native tonemap operator
alone:

```swift
setPostFX(.colorGradeLUT(.enabled(false))) // compare with the .cube grade removed
setPostFX(.colorGradeLUT(.enabled(true)))  // re-enable the .cube grade
```

This is a no-op if no `.cube` has been loaded (i.e. `loadSceneAuthored` was
never called with a `colorGradeLUT`-bearing asset, and `setColorGradeLUT`
was never called directly). See [Using Post-Effects](UsingPostFX.md) for
the full `PostFXProperty` reference.

## Older Assets (Baked Color Management)

Assets exported before this exporter retired `--bake-color-management`
carry a scene-wide, baked whole-transform LUT (the `colorLUT` chunk/
manifest key) instead of, or alongside, a `.cube` grade. The engine still
loads and applies these for backward compatibility — `setPostFX(.colorLUT(.enabled(_)))`
still toggles it — but the exporter and Blender add-on no longer produce
new ones. Re-export with the native tonemap operator and/or a `.cube`
grade instead.
