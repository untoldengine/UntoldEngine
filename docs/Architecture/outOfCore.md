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

## Controlling OOC: `streamingPolicy` and `GeometryStreamingSystem.enabled`

There is no global OOC on/off switch. Whether OOC applies is decided **per-asset** at `setEntityMeshAsync` call time via the `streamingPolicy` parameter.

### What `streamingPolicy` controls

The policy selects the **registration path** — what happens inside `setEntityMeshAsync` before the completion callback fires:

| Policy | What happens at registration | `StreamingComponent` added? | `GeometryStreamingSystem` involved? |
|---|---|---|---|
| `.immediate` | All meshes uploaded to GPU immediately; `RenderComponent` registered | No | No |
| `.outOfCore` | Zero-GPU stub entities registered; CPU entries stored in `ProgressiveAssetLoader` | Yes (`.unloaded`) | Yes — must be running for anything to render |
| `.auto` | `AssetProfiler` decides based on memory budget | Depends | Depends |

`.immediate` means OOC is not used at all for this asset. The full mesh is GPU-resident before the completion callback fires. `GeometryStreamingSystem` never sees this entity because it only operates on entities with a `StreamingComponent` in the `.unloaded` state.

`.outOfCore` means OOC is the only path — nothing renders until `GeometryStreamingSystem` is enabled and uploads the stubs as the camera enters streaming range.

### Relationship with `GeometryStreamingSystem.enabled`

`GeometryStreamingSystem.enabled` is a separate runtime flag that gates whether the streaming loop runs at all:

```
streamingPolicy = .immediate  →  entity has no StreamingComponent
                                  GeometryStreamingSystem.enabled = true/false → no effect on this entity

streamingPolicy = .outOfCore  →  entity has StreamingComponent(.unloaded)
                                  GeometryStreamingSystem.enabled = false → nothing ever renders
                                  GeometryStreamingSystem.enabled = true  → uploads on demand, evicts when far
```

These are genuinely different registration paths, not just different timing for the same outcome:

- `.immediate` — load now, streaming system plays no role for this entity
- `.outOfCore` — register stubs now, `GeometryStreamingSystem` drives GPU residency for the entity's lifetime

---

## Phase 0 — Parse (happens once, async)

```
setEntityMeshAsync(entityId: root, filename: "city_block", withExtension: "usdz")
```

Before any parse begins, the asset passes through a **two-stage admission gate**. Both stages must pass before any ECS entity is created or any GPU memory is allocated.

### Two-Stage Admission Gate

#### Stage 1 — Pre-Parse Gate (three-zone model)

Stage 1 fires before `parseAssetAsync` is called. It uses only the on-disk file size and a conservative expansion multiplier to estimate the worst-case CPU heap spike during parsing:

```
projectedCPUBytes = fileSizeBytes × 20
```

The 20× multiplier is a conservative upper bound for USDZ **geometry** decompression — real-world worst case is ~55× for a dense city geometry USDZ. It is intentionally blunt because no content information is available before parsing.

Results are classified into three zones:

| Zone | Condition | Outcome |
|------|-----------|---------|
| **Safe zone** | `projectedCPU ≤ 50% RAM` | Allow parse. No log entry. |
| **Soft zone** | `projectedCPU > 50% AND < 75% RAM` | Log `[AdmissionGate] Stage 1 SOFT ZONE` warning. Allow parse. Stage 2 is the authoritative gate. |
| **Hard reject** | `projectedCPU ≥ 75% RAM` | Log `[AdmissionGate] Stage 1 HARD REJECT` error. Assign fallback mesh. Return. |

**Why a soft zone?** The 20× multiplier is calibrated for geometry-heavy USDZs. For texture-heavy assets, most of the on-disk bytes are compressed textures — which are **not** decoded during `parseAssetAsync`. The `MDLMeshBufferDataAllocator` only decompresses geometry; textures remain as compressed references until `ensureTexturesLoaded()` is called at first-upload time. A 555 MB texture-heavy USDZ may produce only ~2 GB of parse-time CPU allocation despite a projected 11 GB figure. The soft zone lets these assets pass to Stage 2, which measures the actual geometry footprint.

