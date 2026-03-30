---
id: geometrystreaminggsystem
title: Geometry Streaming System
sidebar_position: 13
---

# Geometry Streaming System

The Geometry Streaming System dynamically loads and unloads geometry based on the camera's proximity to objects. This system is essential for large-scale scenes where loading all geometry at once would exceed available memory or cause performance issues.

## How It Works

The streaming system monitors the distance between the camera and entities that have streaming enabled. Based on configurable radius values, the system automatically:

1. **Loads geometry** when the camera moves within the streaming radius
2. **Keeps geometry loaded** while the camera remains between the streaming and unload radii
3. **Unloads geometry** when the camera moves beyond the unload radius

This creates a "bubble" of loaded geometry around the camera that moves with it through the scene.

## When to Use Geometry Streaming

**Ideal for:**
- Large open-world environments with distant objects
- Scenes where not all objects are visible simultaneously
- Memory-constrained scenarios
- Games with large view distances (forests, cities, landscapes)

**Not recommended for:**
- Small scenes where all objects fit comfortably in memory
- Objects that are always visible
- Dynamic objects that move frequently
- Critical gameplay objects that must always be loaded

## Basic Usage

### Immediate-path assets (small files, `streamingPolicy: .immediate`)

When the engine uses the immediate path, all meshes are GPU-resident by the time the completion fires. Call `enableStreaming` inside the callback to attach streaming radii for distance-based load/unload management:

```swift
private func setupStreaming() {
    let stadium = createEntity()
    setEntityMeshAsync(entityId: stadium, filename: "stadium", withExtension: "usdz") { isOutOfCore in
        guard !isOutOfCore else { return }  // handled below

        print("Scene loaded — enabling streaming")
        enableStreaming(
            entityId: stadium,
            streamingRadius: 250.0,
            unloadRadius: 350.0,
            priority: 10
        )
        GeometryStreamingSystem.shared.enabled = true
    }
}
```

### Out-of-core assets (large files, many objects, or `streamingPolicy: .outOfCore`)

Large assets are registered as stub entities with no GPU allocation. The completion callback fires with `isOutOfCore: true` as soon as all stubs are registered — before any GPU work occurs. You **must** enable `GeometryStreamingSystem` for anything to render:

```swift
private func setupLargeAssetStreaming() {
    let city = createEntity()
    setEntityMeshAsync(
        entityId: city,
        filename: "city_block",
        withExtension: "usdz"
    ) { isOutOfCore in
        if isOutOfCore {
            // Enable the streaming system — stubs start uploading as camera approaches.
            GeometryStreamingSystem.shared.enabled = true
            // Set real streaming radii (replaces the internal Float.greatestFiniteMagnitude placeholders).
            enableStreaming(
                entityId: city,
                streamingRadius: 200.0,
                unloadRadius: 350.0,
                priority: 10
            )
        }
    }
}
```

The engine automatically routes assets to the out-of-core path when they exceed the size threshold (default 50 MB) or object-count threshold (default 50 objects). Use `streamingPolicy: .outOfCore` to force the path regardless of file size.

### Important Notes

1. **Load mesh first**: Always call `setEntityMeshAsync()` before enabling streaming
2. **Use the completion Bool**: `true` = out-of-core stubs registered; `false` = immediate path (already GPU-resident)
3. **Enable the system and call `enableStreaming`**: Both are required for out-of-core assets. `GeometryStreamingSystem.shared.enabled = true` starts the upload loop; `enableStreaming(entityId: root, ...)` propagates real streaming radii to all child stubs so distance-based load/unload works correctly
4. **Async loading**: The `setEntityMeshAsync()` function loads the mesh asynchronously, preventing frame drops

## Parameters Explained

### `streamingRadius`
The distance from the camera at which geometry will be loaded.
- Objects closer than this distance will have their geometry loaded
- Should be set based on your camera's view distance and scene requirements
- **Typical values**: 100-500 units depending on object size and importance

### `unloadRadius`
The distance from the camera at which geometry will be unloaded.
- Must be **larger** than `streamingRadius` to create a buffer zone
- Prevents "thrashing" (rapid loading/unloading as camera moves near the boundary)
- **Recommended**: At least 50-100 units larger than `streamingRadius`

