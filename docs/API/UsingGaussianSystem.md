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
based on camera distance.

Generate tiers from a `.ply` source with the exporter:

```bash
untoldengine export --input "chair.ply" --output "chair.untoldgs" --lod-levels 4
```

Then register the entity with a progressive source:

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

### Debugging progressive LOD

Gaussian progressive LODs participate in the same LOD debug visualization used by mesh
LODs:

```swift
setSpatialDebug(.lodLevels(true))
```

When enabled, the renderer tints Gaussian splats by their currently selected progressive
LOD. This is useful for confirming that the engine is switching tiers as the camera moves.

---

### Running the Gaussian System

Once everything is set up:

1. Run the project.
2. Your Gaussian Splat model will appear in the game window.
3. If the model is not visible or appears incorrect, revisit the file path and format to ensure everything is loaded correctly.

---

## Streaming Gaussian Splats in Large Scenes

`setEntityGaussian` loads a splat immediately and keeps it resident for the lifetime of the
entity — fine for a small number of always-visible splats, but not what you want for props
scattered across a large tile-streamed scene (chairs, tables, decor inside a streamed
building). Loading every one of those up front defeats the point of streaming, and the
engine has no way to unload them again on its own.

For that case, use `setEntityGaussianStreaming` instead. It registers the entity with
`GeometryStreamingSystem`, which loads and unloads it automatically based on camera
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
    boundingBoxHalfExtent: simd_float3,
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
    source: .single(filename: "chair", withExtension: "ply"),
    options: GaussianStreamingOptions(
        streamingRadius: 30.0,
        unloadRadius: 45.0,
        boundingBoxHalfExtent: simd_float3(0.5, 0.8, 0.5)
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
- `boundingBoxHalfExtent`: A local-space half-extent for the entity, roughly matching the
  splat's real-world size. **This has no default and must be supplied.** Without a real
  bounding box, the streaming system's frustum gate collapses to a zero-extent point at
  the entity's exact position — the splat may load once but then fail to reliably
  re-stream in after the camera moves away and back, because re-entry depends on the
  camera looking at that exact point rather than anywhere near the prop.
- `priority`: Optional. Higher-priority entities load first when multiple candidates are
  in range at once. Defaults to `0`.

> Note: If no tile is found containing the entity's position, `setEntityGaussianStreaming`
> logs a warning and leaves the entity as a plain, non-streaming entity (no `StreamingComponent`
> is attached) — it will not crash, but it also will not load. Double-check the position
> against the streamed scene's tile bounds if this happens.

### Progressive Gaussian splat streaming

Use `.progressive(...)` with `setEntityGaussianStreaming` when you want tile-driven
load/unload behavior plus the same coarse-to-fine refinement described above.

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
        unloadRadius: 45.0,
        boundingBoxHalfExtent: simd_float3(0.5, 0.8, 0.5)
    )
)
```

### Which function should I use?

- **`setEntityGaussian`** — load immediately, stays resident. Use for a small number of
  splats that should always be visible (e.g. a single hero object, a standalone demo scene).
- **`setEntityGaussianAsync`** — same immediate/resident behavior, but the parse and GPU
  upload happen off the main thread. Use for a one-off splat load where you don't want a
  frame hitch, but still don't need distance-based unloading.
- **`setEntityGaussian(entityId:source:)`** — load an always-present Gaussian from either
  `.single(...)` or `.progressive(...)`. Use this when you want progressive refinement
  without tile-based scene streaming.
- **`setEntityGaussianStreaming`** — registers the entity with `GeometryStreamingSystem`
  instead of loading everything immediately. Use `.single(...)` for a whole-file streamed
  prop, or `.progressive(...)` for coarse-to-fine Gaussian tiers.