**Hard reject still calls `loadFallbackMesh`** — the entity gets a visible placeholder cube so the scene remains stable and the rejection is immediately apparent.

**Future refinement:** a lightweight ZIP central-directory scan before parsing could separate texture-entry bytes from geometry-entry bytes and apply the 20× multiplier only to the geometry portion, eliminating soft-zone false positives for texture-heavy assets entirely. This is deferred until the soft-zone model is validated on real assets.

#### Stage 2 — Post-Parse Accurate Gate

Stage 2 runs unconditionally after any successful parse — including assets that passed through the soft zone. It uses `AssetProfiler` to measure actual geometry byte estimates from the parsed `MDLMesh` objects:

```
if assetProfile.estimatedGeometryBytes > 75% of physicalMemory → HARD REJECT
```

Stage 2 is the **accurate authority**. It has full visibility into the parsed asset content and rejects based on actual geometry bytes, not file-size heuristics. When Stage 2 fires it also assigns the fallback mesh so the entity remains visible.

The key limitation: by the time Stage 2 runs, `parseAssetAsync` has already allocated CPU heap for all MDLMesh buffers. Stage 2 cannot prevent the parse-time spike — it prevents all *downstream* work (stub registration, MDLAsset retention, CPU registry storage). When the gate fires, `assetData` goes out of scope and ARC releases the parsed buffers.

#### Fallback Behavior on Rejection

When either gate issues a hard reject, `loadFallbackMesh` is called before returning:

```swift
// Both Stage 1 hard reject and Stage 2 hard reject now call:
loadFallbackMesh(entityId: entityId, filename: filename)
```

This assigns a default cube mesh to the entity so the scene is visually stable and the user receives immediate feedback that something was loaded (but replaced). Without the fallback the entity would be invisible and mesh-less.

---

`parseAssetAsync` opens the USDZ using `MDLMeshBufferDataAllocator`. This allocator stores all vertex/index data on the **CPU heap** — no Metal buffers are allocated, so the entire file loads without touching the GPU.

`childObjects(of: MDLMesh.self)` walks the hierarchy and returns **only leaf geometry nodes** — 500 MDLMesh objects, one per building. Each carries its full parent-chain transform and lives entirely in CPU RAM.

The routing decision is controlled by the caller's `MeshStreamingPolicy` parameter:

```swift
setEntityMeshAsync(entityId: root, filename: "city_block", withExtension: "usdz",
                   streamingPolicy: .auto)   // default
```

| Policy | Routing |
|--------|---------|
| `.auto` (default) | `AssetProfiler`-based — budget-relative, domain-aware classification |
| `.outOfCore` | Always stubs + streaming, regardless of size or object count |
| `.immediate` | Always direct GPU upload; permanently GPU-resident, no streaming |

For `.auto`, the engine runs `AssetProfiler` on the parsed `ProgressiveAssetData` to produce an `AssetProfile` and select an `AssetLoadingPolicy`:

```swift
let profile = AssetProfiler.profile(url: url, assetData: assetData, fileSizeBytes: fileSizeBytes)
let policy  = AssetProfiler.classifyPolicy(profile: profile, budget: MemoryBudgetManager.shared.meshBudget)
```

The `AssetLoadingPolicy` has two independent axes — geometry residency and texture residency. The geometry policy drives the out-of-core routing decision:

| `geometryPolicy` | Routing |
|---|---|
| `.streaming` | Out-of-core stubs path — all leaf meshes registered as `.unloaded` stubs |
| `.eager` | Immediate path — all geometry uploaded to GPU in a single pass |

Geometry streaming is selected when any of the following is true:

