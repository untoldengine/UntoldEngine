# Enabling Gaussian System in Untold Engine

The Gaussian System in the Untold Engine is responsible for rendering Gaussian Splatting models. It enables you to visualize high-quality 3D reconstructions created from photogrammetry or neural rendering techniques, providing a modern approach to displaying complex 3D scenes.

## How to Enable the Gaussian System

### Step 1: Create an Entity

Start by creating an entity that represents your Gaussian Splat object.

```swift
let myEntity = createEntity()
```

---

### Step 2: Link a Gaussian Splat to the Entity

To display a Gaussian Splat model, load its .ply file and link it to the entity using setEntityGaussian.

```swift
setEntityGaussian(entityId: myEntity, filename: "splat", withExtension: "ply")
```

You can also use the source-based API:

```swift
setEntityGaussian(
    entityId: myEntity,
    source: .single(filename: "splat", withExtension: "ply")
)
```

Parameters:

- entityId: The ID of the entity created earlier.
- filename: The name of the .ply file (without the extension).
- withExtension: The file extension, typically "ply".

> Note: The Gaussian System renders point cloud data stored in the .ply format. Ensure your Gaussian Splat file is properly formatted and contains the necessary attributes (position, color, opacity, scale, rotation).

Both forms load synchronously and keep the splat resident for the entity's lifetime, and both
compute the entity's `LocalTransformComponent.boundingBox` automatically from the loaded splat
positions — no bounding box parameter is needed for this path.

---

### Step 3: Loading Without Blocking the Main Thread

`setEntityGaussianAsync` does the same immediate/resident load as `setEntityGaussian`, but
parsing, per-splat encoding, and spherical-harmonics packing all run off the main thread —
only the final component registration touches the world. Use it for a one-off splat load
where you don't want a frame hitch but don't need distance-based streaming.

```swift
Task {
    let ok = await setEntityGaussianAsync(
        entityId: myEntity,
        filename: "splat",
        withExtension: "ply"
    )
    if !ok {
        print("Failed to load splat")
    }
}
```

`completion` is an optional alternative to checking the returned `Bool`:

```swift
await setEntityGaussianAsync(
    entityId: myEntity,
    filename: "splat",
    withExtension: "ply"
) { success in
    print(success ? "Loaded" : "Failed to load splat")
}
```

---

### Running the Gaussian System

Once everything is set up:

1. Run the project.
2. Your Gaussian Splat model will appear in the game window.
3. If the model is not visible or appears incorrect, revisit the file path and format to ensure everything is loaded correctly.

---

## Progressive Gaussian Splats

Progressive Gaussian loading is available without a tile-streamed scene. Use it when you
want a Gaussian to appear quickly at a coarse tier, then refine toward full resolution as
the camera gets closer.

Progressive assets use `.untoldgs` tier files:

```text
<baseFilename>_lod0.untoldgs
<baseFilename>_lod1.untoldgs
<baseFilename>_lod2.untoldgs
...
```

`lod0` is the finest/full-resolution tier. Higher LOD numbers are progressively coarser.
The engine loads the coarsest tier first, then `GaussianLODSystem` requests finer tiers
based on camera distance (see [Overdraw-aware LOD selection](#overdraw-aware-lod-selection)
below for a second, distance-independent signal that can also hold an entity on a coarser
tier).

Generate tiers from a `.ply` source with the exporter:

```bash
untoldengine export --input "chair.ply" --output "chair.untoldgs" --lod-levels 4
```

The exporter prints a diagnostic `meanSquaredSplatExtent` per tier and a `boundingBoxHalfExtent`
line computed from the full source asset:

```text
✅ Exported: chair_lod0.untoldgs (meanSquaredSplatExtent: 0.0021)
✅ Exported: chair_lod1.untoldgs (meanSquaredSplatExtent: 0.0087)
✅ Exported: chair_lod2.untoldgs (meanSquaredSplatExtent: 0.0341)
✅ Exported: chair_lod3.untoldgs (meanSquaredSplatExtent: 0.1250)
ℹ️ boundingBoxHalfExtent: (0.42, 0.55, 0.38)
```

Both values are baked directly into each tier's `.untoldgs` file (its header carries the
asset-level bounding box alongside `meanSquaredSplatExtent`) and read back automatically when
the engine loads it — nothing here needs to be copied into your code. The console lines are
diagnostics only (e.g. to sanity-check density/size across source captures).

Then register the entity with the source-based API:

```swift
let chair = createEntity()
translateTo(entityId: chair, position: simd_float3(0.0, 0.0, -3.0))

setEntityGaussian(
    entityId: chair,
    source: .progressive(
        baseFilename: "chair",
        levelCount: 4,
        maxDistances: [5.0, 15.0, 25.0, .greatestFiniteMagnitude]
    )
)
```

`maxDistances` must have one entry per LOD. Each value is the farthest camera distance at
which that LOD is allowed to be selected:

- `lod0` can be used inside `5.0` units.
- `lod1` can be used from `5.0` to `15.0` units.
- `lod2` can be used from `15.0` to `25.0` units.
- `lod3` is used beyond `25.0` units, or while finer tiers are still loading.

