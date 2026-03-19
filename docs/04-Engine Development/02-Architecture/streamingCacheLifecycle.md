# Streaming Cache Lifecycle

This document describes how `GeometryStreamingSystem` and `MeshResourceManager` interact across the full load/unload lifecycle of a city block scene with 500 buildings.

The clean division of responsibility: **`GeometryStreamingSystem` decides when**, **`MeshResourceManager` decides what's in memory**. The streaming system never touches GPU memory directly — it only calls `retain`, `release`, and `loadMesh` on the cache.

---

## The Setup

Each of the 500 buildings has a `StreamingComponent` attached. That component holds:
- `assetFilename` / `assetExtension` — points to the USDZ file
- `assetName` — the specific mesh name inside the file (e.g. `"building_42"`)
- `streamingRadius` — how close the camera must be to trigger a load
- `unloadRadius` — how far the camera must be to trigger an unload
- `state` — `.unloaded`, `.loading`, `.loaded`, or `.unloading`

`MeshResourceManager` knows nothing about distance or cameras. It is purely a **cache + reference counter**. `GeometryStreamingSystem` is the one that decides when to load and unload.

---

## Every Frame: `update(cameraPosition:deltaTime:)`

This is called once per frame from the engine loop. It does two things before any load/unload work:

```swift
currentFrame += 1
MeshResourceManager.shared.currentFrame = currentFrame
```

The frame number is pushed into `MeshResourceManager` so its LRU timestamps stay current. Without this, the cache would have no sense of time and couldn't decide which files are stale.

Updates are **throttled** — by default only run every 0.1 seconds to avoid doing spatial queries every frame.

---

## Step 1 — Spatial Query (Who needs loading?)

The system queries the **Octree** for all entities within `maxQueryRadius` (500m by default):

```swift
let nearbyEntities = OctreeSystem.shared.queryNear(point: effectiveCameraPosition, radius: maxQueryRadius)
```

For each nearby entity, it calculates the camera distance and bins it:

- **`.unloaded` + within `streamingRadius`** → goes into `loadCandidates`
- **`.loaded` + beyond `unloadRadius`** → goes into `unloadCandidates`

Entities already `.loading` or `.unloading` are skipped — they're in progress.

It also checks `loadedStreamingEntities` (a tracked set of currently-loaded entity IDs) for any loaded buildings that drifted **outside** the octree query radius, catching far-away stragglers the spatial query might miss.

---

## Step 2 — Unloads First

```swift
unloadCandidates.sort { lhs.1 > rhs.1 }  // farthest first
```

Unloads are processed before loads to free memory before consuming more. Up to `maxUnloadsPerUpdate` (12 by default) are processed per tick to avoid frame spikes.

Inside `unloadMesh(entityId:)`:

```swift
MeshResourceManager.shared.release(entityId: entityId)
render.mesh = []  // clear reference, GPU data stays in cache
```

The key detail: `render.mesh` is cleared but **`cleanUp()` is NOT called on the meshes**. The GPU buffers stay alive in `MeshResourceManager`'s cache. Only `release()` is called, which decrements the ref count for that mesh. So if 10 buildings all used `"building_type_A"` and 3 get unloaded, the ref count drops from 10 → 7 and the GPU data stays put.

The entity's state is set back to `.unloaded` and it's removed from `loadedStreamingEntities`.

---

## Step 3 — Loads (Up to `maxConcurrentLoads`)

```swift
loadCandidates.sort { /* high priority first, then closest */ }
let availableSlots = maxConcurrentLoads - activeLoadCountSnapshot()  // default: 3 concurrent
```

For each candidate within the slot budget, `loadMesh(entityId:)` is called. This:

1. Sets state to `.loading`
2. Notifies `BatchingSystem` that streaming started
3. Fires off an async `Task`

Inside that async task, `loadMeshAsync` runs:

```swift
guard let meshes = await MeshResourceManager.shared.loadMesh(url: url, meshName: meshName) else { ... }

MeshResourceManager.shared.retain(url: url, meshName: meshName, for: entityId)
```

**`loadMesh` is a cache-first call.** If `city_block.usdz` is already cached (because another building from the same file loaded first), this returns instantly — no disk I/O. If it's not cached, the single-flight gate ensures only one task parses the USDZ even if 50 buildings request it simultaneously.

After `retain`, the mesh data is **copied** for this entity:

```swift
var entityMeshes = meshes.map { $0.copyWithNewUniformBuffers() }
```

This is critical: the cached mesh is shared, but each entity needs its **own uniform buffers** (transform matrices, material data). Without this, 500 buildings would overwrite each other's render data every frame.

The mesh is assigned to the entity's `RenderComponent`, and the entity is registered with `MemoryBudgetManager`.

Back on the main thread (inside `withWorldMutationGate`), state is set to `.loaded` and the entity is added to `loadedStreamingEntities`.

---

## Step 4 — Memory Pressure Eviction

```swift
if MemoryBudgetManager.shared.shouldEvict() {
    evictedByLRU = evictLRU()
}
```

`evictLRU()` has two stages:

**Stage 1** — sweep the cache for zero-ref files:
```swift
MeshResourceManager.shared.evictUnused()
```
Any USDZ file with `totalRefCount == 0` has its GPU buffers freed immediately.

**Stage 2** — if memory pressure remains, walk loaded entities sorted by `lastVisibleFrame` (oldest first):
```swift
candidates.sort { $0.1 < $1.1 }  // oldest lastVisibleFrame first
```

For each candidate (skipping currently visible entities), `unloadMesh` is called, which decrements ref counts. Once a file's ref count hits zero it becomes eligible for `evictUnused` on the next pass.

---

## The Full Interaction Picture

```
GeometryStreamingSystem                    MeshResourceManager
─────────────────────────────────────────────────────────────────
update() every 0.1s
  │
  ├─ currentFrame++ ──────────────────────► currentFrame = N  (LRU clock)
  │
  ├─ Octree query → loadCandidates
  │
  ├─ For each unload candidate:
  │    unloadMesh()
  │      └─ release(entityId) ────────────► refCount["building_42"]--
  │         render.mesh = []               (GPU data stays in cache)
  │
  ├─ For each load candidate (≤3 concurrent):
  │    loadMesh() → async Task
  │      └─ loadMeshAsync()
  │           ├─ loadMesh(url, meshName) ──► cache hit? return instantly
  │           │                              cache miss? parse USDZ once,
  │           │                              wake all waiters
  │           ├─ retain(url, name, id) ────► refCount["building_42"]++
  │           │                              entityToMesh[e042] = (url, name)
  │           └─ mesh.copyWithNewUniformBuffers()
  │              → entity gets its own render buffers
  │
  └─ If memory pressure:
       evictLRU()
         ├─ evictUnused() ───────────────► free GPU buffers for refCount==0 files
         └─ unloadMesh() on oldest entities (same as above)
```