- **Mesh count ≥ 50** — many meshes spike GPU allocation simultaneously even if total size is small
- **Geometry bytes exceed 30% of the platform budget** — e.g. 300 MB asset on a 1 GB machine
- **Monolithic asset (≤ 2 meshes) AND geometry exceeds 30% of budget** — streaming prevents OOM at registration, though the mesh still loads in one step

All thresholds are expressed as **fractions of the live platform budget** (`MemoryBudgetManager.meshBudget`), so they scale correctly across devices:

| Device class | `meshBudget` | 30% geometry threshold |
|---|---|---|
| macOS | 1 GB | ~300 MB |
| iOS high-end | 512 MB | ~154 MB |
| iOS low-end | 256 MB | ~77 MB |
| visionOS | 512 MB | ~154 MB |

This means the same 200 MB asset routes to `.eager` on macOS (fits comfortably) but to `.streaming` on low-end iOS (too large to load all at once). The old fixed thresholds (`fileSizeThresholdBytes = 50 MB`, `outOfCoreObjectCountThreshold = 50 objects`) applied the same cutoff regardless of the target device.

The profiler also classifies the asset's dominant memory domain and logs a full breakdown:

```
[AssetProfiler] 'dungeon3' (2.1 MB) → mixed | geo ~2.9 MB, tex ~6.2 MB | budget: 1024 MB | meshes: 410
[AssetProfiler] Policy → geometry: streaming, texture: eager (source: auto)
```

See [AssetProfiler architecture](assetProfiler.md) for the full classification logic and how geometry and texture policies are derived independently.

---

## Phase 1 — Stub Registration (happens once, synchronous within async context)

### LOD Asset Detection

Before choosing the registration path, `setEntityMeshAsync` inspects the top-level object names for LOD suffixes (`_LOD0`, `_LOD1`, …):

```swift
let lodNameDetection = detectImportedLODGroups(fromSourceNames: topLevelNames)
let hasLODGroups = !lodNameDetection.groups.isEmpty
let useOutOfCore = loadingPolicy.geometryPolicy == .streaming
```

| Condition | Path |
|---|---|
| `useOutOfCore && hasLODGroups` | **LOD+OOC path** — one entity per LOD group, `cpuLODRegistry` |
| `useOutOfCore && !hasLODGroups` | **Regular OOC path** — one stub entity per `MDLObject`, `cpuMeshRegistry` |
| `!useOutOfCore` | Immediate path — all geometry uploaded to GPU in one pass |

### LOD+OOC Stub Registration

When LOD groups are detected in an OOC asset, each group becomes **one entity** (not one entity per MDLObject):

```
withWorldMutationGate {
    Tree group    → createEntity() → LODComponent(stubs) + StreamingComponent(.unloaded)
    Rock group    → createEntity() → LODComponent(stubs) + StreamingComponent(.unloaded)
    ...
}
```

**Per LOD group entity:**
1. `createEntity()` — one entity for all LOD levels of this group
2. `applyWorldTransform(composedWorldTransform(for: lod0MDLObject))` — position from LOD0 object
3. `LocalTransformComponent.boundingBox` — seeded from LOD0 `MDLMesh.boundingBox`
4. `LODComponent` — stub `LODLevel`s for every level: `mesh: []`, `residencyState: .notResident`, `url` and `assetName` set for future disk reload reference
5. `StreamingComponent` — state `.unloaded`, placeholder radii (replaced by `enableStreaming`)
6. `OctreeSystem.shared.registerEntity` — appears in spatial queries immediately

After the gate, CPU entries are stored per (group entity, LOD index):

```swift
cpuLODRegistry[treeEntityId] = [
    0: CPUMeshEntry(object: tree_LOD0_MDLObject, uniqueAssetName: "Tree_LOD0", ...),
    1: CPUMeshEntry(object: tree_LOD1_MDLObject, uniqueAssetName: "Tree_LOD1", ...),
    2: CPUMeshEntry(object: tree_LOD2_MDLObject, uniqueAssetName: "Tree_LOD2", ...),
]
```

