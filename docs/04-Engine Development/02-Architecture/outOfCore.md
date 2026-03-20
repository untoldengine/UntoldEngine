# Out-of-Core System Walkthrough: 500-Building City Block

---

## The Cast

Three independent systems, each with a separate job:

| System | Runs | Job |
|--------|------|-----|
| `ProgressiveAssetLoader` | On demand | CPU registry — stores MDLMesh data, manages asset lifetime |
| `GeometryStreamingSystem` | Every 0.1 s (background) | Load/unload entities by distance; uploads from CPU registry |
| `MeshResourceManager` | On demand (fallback) | Disk cache for non-stub entities |

`ProgressiveAssetLoader` no longer processes per-frame jobs. Its sole responsibility is the CPU registry: storing `CPUMeshEntry` records at registration time and serving them to `GeometryStreamingSystem` on demand. `tick()` is a retained no-op for call-site compatibility.

---

## Phase 0 — Parse (happens once, async)

```
setEntityMeshAsync(entityId: root, filename: "city_block", withExtension: "usdz")
```

`parseAssetAsync` opens the USDZ using `MDLMeshBufferDataAllocator`. This allocator stores all vertex/index data on the **CPU heap** — no Metal buffers are allocated, so the entire file loads without touching the GPU.

`childObjects(of: MDLMesh.self)` walks the hierarchy and returns **only leaf geometry nodes** — 500 MDLMesh objects, one per building. Each carries its full parent-chain transform and lives entirely in CPU RAM.

The routing condition checks two triggers. Either one activates the out-of-core path:

```swift
let isLargeFile    = fileSizeBytes > fileSizeThresholdBytes          // default 50 MB
let hasManyObjects = objectCount  >= outOfCoreObjectCountThreshold   // default 50 objects
```

A 500 MB ship hits `isLargeFile`. An 18 MB city with 200 buildings hits `hasManyObjects`. Both take the same path.

---

## Phase 1 — Stub Registration (happens once, synchronous within async context)

Instead of uploading to the GPU, all 500 buildings are registered immediately as **stub entities** — full ECS presence, zero GPU allocation.

All stubs are registered inside a **single `withWorldMutationGate` acquisition**. This avoids N × acquire/release overhead — for 500 buildings that would be 500 separate gate round-trips on the XR compositor thread. One gate wraps the entire loop:

```
withWorldMutationGate {
    Building #1   → createEntity() → LocalTransform + Scenegraph + StreamingComponent(.unloaded)
    Building #2   → createEntity() → LocalTransform + Scenegraph + StreamingComponent(.unloaded)
    ...
    Building #500 → createEntity() → LocalTransform + Scenegraph + StreamingComponent(.unloaded)
}
```

**Per stub (`registerProgressiveStubEntity`):**
1. `createEntity()` — new ECS entity
2. `applyWorldTransform(composedWorldTransform(for: mdlMesh))` — world position set from the full MDL parent chain, used by octree and distance calculations
3. `LocalTransformComponent.boundingBox` — seeded from `MDLMesh.boundingBox` so spatial queries return correct extents
4. `StreamingComponent` — state `.unloaded`, `streamingRadius = Float.greatestFiniteMagnitude` (placeholder until `enableStreaming` is called)
5. `OctreeSystem.shared.registerEntity` — stub appears in spatial queries immediately
6. No `RenderComponent`, no Metal buffers

After the gate closes, CPU entries are stored in `ProgressiveAssetLoader.cpuMeshRegistry` (lock-based, no ECS mutation needed):

```swift
cpuMeshRegistry[childEntityId] = CPUMeshEntry(
    object: mdlMesh,          // MDLMesh with CPU-heap vertex data
    vertexDescriptor: ...,
    textureLoader: ...,
    device: ...,
    url: ...,
    uniqueAssetName: "Hull_A#42",
    estimatedGPUBytes: 524288 // vertex + index bytes, computed from MDLMesh at stub time
)
```

`estimatedGPUBytes` is computed at stub registration from `MDLMesh.vertexCount` and the vertex descriptor stride — no disk I/O required. It is used by the pre-emptive budget reservation in Phase 3 so the system can check `canAccept()` before starting each upload.

The `MDLAsset` container is retained in `rootAssetRefs[rootEntityId]` so the `MDLMeshBufferDataAllocator` backing all child CPU buffers stays alive.

**Completion callback fires immediately** — no GPU work was done, no frame budget was consumed. The app is unblocked.

---

## Phase 2 — Real Radii (after `enableStreaming` is called)

The completion callback calls:

```swift
enableStreaming(entityId: root, streamingRadius: 80, unloadRadius: 120)
```

