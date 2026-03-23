# Progressive Asset Loader

## TL;DR

`ProgressiveAssetLoader` is a **CPU registry** — its sole responsibility is storing `CPUMeshEntry` records for out-of-core stub entities and serving them to `GeometryStreamingSystem` on demand.

> **Note:** This document describes the current architecture. The earlier tick-based progressive loader (per-frame job queue, `PendingObjectItem`, `enqueue(job)`, `tick()` processing N meshes per frame) was replaced by the out-of-core stub system. `tick()` is retained as a no-op for call-site compatibility only.

---

## What It Stores

When `setEntityMeshAsync` routes an asset through the out-of-core path it stores CPU-side geometry in one of two registries depending on whether the asset contains LOD groups:

- **`cpuMeshRegistry`** (`[EntityID: CPUMeshEntry]`) — one entry per stub entity (regular OOC assets)
- **`cpuLODRegistry`** (`[EntityID: [Int: CPUMeshEntry]]`) — one entry per LOD level per LOD group entity (LOD+OOC assets)

Both registries store `CPUMeshEntry` records:

```swift
struct CPUMeshEntry {
    let object: MDLObject           // MDLMesh with CPU-heap vertex/index data
    let vertexDescriptor: MDLVertexDescriptor
    let textureLoader: TextureLoader
    let device: MTLDevice
    let url: URL
    let filename: String
    let withExtension: String
    let uniqueAssetName: String     // "Hull_A#42" — stable across load cycles
    let estimatedGPUBytes: Int      // vertex + index bytes; used for pre-emptive budget reservation
}
```

Entries are keyed by child entity ID. `GeometryStreamingSystem` retrieves them via `retrieveCPUMesh(for:)` when an entity enters streaming range, copies the MDL buffers into Metal-backed buffers, and registers a `RenderComponent`. The CPU entry is **never removed on unload** — re-approaching an evicted entity re-uploads from RAM with no disk I/O.

### LOD CPU Registry (LOD+OOC Path)

When a USDZ asset contains LOD groups (top-level objects named `Tree_LOD0`, `Tree_LOD1`, etc.) and qualifies for OOC streaming, `setEntityMeshAsync` takes the **LOD+OOC path** instead of the per-stub path:

- One entity is created per LOD group (instead of one entity per MDLObject)
- Each entity gets a `LODComponent` with stub `LODLevel`s — empty mesh arrays, `residencyState: .notResident`
- One `CPUMeshEntry` is stored in `cpuLODRegistry[groupEntityId][lodIndex]` for each LOD level

```swift
// LOD+OOC: per-level CPU entries, keyed by (group entity ID, LOD index)
cpuLODRegistry[treeEntityId] = [
    0: CPUMeshEntry(object: tree_LOD0_MDLObject, uniqueAssetName: "Tree_LOD0", ...),
    1: CPUMeshEntry(object: tree_LOD1_MDLObject, uniqueAssetName: "Tree_LOD1", ...),
    2: CPUMeshEntry(object: tree_LOD2_MDLObject, uniqueAssetName: "Tree_LOD2", ...),
]
```

`GeometryStreamingSystem` detects the LOD+OOC path via `hasCPULODData(for:)` and calls `uploadActiveLODFromCPU` instead of `uploadFromCPUEntry`. This uploads **all** LOD levels from the CPU registry in one pass, then sets the render component to the level appropriate for the current camera distance. Subsequent LOD switches are handled by `LODSystem` which swaps `renderComponent.mesh` from the already-resident `lodComponent.lodLevels` array — no additional streaming needed until the entity is evicted and re-enters range.

---

## The MDLAsset Lifetime Problem

`MDLMeshBufferDataAllocator` (used by `parseAssetAsync`) backs all CPU buffers via the `MDLAsset` container. If the asset is released, all child MDLMesh CPU pointers become dangling.

`ProgressiveAssetLoader` solves this with `rootAssetRefs`:

```swift
private var rootAssetRefs: [EntityID: MDLAsset] = [:]
```

`storeAsset(_:for:)` pins the `MDLAsset` to the root entity ID. It stays alive until `removeOutOfCoreAsset(rootEntityId:)` is called at entity destruction time.

---

## Background Texture Prewarm

`storeAsset(_:for:)` immediately fires a background `Task` at `.userInitiated` priority to call `loadTextures()` before any mesh enters streaming range:

