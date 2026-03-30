# UntoldEngine Tile-Based Streaming Architecture

## Overview

UntoldEngine implements a two-tier proximity-based geometry streaming system for large outdoor scenes on Apple platforms (macOS, visionOS). The system streams geometry in and out of GPU memory based on camera distance, using a spatial octree for efficient range queries.

**Tier 1 — Tile streaming** (`TileComponent`): coarse-grained. Each tile is a whole USDC file covering a bounded region of the world. Tiles load and unload as the camera moves through the scene.

**Tier 2 — OCC mesh streaming** (`StreamingComponent`): fine-grained. Inside a loaded tile, individual mesh stubs upload to the GPU incrementally, governed by distance bands and memory budgets.

---

## Data Model

### Manifest (JSON)

A scene is described by a manifest file listing tiles. Each tile entry specifies:

| Field | Description |
|---|---|
| `tile_id` | Human-readable name (e.g. `"tile_3_2"`) |
| `path_relative_to_manifest` | Path to the USDC file, relative to the manifest |
| `file_size_bytes` | Pre-computed file size used by the memory budget gate |
| `bounds.min` / `bounds.max` | World-space AABB used for octree insertion and frustum tests |
| `center` | World-space center (used for distance calculations) |
| `streaming_radius` | *(optional)* Per-tile load threshold; falls back to `streaming_defaults` |
| `unload_radius` | *(optional)* Per-tile unload threshold; falls back to `streaming_defaults` |
| `prefetch_radius` | *(optional)* Per-tile prefetch start; falls back to `streaming_defaults`, then auto |
| `priority` | *(optional)* Load order when multiple tiles are candidates |

The `streaming_defaults` block sets scene-wide fallback values for all per-tile fields. An optional `shared_bucket` entry holds geometry that spans many tiles and should always be resident (loaded as soon as the camera enters the scene).

### ECS Components

- **`TileComponent`** — attached to every tile stub entity created by `loadTiledScene()`. Carries all metadata needed for the streaming bootstrap and teardown lifecycle.
- **`StreamingComponent`** — attached to individual OCC mesh stubs created inside a loaded tile. Governs per-mesh load/unload within the second streaming tier.
- **`RenderComponent`** — added to an entity only after its GPU geometry upload completes. Absence means the entity is invisible to culling and rendering.

---

## Tile Lifecycle

### States

```
unloaded → parsing → parsed → unloading → unloaded
                  ↘ failed → (retry backoff) → unloaded
```

| State | Meaning |
|---|---|
| `.unloaded` | Stub registered; no geometry in flight |
| `.parsing` | `setEntityMeshAsync` Task is running; GPU upload in progress |
| `.parsed` | Tile's child entities exist and are rendering (or uploading via OCC) |
| `.failed` | Last parse attempt failed; exponential backoff before retry (5 s → 10 s → 20 s → max 60 s) |
| `.unloading` | Teardown in progress; blocks re-dispatch for this tick |

### 1. Scene Load (`loadTiledScene`)

1. Locates and decodes the manifest JSON (no geometry parsed).
2. Destroys all existing scene entities and calls `GeometryStreamingSystem.shared.reset()` to clear all tile and mesh tracking sets, cancel in-flight tasks, and reset camera velocity.
3. Creates a default camera and directional light.
4. Registers one lightweight stub entity per tile inside a single `withWorldMutationGate`. Each stub receives:
   - Identity world transform
   - `LocalTransformComponent.boundingBox` set to the tile's world-space AABB
   - `TileComponent` in `.unloaded` state, with all radii and metadata from the manifest
   - Octree registration (so `queryNear` finds it immediately)

No geometry is parsed or uploaded at this stage. The whole function completes in milliseconds regardless of scene size.

### 2. Streaming Update (per tick, ~100 ms steady / ~16 ms burst)

