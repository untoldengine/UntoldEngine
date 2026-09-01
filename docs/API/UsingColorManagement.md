# Using Color Management

Blender scenes are displayed through a View Transform (e.g. `Standard`,
`AgX`, `Filmic`), plus optional Look, Exposure, and Gamma settings. The
engine has its own native tonemap operator — **ACES Filmic by default** —
plus a native AgX operator for scenes authored with Blender's default View
Transform since 4.0. Neither is a substitute for a custom OCIO config, a
non-stock View Transform, or a Look — for those, use
`--bake-color-management` below.

## Native Tonemap Operator

`setPostFX(.tonemapOperator(_))` selects which built-in operator the engine
runs (only takes effect when no `--bake-color-management` LUT is active —
see below):

```swift
setPostFX(.tonemapOperator(.aces)) // default
setPostFX(.tonemapOperator(.agx))  // matches Blender's default View Transform since 4.0
```

AgX is a native Metal port of the widely-used "Minimal AgX" approximation
of Blender's AgX OCIO config, not a baked asset — it costs nothing at
export time and works on any scene, whether or not it was exported with any
color-management flag. It has not been empirically validated pixel-for-pixel
against a real Blender AgX render (that would need a live Blender
comparison); for color-critical work, verify by exporting the same scene
both ways — once relying on the native operator, once with
`--bake-color-management` (which renders through Blender's actual AgX and is
exact by construction) — and compare visually. `--bake-color-management`
remains the correct choice whenever exact parity matters, or the scene uses
a non-stock View Transform, custom OCIO config, or a Look.

## Baked Color Management (Exact, Any View Transform/Look/OCIO Config)

`--bake-color-management` closes the gap completely, for any View
Transform/Look/OCIO config — not just AgX/ACES — by baking the scene's
active display transform into an `NxNxN` color-grading LUT (lookup table) at
export time. Loading that LUT at runtime makes the engine reproduce
Blender's display transform exactly, replacing the native tonemap operator
above rather than composing with it.

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

## Using An Externally-Authored Grade LUT (.cube)

`--bake-color-management` is one option among two now. If you already have
(or want to hand-author, or export from DaVinci Resolve, Nuke, or any other
grading tool) a standard `.cube` 3D LUT, `--color-grade-lut` stages it
alongside the export as-is — no Blender render, no proprietary container,
no shaper encoding. It's meant to be applied as a **creative grade on top
of** whichever tonemap ran (the engine's native tonemap, or a
`--bake-color-management` bake), not as a replacement for it, so unlike the
baked LUT it operates in ordinary display-referred `[0, 1]` space (or
whatever `DOMAIN_MIN`/`DOMAIN_MAX` the `.cube` declares):

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
folder, and referenced from a `colorGradeLUT` key — separate from `colorLUT`
above — in the `.untold` file or tile manifest. The engine parses the
`.cube` text directly and uploads it to a native Metal 3D texture; there is
no `.utex` conversion step on either side, so any standard `.cube` works,
not just ones this exporter produces. Because `--bake-color-management` and
`--color-grade-lut` are independent mechanisms, both can be used on the same
export — the baked LUT (or native tonemap) runs first, then the `.cube`
grade layers on top.

## Loading The Result In The Engine

Both the baked LUT and the `.cube` grade are scene-authored data, like scene
lights and cameras — neither is registered by a normal mesh load.
`setEntityMesh`/`setEntityMeshAsync` only bring in geometry and materials.
Load them explicitly with `loadSceneAuthored`:

```swift
// From a single .untold asset (file-type: shared)
loadSceneAuthored(filename: "office", withExtension: "untold") { success in
    // Scene-authored lights/cameras, the baked LUT (colorLUT), and the .cube
    // grade (colorGradeLUT) are now registered.
}

// From a tile manifest
loadSceneAuthored(url: manifestURL) { success in
    // Same, sourced from the manifest's colorLUT/colorGradeLUT keys.
}
```

See [Using the Registration System](UsingRegistrationSystem.md#loading-scene-authored-data)
for the full behavior of `loadSceneAuthored`, including scene-authored lights
and cameras.

### Behavior Notes

- Calling `loadSceneAuthored` clears any previously-loaded baked LUT and
  `.cube` grade first, then re-populates each independently based on what
  the asset/manifest actually has.
- Scenes saved through the Untold scene serializer remember the
  scene-authored source asset/manifest. Loading that `.untoldscene` re-applies
  both the baked LUT and the `.cube` grade without duplicating the serialized
  scene-authored light and camera entities.
- If the source wasn't exported with `--bake-color-management`, the engine
  silently falls back to its native tonemap operator (ACES Filmic by
  default) — this is not an error, and nothing needs to be toggled off
  manually. The same applies independently to `--color-grade-lut`: no
  `.cube` means no creative grade, silently.
- IBL and scene lighting are unrelated to color management — see
  [Use Image-Based Lighting (IBL)](UsageExamples.md#use-image-based-lighting-ibl)
  if a scene also needs an HDR environment; loading one does not require or
  imply the other.

## Comparing Against The Default Tonemap

`setPostFX` exposes toggle-only properties for both LUTs — there is nothing
to author here, since both are asset-derived:

```swift
setPostFX(.colorLUT(.enabled(false)))      // compare against the native tonemap operator
setPostFX(.colorLUT(.enabled(true)))       // re-enable the baked LUT
setPostFX(.colorGradeLUT(.enabled(false))) // compare with the .cube grade removed
setPostFX(.colorGradeLUT(.enabled(true)))  // re-enable the .cube grade
```

Each is a no-op if that particular LUT hasn't been loaded (i.e.
`loadSceneAuthored` was never called, or the source asset had no baked color
management / no `.cube` staged). See [Using Post-Effects](UsingPostFX.md) for
the full `PostFXProperty` reference.