### Regular OOC Stub Registration

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

## Phase 2 — Completion Callback and Enabling Streaming

`setEntityMeshAsync`'s completion closure receives `isOutOfCore: Bool`:

- `true` — the asset was registered as stubs; `GeometryStreamingSystem` must be enabled for anything to render.
- `false` — the asset used the immediate path; all meshes are already GPU-resident.

```swift
setEntityMeshAsync(entityId: root, filename: "city_block", withExtension: "usdz") { isOutOfCore in
    if isOutOfCore {
        // Enable the system, then set real streaming radii on the root.
        // enableStreaming propagates the radii down to all child stubs,
        // replacing their Float.greatestFiniteMagnitude placeholders.
        GeometryStreamingSystem.shared.enabled = true
        enableStreaming(entityId: root, streamingRadius: 80, unloadRadius: 120)
    }
}
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

The streaming system can now load buildings within 80 m and unload them beyond 120 m as the camera moves.

---

## Phase 3 — Distance-Based Streaming (every 0.1 s, ongoing)

`GeometryStreamingSystem.update()` runs every 0.1 s.

### Camera position

Distance calculations use `CameraComponent.localPosition` (transformed via `SceneRootTransform.effectiveCameraPosition`), not the `WorldTransformComponent`-derived position. On Vision Pro, `CameraComponent.localPosition` is updated every ARKit frame directly — it is always current. The `WorldTransformComponent` goes through the scene-graph propagation pass and can lag by a frame, causing incorrect distance ordering.

### Memory budget gate (runs before any load)

The system maintains two independent memory pressure signals:

| Signal | Method | Meaning |
|---|---|---|
| Combined | `shouldEvict()` | (mesh + texture) ≥ 85% of `meshBudget` |
| Geometry only | `shouldEvictGeometry()` | mesh bytes alone ≥ 85% of `meshBudget` |

The load gate uses **geometry-only pressure** so that texture upgrades on already-loaded entities cannot block new mesh loads. The two signals drive a three-step response before any load starts:

```
1. if combined high AND geometry NOT high:
       TextureStreamingSystem.shedTextureMemory(maxEntities: 4)
       → texture relief only; no eviction, no load blocking

2. if geometry high:
       TextureStreamingSystem.shedTextureMemory(maxEntities: 8)   ← texture first
       evictLRU()                                                 ← geometry fallback

3. Snapshot shouldEvictGeometry() once after eviction
   → only start new loads if geometry budget allows