### `priority`
Determines the loading order when multiple objects need to be streamed.
- Higher values = loaded first
- Lower values = loaded last
- **Range**: Typically 1-10, but can be any positive integer
- **Usage**:
  - High priority (8-10): Important landmarks, gameplay-critical objects
  - Medium priority (4-7): Standard environment objects
  - Low priority (1-3): Background details, distant decorations

## Radius Configuration Guidelines

Choosing the right radius values is crucial for optimal performance:

```
Camera Position
    |
    |<-- streamingRadius (250) -->|<-- buffer zone -->|<-- unloadRadius (350) -->|
    |
    |    Geometry LOADS here      |  Stays loaded    |  Geometry UNLOADS here
```

### Example Configurations

**Small objects (trees, props):**
- `streamingRadius`: 150-250 units
- `unloadRadius`: 250-350 units
- Buffer: 100 units

**Medium objects (buildings, vehicles):**
- `streamingRadius`: 250-400 units  
- `unloadRadius`: 400-550 units
- Buffer: 150 units

**Large objects (stadiums, mountains):**
- `streamingRadius`: 500-1000 units
- `unloadRadius`: 700-1300 units
- Buffer: 200-300 units

## Combining with Other Systems

Geometry streaming works seamlessly with LOD and Batching systems:

- **LOD + Streaming**: Use LOD for quality management and streaming for memory management
- **Batching + Streaming**: Batches are automatically updated as geometry loads/unloads
- **All three together**: Optimal for large open-world scenes

See the [Combining LOD, Batching, and Streaming](./UsingLOD-Batching-Streaming.md) guide for detailed examples.

## Best Practices

1. **Test radius values**: Start conservative and adjust based on performance metrics
2. **Monitor memory**: Use profiling tools to ensure streaming is reducing memory usage
3. **Priority assignment**: Reserve high priorities for gameplay-critical objects
4. **Buffer zones**: Always maintain adequate buffer between streaming and unload radii
5. **Camera speed**: Faster-moving cameras may need larger streaming radii to prevent pop-in
6. **Position before streaming**: Set entity transforms before enabling streaming

## Tiled Scene Loading (`loadTiledScene`)

For scenes too large to parse as a single USDZ, use `loadTiledScene()`. It reads a JSON manifest describing a grid of small USDC tile files, registers a lightweight stub entity per tile, and lets `GeometryStreamingSystem` load and unload individual tiles as the camera moves through the scene.

### When to use it vs `loadScene`

| | `loadScene` | `loadTiledScene` |
|---|---|---|
| Scene size | Up to ~300 MB | Any size |
| File format | Single USDZ | Many USDC tiles + JSON manifest |
| Streaming unit | Individual mesh entities | Entire tile files |
| Setup cost | Parses the full file upfront | Near-zero (manifest JSON only) |
| Batching | Supported | Not currently supported |

### Manifest Format

The manifest is a JSON file generated by your DCC tool (e.g., a Blender export script):

```json
{
  "version": 1,
  "streaming_defaults": {
    "streaming_radius": 80.0,
    "unload_radius": 120.0,
    "priority": 10
  },
  "tiles": [
    {
      "tile_id": "tile_0_0",
      "path_relative_to_manifest": "tile_export/tile_0_0.usdc",
      "file_size_bytes": 15728640,
      "bounds": {
        "min": [-50.0, -10.0, -50.0],
        "max": [50.0,  40.0,  50.0]
      },
      "center": [0.0, 15.0, 0.0],
      "object_count": 12
    }
  ]
}
```

`path_relative_to_manifest` is always relative to the manifest file's location. Any absolute `path` field present in the JSON is ignored — this keeps manifests portable across machines and app bundles.

Per-tile `streaming_radius`, `unload_radius`, and `priority` are optional; omitting them falls back to `streaming_defaults`.

### File Layout

Place the manifest at `GameData/Models/{name}/{name}.json` so `LoadingSystem` can find it via the standard structured search path, and put tiles in a subfolder alongside it:

```
GameData/
  Models/
    city/
      city.json           ← manifest
      tile_export/
        tile_0_0.usdc
        tile_1_0.usdc
        …
```

### Basic Usage

```swift
loadTiledScene(manifest: "city") { success in
    setSceneReady(success)
}
```

