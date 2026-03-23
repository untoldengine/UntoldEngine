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

### 1. Throttle Check
The system normally does real work every **0.1 seconds** (`updateInterval`). Between ticks, it's a no-op. This prevents wasting CPU every single frame.

When `lastPendingLoadBacklog > 0` (candidates are queued but all slots are busy), the effective interval drops to `burstTickInterval` (default 16 ms). This prevents a 100 ms stall between slot pickups during active loading. The tick rate returns to 100 ms once the backlog drains.

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

## Loading: Async, Concurrency-Limited

Load candidates are **sorted by priority then distance** (high priority + closest first). Only `maxConcurrentLoads = 3` can be active simultaneously.

Before dispatching, the scheduler applies three guards in order:

1. **CPU-entry readiness** — OOC entities whose `CPUMeshEntry` is not yet stored in `ProgressiveAssetLoader` are skipped. This prevents pre-streaming stubs from holding slots while registration is still running.
2. **Prewarm-active deferral** — entities for roots whose background texture prewarm is still running are skipped. Dispatching while the prewarm holds the per-asset texture lock would block all concurrent slots for the remaining prewarm duration. Slots stay free until `isPrewarmActive` returns `false`.
3. **Per-candidate geometry budget check** — if the candidate's estimated GPU footprint would exceed the geometry budget, `evictLRU` is called first.

When all near-band candidates share one `assetRootEntityId`, the near-band concurrency limit expands from `nearBandMaxConcurrentLoads` to `maxConcurrentLoads`. All sub-meshes of one USDZ are treated as a single burst rather than being serialized one-at-a-time.

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

## Memory Pressure: Texture Relief First, Geometry Eviction Last

The engine uses two independent memory pressure signals and responds to them in priority order:

| Pressure signal | Method | Meaning |
|---|---|---|
| Combined (mesh + texture) | `shouldEvict()` | Total GPU allocation ≥ 85% of `meshBudget` |
| Geometry only | `shouldEvictGeometry()` | Mesh allocations alone ≥ 85% of `meshBudget` |

**Why two signals?** `TextureStreamingSystem` upgrades visible textures to higher resolutions after meshes load. Those upgrades increase `totalTextureMemory` in `MemoryBudgetManager`. If the load gate used the combined signal, texture upgrades on already-loaded meshes would silently prevent new mesh loads — even when the geometry-only footprint is well within budget. The split ensures texture pressure cannot block geometry loading.

### Step 1 — Texture downgrade relief

Before considering geometry eviction, the system sheds texture quality on the farthest loaded entities:

```
if combined pressure is high AND geometry pressure is NOT high:
    TextureStreamingSystem.shedTextureMemory(maxEntities: 4)
    → no geometry eviction; texture relief only
```

`shedTextureMemory` forces the farthest entities in the `upgradedEntities` set to `minimumTextureDimension` immediately, bypassing the normal distance-band schedule. A distant wall dropping from 1024 px to 256 px is far less noticeable than a missing mesh.

### Step 2 — Geometry eviction (last resort)

Only triggered when geometry memory itself hits the high-water mark:

```
if geometry pressure is high:
    TextureStreamingSystem.shedTextureMemory(maxEntities: 8)   ← try texture relief first
    evictLRU(cameraPosition:)                                  ← then fall back to geometry eviction
```

`evictLRU`:
1. First evicts unused cached meshes (`MeshResourceManager.evictUnused()`)
2. Collects all loaded streaming entities
3. Sorts by value score (far + large = first to go; see value-score eviction in the out-of-core walkthrough)
4. Unloads them one by one until **geometry-only** pressure clears (loop breaks on `shouldEvictGeometry()`, not the combined signal)
5. Skips entities that are both visible and within `visibleEvictionProtectionRadius` (30 m default)

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
- **Adaptive tick rate** — 16 ms during backlog, 100 ms steady-state — prevents stalls between slot pickups without wasting CPU when idle
- **Single-root burst detection** — when all near-band candidates are sub-meshes of one asset, concurrency expands to the global cap so the asset loads in parallel rather than one mesh at a time
- **Background texture prewarm** — `loadTextures()` runs at registration time so the first-upload path is a no-op and lock wait ≈ 0
- **Prewarm-active deferral** — dispatch is held until the prewarm releases the texture lock, keeping all slots free for the burst
- **Narrowed texture lock scope** — the per-asset lock covers only `ensureTexturesLoaded`; `makeMeshesFromCPUBuffers` runs outside the lock so all slots upload in parallel
- **CPU-entry readiness guard** — stubs registered before their CPU data is ready are skipped rather than wasting a slot
- **Unload-before-load** ordering ensures you free memory before consuming more
- **Cache ownership** means unloading just clears references, actual GPU memory is reused if the same mesh comes back into range
- **Geometry-only load gate** prevents texture upgrades from blocking mesh loads — each domain is budgeted independently
- **Texture relief before geometry eviction** means a drop in distant texture resolution is always preferred over a missing mesh
