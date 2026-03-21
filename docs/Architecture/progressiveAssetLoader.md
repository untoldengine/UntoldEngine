# Progressive Asset Loader

## TL;DR

`ProgressiveAssetLoader` is a **CPU registry** — its sole responsibility is storing `CPUMeshEntry` records for out-of-core stub entities and serving them to `GeometryStreamingSystem` on demand.

> **Note:** This document describes the current architecture. The earlier tick-based progressive loader (per-frame job queue, `PendingObjectItem`, `enqueue(job)`, `tick()` processing N meshes per frame) was replaced by the out-of-core stub system. `tick()` is retained as a no-op for call-site compatibility only.

---

## What It Stores

When `setEntityMeshAsync` routes an asset through the out-of-core path, it registers every leaf mesh as a zero-GPU **stub entity** and stores a `CPUMeshEntry` in the registry for each:

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

---

## The MDLAsset Lifetime Problem

`MDLMeshBufferDataAllocator` (used by `parseAssetAsync`) backs all CPU buffers via the `MDLAsset` container. If the asset is released, all child MDLMesh CPU pointers become dangling.

`ProgressiveAssetLoader` solves this with `rootAssetRefs`:

```swift
private var rootAssetRefs: [EntityID: MDLAsset] = [:]
```

`storeAsset(_:for:)` pins the `MDLAsset` to the root entity ID. It stays alive until `removeOutOfCoreAsset(rootEntityId:)` is called at entity destruction time.

---

## Per-Asset Texture Serialization

`MDLAsset` is not thread-safe. Two `GeometryStreamingSystem` tasks uploading different meshes from the same asset concurrently can race during `texelDataWithTopLeftOrigin` or `loadTextures()`. `ProgressiveAssetLoader` prevents this with a per-asset `NSLock`:

```swift
private var assetTextureLocks: [EntityID: NSLock] = [:]
```

`storeAsset` creates the lock alongside the asset reference. Every upload task must bracket its texture work:

```swift
ProgressiveAssetLoader.shared.acquireAssetTextureLock(for: rootId)
ProgressiveAssetLoader.shared.ensureTexturesLoaded(for: rootId)
// ... makeMeshesFromCPUBuffers (texture reads happen here) ...
ProgressiveAssetLoader.shared.releaseAssetTextureLock(for: rootId)
```

Only one mesh from a given asset hydrates textures at a time. Meshes from *different* assets upload concurrently without contention.

---

## Deferred `loadTextures()`

Large assets skip `asset.loadTextures()` at parse time to avoid the OOM risk of decompressing all textures before the app is interactive. The call is deferred to first-upload time via `ensureTexturesLoaded`:

```swift
func ensureTexturesLoaded(for rootEntityId: EntityID) {
    // Must be called while per-asset texture lock is held.
    // Calls asset.loadTextures() exactly once per asset lifetime.
}
```

`assetTexturesLoaded: Set<EntityID>` ensures the call happens exactly once even if multiple concurrent uploads race to be "first" — the per-asset lock serializes them, and the winner marks the asset as loaded before releasing the lock.

---

## API Surface

| Method | Purpose |
|--------|---------|
| `storeCPUMesh(_:for:)` | Store a `CPUMeshEntry` keyed by child entity ID |
| `retrieveCPUMesh(for:)` | Fetch the entry for `GeometryStreamingSystem` upload |
| `removeCPUMesh(for:)` | Remove a single entry (rarely needed; prefer `removeOutOfCoreAsset`) |
| `storeAsset(_:for:)` | Pin an `MDLAsset` and create its per-asset texture lock |
| `registerChildren(_:for:)` | Associate child entity IDs with a root for bulk cleanup |
| `acquireAssetTextureLock(for:)` | Lock before texture-reading operations |
| `releaseAssetTextureLock(for:)` | Unlock after texture-reading operations |
| `ensureTexturesLoaded(for:)` | Call `loadTextures()` exactly once per asset (must hold texture lock) |
| `removeOutOfCoreAsset(rootEntityId:)` | Release all CPU entries + MDLAsset for a destroyed root entity |
| `cancelAll()` | Release everything — use on scene reset or test teardown |
| `tick()` | No-op stub; retained for call-site compatibility |

---

## Data Flow

```
setEntityMeshAsync (out-of-core path)
  │
  ├─ parseAssetAsync()               → MDLAsset in CPU RAM (no GPU spike)
  ├─ registerProgressiveStubEntity() → 500 ECS stubs, StreamingComponent(.unloaded)
  ├─ storeCPUMesh(entry, for: childId) × 500  → cpuMeshRegistry
  ├─ storeAsset(asset, for: rootId)   → rootAssetRefs, assetTextureLocks
  ├─ registerChildren(childIds, for: rootId)
  └─ completion(isOutOfCore: true)    → caller enables GeometryStreamingSystem

GeometryStreamingSystem (every 0.1 s)
  │
  ├─ entity within streamingRadius && state == .unloaded
  │   └─ retrieveCPUMesh(for: entityId)
  │       ├─ acquireAssetTextureLock(for: rootId)
  │       ├─ ensureTexturesLoaded(for: rootId)  ← deferred loadTextures() here
  │       ├─ makeMeshesFromCPUBuffers()          ← CPU heap → MTLBuffer
  │       ├─ releaseAssetTextureLock(for: rootId)
  │       └─ registerRenderComponent()           ← entity becomes visible
  │
  └─ entity beyond unloadRadius && state == .loaded
      └─ render.mesh = []  (cpuMeshRegistry entry kept — re-upload from RAM)

destroyAllEntities / scene reset
  └─ removeOutOfCoreAsset(rootEntityId:)  → frees CPU heap + MDLAsset
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