`enableStreaming` iterates all children. For out-of-core stubs it finds them via `StreamingComponent` (not `RenderComponent`, which doesn't exist yet):

```swift
for childId in sceneGraph.children {
    if hasRenderComponent || hasStreamingComponent {
        enableStreamingForSingleEntity(childId, streamingRadius: 80, unloadRadius: 120)
    }
}
```

For each stub, `enableStreamingForSingleEntity` detects the no-RenderComponent case and only updates the radii — state stays `.unloaded`:

```
Building #1   StreamingComponent: streamingRadius=80, unloadRadius=120, state=.unloaded
Building #2   StreamingComponent: streamingRadius=80, unloadRadius=120, state=.unloaded
...
Building #500 StreamingComponent: streamingRadius=80, unloadRadius=120, state=.unloaded
```

The streaming system can now manage all 500 buildings.

---

## Phase 3 — Distance-Based Streaming (every 0.1 s, ongoing)

`GeometryStreamingSystem.update()` runs every 0.1 s.

### Camera position

Distance calculations use `CameraComponent.localPosition` (transformed via `SceneRootTransform.effectiveCameraPosition`), not the `WorldTransformComponent`-derived position. On Vision Pro, `CameraComponent.localPosition` is updated every ARKit frame directly — it is always current. The `WorldTransformComponent` goes through the scene-graph propagation pass and can lag by a frame, causing incorrect distance ordering.

### Memory budget gate (runs before any load)

Before starting new uploads, the system checks memory pressure:

```
1. Evict by value-score if MemoryBudgetManager.shouldEvict() → evictLRU()
2. Snapshot shouldEvict() once after eviction
3. Only start new loads if budget allows
```

This prevents in-range stubs from uploading simultaneously and pushing GPU memory past the OS kill threshold. The guard snapshots `shouldEvict()` exactly once after eviction — one lock acquisition, correct post-eviction state.

### Distance-banded concurrency

Load candidates are split into two bands before any load starts:

```
Near band:  distance ≤ streamingRadius × nearBandFraction (default 0.33)
            → serialized: nearBandMaxConcurrentLoads (default 1) in-flight at a time
            → guarantees distance-ordered appearance for the closest meshes

Rest band:  distance > streamingRadius × nearBandFraction
            → uses remaining global slots (maxConcurrentLoads − near-band in-flight)
```

Near-band loads are tracked in a separate `activeNearBandLoads` set so the concurrency limit is enforced independently of the global slot count. This means the closest mesh always completes before the next-closest starts, avoiding random-order pop-in.

### Pre-emptive budget reservation

Before each load starts (both bands), the system checks whether the mesh will fit:

```swift
if let cpuEntry = ProgressiveAssetLoader.shared.retrieveCPUMesh(for: entityId),
   !MemoryBudgetManager.shared.canAccept(sizeBytes: cpuEntry.estimatedGPUBytes) {
    evictLRU(cameraPosition:)   // targeted eviction to make room
    guard canAccept(...) else { continue }  // skip if still no room
}
```

`estimatedGPUBytes` (stored in `CPUMeshEntry` at stub-registration time) lets this check run without any GPU work or disk I/O.

### Load / unload loop

```
For each nearby entity:
  distance = length(entity.worldCenter - effectiveCameraPosition)

  if state == .unloaded && distance <= streamingRadius (80m):
      canAccept(estimatedGPUBytes)?  → evict if not, skip if still no room
      loadMesh(entityId, isNearBand) → checks cpuMeshRegistry → uploadFromCPUEntry()
                                     → makeMeshesFromCPUBuffers → registerRenderComponent
                                     → MemoryBudgetManager.registerMesh()   ← GPU bytes tracked
                                     → state = .loaded

  if state == .loaded && distance > unloadRadius (120m):
      unloadMesh(entityId) → render.mesh = []
                           → MemoryBudgetManager.unregisterMesh()
                           → state = .unloaded
                           → cpuMeshRegistry entry kept intact
```

### Value-score eviction

`evictLRU` no longer evicts purely by least-recently-used frame. Candidates are ranked by a value score:

```
distanceFactor = min(1.0, distance / maxQueryRadius)
sizeFactor     = min(1.0, meshBytes / meshBudget)
score          = evictionDistanceWeight × distanceFactor + evictionSizeWeight × sizeFactor
```

Highest score is evicted first — far, large meshes go before near, small ones. `lastVisibleFrame` is the tiebreaker for equal scores. This protects nearby small meshes (high camera-coverage value) while freeing the largest far meshes first.

#### Distance-aware visibility guard

The eviction loop also applies a distance-aware guard to visible entities:

```
if visible AND distance < visibleEvictionProtectionRadius (default 30 m) → skip (protect close foreground)
if visible AND distance ≥ visibleEvictionProtectionRadius                → allow eviction
```

This replaces the previous hard `visibleEntityIds.contains` block that prevented evicting any visible entity regardless of distance. The old guard caused a residency deadlock on zoom-out → zoom-in cycles: after zooming back in, all loaded far meshes were in-frustum, making every candidate unevictable — budget was permanently stuck and nearby meshes could not load.

With the distance-aware guard, far visible meshes (beyond 30 m) are evictable under memory pressure. Meshes within 30 m of the camera remain protected from eviction to prevent obvious foreground popping.

**Tuning:** `visibleEvictionProtectionRadius` should be set to ~15% of your `streamingRadius`. For `streamingRadius = 200 m`, the default 30 m is appropriate.

### The CPU upload path (`uploadFromCPUEntry`)

When `loadMeshAsync` is called for an out-of-core stub, it checks the CPU registry **before** going to disk:

```swift
if let cpuEntry = ProgressiveAssetLoader.shared.retrieveCPUMesh(for: entityId) {
    return await uploadFromCPUEntry(entityId: entityId, cpuEntry: cpuEntry)
}
// fallback: MeshResourceManager (disk / cache) for non-stub entities
```

`uploadFromCPUEntry`:
1. `makeMeshesFromCPUBuffers` — copies MDLMesh vertex/index data from CPU heap to Metal-backed buffers
2. `registerRenderComponent` — entity gets a `RenderComponent`, becomes visible
3. `MemoryBudgetManager.registerMesh` — registers the Metal allocation so `shouldEvict()` sees it
4. CPU data is **not** cleared — the `cpuMeshRegistry` entry stays so the next eviction+reload cycle re-uploads from RAM, not disk

### Memory model at steady state

```
CPU RAM:  ~100-200 MB  (all 500 buildings' MDLMesh data, always resident)
GPU RAM:  ~10-30 MB    (only the ~15-20 buildings within 80m of camera)
Disk:     read once at startup
```

---

## What "Walking Around the City" Actually Does

```
Camera starts at south entrance (0, 0, 0)
→ buildings within 80m: #1-#18 → uploadFromCPUEntry → .loaded → visible
→ buildings 81-500m away: .unloaded → invisible, CPU data resident

Camera walks north 200m to (0, 0, -200)
→ buildings #1-#18 now beyond 120m → unloadMesh → .unloaded → Metal buffers freed
→ buildings #220-#238 now within 80m → uploadFromCPUEntry → .loaded → visible
→ re-approach #1-#18 later → uploadFromCPUEntry again (from CPU RAM, not disk)
```

Every building is always present as an ECS entity. The GPU footprint at any moment reflects only what the camera can actually see. No entity is ever permanently absent — all 500 are available for upload at any time.

---

## Lifetime and Cleanup

When the root entity is destroyed, call:

```swift
ProgressiveAssetLoader.shared.removeOutOfCoreAsset(rootEntityId: rootId)
```

This releases all `CPUMeshEntry` references and the `MDLAsset`, freeing the CPU-heap geometry data for all 500 buildings.

---

## Tuning Reference

| Property | Default | Effect |
|----------|---------|--------|
| `ProgressiveAssetLoader.fileSizeThresholdBytes` | 50 MB | Files above this use out-of-core |
| `ProgressiveAssetLoader.outOfCoreObjectCountThreshold` | 50 objects | Files with more objects than this use out-of-core regardless of size |
| `GeometryStreamingSystem.maxConcurrentLoads` | 3 | Total concurrent CPU→Metal uploads across both bands |
| `GeometryStreamingSystem.nearBandFraction` | 0.33 | Fraction of `streamingRadius` defining the near band; near-band loads are serialized |
| `GeometryStreamingSystem.nearBandMaxConcurrentLoads` | 1 | Max in-flight loads in the near band; 1 guarantees distance-ordered appearance |
| `GeometryStreamingSystem.updateInterval` | 0.1 s | How often load/unload decisions run |
| `GeometryStreamingSystem.maxQueryRadius` | 500 m | Octree query radius; must be ≥ `unloadRadius` |
| `GeometryStreamingSystem.evictionDistanceWeight` | 0.6 | How much distance contributes to eviction score; higher = farther entities evicted first |
| `GeometryStreamingSystem.evictionSizeWeight` | 0.4 | How much GPU size contributes to eviction score; higher = larger meshes evicted first |
| `GeometryStreamingSystem.visibleEvictionProtectionRadius` | 30 m | Visible entities within this distance are never evicted; set to ~15% of `streamingRadius` |
| `streamingRadius` | caller-set | Distance at which `.unloaded` entities get uploaded |
| `unloadRadius` | caller-set | Distance beyond which `.loaded` entities are evicted; must be > `streamingRadius` |
| `MemoryBudgetManager.meshBudget` | device-set | GPU memory ceiling; raise if headroom allows, lower if crashes persist |