```swift
func storeAsset(_ asset: MDLAsset, for rootEntityId: EntityID) {
    // Pin the asset and create the per-asset texture lock.
    lock.lock()
    rootAssetRefs[rootEntityId] = asset
    assetTextureLocks[rootEntityId] = NSLock()
    lock.unlock()
    // Kick off background prewarm immediately.
    prewarmTexturesAsync(for: rootEntityId)
}
```

The prewarm task acquires the per-asset texture lock, calls `ensureTexturesLoaded`, and releases the lock — all off the critical path. By the time the first mesh enters streaming range, `loadTextures()` has typically already completed, so the first-upload path sees a no-op `ensureTexturesLoaded` call and zero lock wait.

`activePrewarmRoots` tracks which roots have an in-flight prewarm task. `GeometryStreamingSystem` queries `isPrewarmActive(for:)` in the dispatch loop and defers uploading entities for that root until the prewarm completes. This prevents the first batch of uploads from blocking on the texture lock for the full remaining prewarm duration.

---

## Per-Asset Texture Serialization

`MDLAsset` is not thread-safe. Two `GeometryStreamingSystem` tasks uploading different meshes from the same asset concurrently can race during `loadTextures()`. `ProgressiveAssetLoader` prevents this with a per-asset `NSLock`:

```swift
private var assetTextureLocks: [EntityID: NSLock] = [:]
```

`storeAsset` creates the lock alongside the asset reference. Every upload task brackets only `ensureTexturesLoaded` with the lock — the lock is released **before** `makeMeshesFromCPUBuffers`:

```swift
ProgressiveAssetLoader.shared.acquireAssetTextureLock(for: rootId)
ProgressiveAssetLoader.shared.ensureTexturesLoaded(for: rootId)
ProgressiveAssetLoader.shared.releaseAssetTextureLock(for: rootId)
// makeMeshesFromCPUBuffers runs without the lock — MDLAsset is read-only after loadTextures()
```

After `loadTextures()` completes the `MDLAsset` is in a stable read-only state. Concurrent `makeMeshesFromCPUBuffers` calls from the same asset are safe without the lock, so all three upload slots can proceed in parallel once the prewarm is done.

Only the `ensureTexturesLoaded` call is serialized per asset. Meshes from *different* assets upload concurrently without any contention.

---

## Deferred `loadTextures()`

Large assets skip `asset.loadTextures()` at parse time to avoid the OOM risk of decompressing all textures before the app is interactive. The call is deferred via `ensureTexturesLoaded`:

```swift
func ensureTexturesLoaded(for rootEntityId: EntityID) {
    // Must be called while per-asset texture lock is held.
    // Calls asset.loadTextures() exactly once per asset lifetime.
}
```

`assetTexturesLoaded: Set<EntityID>` ensures the call happens exactly once. In normal operation the prewarm task wins the race and marks the asset loaded before any upload task reaches `ensureTexturesLoaded`, making the upload-path call a no-op.

---

## API Surface

| Method | Purpose |
|--------|---------|
| `storeCPUMesh(_:for:)` | Store a `CPUMeshEntry` keyed by child entity ID (regular OOC) |
| `retrieveCPUMesh(for:)` | Fetch the entry for `GeometryStreamingSystem` upload (regular OOC) |
| `removeCPUMesh(for:)` | Remove a single entry (rarely needed; prefer `removeOutOfCoreAsset`) |
| `storeCPULODMesh(_:for:lodIndex:)` | Store a `CPUMeshEntry` for one LOD level of a LOD group entity |
| `retrieveCPULODMesh(for:lodIndex:)` | Fetch the entry for a specific LOD level |
| `retrieveAllCPULODMeshes(for:)` | Fetch all LOD-level entries for a group entity |
| `hasCPULODData(for:)` | Returns `true` if the entity was registered via the LOD+OOC path |
| `removeCPULODEntry(for:)` | Remove all LOD entries for a group entity |
| `storeAsset(_:for:)` | Pin an `MDLAsset`, create its per-asset texture lock, and kick off background prewarm |
| `isPrewarmActive(for:)` | Returns `true` while the background prewarm task holds the texture lock for this root |
| `registerChildren(_:for:)` | Associate child entity IDs with a root for bulk cleanup |
| `acquireAssetTextureLock(for:)` | Lock before calling `ensureTexturesLoaded` |
| `releaseAssetTextureLock(for:)` | Unlock immediately after `ensureTexturesLoaded` — before GPU upload work |
| `ensureTexturesLoaded(for:)` | Call `loadTextures()` exactly once per asset (must hold texture lock) |
| `removeOutOfCoreAsset(rootEntityId:)` | Release all CPU entries (both registries) + MDLAsset for a destroyed root entity |
| `cancelAll()` | Release everything — use on scene reset or test teardown |
| `tick()` | No-op stub; retained for call-site compatibility |