The system always falls back to the best tier already resident in memory, so the entity can
become visible quickly with the coarsest tier and refine toward `lod0`.

There's no bounding-box parameter to pass here: the engine reads the box baked into the
coarsest tier's header synchronously at registration time, so the entity has a correct,
exact bounding box from frame one.

### Overdraw-aware LOD selection

Distance alone is a proxy for how expensive a Gaussian entity is to render — two assets at
the same distance can have very different overdraw depending on splat density. On top of the
distance/`maxDistances` selection above, `GaussianLODSystem` also estimates the entity's mean
overdraw (blended fragments per pixel across its screen footprint) each LOD update, using
`meanSquaredSplatExtent` values baked into each `.untoldgs` tier by the exporter. If a
distance-selected tier would exceed `LODConfig.shared.gaussianOverdrawBudget` (default `12.0`,
see `LODConfig.swift`), the system walks to a coarser tier instead — it never picks a finer
tier than distance already allows.

This is fully automatic for any asset baked with the current exporter — there is nothing to
wire up. It only has an effect on tiers that carry a real `meanSquaredSplatExtent`; `.untoldgs`
files baked before this feature existed fall back to pure distance-based selection.

Tune `LODConfig.shared.gaussianOverdrawBudget` on-device by watching GPU frame time while
varying it — the default is a starting guess, not a derived constant.

### Debugging progressive LOD

Gaussian progressive LODs participate in the same LOD debug visualization used by mesh
LODs:

```swift
setSpatialDebug(.lodLevels(true))
```

When enabled, the renderer tints Gaussian splats by their currently selected progressive
LOD. This is useful for confirming that the engine is switching tiers as the camera moves,
including tiers the overdraw budget forces early.

---

## Streaming Gaussian Splats in Large Scenes

`setEntityGaussian` loads a splat immediately and keeps it resident for the lifetime of the
entity — fine for a small number of always-visible splats, but not what you want for props
scattered across a large tile-streamed scene (chairs, tables, decor inside a streamed
building). Loading every one of those up front defeats the point of streaming, and the
engine has no way to unload them again on its own.

For that case, register the entity with `GeometryStreamingSystem` instead, via
`setEntityGaussianStreaming`, which loads and unloads it automatically based on camera
distance — the same way it already handles the surrounding streamed tile geometry. It can
stream either one whole Gaussian file or a progressive `.untoldgs` tier set.

### API overview

```swift
setEntityGaussianStreaming(
    entityId: EntityID,
    source: GaussianSource,
    options: GaussianStreamingOptions
)
```

`GaussianSource` selects what kind of Gaussian asset the streaming system should load:

```swift
.single(filename: String, withExtension: String)

.progressive(
    baseFilename: String,
    withExtension: String = "untoldgs",
    levelCount: Int,
    maxDistances: [Float]
)
```

`GaussianStreamingOptions` controls the entity's streaming behavior:

```swift
GaussianStreamingOptions(
    streamingRadius: Float = 100.0,
    unloadRadius: Float = 150.0,
    boundingBoxHalfExtent: simd_float3? = nil,
    priority: Int = 0
)
```

### Prerequisites

This only makes sense in a scene that is already using tile-based streaming — i.e. one
loaded with `setEntityStreamScene` (see [Using the Geometry Streaming System](UsingGeometryStreamingSystem.md)).
`setEntityGaussianStreaming` attaches the splat to whichever tile stub's bounds contain
the entity's position, so it needs those tile stubs to already exist. Call it **after**
`setEntityStreamScene`'s completion handler has fired — tile stubs are guaranteed to be
registered by then.

### Step 1: Create and position the entity

Position and orient the entity *before* registering it for streaming — the position at the
time you call `setEntityGaussianStreaming` is what determines which tile it gets attached
to.

```swift
let streamSplat = createEntity()
translateTo(entityId: streamSplat, position: simd_float3(2.0, 0.0, -4.0))
rotateTo(entityId: streamSplat, angle: 180.0, axis: simd_float3(1.0, 0.0, 0.0))
```

### Step 2: Register it for streaming

```swift
setEntityGaussianStreaming(
    entityId: streamSplat,
    source: .single(filename: "chair", withExtension: "untoldgs"),
    options: GaussianStreamingOptions(
        streamingRadius: 30.0,
        unloadRadius: 45.0
    )
)
```

Parameters:

- `entityId`: The entity created and positioned in Step 1.
- `source`: Use `.single(filename:withExtension:)` for a whole `.ply`/`.untoldgs` asset, or
  `.progressive(baseFilename:levelCount:maxDistances:)` for progressive tiers named
  `<baseFilename>_lod0.untoldgs`, `<baseFilename>_lod1.untoldgs`, etc.
- `streamingRadius`: Distance from the camera at which the splat starts loading.
- `unloadRadius`: Distance beyond which the splat unloads. Should be larger than
  `streamingRadius` to avoid load/unload thrashing at the boundary.
