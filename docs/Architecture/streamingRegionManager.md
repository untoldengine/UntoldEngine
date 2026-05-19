# StreamingRegionManager

`StreamingRegionManager` provides a lightweight, region-based geometry streaming API that is an alternative to the tile manifest system (`setEntityStreamScene`). Rather than consuming a JSON manifest, callers register explicit `StreamingRegion` values — each describing a world-space AABB and a list of asset references — and the manager loads or unloads them based on camera proximity.

Use this API for handcrafted or procedurally defined streaming zones where a manifest file is not practical. Use `setEntityStreamScene` for large outdoor/indoor scenes exported by the Blender pipeline.

---

## When to use which API

| Scenario | Preferred API |
|---|---|
| Large scene exported by the Blender pipeline (tiles, HLOD, LOD levels) | `setEntityStreamScene(entityId:url:)` |
| Handcrafted streaming zones (e.g. dungeon rooms, level sectors) | `StreamingRegionManager` |
| Always-resident objects (characters, props, HUD elements) | `setEntityMeshAsync(entityId:filename:withExtension:)` |

---

## Core Types

### `StreamingRegion`

```swift
public struct StreamingRegion: Identifiable {
    public let id: UUID
    public let bounds: AABB          // World-space AABB that triggers load/unload
    public let priority: Int         // Higher = loaded first when slots compete
    public let assets: [AssetReference]
    public var state: StreamingState
    public var loadedEntities: [EntityID]
    public var estimatedMemorySize: Int  // Bytes; used for memory budget gate
}
```

`AssetReference` names a single asset by filename and extension:

```swift
public struct AssetReference: Equatable, Hashable {
    public let filename: String
    public let fileExtension: String
}
```

### `StreamingState`

```
unloaded → loading → loaded → unloading → unloaded
```

| State | Meaning |
|---|---|
| `.unloaded` | No geometry loaded for this region |
| `.loading` | Async load task running |
| `.loaded` | All region assets are GPU-resident |
| `.unloading` | Teardown in progress |

---

## Configuration

```swift
StreamingRegionManager.shared.enabled = true
StreamingRegionManager.shared.streamingRadius = 100.0   // load within this distance
StreamingRegionManager.shared.unloadRadius = 150.0      // unload beyond this distance
StreamingRegionManager.shared.maxConcurrentLoads = 3    // max simultaneous loads
StreamingRegionManager.shared.checkInterval = 0.5       // seconds between evaluations
```

| Property | Default | Notes |
|---|---|---|
| `streamingRadius` | 100 m | Camera-to-AABB distance inside which the region loads |
| `unloadRadius` | 150 m | Camera-to-AABB distance beyond which the region unloads |
| `maxConcurrentLoads` | 3 | Hard cap on simultaneous region load tasks |
| `checkInterval` | 0.5 s | Tick rate; skips frames between evaluations |

These are shared global defaults. Per-region load distance is not currently configurable; all regions use the same radii. For per-region control, use `setEntityStreamScene` with a manifest.

---

## Usage

### Registering regions

```swift
let region = StreamingRegion(
    bounds: AABB(min: simd_float3(-50, 0, -50), max: simd_float3(50, 10, 50)),
    priority: 1,
    assets: [
        AssetReference(filename: "dungeon_room_A", withExtension: "untold"),
        AssetReference(filename: "dungeon_room_A_props", withExtension: "untold"),
    ],
    estimatedMemorySize: 40_000_000  // 40 MB estimate
)

StreamingRegionManager.shared.registerRegion(region)
```

### Updating each frame

```swift
// Call from your game loop:
StreamingRegionManager.shared.update(cameraPosition: cameraPos, deltaTime: dt)
```

`update()` throttles internally — real work only runs every `checkInterval` seconds.

### Removing regions

```swift
StreamingRegionManager.shared.unregisterRegion(id: region.id)
```

Unregistering cancels any in-flight load task immediately.

### Force load / unload (testing or cutscenes)

```swift
let didLoad = await StreamingRegionManager.shared.forceLoadRegion(id: region.id)
let didUnload = await StreamingRegionManager.shared.forceUnloadRegion(id: region.id)
```

---

## Per-frame Update Logic

Each tick (every `checkInterval` seconds):

1. **Find load candidates** — `.unloaded` regions whose AABB is within `streamingRadius` of the camera. Sorted by priority (descending) then distance (ascending).
2. **Find unload candidates** — `.loaded` regions whose AABB is beyond `unloadRadius`.
3. **Unload first** — frees memory before committing to new loads.
4. **Load up to `maxConcurrentLoads` candidates** — each spawns an async `Task`.

Distance is measured as the closest point on the region AABB to the camera position (AABB distance, not center distance), so an AABB that surrounds the camera has distance 0.

---

## Load Path

`loadRegion(id:)` (internal):

1. Marks region `.loading`.
2. Checks `MemoryBudgetManager.canAccept(sizeBytes:)`. If the budget is full, attempts `evictLRU` before proceeding; if still full, marks region `.unloaded` and returns.
3. For each `AssetReference` in `region.assets`:
   - Calls `createEntity()` + `setEntityMeshAsync(entityId:filename:withExtension:)`.
   - Registers memory with `MemoryBudgetManager` for the root entity and all children.
4. Marks region `.loaded`; records `loadedEntities`.
5. Emits `AssetResidencyChangedEvent(isResident: true)` for each entity (including children) so `BatchingSystem` and `LODSystem` see the new geometry.

---

## Unload Path

`unloadRegion(id:)` (internal):

1. Marks region `.unloading`.
2. Emits `AssetResidencyChangedEvent(isResident: false)` for all entities (children first) before destroying them — ensures `BatchingSystem` removes them from pending queues cleanly.
3. Calls `MemoryBudgetManager.unregisterMesh(entityId:)` for all entities.
4. Calls `destroyEntity(entityId:)` for each root (cascades to children).
5. Marks region `.unloaded`; clears `loadedEntities`.

---

## Stats

```swift
let stats = StreamingRegionManager.shared.getStats()
// stats.totalRegions, loadedRegions, loadingRegions, activeLoads
// stats.totalRootEntities, totalEntitiesWithChildren
// stats.regionMemory (actual GPU bytes from MemoryBudgetManager)
// stats.estimatedMemory (sum of user-supplied estimates)
// stats.totalEngineMemory (entire engine, from MemoryBudgetManager)
```

---

## Relationship to `GeometryStreamingSystem`

`StreamingRegionManager` is independent of `GeometryStreamingSystem`. It loads region assets through `setEntityMeshAsync`, so region assets are immediate/cache-backed `.untold` loads rather than tile-owned OCC stubs. It can run alongside a tile-streamed outdoor scene (`setEntityStreamScene`) with handcrafted interior sectors. Both systems share `MemoryBudgetManager`, so memory pressure from one is visible to the other.

`StreamingRegionManager` does **not** use the octree, frustum gating, prefetch radius, grace-period teardown, or HLOD/LOD systems. It is intentionally simpler. For any of those features, use `setEntityStreamScene` with a manifest.

---

## See Also

- [`tilebasedstreaming.md`](tilebasedstreaming.md) — tile lifecycle, manifest schema, HLOD, LOD bands
- [`geometryStreamingSystem.md`](geometryStreamingSystem.md) — mesh-level OCC streaming, memory pressure, eviction
- [`streamingCacheLifecycle.md`](streamingCacheLifecycle.md) — how GPU and CPU residency are managed across both systems
