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

Parameters:

- entityId: The ID of the entity created earlier.
- filename: The name of the .ply file (without the extension).
- withExtension: The file extension, typically "ply".

> Note: The Gaussian System renders point cloud data stored in the .ply format. Ensure your Gaussian Splat file is properly formatted and contains the necessary attributes (position, color, opacity, scale, rotation).

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

For that case, use `setEntityGaussianStreamable` instead. It registers the entity with
`GeometryStreamingSystem`, which loads and unloads it automatically based on camera
distance — the same way it already handles the surrounding streamed tile geometry.

### Prerequisites

This only makes sense in a scene that is already using tile-based streaming — i.e. one
loaded with `setEntityStreamScene` (see [Using the Geometry Streaming System](UsingGeometryStreamingSystem.md)).
`setEntityGaussianStreamable` attaches the splat to whichever tile stub's bounds contain
the entity's position, so it needs those tile stubs to already exist. Call it **after**
`setEntityStreamScene`'s completion handler has fired — tile stubs are guaranteed to be
registered by then.

### Step 1: Create and position the entity

Position and orient the entity *before* registering it for streaming — the position at the
time you call `setEntityGaussianStreamable` is what determines which tile it gets attached
to.

```swift
let streamSplat = createEntity()
translateTo(entityId: streamSplat, position: simd_float3(2.0, 0.0, -4.0))
rotateTo(entityId: streamSplat, angle: 180.0, axis: simd_float3(1.0, 0.0, 0.0))
```

### Step 2: Register it for streaming

```swift
setEntityGaussianStreamable(
    entityId: streamSplat,
    filename: "chair",
    withExtension: "ply",
    streamingRadius: 30.0,
    unloadRadius: 45.0,
    boundingBoxHalfExtent: simd_float3(0.5, 0.8, 0.5)
)
```

Parameters:

- `entityId`: The entity created and positioned in Step 1.
- `filename` / `withExtension`: Same as `setEntityGaussian` — the `.ply` file to stream in
  once the camera is in range.
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

> Note: If no tile is found containing the entity's position, `setEntityGaussianStreamable`
> logs a warning and leaves the entity as a plain, non-streaming entity (no `StreamingComponent`
> is attached) — it will not crash, but it also will not load. Double-check the position
> against the streamed scene's tile bounds if this happens.

### Which function should I use?

- **`setEntityGaussian`** — load immediately, stays resident. Use for a small number of
  splats that should always be visible (e.g. a single hero object, a standalone demo scene).
- **`setEntityGaussianAsync`** — same immediate/resident behavior, but the parse and GPU
  upload happen off the main thread. Use for a one-off splat load where you don't want a
  frame hitch, but still don't need distance-based unloading.
- **`setEntityGaussianStreamable`** — registers the entity with `GeometryStreamingSystem`
  instead of loading anything itself. Use for splat props inside a large, tile-streamed
  scene, where you want the same load-when-near/unload-when-far behavior the rest of the
  scene already gets.

