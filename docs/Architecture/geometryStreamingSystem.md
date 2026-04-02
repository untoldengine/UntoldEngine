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

**OS pressure bypass** — if a `pendingPressureRelief` flag is set (fired by the OS pressure callback on a background queue), the throttle check is bypassed entirely for that call. This guarantees eviction runs within one frame (≤ 11 ms at 90 fps) rather than waiting up to 100 ms for the next normal tick. Without this, a `.critical` signal arriving right after a tick would sit unprocessed for the full throttle interval — longer than visionOS's kill window.

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

Before dispatching, the scheduler applies four guards in order:

1. **Tile ownership** (`isTileOwned`) — the entity must be a descendant of a `TileComponent` entity. Non-tile-owned entities are rejected immediately and their state is never mutated. `StreamingComponent` is an internal, tile-subordinate mechanism; it is not valid on standalone entities. See [StreamingComponent Ownership Model](#streamingcomponent-ownership-model) below.
2. **CPU-entry readiness** — OOC entities whose `CPUMeshEntry` is not yet stored in `ProgressiveAssetLoader` are skipped. This prevents pre-streaming stubs from holding slots while registration is still running.
3. **Prewarm-active deferral** — entities for roots whose background texture prewarm is still running are skipped. Dispatching while the prewarm holds the per-asset texture lock would block all concurrent slots for the remaining prewarm duration. Slots stay free until `isPrewarmActive` returns `false`.
4. **Per-candidate geometry budget check** — if the candidate's estimated GPU footprint would exceed the geometry budget, `evictLRU` is called first.

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

## StreamingComponent Ownership Model

`StreamingComponent` is an **internal, tile-subordinate** component. It is not a public API for external callers.

- Only entities that are **descendants of a `TileComponent` entity** may have an active `StreamingComponent`. `loadMesh()` enforces this with the `isTileOwned()` guard, which walks the `ScenegraphComponent.parent` chain and returns `false` for any entity that has no `TileComponent` ancestor.
- `StreamingComponent` stubs are created internally by `setEntityMeshAsync` for the out-of-core (OCC) path when a tile file is large enough to be split into sub-mesh stubs. External callers never attach `StreamingComponent` directly.
- `enableStreaming()` is `internal`; it is not part of the public API.

### What to use instead

| Use case | API |
|---|---|
| Streamable geometry (terrain, city blocks, large scenes) | `loadTiledScene(manifest:withExtension:completion:)` + manifest JSON |
| Always-resident objects (characters, props, HUD elements) | `setEntityMeshAsync(entityId:filename:withExtension:completion:)` |

`loadTiledScene` is the **only public entry point** for streamable scene geometry. It decodes the manifest, calls the internal `registerTiledScene()`, and hands off all streaming lifecycle management to `GeometryStreamingSystem`.

```
isTileOwned(entityId:) — private helper in GeometryStreamingSystem+MeshStreaming.swift
  Walks ScenegraphComponent.parent chain upward.
  Returns true only if a TileComponent is found somewhere in the ancestry.
  Returns false for any standalone entity (no parent chain, or chain ends without a tile).
```

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
| Combined | `shouldEvict()` | Geometry pool ≥ 85% of `geometryBudget` **OR** texture pool ≥ 85% of `textureBudget` |
| Geometry only | `shouldEvictGeometry()` | Mesh allocations alone ≥ 85% of `geometryBudget` |

**Why two signals?** `TextureStreamingSystem` upgrades visible textures to higher resolutions after meshes load. Those upgrades increase `totalTextureMemory` in `MemoryBudgetManager`. If the load gate used the combined signal, texture upgrades on already-loaded meshes would silently prevent new mesh loads — even when the geometry-only footprint is well within budget. The split pools (`geometryBudget` + `textureBudget`) ensure each domain has an independent ceiling so neither can starve the other.

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
6. Accepts an optional `maxEvictions` cap (default `Int.max`). The OS pressure path passes `16` per call — this bounds single-frame work during a burst. Any remaining candidates spill to subsequent ticks.

The `sizeFactor` in the eviction score is normalized against `geometryBudget` (not the combined budget), so a mesh consuming 80% of the geometry pool scores correctly rather than appearing to consume only ~48% of a combined total.

### Step 3 — OS memory pressure (proactive, out-of-band)

In addition to the per-tick budget checks above, `MemoryBudgetManager` subscribes to OS memory pressure events via `DispatchSource.makeMemoryPressureSource`:

| OS signal | Response | `maxEntities` |
|---|---|---|
| `.warning` | Texture shed | 8 |
| `.critical` | Texture shed + double geometry eviction pass (capped at 16 per pass) + CPU heap release | 20 |

The OS callback fires on a background queue and sets a `pendingPressureRelief` flag on `GeometryStreamingSystem`. The flag is drained at the **start of the next `update()` tick** on the main thread, so all eviction work stays on the same thread as the rest of the streaming system. This prevents the OS from silently escalating to `.critical` and terminating the process — on visionOS in particular, the window between `.warning` and process kill can be under a second.

**CPU heap release on critical pressure** — `evictLRU` only frees GPU Metal buffers tracked by `MemoryBudgetManager`. The OS measures total process memory, which includes `ProgressiveAssetLoader.rootAssetRefs` (the live `MDLAsset` tree and all child `CPUMeshEntry` vertex/index buffers). For a 500-building scene this CPU heap can reach hundreds of megabytes. On `.critical`, after the two geometry eviction passes, `GeometryStreamingSystem` calls `ProgressiveAssetLoader.shared.releaseWarmAsset(rootEntityId:)` on every warm root. This frees the CPU heap immediately. The rehydration context (asset URL + loading policy) is retained, so a cold re-stream from disk is transparent when the camera re-approaches.

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
- **Split geometry/texture pools** (`geometryBudget` + `textureBudget`) give each domain an independent ceiling and high-water mark — a texture-heavy scene cannot crowd out geometry loads and vice versa
- **Runtime device budget probing** — `geometryBudget` and `textureBudget` are derived at init from `MTLDevice.recommendedMaxWorkingSetSize` (macOS) or `os_proc_available_memory()` (visionOS/iOS) rather than hardcoded platform defaults; budgets adapt to actual device headroom
- **SceneRootTransform consistency** — all distance calculations (GeometryStreamingSystem, LODSystem, inline LOD upload helpers) pass camera position through `SceneRootTransform.shared.effectiveCameraPosition()` so XR physical-head movement and scene-root translations are applied uniformly; raw `cameraComponent.localPosition` is never used directly for distance math
- **Camera sync always runs** — `syncStreamingCameraPosition()` executes every frame regardless of the `loading` flag; decoupling it from the loading guard prevents the streaming camera from freezing while an asset load is in flight
- **OS memory pressure subscription** — `DispatchSource.makeMemoryPressureSource` fires proactive texture shedding and geometry eviction before the OS escalates to process termination; the response runs on the next `update()` tick to stay single-threaded
- **evictLRU per-call cap** — the `maxEvictions` parameter (default `Int.max`) bounds single-frame eviction work; the OS pressure path uses 16 per pass so a `.critical` burst doesn't spike one frame; remaining candidates spill to subsequent ticks
- **CPU heap release on critical pressure** — on `.critical`, after geometry eviction, `ProgressiveAssetLoader.releaseWarmAsset()` is called for every warm root, freeing the MDLAsset CPU heap the OS measures; rehydration context survives so cold re-stream from disk is transparent

---

## Tile-Level Streaming

The tile-level streaming layer sits **above** the mesh-level OOC streaming. For full documentation, architecture diagrams, and tuning guidance see [`docs/Architecture/tilebasedstreaming.md`](tilebasedstreaming.md). This section summarises the key design decisions that interlock with the mesh-level system documented above.

### Per-frame passes in `update()` (tile layer, in order)

1. **Tile load pass** — dispatches `.unloaded` stubs within `effectivePrefetchRadius` (frustum-gated, budget-gated, up to `maxConcurrentTileLoads`). Tiles with LOD levels are gated: the full tile only loads when the camera is within the finest LOD switch distance.
2. **Tile unload pass** — three sub-passes (nearby beyond `unloadRadius`, `.parsed` outside query radius, `.parsing` outside query radius).
3. **HLOD streaming pass** — for each tile stub, loads or unloads the HLOD proxy based on camera distance vs `hlodSwitchDistance` and `tileComp.state`. Uses `hlodHysteresisFactor` (default 0.90) to prevent thrashing at boundaries. Capped by `maxConcurrentHLODLoads` (default 4).
4. **HLOD out-of-range cleanup** — unloads HLOD entities for tiles that drifted entirely outside `maxQueryRadius`.
5. **Per-tile LOD streaming pass** — for each tile stub, finds the target LOD level for the current distance with hysteresis (`lodHysteresisFactor`, default 0.90). Skips when HLOD is resident (avoids dual representation). Loads target; unloads others; unloads all when tile is `.parsed`. Capped by `maxConcurrentLODLoads` (default 4).
6. **Per-tile LOD out-of-range cleanup** — unloads LOD entities for tiles outside `maxQueryRadius`.

### TileComponent

Tile stubs carry a `TileComponent` (no `StreamingComponent`, no `RenderComponent`):

| Field | Purpose |
|---|---|
| `tileURL` | Absolute URL of the USDC file on disk |
| `fileSizeBytes` | Pre-computed file size for the memory budget gate |
| `streamingRadius` | Visual display threshold — tile is rendered once parsed |
| `prefetchRadius` | Background load threshold (`> streamingRadius`); auto = midpoint of stream/unload gap |
| `unloadRadius` | Distance beyond which teardown is scheduled |
| `priority` | Load-order priority when multiple tiles are candidates |
| `tileId` | Debug identifier matching the manifest `tile_id` |
| `state` | `.unloaded → .parsing → .parsed → .unloading` |
| `pendingUnloadSince` | CFAbsoluteTime when tile first exceeded `unloadRadius`; 0 = in range |
| `loadTask` | The in-flight Swift `Task` (cancelled on teardown) |
| `meshEntityId` | The dedicated mesh-child entity ID; stored so the asset-loading timeout guard can force-close `AssetLoadingGate` if `loadTextures()` hangs |
| `hlodURL` | URL of the HLOD proxy USDC, if present in the manifest |
| `hlodEntityId` | ECS entity holding the HLOD mesh; `.invalid` when unloaded |
| `hlodState` | HLOD lifecycle: `.unloaded → .loading → .loaded → .unloading` |
| `hlodSwitchDistance` | Camera distance beyond which the HLOD is shown |
| `hlodLoadTask` | In-flight HLOD load `Task` (cancelled before `hlodState = .unloading`) |
| `lodLevels` | `[TileLODLevel]` — per-tile intermediate LOD entries parsed from manifest |

### Tile Load Pass (inside `update()`)

After the mesh-level scan, a second pass handles tile stubs:

1. For each `.unloaded` stub within `effectivePrefetchRadius + 1.0` (not `streamingRadius` — tiles start loading before the camera enters the display zone):
   - Scores distance against the predictive (look-ahead) camera position.
   - Applies the **frustum gate** (`tileStreamingFrustum`, padded by `tileFrustumGatePadding = 20 m`).
   - Collects as a load candidate.
2. **Geometry budget gate** — if `shouldEvictGeometry()`, runs texture shedding and `evictLRU` (capped at 8) before dispatch.
3. Up to `maxConcurrentTileLoads` (default **2**) dispatched via `loadTile()`, subject to the `tileParseMemoryBudgetMB` (200 MB) in-flight gate.

### Tile Unload Pass (inside `update()`)

Three sub-passes each tick, capped at `maxTileUnloadsPerUpdate` (default **2**) total teardowns:

1. **Nearby tiles beyond `unloadRadius`** — differentiates by state:
   - `.parsing` (not yet visible) — cancelled immediately, no grace delay.
   - `.parsed` (visible geometry) — starts or checks the **unload grace period** (`unloadGracePeriod = 3 s`). Tile only tears down after being out of range for the full grace period; the timer resets if the camera returns inside `unloadRadius`.
2. **`.parsed` tiles outside the octree query radius** — same grace period logic.
3. **`.parsing` tiles outside the octree query radius** — cancelled immediately to prevent ghost geometry flashes on fast movement or teleports.

### Design Decisions

- **Prefetch radius decouples load from display** — tiles start loading at `effectivePrefetchRadius` (auto: midpoint of stream/unload gap) so the parse completes before the camera reaches the visual zone, eliminating blank-screen pops on tile entry.
- **Grace period prevents oscillation** — a 3-second hold on `.parsed` tile teardown stops rapid load/unload cycles at tile boundaries, which was the primary cause of flickering in large scenes.
- **`maxTileUnloadsPerUpdate = 2`** — spreading GPU buffer releases across frames prevents a single-frame blank when many tiles leave range simultaneously.
- **`maxConcurrentTileLoads = 2`** — two concurrent parses balance throughput for large scenes against RAM spike risk. Each parse calls `MDLAsset(url:)` on a full USDC file; the `tileParseMemoryBudgetMB` gate serialises naturally when a large tile saturates the budget.
- **`blockRenderLoop: false` on all tile/LOD/HLOD loads** — `setEntityMeshAsync` is called with `blockRenderLoop: false` so that `AssetLoadingGate.isLoadingAny` is not held `true` during the (potentially multi-second) parse. Without this, concurrent parses freeze `visibleEntityIds` updates and stall the render loop.
- **Hysteresis on LOD/HLOD transitions** — `lodHysteresisFactor` (default 0.90) and `hlodHysteresisFactor` (default 0.90) add a 10% inner band so the camera must move meaningfully past a switch boundary before the current representation is unloaded. Without hysteresis, frame-to-frame distance jitter causes rapid load/unload cycles that freeze the engine.
- **`cancelPendingEntities` before entity destruction** — when `unloadLODLevel` or `unloadHLOD` tears down child entities, it first calls `BatchingSystem.shared.cancelPendingEntities(_:)` with the render descendant IDs, purging them from all pending batching queues. This prevents "entity is missing" errors when the batching tick tries to process additions for entities that were destroyed between event queuing and tick processing.
- **`notifyTileEntitiesResident` replaces the event storm** — tile/LOD/HLOD load completions call `BatchingSystem.shared.notifyTileEntitiesResident(_:)` instead of the former two-step `queueResidencyEventsForRenderDescendants` + `notifyTileParsedEntities` pairing. The single call directly registers entities in the batching system's pending additions and marks them for quiescence bypass, avoiding hundreds of individual `AssetResidencyChangedEvent` objects through `SystemEventBus`.
- **Identity world transform on stubs** — tile geometry is exported in world space; no runtime coordinate conversion needed.
- **`.auto` streaming policy** — tiles use the same admission gate as regular assets; unexpectedly large tiles are gracefully rejected and retried rather than crashing.
- **Zombie-state guard in completion** — completion callback checks `tc.state == .parsing`. If `unloadTile` ran mid-parse (state is `.unloading`), result is discarded and the pre-created child entity is cleaned up — stub never enters a "geometry missing" zombie state.
- **`defer` slot release** — `releaseActiveTileLoad` in `defer` frees the concurrency slot on all exit paths (success, failure, cancelled-state early return).
- **`removeTileComponent` deregisters from streaming system** — cancels in-flight `loadTask` and calls `GeometryStreamingSystem.shared.unregisterTileEntity(entityId)` to atomically remove the entity from all four tile tracking sets (`loadedTileEntities`, `loadingTileEntities`, `activeTileLoads`, `meshEntityToTileEntity`).
- **`reset()` clears tile tracking sets** — called by `loadTiledScene()` after scene destruction so no stale entity IDs from the previous scene persist into the new scene's streaming passes.
- **HLOD unload race** — `hlodState = .unloading` is set **before** `hlodLoadTask.cancel()`. The load-completion callback checks `hlodState` before marking `.loaded`; setting it first ensures the callback always discards a racing in-flight result.
- **Per-tile LOD follows the same race fix** — `level.state = .unloading` is set before `level.loadTask?.cancel()`.
- **LOD unload-all on tile parse** — when `loadTile`'s completion callback fires (state transitioning to `.parsed`), both `unloadHLOD(entityId:)` and `unloadAllLODLevels(entityId:)` are called. The full tile has taken over all distance bands; intermediate representations are no longer needed.
- **`loadedLODEntities` tracking set** — mirrors `loadedTileEntities` for the LOD layer. Allows `reset()` to cancel all in-flight LOD tasks and `loadTiledScene()` second-call safety to clear stale LOD entity IDs.
- **`AssetLoadingGate` timeout** — `meshEntityId` is stored in `TileComponent` so the timeout guard can call `AssetLoadingState.shared.finishLoading(entityId: meshEntityId)` without an O(n) map scan if `loadTextures()` hangs and the gate would otherwise remain open permanently.
