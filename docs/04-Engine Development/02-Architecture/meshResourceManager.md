# MeshResourceManager

`MeshResourceManager` is a singleton that acts as the shared GPU memory layer for mesh assets. It caches entire USDZ files, tracks which entities use which meshes via reference counting, and evicts unused geometry under memory pressure.

---

## The Core Data Model

`MeshResourceManager` is a **singleton** (`shared`) that manages two key dictionaries:

```
resources:      URL -> MeshResource       (the cache — one entry per USDZ file)
entityToMesh:   EntityID -> (URL, name)   (which entity uses which mesh)
```

A `MeshResource` holds **all meshes** from a single USDZ file, keyed by asset name:

```
city_block_A.usdz  ->  MeshResource {
    meshesByName:    { "building_01": [...], "window_01": [...], "door_01": [...] }
    refCountByName:  { "building_01": 12, "window_01": 48, "door_01": 12 }
    totalMemorySize: 42_000_000   // bytes on GPU
    lastAccessFrame: 1042
}
```

---

## Phase 1 — Loading (First Request)

Say entity `e001` needs `"building_01"` from `city_block_A.usdz`:

```
loadMesh(url: city_block_A.usdz, meshName: "building_01")
```

**Step 1 — Cache check** (`getCachedMesh`): nothing cached yet → miss.

**Step 2 — Single-flight gate** (`waitForExistingLoadOrBecomeLoader`):
- First caller wins: it is designated the **loader** and gets `true`.
- If 10 other entities request the same file simultaneously, they all queue up as **waiters** inside `inFlightLoadWaiters[url]`. They suspend via `CheckedContinuation` — no busy-waiting.

**Step 3 — Parse & upload** (`Mesh.loadSceneMeshesAsync`):
- The entire USDZ is parsed once. Every mesh in the file is uploaded to GPU buffers.
- Result is a `[[Mesh]]` — one inner array per named asset.

**Step 4 — Build the dictionary and cache it**:
```swift
meshesByName["building_01"] = [mesh1, mesh2, ...]   // LODs or submeshes
meshesByName["window_01"]   = [mesh3, ...]
meshesByName["door_01"]     = [mesh4, ...]
totalMemorySize = 42 MB
```
This is stored in `resources[city_block_A.usdz]`.

**Step 5 — Wake waiters** (`finishInFlightLoad`):
- All 10 suspended callers are resumed with `false` (they don't load — file is already cached).
- Each then calls `getCachedMesh` and gets their mesh instantly.

---

## Phase 2 — Reference Counting (Entity Lifecycle)

When the streaming system decides entity `e001` will **render** `"building_01"`:

```swift
retain(url: city_block_A.usdz, meshName: "building_01", for: e001)
```

This:
1. Releases any previous mesh the entity held (safety cleanup).
2. Records `entityToMesh[e001] = (city_block_A.usdz, "building_01")`.
3. Increments `refCountByName["building_01"]` from 0 → 1.

After 500 entities are assigned across the city block:

```
refCountByName: { "building_01": 45, "window_01": 180, "streetlight": 60, ... }
totalRefCount = 500
isInUse = true   ← cannot be evicted
```

When an entity scrolls **out of view** and is culled:

```swift
release(entityId: e099)
```

This removes `entityToMesh[e099]` and decrements `refCountByName["building_01"]` from 45 → 44.

---

## Phase 3 — Eviction (Memory Pressure)

Three eviction strategies exist:

| Method | When to Use |
|---|---|
| `evict(url:)` | Force-remove one specific file (only if `refCount == 0`) |
| `evictUnused()` | Sweep all files with zero references |
| `evictToFreeMemory(targetBytes:)` | **LRU** — evict oldest-accessed files first until `targetBytes` freed |

For a city block, `evictToFreeMemory` is most useful. Say GPU budget is exceeded by 80 MB:

```
candidates = resources where totalRefCount == 0
           sorted by lastAccessFrame ascending  (oldest first)

Evict city_block_C.usdz  → frees 38 MB   (last seen frame 200)
Evict city_block_D.usdz  → frees 44 MB   (last seen frame 310)
Total freed: 82 MB ✓
```

For each evicted mesh, `mesh.cleanUp()` is called to free the Metal GPU buffers.

`lastAccessFrame` is updated every time a mesh is accessed (cache hit) or retained, so actively-used files naturally survive LRU pressure.

---

## Thread Safety

All state is protected by a **concurrent `DispatchQueue`** with the readers-writers pattern:
- Reads use `accessQueue.sync` — concurrent reads are fine.
- Writes use `accessQueue.sync(flags: .barrier)` — exclusive access, blocks concurrent reads.

This makes the manager safe to call from multiple streaming tasks loading different USDZ files in parallel.

---

## Summary Flow for 500-Mesh City Block

```
Frame 0: Scene starts loading
  → 5 USDZ files queued
  → Each file: one task becomes loader, others wait
  → All 5 files parsed, all meshes cached in GPU memory

Frame 1–N: Entities stream in/out of view
  → retain() as entities enter view frustum
  → release() as entities leave
  → refCounts track exactly how many entities use each mesh

Memory pressure detected:
  → evictToFreeMemory() walks LRU list
  → Only files with refCount==0 are eligible
  → GPU buffers freed via cleanUp()
  → Files still in view are untouched
```

The key insight: **one disk parse per USDZ file**, no matter how many entities share its meshes. Reference counting prevents premature eviction, and LRU ensures the least-recently-seen geometry is freed first under memory pressure.

---

## Callers

`MeshResourceManager` is used by three systems:

### GeometryStreamingSystem — Primary driver
Owns the full lifecycle:
- Updates `currentFrame` each tick to keep LRU timestamps fresh.
- Calls `loadMesh` + `retain` when an entity streams into view.
- Calls `release` when an entity streams out of view.
- Calls `evictUnused()` to free GPU memory.
- Reads `getStats()` for diagnostics and memory budgeting.

### RegistrationSystem — Cache pre-warmer
Calls `cacheLoadedMeshes(url:meshArrays:)` when entities are registered into the scene, so meshes are already in the cache before the streaming system requests them. Also calls `release` when entities are unregistered.

### UntoldEngine (Renderer) — Read-only monitoring
Reads `getStats()` only, likely for a debug overlay or performance HUD.
