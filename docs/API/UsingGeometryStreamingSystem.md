# Geometry Streaming System

UntoldEngine streams large worlds through a **manifest-driven tiled scene** pipeline.

The public rule is simple:

| Use case | API |
|---|---|
| Streamed world geometry (manifest-driven) | `setEntityStreamScene(entityId:manifest:withExtension:completion:)` |
| Handcrafted streaming zones (no manifest) | `StreamingRegionManager` — register `StreamingRegion` AABB + asset lists directly |
| Always-resident assets | `setEntityMeshAsync(entityId:filename:withExtension:completion:)` |

`GeometryStreamingSystem` manages the runtime once a streamed scene is loaded. It is not a public component-authoring workflow for standalone entities.

> For handcrafted zone streaming without a manifest (e.g. dungeon rooms, level sectors), use `StreamingRegionManager.shared`. See the [StreamingRegionManager architecture doc](../Architecture/streamingRegionManager.md) for the full API.

## Public Workflow

### Local manifest

```swift
let sceneRoot = createEntity()
setEntityName(entityId: sceneRoot, name: "city")

setEntityStreamScene(entityId: sceneRoot, manifest: "city", withExtension: "json") { success in
    setSceneReady(success)
}
```

### Remote manifest

```swift
let sceneRoot = createEntity()
setEntityName(entityId: sceneRoot, name: "city")

if let url = URL(string: "https://cdn.example.com/city/city.json") {
    setEntityStreamScene(entityId: sceneRoot, url: url) { success in
        setSceneReady(success)
    }
}
```

> **Legacy overloads** — `loadTiledScene(manifest:)` and `loadTiledScene(url:)` remain available for backwards compatibility. They create an internal root entity automatically. Prefer `setEntityStreamScene(entityId:...)` when you need a stable handle to the scene.

Remote manifests are downloaded and cached locally. Tile, HLOD, and per-tile LOD URLs are resolved relative to the manifest URL and fetched on demand.

## What Streams

The engine uses multiple geometry layers:

- **Full tile**: the main tile payload loaded by `loadTile()`. Tile assets use the `.untold` binary format, loaded by `UntoldReader` without ModelIO.
- **Per-tile LOD**: intermediate meshes shown while the full tile is still out of range
- **HLOD**: coarse far-distance proxy
- **OCC sub-mesh stubs**: fine-grained `StreamingComponent` entities created internally inside large tiles

`StreamingComponent` is internal to the tile-owned OCC path. External callers should not attach it manually or rely on `enableStreaming(...)`.

> **Known gap:** the public function `createStreamingEntity(filename:withExtension:streamingRadius:unloadRadius:priority:)` creates a standalone entity with a `StreamingComponent` but no `TileComponent` ancestor. Since the streaming update pass requires tile ownership (see below), entities created this way are never actually loaded by the normal streaming tick. Don't use it — prefer `setEntityMeshAsync` or `setEntityStreamScene`.

## Manifest Fields That Matter

These are the important fields for geometry streaming:

| Field | Meaning |
|---|---|
| `streaming_radius` | Full tile display zone |
| `unload_radius` | Tile teardown threshold |
| `prefetch_radius` | Background parse threshold before the tile becomes visible |
| `priority` | Tile load ordering when many tiles compete |
| `hlod_levels` | Optional far proxy meshes |
| `lod_levels` | Optional per-tile intermediate LOD meshes |
| `file_size_bytes` | Parse-budget hint used by the runtime gate |

If `prefetch_radius` is omitted, the engine computes it automatically from the gap between `streaming_radius` and `unload_radius`.

## Runtime Behavior

Each update tick, `GeometryStreamingSystem`:

1. Queries the octree within `maxQueryRadius`.
2. Chooses tile parse candidates using predictive camera motion, frustum gating, floor/interior gates, screen-space importance, and loaded-tile occlusion weighting.
3. Parses up to `maxConcurrentTileLoads` tiles, subject to `tileParseMemoryBudgetMB`.
4. Streams OCC child meshes inside loaded tiles using `maxConcurrentLoads`.
5. Unloads tiles, LODs, HLODs, and OCC meshes when they leave range or memory pressure requires eviction.

Important defaults:

- `maxConcurrentTileLoads = 2`
- `maxConcurrentLoads = 3`
- `maxConcurrentLODLoads = 4`
- `maxConcurrentHLODLoads = 4`
- `updateInterval = 0.1`
- `burstTickInterval = 0.016`
- `floorProximityGateY = 5.0`
- `minimumParsedTileResidentSeconds = 8.0`

## Useful Runtime Knobs

```swift
// Tile concurrency
setGeometryStreaming(.tileConcurrency(2))
setGeometryStreaming(.meshConcurrency(3))
setGeometryStreaming(.lodConcurrency(4))
setGeometryStreaming(.hlodConcurrency(4))

// Frustum gate
setGeometryStreaming(.frustumGate(.enabled(
    meshPadding: 5.0,
    tilePadding: 20.0
)))

// Spatial query
setGeometryStreaming(.queryRadius(500.0)) // must cover farthest unload_radius

// Velocity predictor (predictive tile loading)
setGeometryStreaming(.velocityLookAhead(time: 0.5, minSpeed: 1.5))

// Interior zone gating (v4 quadtree-floor manifests)
// Tiles tagged interior=true only load when the camera is inside this AABB.
// Set automatically from the manifest; override if needed:
setGeometryStreaming(.interiorZone(AABB(
    min: simd_float3(-10, 0, -10),
    max: simd_float3(10, 5, 10)
)))

// Floor-aware gating for v4 quadtree-floor manifests.
// Interior tiles with floor metadata only dispatch when their Y center is near the camera.
setGeometryStreaming(.floorProximityGateY(5.0))

// Tile candidate ordering
setGeometryStreaming(.candidateSorting(importance: true, occlusion: true))

// Tile unload stability
setGeometryStreaming(.minimumParsedTileResidentSeconds(8.0))

// Parse safety
setGeometryStreaming(.timeouts(tileParse: 60.0, meshLoad: 60.0))
```