---

## Data Flow

```
setEntityMeshAsync (out-of-core path — regular OOC)
  │
  ├─ parseAssetAsync()               → MDLAsset in CPU RAM (no GPU spike)
  ├─ registerProgressiveStubEntity() → N ECS stubs, StreamingComponent(.unloaded)
  ├─ storeCPUMesh(entry, for: childId) × N  → cpuMeshRegistry
  ├─ storeAsset(asset, for: rootId)   → rootAssetRefs, assetTextureLocks
  │     └─ prewarmTexturesAsync()    → background Task: acquireLock / loadTextures() / releaseLock
  ├─ registerChildren(childIds, for: rootId)
  └─ completion(true)                → caller enables GeometryStreamingSystem

setEntityMeshAsync (out-of-core path — LOD+OOC)
  │
  ├─ parseAssetAsync()               → MDLAsset in CPU RAM
  ├─ detectImportedLODGroups()        → N LOD groups detected
  ├─ (per group) createEntity + LODComponent(stubs) + StreamingComponent(.unloaded)
  ├─ storeCPULODMesh(entry, for: groupId, lodIndex:) × (N groups × L levels)  → cpuLODRegistry
  ├─ storeAsset(asset, for: rootId)
  │     └─ prewarmTexturesAsync()    → background Task: acquireLock / loadTextures() / releaseLock
  ├─ registerChildren(groupEntityIds, for: rootId)
  └─ completion(true)

GeometryStreamingSystem (adaptive tick: 16 ms during backlog, 100 ms steady-state)
  │
  ├─ isPrewarmActive(rootId)?  → YES → defer all entities for this root (slots stay free)
  │
  ├─ entity within streamingRadius && state == .unloaded
  │   ├─ hasCPULODData?  → YES → uploadActiveLODFromCPU()
  │   │     ├─ retrieveAllCPULODMeshes(for: entityId)
  │   │     ├─ acquireAssetTextureLock / ensureTexturesLoaded / releaseAssetTextureLock
  │   │     ├─ makeMeshesFromCPUBuffers() × L levels  ← lock released; parallel uploads safe
  │   │     ├─ LODComponent.lodLevels[i].residencyState = .resident  for each uploaded level
  │   │     └─ registerRenderComponent() at distance-appropriate LOD
  │   │
  │   └─ hasCPULODData?  → NO  → retrieveCPUMesh / uploadFromCPUEntry (regular OOC)
  │         ├─ acquireAssetTextureLock / ensureTexturesLoaded / releaseAssetTextureLock
  │         ├─ makeMeshesFromCPUBuffers()  ← lock released; parallel uploads safe
  │         └─ registerRenderComponent()
  │
  └─ entity beyond unloadRadius && state == .loaded
      └─ render.mesh = []  (cpu entries kept — re-upload from RAM on re-approach)

destroyAllEntities / scene reset
  └─ removeOutOfCoreAsset(rootEntityId:)  → frees both CPU registries + MDLAsset
```

---

## Memory Model at Steady State

```
CPU RAM:  all leaf meshes' MDLMesh vertex/index data — always resident
GPU RAM:  only entities within streamingRadius — uploaded on demand
Disk:     read exactly once at parse time
```

This trades a modest CPU-RAM footprint for predictable GPU memory usage and zero-latency re-uploads after eviction.

---

## Cleanup

Call `removeOutOfCoreAsset(rootEntityId:)` when destroying a root entity to free its CPU-heap geometry and texture-lock state:

```swift
ProgressiveAssetLoader.shared.removeOutOfCoreAsset(rootEntityId: rootId)
```

`destroyAllEntities` does not call this automatically — you must call it explicitly if you are managing entity lifetimes outside the engine's destruction path.

For full teardown (scene resets, tests):

```swift
ProgressiveAssetLoader.shared.cancelAll()
```