`GeometryStreamingSystem.update(cameraPosition:deltaTime:)` runs each frame. It queries the octree for all entities within `maxQueryRadius` (default 500 m). This is a **query ceiling**, not a load radius — it just defines the outer bound of the candidate pool. Each entity in the result is then tested against its own per-entity radii (`effectivePrefetchRadius`, `streamingRadius`, `unloadRadius`) to decide what actually happens. `maxQueryRadius` must be large enough to cover the largest `unloadRadius` in the scene, or far tiles will never be found for out-of-range teardown.

**Camera velocity** is computed each tick via exponential smoothing and used to project a *predictive position* (`velocityLookAheadTime = 0.5 s` ahead). Tile distances are scored against `min(actual, predictive)` so tiles in the direction of travel are prioritised before the camera physically arrives.

**Tile load pass** — for each `.unloaded` stub:

1. Computes effective distance using the predictive position.
2. Tests against `effectivePrefetchRadius` (see [Prefetch Radius](#prefetch-radius)).
3. Applies the **frustum gate** (padded AABB vs camera frustum, `tileFrustumGatePadding = 20 m`). Tiles fully outside the frustum are skipped this tick.
4. Eligible tiles are sorted by priority (descending) then distance (ascending).
5. Up to `maxConcurrentTileLoads` (default 2) are dispatched via `loadTile()`, subject to the **memory budget gate**: the total parse memory in flight must stay under `tileParseMemoryBudgetMB` (200 MB), with a guarantee that at least one tile always loads even if it alone exceeds the budget.

**Tile unload pass** — three sub-passes each tick. All passes use `min(actual, predictive)` distance, matching the load pass, so a tile the camera is approaching is not torn down mid-parse:

1. **Nearby tiles** still in the octree result but beyond `unloadRadius`.
2. **Loaded tiles** that drifted entirely outside `maxQueryRadius`.
3. **Parsing tiles** that drifted outside `maxQueryRadius` (fast movement or teleport).

Both `.parsing` and `.parsed` tiles go through the **grace period** (see [Unload Grace Period](#unload-grace-period)) before actual teardown (passes 1 and 2). Pass 3 tiles are genuinely beyond the 500 m query radius and are cancelled without a grace period — boundary oscillation cannot occur at that range. At most `maxTileUnloadsPerUpdate` (default 2) tiles are torn down per tick to spread GPU buffer releases across frames.

### 3. `loadTile(entityId:)`

1. Sets `tileComp.state = .parsing`; reserves a slot in `activeTileLoads`.
2. Creates a dedicated child *mesh entity* under the tile stub (`capturedMeshEntityId`) inside `withWorldMutationGate`. This guarantees `unloadTile`'s `collectTileDescendants` always has at least one child to destroy, regardless of how many submeshes the tile contains.
3. Registers `capturedMeshEntityId → tileEntityId` in `meshEntityToTileEntity` for O(1) OCC upload counter updates.
4. Spawns a Swift `Task` calling `setEntityMeshAsync(entityId: capturedMeshEntityId, streamingPolicy: .auto)`.
   - `.auto` policy: the admission gate chooses `fullLoad` (parse + immediate GPU upload) or `outOfCore` (parse to CPU heap, upload stubs via `StreamingComponent`) based on tile file size and available RAM.
5. Completion callback (fires on the main thread):
   - **Zombie-state guard** — checks `tc.state == .parsing`. If `unloadTile` ran while the parse was in flight, the state will be `.unloading`. The callback discards the result, destroys the pre-created child entity, and returns without marking the tile loaded.
   - On confirmed `.parsing`: transitions to `.parsed`, seeds `totalOCCStubs` from `countOCCDescendants`.
   - On failure: destroys child entity, increments `failureCount`, sets state to `.failed` (retry backoff).
   - **`defer { releaseActiveTileLoad }`** — the concurrency slot is freed on all exit paths.

### 4. OCC Sub-Mesh Upload (second streaming tier)

For large tiles using the `outOfCore` path, `setEntityMeshAsync` creates child OCC stub entities under `capturedMeshEntityId`, each with a `StreamingComponent` in `.unloaded` state. `GeometryStreamingSystem.update()` iterates these stubs in a separate pass — uploading them in batches governed by `maxConcurrentLoads` (3), with a `nearBandMaxConcurrentLoads = 1` serial slot for the closest mesh stubs so distance-ordered appearance is preserved.

Each completed OCC upload calls `incrementParentTileOCCCount(for:)`, which increments `tileComp.uploadedOCCStubs`. The `visualState` property (`TileVisualState`) tracks upload progress: `.empty` → `.partial` → `.usable` (≥ 50% uploaded) → `.complete`.

### 5. `unloadTile(entityId:)`

1. Captures `wasParsing = (tileComp.state == .parsing)`.
2. Sets `tileComp.state = .unloading`; cancels `tileComp.loadTask`.
3. If `wasParsing`: removes from `loadingTileEntities` and bails out. The Task completion callback will find `.unloading`, discard the result, and dispatch deferred child-entity cleanup — this avoids a concurrent ECS write race since `setEntityMeshAsync` may still be running.
4. If `.parsed`: calls `collectTileDescendants(entityId)` to walk the child tree, cancelling any in-flight OCC streaming tasks. Calls `destroyEntity` on all descendants + `finalizePendingDestroys()`. This releases GPU buffers, removes octree entries, releases `MeshResourceManager` refs, and unregisters from `MemoryBudgetManager`.
5. Calls `ProgressiveAssetLoader.shared.removeOutOfCoreAsset(rootEntityId:)` to free CPU-heap MDLAsset data for out-of-core tiles.
6. Resets `totalOCCStubs`, `uploadedOCCStubs`, `pendingUnloadSince` to 0.
7. Sets `tileComp.state = .unloaded`; removes from `loadedTileEntities`.

The tile stub entity itself is **never destroyed**. It stays in the octree as a cheap placeholder so the streaming system reloads the tile on the next approach.

---

## Prefetch Radius

The **prefetch radius** decouples "when the tile starts loading" from "when the tile must be visible." Tiles begin parsing as soon as the camera enters `effectivePrefetchRadius`, which is larger than `streamingRadius`. By the time the camera reaches `streamingRadius`, the parse is already complete and the geometry appears without a blank frame.

```
                  camera direction →
─────────────────────────────────────────────────────
                  prefetchRadius (auto: midpoint)
                  │           streamingRadius
                  │           │        unloadRadius
                  ▼           ▼        ▼
  · · · · · · · ·|· · · · · ·|████████|· · · · · · ·
                 start       tile is  stop
                 loading     visible  loading
```

`effectivePrefetchRadius` resolution (in priority order):
1. Per-tile `prefetch_radius` field in the manifest
2. Scene-wide `prefetch_radius` in `streaming_defaults`
3. **Auto**: `streamingRadius + (unloadRadius − streamingRadius) × 0.5`

For the typical `streamingRadius = 80 m`, `unloadRadius = 120 m` default, auto resolves to **100 m** — giving 20 m of prefetch advance at walking speed (~1.5 m/s) that is ~13 seconds of loading headroom, well above the 1–2 s parse time for a 15–20 MB tile.

---

## Unload Grace Period

When a `.parsed` tile (with visible GPU geometry) first exceeds `unloadRadius`, `pendingUnloadSince` is set to the current time. The tile is only torn down once `CFAbsoluteTimeGetCurrent() − pendingUnloadSince ≥ unloadGracePeriod` (default **3 seconds**).

If the camera re-enters `unloadRadius` before the grace period expires, `pendingUnloadSince` is reset to 0 and the tile stays loaded with no interruption. This eliminates rapid load/unload oscillation at tile boundaries (the most common cause of flickering at tile edges).

Both `.parsing` and `.parsed` tiles honour the grace period. `.parsing` tiles have no visible geometry, but the grace window lets an in-flight parse complete naturally rather than being cancelled and immediately re-dispatched. Immediate cancellation was a false economy: the cancelled Swift Task still ran to completion before the state could reset, so the tile was re-dispatched on the very next tick, creating a tight load-cancel loop.

`pendingUnloadSince` is also reset in `unloadTile()` so the counter is clean for the next load/unload cycle.

---

## Memory Management

- **`MemoryBudgetManager`** tracks geometry and texture GPU bytes against per-platform budgets (probed at startup).
- Before dispatching any tile load, the system checks `shouldEvictGeometry()`. If true, it runs `TextureStreamingSystem.shedTextureMemory` and `evictLRU` (capped at 8 evictions) before attempting a tile parse. This prevents a tile's multi-MB commit from pushing RAM over budget.
- **LRU eviction** scores loaded streaming entities by camera distance × `evictionDistanceWeight` + GPU size × `evictionSizeWeight`. Entities within `visibleEvictionProtectionRadius` (30 m) are protected.
- **OS memory pressure** callbacks (`DispatchSource.makeMemoryPressureSource`) set a flag; eviction is deferred to the next `update()` tick to stay single-threaded.
- **`tripleVisibleEntities.clearAll()`** — called in `finalizePendingDestroys()` to clear all triple-buffer slots so the renderer does not read stale entity IDs after a scene reload.

---

## Threading Model

- All ECS mutations (`createEntity`, `registerComponent`, `destroyEntity`, `finalizePendingDestroys`) must run on the **main thread**.
- Background Swift Tasks handle disk I/O, USDC parsing, and CPU→Metal buffer copies.
- `withWorldMutationGate` is an activity counter, not a mutex. It does **not** provide mutual exclusion — it signals that ECS mutations are occurring.
- `scene.exists(entityId)` guards before every ECS write in upload completions prevent writes to entities destroyed while an upload was in flight (cooperative cancellation race).
- Tile tracking sets (`loadedTileEntities`, `loadingTileEntities`, `activeTileLoads`, `meshEntityToTileEntity`) are protected by `stateLock` and accessed only through accessor methods.

---

## Scene Reload Safety

When `loadTiledScene()` is called for a second time:

1. All existing entities are destroyed via `destroyEntity` + `finalizePendingDestroys()`.
   - `removeTileComponent` (the `ComponentRegistry` cleanup handler for `TileComponent`) cancels the tile's in-flight `loadTask` and calls `GeometryStreamingSystem.shared.unregisterTileEntity(entityId)`, removing stale IDs from all four tracking sets atomically.
2. `GeometryStreamingSystem.shared.reset()` is called explicitly to clear any remaining tracking state, cancel all streaming tasks, and reset camera velocity.
3. New stubs are registered for the incoming scene.

Any tile Task that was already in flight and completes after step 1–2 finds `scene.exists(entityId) == false` and returns early via the `guard` in its completion closure. The `defer`-based slot release still fires, so no concurrency slot is leaked.

---

## Key Design Parameters

| Property | Default | Notes |
|---|---|---|
| `maxConcurrentTileLoads` | 2 | Hard cap on simultaneous tile parses |
| `tileParseMemoryBudgetMB` | 200 MB | Total CPU parse memory allowed in flight |
| `maxTileUnloadsPerUpdate` | 2 | Max tile teardowns per streaming tick |
| `unloadGracePeriod` | 3.0 s | Hold time before tearing down a visible tile |
| `maxConcurrentLoads` (OCC) | 3 | Simultaneous mesh-level GPU uploads |
| `nearBandMaxConcurrentLoads` | 1 | Serial slot for closest mesh stubs |
| `maxUnloadsPerUpdate` (mesh) | 12 | Max mesh-level unloads per tick |
| `updateInterval` | 100 ms | Streaming tick rate (steady state) |
| `burstTickInterval` | 16 ms | Tick rate during near-band backlog |
| `frustumGatePadding` (mesh) | 5 m | Frustum pad for mesh-level candidates |
| `tileFrustumGatePadding` | 20 m | Frustum pad for tile-level candidates |
| `velocityLookAheadTime` | 0.5 s | Predictive position look-ahead |
| `velocityLookAheadMinSpeed` | 1.5 m/s | Minimum speed to activate look-ahead |
| `visibleEvictionProtectionRadius` | 30 m | Distance inside which eviction is blocked |
