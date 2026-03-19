# GeometryStreamingSystem

## The Setup: City Block as Streaming Entities

Imagine your city block USDZ is broken into many individually registered entities — `building_A`, `building_B`, `streetlamp_01`, `car_01`, etc. Each has a `StreamingComponent` that stores:

- `assetFilename` / `assetExtension` — where the mesh lives on disk
- `streamingRadius` — how close the camera must be to **load** it
- `unloadRadius` — how far before it gets **unloaded**
- `priority` — which buildings load first when slots are contested
- `state` — `.unloaded`, `.loading`, `.loaded`, or `.unloading`

---

## Every Frame: `update(cameraPosition:deltaTime:)`

The engine calls this every frame. Here's what happens:

### 1. Throttle Check (line 107)
The system only does real work every **0.1 seconds** (`updateInterval`). Between ticks, it's a no-op. This prevents wasting CPU every single frame.

### 2. Spatial Query via Octree (line 123)
Instead of checking all 500 city entities, it asks the `OctreeSystem`:
> "Give me every entity within 500m of the camera."

This is the key performance trick — only nearby entities are evaluated.

### 3. Classify Each Nearby Entity (lines 129–157)

For each entity the octree returns, the system calculates the **distance from camera to the entity's bounding box center**, then:

| State | Condition | Action |
|---|---|---|
| `.unloaded` | distance ≤ `streamingRadius` | → add to **load candidates** |
| `.loaded` | distance > `unloadRadius` | → add to **unload candidates** |
| `.loaded` | still in range | → stamp `lastVisibleFrame` (keep alive) |
| `.loading` / `.unloading` | — | skip, already in progress |

### 4. Out-of-Range Loaded Entities (lines 164–183)
The octree query only covers nearby space. But what if `building_Z` was loaded and the player sprinted far away — it might not be in the octree result anymore. So the system also checks its `loadedStreamingEntities` tracking set for any loaded entity **not** in the octree result, and adds those to unload candidates if they're too far.

---

## Unloading First: Free Memory Before Loading New Things (lines 191–197)

Unload candidates are **sorted farthest-first** (most wasteful memory first). Up to `maxUnloadsPerUpdate = 12` are processed per tick to avoid frame spikes.

`unloadMesh()` does:
1. Sets state → `.unloading`
2. Notifies `BatchingSystem` the entity is retiring
3. Cancels any in-flight load task
4. Calls `MeshResourceManager.shared.release(entityId:)` — decrements reference count on the cached mesh
5. Clears `render.mesh = []` — the GPU buffers are **not destroyed** (cache still owns them)
6. Clears LOD level meshes if applicable
7. Unregisters from `MemoryBudgetManager`
8. Sets state → `.unloaded`
9. Fires an `AssetResidencyChangedEvent(isResident: false)`

---

## Loading: Async, Concurrency-Limited (lines 200–214)

Load candidates are **sorted by priority then distance** (high priority + closest first). Only `maxConcurrentLoads = 3` can be active simultaneously.

`loadMesh()` does:
1. Reserves a slot in `activeLoads` (thread-safe via `NSLock`)
2. Sets state → `.loading`
3. Notifies `BatchingSystem` streaming started
4. Spawns a Swift `Task` (runs off the main thread)

Inside the async task:
- If the entity has a `LODComponent` → calls `reloadLODEntity()` which loads all LOD levels
- Otherwise → calls `loadMeshAsync()` which goes to `MeshResourceManager` (cache-first, file fallback)
- After loading, back on the main thread via `withWorldMutationGate`:
  - Assigns `render.mesh` with fresh copies of uniform buffers (critical — prevents entities sharing GPU state from overwriting each other)
  - Sets state → `.loaded`
  - Fires `AssetResidencyChangedEvent(isResident: true)`
  - Records load in `MemoryBudgetManager`

---

## LOD Path: `reloadLODEntity()` (lines 313–415)

For LOD entities (e.g., a skyscraper with 3 detail levels), it:
1. Loads **all LOD levels** concurrently from cache/disk
2. Calculates current camera-to-entity distance
3. Picks the appropriate LOD level (highest detail that fits distance)
4. Sets `renderComponent.mesh` to that LOD's mesh data
5. Marks `lodComponent.currentLOD`

---

## Memory Pressure: LRU Eviction (lines 544–587)

After each update tick, if `MemoryBudgetManager.shared.shouldEvict()` returns true:
1. First evicts unused cached meshes (`MeshResourceManager.evictUnused()`)
2. Collects all loaded streaming entities
3. Sorts by `lastVisibleFrame` — **oldest seen = first to go**
4. Unloads them one by one until memory pressure is relieved
5. Skips any entity currently in `visibleEntityIds` (on screen right now)

---

## City Block Scenario: Summary Flow

```
Player spawns at corner of city block
│
├─ Frame 1 tick: Octree finds 8 nearby buildings
│   ├─ 5 are unloaded + within streamingRadius → load candidates
│   └─ 3 are loading already → skip
│
├─ Up to 3 async loads fire simultaneously
│   ├─ building_A: cache miss → read from USDZ file
│   ├─ building_B: cache hit → instant
│   └─ building_C: cache miss → read from USDZ file
│
├─ Player walks forward → building_K enters range
│   └─ Queued in load candidates (backlog until a slot frees)
│
├─ Player runs past old buildings → building_A now > unloadRadius
│   └─ render.mesh cleared, reference released, memory freed
│
└─ Memory pressure → LRU eviction kicks in
    └─ building_E (not visible, oldest lastVisibleFrame) → evicted
```

The key design decisions here are:
- **Octree spatial query** prevents O(n) entity iteration every tick
- **Concurrency cap (3)** prevents GPU/IO saturation during fast movement
- **Unload-before-load** ordering ensures you free memory before consuming more
- **Cache ownership** means unloading just clears references, actual GPU memory is reused if the same mesh comes back into range