No streaming flags are needed — tile streaming is always active. The scene's default camera and directional light are created automatically (same as `loadScene`).

### Frustum Gate

The system skips tiles whose world AABB is entirely outside the camera frustum before queuing them for loading. This prevents parsing tiles behind the camera.

Two frustums are built once per tick — one for mesh-level candidates and one for tile-level candidates, each with a different padding:

```swift
// Mesh-level OOC candidates: 5 m pad (default)
GeometryStreamingSystem.shared.frustumGatePadding = 5.0

// Tile-level candidates: 20 m pad (default)
// Wider because a single tile pop-in covers an entire building or scene section,
// which is far more jarring than a missing mesh stub.
// Increase if tiles pop in during fast rotation; decrease for small indoor tiles.
GeometryStreamingSystem.shared.tileFrustumGatePadding = 20.0

// Disable entirely for 360° scenes (e.g. panoramas)
GeometryStreamingSystem.shared.enableFrustumGate = false
```

Unloading is never gated — turning away from a loaded tile does not trigger eviction.

### Concurrency

Tile loads are serialised to `maxConcurrentTileLoads` (default 1). Each tile load parses an entire USDC file into CPU heap, so simultaneous parses on large tiles can spike RAM:

```swift
// Increase only for small tiles (< 5 MB each) with confirmed RAM headroom
GeometryStreamingSystem.shared.maxConcurrentTileLoads = 2
```

### Tile Sizing Guidelines

Tile size set in your DCC tool directly affects streaming behaviour. The tile grid must be scaled appropriately for the scene and typical object sizes:

| Tile footprint | Objects per tile | Effect |
|---|---|---|
| Too small (< 5 units) | 1–2 | Excessive tile count, high overhead |
| Good (50–200 units) | 10–50 | Smooth streaming, bounded RAM |
| Too large (> 500 units) | 100+ | Single-tile RAM spike, frame shaking |

**Common mistake**: setting a 10×10 tile grid on a 1 600-unit scene. With `assignment_mode: center`, large objects spanning hundreds of units are assigned to a single tile by their center coordinate — a few tiles accumulate most of the scene's geometry and produce multi-hundred-MB files that cause RAM spikes when loaded. Match tile size to the typical *object* size in your scene, not the overall scene extent.

---

## Common Issues

### Objects Not Loading
- **Out-of-core assets**: Confirm `GeometryStreamingSystem.shared.enabled = true` is set after load — stubs never upload if the system is disabled
- Ensure `streamingRadius` is large enough for your camera's viewing distance
- Check that the completion callback received `isOutOfCore: true` (out-of-core) or `false` (immediate) and handled each case
- Verify the entity has been positioned in the scene
- After loading a second asset, re-enable the streaming system if you disabled it before loading (setting `enabled = false` does not re-enable automatically)

### Geometry "Popping" In and Out
- Increase the buffer between `streamingRadius` and `unloadRadius`
- For tile-level pop-in specifically, increase `tileFrustumGatePadding` (default 20 m) so tiles are queued for loading earlier during rotation
- Consider using LOD to smooth transitions
- Adjust camera movement speed or increase radii

### Tile-Based Scene: Model Disappears Entirely
This is usually caused by one of two things:

1. **Frustum gate rejecting all tiles** — if `SceneRootTransform` applies an offset that shifts the camera into a different coordinate space than the tile AABBs, every tile can appear outside the frustum. Temporarily set `enableFrustumGate = false` to confirm; if tiles appear, adjust your scene root transform.

2. **Memory pressure evicting before tiles load** — if geometry budget is exhausted, new tile parses are blocked and existing tiles are evicted. Check `MemoryBudgetManager` logs for `shouldEvictGeometry()` returning `true` on every tick.

### Ghost Geometry After Fast Movement or Teleport
If a tile briefly appears far away after a camera jump, a parse was already in flight when the camera moved. The `loadingTileEntities` out-of-range check cancels these automatically, but there is a one-tick window. If this is still visible, increase `unloadRadius` to give tiles a larger buffer before cancellation is triggered.

### Performance Issues
- Too many objects loading simultaneously: Adjust priorities to stagger loading
- Streaming radius too large: Reduce radius to load fewer objects
- Use LOD to reduce complexity of loaded geometry