- `boundingBoxHalfExtent`: Optional local-space half-extent for the entity, roughly matching
  the splat's real-world size. `GeometryStreamingSystem`'s frustum gate needs a real
  local-space volume on the entity *before* it ever loads, so a `.untoldgs` source's box is
  read from its baked header synchronously at registration time when this is left `nil` — no
  value needed for that case. **A raw `.ply` source has no baked header, so this must be
  supplied explicitly there** — omitting it leaves the entity non-streaming (logged as a
  warning) rather than registering a zero-size placeholder, which would collapse the frustum
  gate to a single exact point and make re-streaming unreliable once the camera moves away
  and back. When you do need one, the exporter's printed `boundingBoxHalfExtent` diagnostic
  (see above) is a good starting value.
- `priority`: Optional. Higher-priority entities load first when multiple candidates are
  in range at once. Defaults to `0`.

> Note: If no tile is found containing the entity's position, `setEntityGaussianStreaming`
> logs a warning and leaves the entity as a plain, non-streaming entity (no `StreamingComponent`
> is attached) — it will not crash, but it also will not load. Double-check the position
> against the streamed scene's tile bounds if this happens.

### Progressive Gaussian splat streaming

Use `.progressive(...)` with `setEntityGaussianStreaming` when you want tile-driven
load/unload behavior plus the same coarse-to-fine refinement (including the
[overdraw-aware LOD clamp](#overdraw-aware-lod-selection)) described above.

Progressive tier filenames must follow this pattern:

```text
<baseFilename>_lod0.untoldgs
<baseFilename>_lod1.untoldgs
<baseFilename>_lod2.untoldgs
...
```

For example, if `baseFilename` is `"chair"` and `levelCount` is `4`, the engine expects:

```text
chair_lod0.untoldgs
chair_lod1.untoldgs
chair_lod2.untoldgs
chair_lod3.untoldgs
```

```swift
setEntityGaussianStreaming(
    entityId: streamSplat,
    source: .progressive(
        baseFilename: "chair",
        levelCount: 4,
        maxDistances: [5.0, 15.0, 25.0, .greatestFiniteMagnitude]
    ),
    options: GaussianStreamingOptions(
        streamingRadius: 30.0,
        unloadRadius: 45.0
    )
)
```

`.untoldgs` progressive tiers always have a baked header, so `boundingBoxHalfExtent` can be
omitted here the same way it can for `.single(...)` with a `.untoldgs` file.

### Putting it together: stream scene + streaming splat

`setEntityGaussianStreaming` needs the tile stubs `setEntityStreamScene` creates (see
[Prerequisites](#prerequisites) above), so the natural place to register streaming splat props
is inside the same completion handler that loads the streamed tile scene:

```swift
let sceneRoot = createEntity()
setEntityStreamScene(entityId: sceneRoot, manifest: "dungeon", withExtension: "json") { success in
    guard success else {
        setSceneReady(false)
        return
    }

    let splat = createEntity()
    translateTo(entityId: splat, position: simd_float3(2.0, 0.0, -4.0))
    rotateBy(entityId: splat, angle: 180.0, axis: simd_float3(1.0, 0.0, 0.0))

    setEntityGaussianStreaming(
        entityId: splat,
        source: .progressive(
            baseFilename: "pooltable",
            levelCount: 4,
            maxDistances: [15.0, 25.0, 35.0, .greatestFiniteMagnitude]
        ),
        options: GaussianStreamingOptions(
            streamingRadius: 100.0,
            unloadRadius: 140.0
        )
    )

    setSceneReady(true)
}
```

`boundingBoxHalfExtent` is omitted from `GaussianStreamingOptions` here since `pooltable` is a
`.untoldgs` progressive asset — its box comes from the baked header automatically (see
[API overview](#api-overview) above). Guarding on `success` before registering the splat and
calling `setSceneReady` matters: without it, a failed scene load would still try to attach a
streaming prop to tile stubs that were never created, and would report the scene ready when it
isn't.

---

## Which function should I use?

| Function | Resident/Streamed | LOD | Use when |
|---|---|---|---|
| `setEntityGaussian(entityId:filename:withExtension:)` | Resident, loads immediately (blocks) | None | A small number of splats that should always be visible (a hero object, a standalone demo scene). |
| `setEntityGaussian(entityId:source:)` | Resident | None (`.single`) or progressive (`.progressive`) | Same as above, plus a single call site that can also take `.progressive(...)` for coarse-to-fine refinement without a tile-streamed scene. |
| `setEntityGaussianAsync` | Resident, loads off-thread | None | Same as `setEntityGaussian`, but avoids a frame hitch on a large `.ply`. |
| `setEntityGaussianStreaming(source:options:)` | Streamed via `GeometryStreamingSystem` | None (`.single`) or progressive (`.progressive`) | Props scattered across a tile-streamed scene that should load/unload with camera distance. |

All progressive paths (`setEntityGaussian(source: .progressive(...))` and
`setEntityGaussianStreaming(source: .progressive(...), options:)`) share the same
[overdraw-aware LOD selection](#overdraw-aware-lod-selection) behavior automatically.