```

This prevents in-range stubs from uploading simultaneously and pushing GPU memory past the OS kill threshold. The geometry-only gate also prevents the budget-exhaustion/eviction deadlock that occurs on scenes where every entity fits within the streaming radius: texture upgrades no longer consume geometry headroom, so all stubs can load regardless of how much texture memory is in use.

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

Before each load starts (both bands), the system checks whether the mesh will fit using the **geometry-only** budget check:

```swift
if let cpuEntry = ProgressiveAssetLoader.shared.retrieveCPUMesh(for: entityId),
   !MemoryBudgetManager.shared.canAcceptMesh(sizeBytes: cpuEntry.estimatedGPUBytes) {
    evictLRU(cameraPosition:)     // targeted geometry eviction to make room
    guard canAcceptMesh(...) else { continue }  // skip if still no room
}
```

`canAcceptMesh` checks only `totalMeshMemory + sizeBytes ≤ meshBudget` — texture memory is excluded. This ensures that a large batch of texture upgrades on visible entities cannot prevent a nearby stub from loading its geometry.

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

### The CPU upload path

`loadMesh` selects the upload function based on the entity's registration type:

```swift
if hasCPULODData {
    // LOD+OOC entity: upload all LOD levels from cpuLODRegistry
    await uploadActiveLODFromCPU(entityId: entityId)
} else if hasLOD {
    // Disk-based LOD entity (no CPU registry): reload from MeshResourceManager
    await reloadLODEntity(entityId: entityId)
} else {
    // Regular entity (OOC or immediate): upload from cpuMeshRegistry or disk
    await loadMeshAsync(...)
}
```

#### `uploadActiveLODFromCPU` (LOD+OOC entities)

1. Checks if the root asset is cold — if so, calls `rehydrateColdAsset` to re-parse and rebuild `cpuLODRegistry`
2. `retrieveAllCPULODMeshes(for: entityId)` — fetches all LOD-level CPU entries
3. Texture lock acquired; `ensureTexturesLoaded` called once for the root asset
4. `makeMeshesFromCPUBuffers` — uploads every LOD level from CPU heap to Metal
5. `lodComponent.lodLevels[i].residencyState = .resident` for each uploaded level
6. `registerRenderComponent` — entity becomes visible at the distance-appropriate LOD
7. `MemoryBudgetManager.registerMesh` — total GPU bytes for all LOD levels registered
8. CPU data retained — re-approach after eviction re-uploads all levels from RAM

#### `uploadFromCPUEntry` (regular OOC entities)

When `loadMeshAsync` is called for a regular out-of-core stub, it checks the CPU registry **before** going to disk:

```swift
if let cpuEntry = ProgressiveAssetLoader.shared.retrieveCPUMesh(for: entityId) {
    return await uploadFromCPUEntry(entityId: entityId, cpuEntry: cpuEntry)
}
// fallback: MeshResourceManager (disk / cache) for non-stub entities
```

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

## Texture Loading

### Why `loadTextures()` Is Deferred

`MDLAsset` decompresses texture data lazily. Calling `asset.loadTextures()` at parse time for a 500 MB USDZ can OOM-kill the process before the app is interactive. The out-of-core path skips `loadTextures()` at parse time and defers it to first-upload time.

### `ensureTexturesLoaded` — Called Once Per Asset

`GeometryStreamingSystem.uploadFromCPUEntry` calls `ensureTexturesLoaded(for: rootId)` before the first `makeMeshesFromCPUBuffers` call for each asset. The method:

1. Checks `assetTexturesLoaded` — returns immediately if already done.
2. Calls `asset.loadTextures()` — decompresses textures into CPU RAM once.
3. Marks the asset in `assetTexturesLoaded` — subsequent uploads skip this call entirely.

### Per-Asset NSLock — Serializing Concurrent Texture Reads

`MDLAsset` is not thread-safe. Two concurrent uploads from the same asset can race in `texelDataWithTopLeftOrigin`. Each asset has a dedicated `NSLock` in `ProgressiveAssetLoader.assetTextureLocks`:

```
Task A (Building #1)                Task B (Building #2)
acquireAssetTextureLock(rootId)     acquireAssetTextureLock(rootId)  ← BLOCKS
ensureTexturesLoaded(rootId)            ...waiting...
makeMeshesFromCPUBuffers(#1)            ...waiting...
releaseAssetTextureLock(rootId)     ← unblocks
                                    ensureTexturesLoaded(rootId)     ← no-op (already done)
                                    makeMeshesFromCPUBuffers(#2)
                                    releaseAssetTextureLock(rootId)
```

Uploads from *different* assets run concurrently without contention — each asset has its own lock.

### Texture Cache Key Uniqueness (`objectIdentityURL`)

`TextureLoader` caches textures by URL. USDZ files with bracket-notation paths (e.g., `file:///scene.usdz[0/texture.png]`) produce stable, unique URLs via `parseUSDZBracketPath`. But when an MDLTexture has no parseable bracket path, a fallback URL is generated from the pointer identity of the `MDLTexture` object:

```swift
URL(string: "mdl-obj-\(UInt(bitPattern: ObjectIdentifier(mdlTex)))")!
```

This ensures every unnamed or identically-named texture gets a unique cache key, preventing one texture from being substituted for another on meshes that happen to share a texture name.

The same identity URL is used as `material.baseColorURL`, so `BatchingSystem.getMaterialHash` also distinguishes these textures correctly — which prevents wrong textures from appearing after static batching.

---

## Warm / Cold CPU Residency

By default every registered root asset is **CPU-warm**: its `MDLAsset` and all child `CPUMeshEntry` objects live in RAM indefinitely. That is the right default for scenes that fit in RAM, but for extremely large world-scale scenes (hundreds of open-world chunks, each with its own USDZ) it is desirable to evict CPU-heap geometry data for assets that the camera is far from.

### `releaseWarmAsset` — Free CPU Heap Without Destroying the Entity

```swift
ProgressiveAssetLoader.shared.releaseWarmAsset(rootEntityId: rootId)
```

Releases the `MDLAsset` and all child `CPUMeshEntry` objects for `rootId`, freeing CPU heap memory. The root is now **CPU-cold**.

The rehydration context (URL + loading policy) stored at stub-registration time is **retained** — the asset can be re-parsed from disk transparently when the camera re-approaches.

`releaseWarmAsset` does **not** destroy ECS entities, streaming components, or GPU-resident meshes. GPU eviction remains the responsibility of `GeometryStreamingSystem.evictLRU`.

### Transparent Cold Re-Stream

When `loadMeshAsync` is called for a child entity whose root is cold (i.e. `retrieveCPUMesh` returns `nil` AND `isColdRoot` is true), `GeometryStreamingSystem` automatically calls `rehydrateColdAsset`:

```
loadMeshAsync(entityId: building_42)
  → retrieveCPUMesh(building_42) = nil
  → isColdRoot(rootId) = true
  → rehydrateColdAsset(rootId, context)      ← re-parse from disk
      getOrCreateRehydrationTask(rootId)     ← exactly one Task per root
      Mesh.parseAssetAsync(context.url)      ← USDZ re-read
      storeCPUMesh for all children          ← rebuild CPU registry
      storeAsset + markAsWarm                ← root is warm again
  → retrieveCPUMesh(building_42) = CPUMeshEntry
  → uploadFromCPUEntry                       ← normal CPU→Metal upload
```

Concurrent child uploads for the same cold root all await the **same** `Task<Bool, Never>` — `getOrCreateRehydrationTask` ensures only one re-parse runs per root regardless of how many children simultaneously detect the cold state.

### Warm/Cold State Machine

```
                         storeAsset + registerChildren
                         storeRootRehydrationContext
                                  │
                                  ▼
                             [CPU-warm]
                           (default state)
                                  │
              releaseWarmAsset()  │
                                  ▼
                             [CPU-cold]
                       MDLAsset released
                    CPUMeshEntry[] cleared
                    rehydrationContext alive
                                  │
     rehydrateColdAsset() + markAsWarm()
                                  │
                                  ▼
                             [CPU-warm]
                       MDLAsset restored
                    CPUMeshEntry[] rebuilt
```

`removeOutOfCoreAsset` exits the state machine entirely — ECS entities remain but all registry entries (warm or cold) are cleared and the rehydration context is removed.

---

## Lifetime and Cleanup

When the root entity is destroyed, call:

```swift
ProgressiveAssetLoader.shared.removeOutOfCoreAsset(rootEntityId: rootId)
```

This releases all `CPUMeshEntry` references, the `MDLAsset`, warm/cold state, and the rehydration context — freeing all CPU-heap geometry data for all 500 buildings.

To free CPU heap without destroying the entity (e.g., for a far chunk that may return):

```swift
ProgressiveAssetLoader.shared.releaseWarmAsset(rootEntityId: rootId)
// Entity remains registered; re-approach triggers transparent cold re-stream from disk.
```

---

## Tuning Reference

| Property | Default | Effect |
|----------|---------|--------|
| `MemoryBudgetManager.meshBudget` | device-set | GPU memory ceiling; all `AssetProfiler` thresholds are expressed as fractions of this value |
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
