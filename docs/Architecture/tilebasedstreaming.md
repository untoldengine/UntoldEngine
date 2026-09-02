# UntoldEngine Tile-Based Streaming Architecture

## Overview

UntoldEngine implements a multi-tier proximity-based geometry streaming system for large outdoor and indoor scenes on Apple platforms (macOS, visionOS). The system streams geometry in and out of GPU memory based on camera distance, using a spatial **octree** for efficient runtime range queries. Tile spatial partitioning in the manifest can follow either a uniform grid (v3) or a quadtree floor layout (v4) — see [Manifest Versions and Quadtree Partitioning](#manifest-versions-and-quadtree-partitioning).

**Tier 1 — Tile streaming** (`TileComponent`): coarse-grained. Each tile is a `.untold` binary file covering a bounded region of the world. Tiles load and unload as the camera moves through the scene.

**Tier 2 — OCC mesh streaming** (`StreamingComponent`): fine-grained. Inside a loaded tile, individual mesh stubs upload to the GPU incrementally, governed by distance bands and memory budgets.

**HLOD (Hierarchical Level of Detail)**: a coarse proxy mesh shown in place of an unloaded tile. Loaded when the tile leaves range, unloaded when the full tile finishes parsing. Provides continuity for distant geometry without holding the full tile in GPU memory.

**Per-tile LOD levels** (`TileLODLevel`): intermediate mesh representations that bridge the gap between the full tile (`streamingRadius`) and the HLOD switch distance. Finer than HLOD but coarser than the full tile; shown while the tile itself is unloaded and the camera is at mid-range.

**Hysteresis**: both HLOD and per-tile LOD transitions use a hysteresis band to prevent thrashing when the camera hovers near a switch boundary. A loaded representation is not unloaded until the camera moves meaningfully past the switch threshold (controlled by `hlodHysteresisFactor` and `lodHysteresisFactor`, both default 0.90 = 10% inner band). Without hysteresis, frame-to-frame distance jitter near a boundary causes rapid load/unload cycles that freeze the engine.

### Distance Band Summary

```
camera distance →  close        mid-range       far         very far
                   ──────────────────────────────────────────────────
full tile          ████████████
per-tile LOD 0                  ██████
per-tile LOD 1                          ██████
HLOD                                            ████████████████████
nothing visible    nothing                                  (if no HLOD)
```

| Band | Representation | Controlled by |
|---|---|---|
| `< streamingRadius` | Full tile (all submeshes) | `TileComponent.state == .parsed` |
| `streamingRadius … LOD[n].switchDistance` | Per-tile LOD n (coarser each step) | `TileLODLevel.state` |
| `> last LOD switchDistance … hlodSwitchDistance` | HLOD proxy mesh | `TileComponent.hlodState` |
| `> hlodSwitchDistance` | Nothing (tile + HLOD both unloaded) | — |

---

## Data Model

### Manifest (JSON)

A scene is described by a manifest file listing tiles.

#### Top-level manifest fields

| Field | Description |
|---|---|
| `version` | Integer schema version (`3` = uniform grid, `4` = quadtree floor) |
| `partitioning_mode` | *(v4 only)* `"uniform_grid"`, `"quadtree_floor"`, or `"kdtree_floor"` — describes how tiles were partitioned by the export pipeline |
| `streaming_defaults` | Scene-wide fallback radii and priority used when a tile omits its own values |
| `tiles` | Array of tile entries (see below) |
| `shared_bucket` | *(optional)* A single always-resident tile for geometry that spans many tiles |
| `tile_size` | *(optional)* Tile footprint in world units, used to align batch cell size with tile boundaries |
| `interior_zone` | *(v4 only)* Union AABB of all `ExteriorShell` tiles. Interior tiles are only loaded while the camera is inside this volume |
| `scene_lights` | *(optional)* Scene-authored lights exported from Blender. Registered only by an explicit `loadSceneAuthored(url:)` call; not tied to tile residency |
| `scene_cameras` | *(optional)* Scene-authored cameras exported from Blender. Registered only by an explicit `loadSceneAuthored(url:)` call; not tied to tile residency |
| `colorLUT` | *(optional, legacy)* Baked whole-transform color-grading LUT from the now-retired `--bake-color-management` flag. Only present in manifests produced before that flag was removed; still applied by `loadSceneAuthored(url:)` for backward compatibility |
| `colorGradeLUT` | *(optional)* Externally-authored `.cube` creative grade staged with `--color-grade-lut` (see [Using the Exporter](../API/UsingTheExporter.md)). Same rule as `scene_lights`/`scene_cameras`: registered only by an explicit `loadSceneAuthored(url:)` call; regular tile scene loading does not apply it |

The `streaming_defaults` block sets scene-wide fallback values for all per-tile fields. An optional `shared_bucket` entry holds geometry that spans many tiles and should always be resident (loaded as soon as the camera enters the scene). `scene_lights`, `scene_cameras`, and `colorGradeLUT` (or the legacy `colorLUT`) are persistent scene payload data available to `loadSceneAuthored(url:)`; regular tile scene loading does not register any of them automatically.

#### Per-tile entry fields

| Field | Description |
|---|---|
| `tile_id` | Human-readable name (e.g. `"tile_3_2"`) |
| `path_relative_to_manifest` | Path to the tile's `.untold` file, relative to the manifest |
| `file_size_bytes` | Pre-computed file size used by the memory budget gate |
| `bounds.min` / `bounds.max` | World-space AABB used for octree insertion and frustum tests |
| `center` | World-space center (used for distance calculations) |
| `streaming_radius` | *(optional)* Per-tile load threshold; falls back to `streaming_defaults` |
| `unload_radius` | *(optional)* Per-tile unload threshold; falls back to `streaming_defaults` |
| `prefetch_radius` | *(optional)* Per-tile prefetch start; falls back to `streaming_defaults`, then auto |
| `priority` | *(optional)* Load order when multiple tiles are candidates |
| `hlod_levels` | *(optional)* Array of HLOD proxy entries; see [HLOD](#hlod-hierarchical-level-of-detail) |
| `lod_levels` | *(optional)* Array of per-tile intermediate LOD entries; see [Per-tile LOD Levels](#per-tile-lod-levels) |
| `floor_id` | *(v4 only, optional)* Floor index within a building; `0` = ground floor |
| `quadtree_node_id` | *(v4 only, optional)* Spatial node identifier written by the export script. Underscore format (inline annotation): `"F02_Q_0_0_0"`. Compact format (pre-annotated phase12): `"F02Q100"`. **Runtime-significant**: the engine uses this field to build the [hierarchy-aware tile culling](#hierarchy-aware-tile-culling) index at scene load time |
| `semantic_tier` | *(v4 only, optional)* One of `"ExteriorShell"`, `"StructuralInterior"`, `"RoomContents"`, `"FineProps"`. The `streaming_radius` already encodes the correct load distance for the tier; no additional runtime logic is required |
| `interior` | *(v4 only, optional)* When `true`, this tile contains interior-only geometry and is gated on the camera being inside `interior_zone` |

#### HLOD manifest contract

```json
"hlod_levels": [
  { "path": "tiles/tile_0_0_hlod.untold", "switch_distance": 300.0 }
]
```

`switch_distance` is the camera distance beyond which the HLOD is shown in place of the tile. Typically a single entry per tile. The HLOD file is a coarse merged mesh exported by the content pipeline.

#### Per-tile LOD manifest contract

```json
"lod_levels": [
  { "path": "tiles/tile_0_0_lod1.untold", "switch_distance": 80.0 },
  { "path": "tiles/tile_0_0_lod2.untold", "switch_distance": 150.0 }
]
```

Entries **must be sorted ascending by `switch_distance`** (smallest = finest = closest). `switch_distance` is the camera distance beyond which this LOD is preferred over the finer level (or the full tile). The engine sorts entries on load, so unsorted manifests are corrected at runtime, but sorted manifests are the canonical contract.

### ECS Components

- **`TileComponent`** — attached to every tile stub entity created by `setEntityStreamScene()`. Carries all metadata needed for the streaming bootstrap and teardown lifecycle. Key fields added for HLOD and LOD:
  - `hlodURL`, `hlodEntityId`, `hlodState`, `hlodSwitchDistance`, `hlodLoadTask` — HLOD lifecycle
  - `lodLevels: [TileLODLevel]` — per-tile intermediate LOD entries
  - `meshEntityId` — the dedicated mesh-child entity ID, stored so the parse-timeout watchdog can force-close `AssetLoadingGate` if the parse Task becomes stuck
- **`TileLODLevel`** — one instance per LOD entry in the manifest. Carries `url`, `switchDistance`, `entityId`, `state` (`HLODAssetState`), and `loadTask`. Mirrors the HLOD lifecycle pattern.
- **`TileLODTagComponent`** — lightweight tag placed on render-descendant mesh entities spawned by the streaming system for per-tile LOD levels and HLODs. Carries a `levelIndex` used by the LOD debug renderer (`colorRenderablesByLOD`) and by `BatchingSystem.resolveBatchCandidate` to derive the batch LOD index for these entities (which have no `LODComponent`). `levelIndex` follows `lodDebugPalette`: 1 = LOD1 (green), 2 = LOD2 (blue), 5 = HLOD (cyan).
- **`StreamingComponent`** — attached to individual OCC mesh stubs created inside a loaded tile. Governs per-mesh load/unload within the second streaming tier.
- **`RenderComponent`** — added to an entity only after its GPU geometry upload completes. Absence means the entity is invisible to culling and rendering.

---

## Manifest Versions and Quadtree Partitioning

The manifest schema has evolved across two versions:

### v3 — Uniform Grid

`"partitioning_mode": "uniform_grid"` (or `version: 3` without the field). Tiles are laid out in a regular spatial grid. There is no `interior_zone` and no semantic tier hierarchy. This is the original format produced by the v1 Blender export script.

### v4 — Quadtree Floor

`"partitioning_mode": "quadtree_floor"` (or `version: 4`). Tiles are partitioned by a floor-level quadtree, typically for multi-storey indoor scenes. The export script assigns each tile a `quadtree_node_id` (e.g. `"F02_Q_0_0"` for inline annotation, or compact `"F02Q100"` for pre-annotated phase12 scenes) and a `semantic_tier` label.

### v4 — KD-tree Floor

`"partitioning_mode": "kdtree_floor"`. Identical to `quadtree_floor` in structure, but tiles were partitioned using a KD-tree instead of a quadtree. The KD-tree splits each floor's XY plane on the longer axis at the median object center, producing tiles that reflect actual geometry density rather than equal-area subdivisions. Tile node IDs use underscore format with `_K_` as the tree marker (e.g. `"F02_K_0_1_0"`). Use `--kdtree` in the exporter to produce this format.

**Semantic tiers** encode the expected load distance by naming convention — the export pipeline sets `streaming_radius` to the correct value for each tier, so the runtime treats them identically during streaming. The tiers are:

| Tier | Description |
|---|---|
| `ExteriorShell` | Outer building shell, always-visible facade geometry |
| `StructuralInterior` | Floors, walls, and structural elements inside the shell |
| `RoomContents` | Furniture and fixtures within individual rooms |
| `FineProps` | Small detail props, only visible at close range |

**Interior zone gating** — the manifest's `interior_zone` is the union AABB of all `ExteriorShell` tiles. On each streaming tick, the engine checks whether the camera is inside this volume. Tiles with `"interior": true` are only dispatched for loading while the camera is inside. This prevents the engine from loading room-level geometry when the player is outside the building, regardless of distance.

**Floor proximity gating** — for v4 `quadtree_floor` manifests, interior tiles that carry `floor_id` are also checked against `GeometryStreamingSystem.shared.floorProximityGateY` (default 5 m). The gate compares the camera's Y position to the tile's manifest center Y and suppresses new load dispatches for vertically distant floors. It does not unload already parsed tiles; normal `unloadRadius`, grace, and dwell rules still control teardown.

> The quadtree and KD-tree partitioning are content-pipeline and manifest-level concepts. At runtime the engine uses an **octree** for spatial range queries (finding tile stubs near the camera). The manifest's `quadtree_node_id` is used by the [hierarchy-aware tile culling](#hierarchy-aware-tile-culling) system to build a parent-region index and is therefore **runtime-significant** for v4 manifests.

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

### 1. Scene Load (`setEntityStreamScene`)

1. Locates and decodes the manifest JSON (no geometry parsed). If the manifest URL is HTTP/HTTPS, it is downloaded and cached via `RemoteAssetDownloader` before decoding. Tile asset URLs in the manifest are resolved relative to the manifest's base URL, so remote manifests produce remote tile URLs (e.g. `https://cdn.example.com/scene/tiles/tile_0_0.untold`). See [`asset_remote_streaming.md`](asset_remote_streaming.md) for the full download lifecycle.
2. Resets `interiorZone` and `firstRangeTimestamps` on `GeometryStreamingSystem` so stale scene-level state from a previous scene does not bleed into the new one.
3. Registers the supplied root entity with `TiledSceneComponent`, `LocalTransformComponent`, and `ScenegraphComponent`.
4. Registers one lightweight stub entity per tile inside a single `withWorldMutationGate`, parented under the root entity. Each stub receives:
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
4. Applies the **hierarchy gate** (see [Hierarchy-Aware Tile Culling](#hierarchy-aware-tile-culling)). Tiles whose parent spatial region is fully covered by closer loaded tiles have their occlusion score multiplied by `hierarchyOcclusionPenalty` (default 0.005), sorting them far below unoccluded candidates. They can still load when no better candidates exist.
5. Eligible tiles are sorted by priority (descending) then distance (ascending).
6. Within each priority tier, candidates are sorted by screen-space importance. The score uses projected tile footprint, view alignment, and optionally an occlusion weight derived from closer loaded tile AABBs. Occlusion never hard-blocks a tile; `occlusionMinWeight` leaves a nonzero floor so sparse or glassy geometry does not permanently hide work.
7. Up to `maxConcurrentTileLoads` (default 2) are dispatched via `loadTile()`, subject to the **memory budget gate**: the total parse memory in flight must stay under `tileParseMemoryBudgetMB` (200 MB), with a guarantee that at least one tile always loads even if it alone exceeds the budget.

**Tile unload pass** — three sub-passes each tick. All passes use `min(actual, predictive)` distance, matching the load pass, so a tile the camera is approaching is not torn down mid-parse:

1. **Nearby tiles** still in the octree result but beyond `unloadRadius`.
2. **Loaded tiles** that drifted entirely outside `maxQueryRadius`.
3. **Parsing tiles** that drifted outside `maxQueryRadius` (fast movement or teleport).

Both `.parsing` and `.parsed` tiles go through the **grace period** (see [Unload Grace Period](#unload-grace-period)) before actual teardown when they are still inside the octree query radius. Parsed tiles also honor `minimumParsedTileResidentSeconds` (default 8 s), so a newly visible tile cannot be immediately evicted or unloaded while the camera settles near a boundary. Pass 3 tiles are genuinely beyond the 500 m query radius and are cancelled without a grace period — boundary oscillation cannot occur at that range. At most `maxTileUnloadsPerUpdate` (default 2) tiles are torn down per tick to spread GPU buffer releases across frames.

### 3. `loadTile(entityId:)`

1. Sets `tileComp.state = .parsing`; reserves a slot in `activeTileLoads`.
2. Creates a dedicated child *mesh entity* under the tile stub (`capturedMeshEntityId`) inside `withWorldMutationGate`. This guarantees `unloadTile`'s `collectTileDescendants` always has at least one child to destroy, regardless of how many submeshes the tile contains.
3. Registers `capturedMeshEntityId → tileEntityId` in `meshEntityToTileEntity` for O(1) OCC upload counter updates.
4. Spawns a Swift `Task` calling `setEntityMeshAsync(entityId: capturedMeshEntityId, streamingPolicy: .auto, blockRenderLoop: false)`.
   - `.auto` policy: the admission gate chooses `fullLoad` (parse + immediate GPU upload) or `outOfCore` (store native `RuntimeAssetNode` CPU data and upload child stubs via `StreamingComponent`) based on renderable node count and geometry budget fraction.
   - `blockRenderLoop: false` — tile parses do **not** hold the `AssetLoadingGate` open. Without this, concurrent tile parses would keep `isLoadingAny == true` for their full duration, freezing `visibleEntityIds` updates and stalling the render loop. LOD and HLOD loads also use `blockRenderLoop: false` for the same reason.
5. Completion callback (fires on the main thread):
   - **Zombie-state guard** — checks `tc.state == .parsing`. If `unloadTile` ran while the parse was in flight, the state will be `.unloading`. The callback discards the result, destroys the pre-created child entity, and returns without marking the tile loaded.
   - On confirmed `.parsing`: transitions to `.parsed`, seeds `totalOCCStubs` from `countOCCDescendants`.
   - **fullLoad path** (`occCount == 0`): all geometry is immediately GPU-resident. The callback:
     1. Calls `setEntityStaticBatchComponent` to tag the entity hierarchy for cell-based static batching.
     2. Calls `BatchingSystem.shared.notifyTileEntitiesResident(_:)` with the set of render descendant IDs. This single call replaces the former two-step `queueResidencyEventsForRenderDescendants` + `notifyTileParsedEntities` pairing — it directly registers the entities in the batching system's pending additions and marks them for quiescence bypass, avoiding the per-entity event storm through `SystemEventBus`. See [Tile-Local Batch Promotion](batchingSystem.md#tile-local-batch-promotion).
   - **OCC path** (`occCount > 0`): `setEntityStaticBatchComponent` is called but residency notifications are not sent — they fire automatically as each OCC stub completes its GPU upload via the normal `handleResidencyChange` flow. The normal quiescence delay applies to keep the batch from rebuilding after each individual stub upload.
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
5. Calls `ProgressiveAssetLoader.shared.removeOutOfCoreAsset(rootEntityId:)` to free `CPURuntimeEntry` data for out-of-core tiles.
6. Resets `totalOCCStubs`, `uploadedOCCStubs`, `pendingUnloadSince` to 0.
7. Sets `tileComp.state = .unloaded`; removes from `loadedTileEntities`.

The tile stub entity itself is **never destroyed**. It stays in the octree as a cheap placeholder so the streaming system reloads the tile on the next approach.

---

## Hierarchy-Aware Tile Culling

For v4 (`quadtree_floor` or `kdtree_floor`) manifests, the engine builds a **tile hierarchy index** at scene load time from the `quadtree_node_id` field of every registered tile stub. This index maps each parent spatial prefix to the union AABB of all tiles beneath it.

### How it works

At scene load, `buildTileHierarchyIndex()` iterates all tile stubs and groups them by their immediate parent prefix:

```
"F02_Q_0_0_0"  →  parent "F02_Q_0_0"  →  union AABB of all F02_Q_0_0_* tiles
"F02_Q_0_0_1"  →  parent "F02_Q_0_0"  →  (same entry, AABB grows to include this tile)
"F02_Q_0_1_0"  →  parent "F02_Q_0_1"  →  separate entry
```

Both ID formats are supported:
- **Underscore format** (v4 inline annotation): `"F02_Q_0_0_0"` → parent `"F02_Q_0_0"`
- **Compact format** (pre-annotated phase12): `"F02Q100"` → parent `"F02Q10"` (last digit dropped)

### Each streaming tick

Before evaluating individual tile load candidates, the system tests each parent region's union AABB against the set of already-loaded tile occluders. If a parent region's screen projection is covered by closer loaded geometry (`occlusionFullThreshold`, default 85%), the prefix is added to `occludedParentRegions`.

The ancestor walk then checks every candidate tile's full ancestor chain — not just its immediate parent — so a coarse parent region being occluded propagates down to all descendant tiles regardless of how many levels deep they are.

### Priority penalty, not hard skip

Tiles whose ancestor is in `occludedParentRegions` have their occlusion score multiplied by `hierarchyOcclusionPenalty` (default 0.005). This sorts them far below unoccluded candidates — effectively deferring them — while still allowing them to load when no better candidates compete for slots. This prevents permanent holes when the camera snaps toward previously-occluded geometry.

The `hierGateSkip` counter in engine stats counts tiles penalized this way each tick.

### When the gate is inactive

- `enableOcclusionSort = false` — occlusion scoring disabled entirely
- No loaded tiles yet — occluder list is empty
- Camera inside the parent region's AABB — closest-point distance is 0, no occluder can be "closer"
- v3 uniform-grid manifests — no `quadtree_node_id`, index stays empty

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
- **LRU eviction** scores loaded OCC streaming entities by camera distance × `evictionDistanceWeight` + GPU size × `evictionSizeWeight`. Entities within `visibleEvictionProtectionRadius` (30 m) are protected.
- **Tile geometry eviction** (`evictTileGeometry`) runs after OCC eviction if geometry pressure remains high. It can evict full-load tiles, HLODs, and per-tile LODs that are outside their tile `streamingRadius`; parsed full tiles are protected until `minimumParsedTileResidentSeconds` elapses.
- **OS memory pressure** callbacks (`DispatchSource.makeMemoryPressureSource`) set a flag; eviction is deferred to the next `update()` tick to stay single-threaded.
- **`tripleVisibleEntities.clearAll()`** — called in `finalizePendingDestroys()` to clear all triple-buffer slots so the renderer does not read stale entity IDs after a scene reload.

### Full-load tile geometry eviction

`evictLRU` targets `loadedStreamingEntities` — the set of OCC mesh stubs (entities with `StreamingComponent`). Full-load tile geometry lives on `RenderComponent` entities created by the `fullLoad` path of `setEntityMeshAsync` and is **not** in `loadedStreamingEntities`.

The current runtime follows `evictLRU` with `evictTileGeometry(...)` when geometry pressure remains high. This second-stage pass reaches full-load tiles, HLODs, and per-tile LODs, sorted farthest first. It protects a tile while the camera is inside that tile's own `streamingRadius`, because that tile would otherwise be re-dispatched immediately on the next streaming tick.

Parsed full tiles also use `minimumParsedTileResidentSeconds` (default 8 s) as a dwell floor before memory-pressure eviction can tear them down. This prevents large floor or facade tiles from appearing briefly and disappearing again while the camera settles near a streaming boundary.

### `forceUnloadAllParsedTiles()` — explicit session transition

When an app transitions between "active" and "inspection/calibration" modes (e.g. scaling a tiled scene down to miniature for placement), explicitly freeing the previous session's tiles avoids waiting for distance-based unloads, grace periods, per-tick caps, and dwell guards before the next full-scale session loads new tiles.

```swift
GeometryStreamingSystem.shared.forceUnloadAllParsedTiles()
```

This iterates `loadedTileEntities` and calls `unloadTile()` for every `.parsed` tile, **bypassing the grace period and per-tick cap**. `unloadTile()` destroys the mesh-root child entity and all its descendants inside `withWorldMutationGate`, calls `finalizePendingDestroys()`, and unregisters GPU memory from `MemoryBudgetManager`. It also unloads any resident HLOD and per-tile LOD representations. By the time the call returns, `shouldEvictGeometry()` reflects the freed memory and the next session can load tiles without hitting the budget guard.

**When to call it:** call `forceUnloadAllParsedTiles()` when the user deliberately exits the active rendering session — for example, tapping a "recalibrate" or "place model" button that scales the scene down to a miniature view. Do **not** call it during normal streaming (movement, room changes) — the distance-based unload pass handles those cases correctly and with appropriate hysteresis.

---

## Threading Model

- All ECS mutations (`createEntity`, `registerComponent`, `destroyEntity`, `finalizePendingDestroys`) must run on the **main thread**.
- Background Swift Tasks handle disk I/O, `.untold` file parsing, and CPU→Metal buffer copies.
- `withWorldMutationGate` is an activity counter, not a mutex. It does **not** provide mutual exclusion — it signals that ECS mutations are occurring.
- `scene.exists(entityId)` guards before every ECS write in upload completions prevent writes to entities destroyed while an upload was in flight (cooperative cancellation race).
- Tile tracking sets (`loadedTileEntities`, `loadingTileEntities`, `activeTileLoads`, `meshEntityToTileEntity`) are protected by `stateLock` and accessed only through accessor methods.

---

## Scene Reload Safety

When `setEntityStreamScene` is called for a second time (replacing a previous scene):

1. The caller destroys the old root entity (`destroyEntity(entityId: oldRoot)`), which cascades to all tile stubs. For each destroyed stub, `removeTileComponent` (the `ComponentRegistry` cleanup handler for `TileComponent`) cancels the tile's in-flight `loadTask` and calls `GeometryStreamingSystem.shared.unregisterTileEntity(entityId)`, removing stale IDs from all tracking sets atomically.
2. `setEntityStreamScene` resets `interiorZone` and `firstRangeTimestamps` so scene-level streaming state is clean for the new scene.
3. New stubs are registered under the new root entity.

Any tile Task that was already in flight and completes after step 1–2 finds `scene.exists(entityId) == false` and returns early via the `guard` in its completion closure. The `defer`-based slot release still fires, so no concurrency slot is leaked.

---

---

## HLOD (Hierarchical Level of Detail)

HLOD fills the gap beyond a tile's `unloadRadius` by showing a coarse proxy mesh while the full tile is not in GPU memory. This eliminates the visual "pop to nothing" when a tile leaves range.

### Lifecycle

```
hlodState:  unloaded → loading → loaded → unloading → unloaded
```

| State | Meaning |
|---|---|
| `.unloaded` | No HLOD geometry in GPU memory |
| `.loading` | `loadHLOD()` task running |
| `.loaded` | HLOD entity exists and is rendering |
| `.unloading` | Teardown in progress |

### Load trigger

HLOD is loaded when all of the following hold:
- The tile has an `hlodURL` in its `TileComponent`
- `dist >= hlodSwitchDistance` (camera is beyond the switch threshold)
- `tileComp.state != .parsed` (full tile is not resident — no redundant HLOD)
- `hlodState == .unloaded`
- `activeHLODLoadCount() < maxConcurrentHLODLoads` (default 4) — prevents simultaneous mass dispatch of 100+ HLOD parses that would OOM-kill the process

### Unload trigger

HLOD is unloaded (and the load task cancelled) when:
- The full tile reaches `.parsed` — full geometry has taken over; HLOD is redundant. No hysteresis here — always unload promptly.
- `dist < hlodSwitchDistance × hlodHysteresisFactor` (default 0.90) — camera has moved **meaningfully** inside the switch distance. The hysteresis band `[switchDistance × factor, switchDistance)` keeps the HLOD resident while the camera lingers at the boundary, preventing thrashing.

**Race fix:** `hlodState = .unloading` is set **before** `hlodLoadTask.cancel()`. This prevents the load completion callback from seeing `.loading` and incorrectly marking the HLOD as `.loaded` after teardown is already in progress.

**Minimum dwell guard:** After any HLOD load or unload, `tileComp.lastHLODTransitionTime` is stamped. The next HLOD transition is suppressed until `secondaryRepresentationMinDwellSeconds` (default 1.0 s) has elapsed. This prevents the HLOD from flip-flopping faster than once per second when the camera lingers at the switch boundary while hysteresis alone is insufficient.

### Out-of-range cleanup

A second pass after the main HLOD pass tears down HLOD entities for tiles that have drifted entirely outside `maxQueryRadius`. These tiles are no longer in the octree result and would otherwise remain with stale `.loaded` HLOD entities indefinitely.

---

## Per-tile LOD Levels

Per-tile LODs fill the mid-distance band between the full tile (`streamingRadius`) and the HLOD (`hlodSwitchDistance`). They are intermediate meshes — coarser than the full tile but finer than HLOD — shown while the tile itself is unloaded.

**Distinction from HLOD:**

| | HLOD | Per-tile LOD |
|---|---|---|
| Purpose | Replace unloaded tile at *very far* distances | Provide finer intermediate detail at *mid* distances |
| Memory concern | Yes — always-resident coarse mesh | Yes — one entity per active LOD level |
| GPU cost concern | Low (coarse mesh) | Medium (finer than HLOD, less than full tile) |
| Distance band | `> hlodSwitchDistance` | `streamingRadius … hlodSwitchDistance` |

### Lifecycle

Each `TileLODLevel` follows the same `HLODAssetState` state machine as HLOD:

```
state:  unloaded → loading → loaded → unloading → unloaded
```

### LOD selection logic (per frame, per tile)

```
if HLOD is loaded or loading → unload all LOD levels (avoid dual representation)
if dist >= hlodSwitchDistance → unload all LOD levels (HLOD pass handles this band)

find target index (with hysteresis):
  for each level i:
    threshold = (i is currently active) ? switchDistance × lodHysteresisFactor : switchDistance
    last level where threshold ≤ dist → that level
  no match (dist < LOD[0].threshold)  → no LOD (tile will load or is already parsed)

load target level if .unloaded (capped by maxConcurrentLODLoads)
unload all other levels that are .loaded or .loading
```

The hysteresis ensures the currently active LOD level uses a lowered unload threshold (`switchDistance × lodHysteresisFactor`, default 0.90), so the camera must move meaningfully inward before the level is swapped. Levels that are not currently active use the full `switchDistance`.

**Minimum dwell guard:** LOD transitions are also gated by `secondaryRepresentationMinDwellSeconds` (default 1.0 s). After any per-tile LOD load or unload, `tileComp.lastLODTransitionTime` is stamped and the next transition is suppressed until 1.0 s has elapsed. This prevents oscillation between adjacent LOD levels when the camera is stationary near a switch threshold.

When `tileComp.state == .parsed` (full tile is resident), all LOD levels are unloaded — the full tile has taken over for that distance band.

### `loadLODLevel(entityId:levelIndex:)`

1. Creates a child entity under the tile stub.
2. Loads the LOD `.untold` asset via `setEntityMeshAsync` with `.immediate` policy and `blockRenderLoop: false` (small proxy mesh, must not stall the render loop).
3. On success: tags render descendants with `TileLODTagComponent(levelIndex: capturedIndex + 1)` for LOD debug visualization, tags the entity for static batching (`setEntityStaticBatchComponent`), and calls `BatchingSystem.shared.notifyTileEntitiesResident(_:)` to bypass the quiescence delay.
4. Marks the entity in `loadedLODEntities` tracking set.

### `unloadLODLevel(entityId:levelIndex:)`

1. Sets `level.state = .unloading` **before** `level.loadTask?.cancel()` (same race fix as HLOD).
2. Calls `BatchingSystem.shared.notifyTileEntitiesUnloading(_:)` with the render descendant IDs — removes pending additions and committed cell membership before the entities are destroyed, preventing stale or recycled IDs from remaining in batch state.
3. Destroys the child entity.
4. Force-releases `AssetLoadingGate` for the destroyed entity (idempotent no-op if the Task already closed it).
5. Removes from `loadedLODEntities` when all levels are clear.

### Out-of-range cleanup

A pass after the LOD streaming pass tears down LOD entities for tiles outside `maxQueryRadius`, mirroring the HLOD cleanup pass.

### Interaction with `loadTile` completion

When the full tile finishes parsing, `unloadAllLODLevels(entityId:)` is called alongside `unloadHLOD(entityId:)`. Both intermediate representations are removed as the full tile takes over.

---

## Asset Loading Freeze Prevention

The `.untold` format loads via `UntoldReader` without calling `loadTextures()` or any blocking ModelIO API, so tile parses do not produce `AssetLoadingGate` hangs by design.

The 60-second tile-parse watchdog (see [Tile-Parse Watchdog](#tile-parse-watchdog) below) serves as the safety net for any stuck parse Task — for example when the OS suspends the Task or disk I/O stalls indefinitely. When the watchdog fires it force-closes the gate defensively:

```swift
let hungMeshId = tc.meshEntityId
tc.meshEntityId = .invalid
if hungMeshId != .invalid {
    Task { await AssetLoadingState.shared.finishLoading(entityId: hungMeshId) }
}
```

`finishLoading` is idempotent — if the Task already closed the gate normally, this call is a no-op.

---

## Tile-Parse Watchdog

The tile-parse watchdog guards against the entire tile parse Task becoming stuck — for example when the OS suspends the Task, disk I/O stalls indefinitely, or a remote download never completes.

On every streaming tick, `GeometryStreamingSystem.update()` checks every tile currently in `.parsing` state:

```
if CFAbsoluteTimeGetCurrent() - tc.parseStartTime > tileParseTimeoutSeconds (default 60 s):
    cancel loadTask
    force-close AssetLoadingGate for meshEntityId
    increment failureCount → tile enters exponential backoff
    release concurrency slot
```

**`parseStartTime` is set after the remote fetch completes**, not when `loadTile()` is first called. For remote tiles, the time waiting for the network does not count against the 60-second budget — only the actual CPU parse time does. This avoids spurious timeouts on slow connections.

**Two distinct timeout layers:**

| Mechanism | Scope | Deadline | On trigger |
|---|---|---|---|
| Tile-parse watchdog | Entire tile parse Task | 60 s (`tileParseTimeoutSeconds`) | Cancels task, marks `.failed`, enters retry backoff |

---

## Key Design Parameters

| Property | Default | Notes |
|---|---|---|
| `maxConcurrentTileLoads` | 2 | Hard cap on simultaneous tile parses |
| `maxConcurrentLODLoads` | 4 | Hard cap on simultaneous per-tile LOD level loads |
| `maxConcurrentHLODLoads` | 4 | Hard cap on simultaneous HLOD mesh loads |
| `lodHysteresisFactor` | 0.90 | LOD unload threshold multiplier (10% inner band) |
| `hlodHysteresisFactor` | 0.90 | HLOD unload threshold multiplier (10% inner band) |
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
| `hlodSwitchDistance` | manifest `switch_distance` | Camera distance beyond which HLOD is shown |
| LOD `switchDistance` | manifest `switch_distance` per entry | Camera distance beyond which this LOD is preferred |
| `tileParseTimeoutSeconds` | 60 s | Watchdog deadline for an entire tile parse Task after remote download completes; forces tile to `.failed` and frees concurrency slot |
| `meshLoadTimeoutSeconds` | 60 s | Watchdog deadline for OCC mesh uploads and cache-backed mesh loads; resets stuck mesh loads to `.unloaded` |
| `secondaryRepresentationMinDwellSeconds` | 1.0 s | Minimum time a HLOD or per-tile LOD level must dwell before the next transition is allowed; prevents flip-flopping between representations faster than once per second |
| `minimumParsedTileResidentSeconds` | 8.0 s | Minimum time a parsed full tile remains resident before normal unload or tile-geometry eviction may tear it down |
| `floorProximityGateY` | 5 m | Maximum Y distance for dispatching floor-aware interior tiles; set to `Float.greatestFiniteMagnitude` to disable |
| `enableImportanceSort` | true | Sort tile candidates by screen-space importance within priority tiers |
| `enableOcclusionSort` | true | Deprioritize tile candidates whose screen footprint is covered by closer loaded tile AABBs |
| `hierarchyOcclusionPenalty` | 0.005 | Occlusion score multiplier for tiles whose parent region is fully occluded. Near-zero value defers them without hard-blocking; set to 0.0 to restore old hard-skip behavior |
