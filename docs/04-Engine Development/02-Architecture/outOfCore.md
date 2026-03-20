# Out-of-Core System Walkthrough: 500-Building City Block

---

## The Cast

Three independent systems, each with a separate job:

| System | Runs | Job |
|--------|------|-----|
| `ProgressiveAssetLoader` | On demand | CPU registry — stores MDLMesh data, manages asset lifetime |
| `GeometryStreamingSystem` | Every 0.1 s (background) | Load/unload entities by distance; uploads from CPU registry |
| `MeshResourceManager` | On demand (fallback) | Disk cache for non-stub entities |

---

## Phase 0 — Parse (happens once, async)

```
setEntityMeshAsync(entityId: root, filename: "city_block", withExtension: "usdz")
```

`parseAssetAsync` opens the USDZ using `MDLMeshBufferDataAllocator`. This allocator stores all vertex/index data on the **CPU heap** — no Metal buffers are allocated, so the entire file loads without touching the GPU.

`childObjects(of: MDLMesh.self)` walks the hierarchy and returns **only leaf geometry nodes** — 500 MDLMesh objects, one per building. Each carries its full parent-chain transform and lives entirely in CPU RAM.

The routing condition checks two triggers. Either one activates the out-of-core path:

```swift
let isLargeFile   = fileSizeBytes > fileSizeThresholdBytes     // default 50 MB
let hasManyObjects = objectCount  >= outOfCoreObjectCountThreshold  // default 50 objects
```

A 500 MB ship hits `isLargeFile`. An 18 MB city with 200 buildings hits `hasManyObjects`. Both take the same path.

---

## Phase 1 — Stub Registration (happens once, synchronous within async context)

Instead of uploading to the GPU, all 500 buildings are registered immediately as **stub entities** — full ECS presence, zero GPU allocation:

```
Building #1  → createEntity() → LocalTransform + Scenegraph + StreamingComponent(.unloaded)
Building #2  → createEntity() → LocalTransform + Scenegraph + StreamingComponent(.unloaded)
...
Building #500 → createEntity() → LocalTransform + Scenegraph + StreamingComponent(.unloaded)
```

**Per stub (`registerProgressiveStubEntity`):**
1. `createEntity()` — new ECS entity
2. `applyWorldTransform(composedWorldTransform(for: mdlMesh))` — world position set from the full MDL parent chain, used by octree and distance calculations
3. `LocalTransformComponent.boundingBox` — seeded from `MDLMesh.boundingBox` so spatial queries return correct extents
4. `StreamingComponent` — state `.unloaded`, `streamingRadius = Float.greatestFiniteMagnitude` (placeholder until `enableStreaming` is called)
5. `OctreeSystem.shared.registerEntity` — stub appears in spatial queries immediately
6. No `RenderComponent`, no Metal buffers

Each MDLMesh is stored in `ProgressiveAssetLoader.cpuMeshRegistry` keyed by child entity ID:

```swift
cpuMeshRegistry[childEntityId] = CPUMeshEntry(
    object: mdlMesh,          // MDLMesh with CPU-heap vertex data
    vertexDescriptor: ...,
    textureLoader: ...,
    device: ...,
    url: ...,
    uniqueAssetName: "Hull_A#42"
)
```

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
Building #1  StreamingComponent: streamingRadius=80, unloadRadius=120, state=.unloaded
Building #2  StreamingComponent: streamingRadius=80, unloadRadius=120, state=.unloaded
...
Building #500 StreamingComponent: streamingRadius=80, unloadRadius=120, state=.unloaded
```

The streaming system can now manage all 500 buildings.

---

## Phase 3 — Distance-Based Streaming (every 0.1 s, ongoing)

`GeometryStreamingSystem.update()` runs every 0.1 s. It queries the octree for nearby entities and evaluates each `StreamingComponent`:

```
For each nearby entity:
  distance = length(entity.worldCenter - camera.worldPosition)

  if state == .unloaded && distance <= streamingRadius (80m):
      loadMesh(entityId)   → checks cpuMeshRegistry → uploadFromCPUEntry()
                           → makeMeshesFromCPUBuffers → registerRenderComponent
                           → state = .loaded

  if state == .loaded && distance > unloadRadius (120m):
      unloadMesh(entityId) → render.mesh = []
                           → MemoryBudgetManager.unregisterMesh()
                           → state = .unloaded
                           → cpuMeshRegistry entry kept intact
```

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
3. CPU data is **not** cleared — the `cpuMeshRegistry` entry stays so the next eviction+reload cycle re-uploads from RAM, not disk

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
| `fileSizeThresholdBytes` | 50 MB | Files above this use out-of-core |
| `outOfCoreObjectCountThreshold` | 50 objects | Files with more objects than this use out-of-core regardless of size |
| `GeometryStreamingSystem.maxConcurrentLoads` | 3 | Concurrent CPU→Metal uploads; raise for faster initial population |
| `GeometryStreamingSystem.updateInterval` | 0.1 s | How often load/unload decisions run |
| `GeometryStreamingSystem.maxQueryRadius` | 500 m | Octree query radius; must be ≥ `unloadRadius` |
| `streamingRadius` | caller-set | Distance at which `.unloaded` entities get uploaded |
| `unloadRadius` | caller-set | Distance beyond which `.loaded` entities are evicted; must be > `streamingRadius` |