Use `maxQueryRadius` large enough to cover the farthest `unload_radius` in the scene, or out-of-range tiles may not be discovered for teardown.

## Session Transitions — `forceUnloadAllParsedTiles()`

```swift
GeometryStreamingSystem.shared.forceUnloadAllParsedTiles()
```

This call immediately unloads every `.parsed` tile and all resident HLOD and LOD representations, bypassing the 3-second grace period and the 2-per-tick unload cap. It runs synchronously on the main thread: for each tile it destroys the mesh-root child entity and all its descendants via `unloadTile()`, calls `finalizePendingDestroys()`, and unregisters the GPU allocation from `MemoryBudgetManager`. When it returns, `shouldEvictGeometry()` reflects the freed memory.

### Why you need it

Full-load tile GPU memory is tracked by `MemoryBudgetManager` but is **not** in `loadedStreamingEntities` — the set that `evictLRU` targets. If you start a new tile-loading session while old tiles are still resident, this sequence locks the load loop:

1. `shouldEvictGeometry()` is `true` — old tiles still occupy the budget.
2. `evictLRU` runs and frees nothing (wrong entity set).
3. `guard !shouldEvictGeometry() else { break }` fires every tick.
4. No new tiles load. The scene freezes until the slow distance-based unload completes (3-second grace period × 2-per-tick cap = **10+ seconds** for a large scene).

### When to call it

Call `forceUnloadAllParsedTiles()` whenever you are about to start a new tile-loading session while tiles from a previous one may still be in GPU memory. The two common cases are:

**1. Switching between full-scale and calibration/inspection mode**

When a user scales the scene down to inspect or reposition it (e.g. a miniature placement workflow), the previous full-scale session's tiles must be freed before they switch back to full scale:

```swift
// Entering calibration — free the previous full-scale session's memory.
GeometryStreamingSystem.shared.forceUnloadAllParsedTiles()
scaleSceneTo(calibrationScale)
translateSceneTo(position: placementTarget)
```

Without this call, every calibration → full-scale cycle leaves more tiles in memory. After a few cycles the memory budget is exhausted, `shouldEvictGeometry()` permanently breaks the load loop, and the scene freezes.

**2. Switching directly from one tiled scene to another**

When the user cancels a scene mid-load and immediately loads a different one, tiles from the first scene may be partially or fully parsed:

```swift
// User tapped "wrong scene" and is loading a different one.
GeometryStreamingSystem.shared.forceUnloadAllParsedTiles()
destroyEntity(entityId: oldSceneRoot)
setEntityStreamScene(entityId: newSceneRoot, manifest: "correct_scene") { ... }
```

This guarantees the memory budget is clean before the new scene's first streaming tick runs. Without it there is a race between `finalizePendingDestroys()` (which frees GPU memory when the old root entity is torn down) and the streaming tick that checks `shouldEvictGeometry()` — the tick can fire before the destroy finalizes, blocking early tile loads in the new scene.

### When NOT to call it

- **Normal camera movement and room transitions** — the distance-based unload pass handles these with appropriate hysteresis. Calling `forceUnloadAllParsedTiles()` here would discard tiles the user is about to need.
- **Returning to a menu with no subsequent tile loading** — `destroyEntity` on the scene root cascades through all tile stubs; their component cleanup (`removeTileComponent`) cancels in-flight tasks and removes them from tracking sets. No explicit unload is needed.

The rule of thumb: **call it whenever you know a new tile-streaming session is about to start and you cannot guarantee the previous session has already finished unloading.**

## Interaction with Other Systems

- **Texture streaming**: `setEntityStreamScene(...)` automatically aligns texture distance bands to the manifest radii.
- **Batching**: full-load tiles, per-tile LODs, and HLODs notify `BatchingSystem` automatically. OCC sub-mesh uploads join batching incrementally through normal residency events.
- **Memory pressure**: texture quality is shed first; geometry eviction follows only when geometry pressure remains high.
- **Tile geometry eviction**: if OCC eviction cannot clear geometry pressure, the system can evict full-load tiles, HLODs, and per-tile LODs through `evictTileGeometry`, while protecting tiles inside their own `streamingRadius` and respecting the parsed-tile minimum dwell.

## Common Problems

### Tiles pop in on camera rotation

- Increase `setGeometryStreaming(.frustumGate(.enabled(meshPadding:tilePadding:)))` tile padding
- Keep the frustum gate enabled

### Tiles unload and reload too aggressively

- Increase the gap between `streaming_radius` and `unload_radius`
- Increase or explicitly author `prefetch_radius`

### Tile parse bursts spike memory

- Lower `setGeometryStreaming(.tileConcurrency(...))`
- Reduce per-tile file sizes in the exported manifest

### Streaming does nothing

- Verify you loaded the scene through `setEntityStreamScene(...)`
- Verify the manifest radii are reasonable for your scene scale
- Do not expect standalone `StreamingComponent` entities to stream; tile ownership is enforced

## Related Docs

- [Tile-Based Streaming](../Architecture/tilebasedstreaming.md)
- [Geometry Streaming Architecture](../Architecture/geometryStreamingSystem.md)
- [Texture Streaming](../Architecture/textureStreamingSystem.md)
- [Remote Asset Streaming](../Architecture/asset_remote_streaming.md)
