# BatchingSystem — How It Works

The goal is simple: instead of issuing 100 separate draw calls (one per entity), merge entities that share the same material into a single combined GPU buffer and issue **one draw call per material group**. This is called **static batching**.

---

## Step 0: The World is Divided into Cells

The 3D world is partitioned into a 3D grid of **cells**. The cell size is calibrated at scene load time: when a tile manifest is present, the cell size is set to `2 × tileSize` so that cell boundaries align with tile boundaries. When no manifest is present, the default of 32 world units is used.

Every entity is assigned to a cell based on the world-space center of its bounding box:

```
cellId(x, y, z) = floor(worldCenter / cellSize)
```

**Why align to tile boundaries?** Batching 100 entities scattered across a huge world into one mesh is wasteful — you'd rebuild everything when anything changes. Cells localize the damage. When cell boundaries align with tile boundaries, loading or unloading a tile only touches the cells that tile occupies — no cross-tile batch rebuilds.

---

## Step 1: Entity Registration

When your 100 entities load, each one that has a `StaticBatchComponent` gets registered:

- **Eligibility check** (`resolveBatchCandidate`): the entity must have a `RenderComponent`, `WorldTransformComponent`, no skeleton/animation, no transparency, no gizmo/light component, and its mesh must already be resident in memory. The LOD index is derived from `LODComponent.currentLOD` (entity-level LOD), then `TileLODTagComponent.levelIndex` (per-tile LOD/HLOD children), defaulting to 0. `isLODBatch` on the resulting `BatchGroup` is true if any member entity has either component.
- If eligible → it gets assigned to a cell and added to `cellToEntities[cellId]`.
- The cell is marked **dirty** and its state becomes `renderableUnbatched`.

---

## Step 2: Per-Frame Tick — The Pipeline

Every frame, `tick()` runs through this pipeline:

### 2a. Process Removals & Additions
Any entities that changed (LOD switch, mesh evicted/streamed in) are removed from their old cell and re-registered in their current cell. This marks the affected cells dirty.

**Tile-loaded entities bypass the quiescence delay.** When a fullLoad tile (or LOD/HLOD load) finishes, `GeometryStreamingSystem` calls `BatchingSystem.notifyTileEntitiesResident(_:)` with the set of render-ready entity IDs. This single call directly registers the entities in `pendingEntityAdditions`, marks them as tile-parsed (for quiescence bypass), and resolves their cell membership — replacing the former two-step `queueResidencyEventsForRenderDescendants` + `notifyTileParsedEntities` pairing and avoiding the per-entity event storm through `SystemEventBus`. Their cells are immediately promoted to `batchPending` in the same tick. See [Tile-Local Batch Promotion](#tile-local-batch-promotion) below.

**Stale entity purge on LOD/HLOD teardown.** When `unloadLODLevel` or `unloadHLOD` destroys child entities, it first calls `BatchingSystem.cancelPendingEntities(_:)` with the render descendant IDs. This removes them from `pendingEntityAdditions`, `pendingEntityRemovals`, `newlyResidentEntities`, and `tileParsedEntityIds` before the entities are destroyed — preventing "entity is missing" errors on the next `tick()` and avoiding wasted batch rebuilds for entities that no longer exist.

### 2b. Update Visibility History
The system checks which cells currently contain visible entities and records `cellLastVisibleFrame[cellId]`. This drives **visibility gating** — the system won't waste CPU rebuilding cells you can't see.

### 2c. Promote Dirty Cells → `batchPending`
For each dirty cell in state `renderableUnbatched` or `streaming`:
- Is it visible (or recently visible within 120 frames)?
- Has it been stable for at least `quiescenceFramesBeforeBatchBuild` frames (default: 1)?

If yes → state becomes **`batchPending`**.

Cells flagged by tile promotion skip the quiescence check and advance directly to `batchPending` in the same tick.

### 2d. Rebuild Dirty Cells (`rebuildDirtyCells`)

This is the core build loop:

1. **Apply completed background artifacts first** — results from previous frames' async builds are swapped in (up to `maxArtifactAppliesPerTick = 4` per frame).

2. **Gather `batchPending` cells** and build rebuild candidates. For each:
   - Estimate the work: count total vertices + indices + bytes across all entities in the cell.
   - If a cell **exceeds the per-cell complexity guard** (>160K verts, >300K indices, >8MB), it's flagged `runtimeIneligibleCells` and stays unbatched.
   - Otherwise it becomes a `CellRebuildCandidate`.

3. **Sort candidates** by priority:
   - Currently visible > recently visible > long ago visible
   - Smaller estimated bytes first (lighter work first)
   - Oldest dirty-since-frame first

4. **Apply per-tick budgets**: up to 8 cells, 120K verts, 220K indices, 6MB total per tick. Once budgets are exhausted, remaining cells defer to next frame.

5. **Snapshot build inputs** under a world mutation gate: for each selected cell, group its entities' meshes by `BatchBuildKey = (cellId, materialHash, lodIndex)`. This produces `CellBuildInput`.

6. **Dispatch background builds** on `artifactBuildQueue` (a `.utility` DispatchQueue). The heavy work — actually merging vertex data — happens off the main thread.

---

## Step 3: Building the Batch (`buildPreparedArtifact`)

For each `CellBuildInput`, on the background thread:

- Iterate material groups. **Skip any group with < 2 meshes** (no point batching a single mesh).
- For each group that qualifies, call `createBatchGroup`:
  - Loop through all meshes in the group.
  - For each mesh, extract positions, normals, UVs, tangents from the Metal buffers.
  - Transform each vertex by the entity's world transform (`worldTransform.space * mesh.localSpace`).
  - Re-index indices with an offset (since vertices are now concatenated into one flat array).
  - Compute the world-space **AABB** of the merged geometry (min/max of all vertex positions).
  - Allocate new `MTLBuffer`s for the merged position/normal/UV/tangent/index data.
- The result is a `PreparedCellArtifact` containing `[BatchGroup]`.

So 100 entities all sharing the same wood-plank material → **1 BatchGroup** with 1 merged MTLBuffer and one tight world-space AABB.

> **What is an artifact?**
> An artifact is the **output package produced by a build job**: 
    the **input** is `CellBuildInput` (a snapshot of which entities are in a cell and how they're grouped by material), and the **artifact** (`PreparedCellArtifact`) is the finished result — the merged MTLBuffers, entity-to-batch mappings, vertex/index counts, and build time. Everything needed to install the batch into the live scene.
>

---

## Step 4: Applying the Artifact

Back on the main thread (next frame or same frame if sync mode):

- Validate the artifact is still current (epoch + generation check — discards stale builds if the scene changed while it was building).
- Remove any existing batches for the cell (queue old GPU buffers for retirement with a 3-frame safety delay so the GPU isn't still using them).
- Append the new `BatchGroup`s to `batchGroups`.
- Update `entityToBatch[entityId]` so the renderer knows each entity is now represented by a batch.
- Reconcile streaming textures: if a texture streamed to a higher mip while the build was in flight, patch the batch's material in-place so it doesn't revert.
- Mark cell state → **`renderableBatched`**.

---

## Step 5: Rendering

The renderer uses **cluster-level frustum culling** to determine which batch groups to submit. Each `BatchGroup` carries a precomputed world-space AABB (`boundingBox`) covering all geometry in the group. The render passes test each group's AABB directly against the current-frame frustum — **one AABB test per batch group, not one per entity**. Groups whose AABB is fully outside the frustum are skipped without any entity-level traversal.

For batch groups that survive the AABB test, each `BatchGroup` is one draw call with its merged buffer. 100 entities sharing one material = **1 draw call**, submitted only when the group's spatial bounds are within the frustum.

Per-entity batching membership (`entityToBatch`) is still maintained and used by non-batched rendering paths and by tests.

---

## Step 6: Retirement (Safe GPU Buffer Release)

Old GPU buffers aren't freed immediately. They go into `retiringBatchArtifacts` with a `retireAfterFrame = currentFrame + 3`. After 3 frames, the system drops the Swift reference, allowing ARC to release the MTLBuffers — guaranteeing the GPU has finished with them.

---

## Cell Lifecycle State Machine

```
unloaded
   ↓ (entity becomes resident)
streaming
   ↓ (quiescence + visibility check pass)
   ↓ (or: tile-local promotion — bypasses quiescence)
renderableUnbatched
   ↓ (promoted, budget available)
batchPending
   ↓ (build dispatched + applied)
renderableBatched
   ↓ (entity removed or LOD change)
retiring → unloaded
```

---

## Tile-Local Batch Promotion

When a **fullLoad tile** (one that completes GPU upload in a single step, `occCount == 0`), per-tile LOD level, or HLOD mesh finishes loading, `GeometryStreamingSystem` hands off the set of render-ready entity IDs to the batching system:

```swift
BatchingSystem.shared.notifyTileEntitiesResident(renderIds)
```

This single call combines what was previously a per-entity `AssetResidencyChangedEvent` storm + a separate `notifyTileParsedEntities` call. The entities are registered directly in the batching system's pending additions and marked for quiescence bypass, avoiding hundreds of individual events through `SystemEventBus`.

In the next `tick()`, those entities are processed differently from ordinary streaming arrivals:

1. **`deferBatchBuild = false`** — the extra one-frame deferral applied to newly-resident streaming entities is suppressed.
2. **Immediate cell promotion** — after the entities are registered, the system collects the cells they were assigned to and forces them from `renderableUnbatched` → `batchPending` in the same tick, bypassing the `quiescenceFramesBeforeBatchBuild` wait.

The result: a tile that finishes parsing on frame N will have its cells in `batchPending` on frame N+1 and a completed batch ready to submit one or two frames later (depending on background build time), rather than waiting for the quiescence window first.

This is safe because a tile's geometry arrives atomically — all entities are registered at once with no further churn expected. The quiescence delay exists to absorb incremental arrivals (OCC stub uploads); it is unnecessary and harmful for the fullLoad tile path.

**OCC tiles are unchanged.** For tiles using the out-of-core upload path, individual mesh stubs still arrive one at a time via the normal `handleResidencyChange` flow. The quiescence delay is preserved for these so the batch doesn't rebuild for each individual stub upload.

---

## BatchGroup AABB

Every `BatchGroup` stores a **precomputed world-space AABB**:

```swift
var boundingBox: (min: simd_float3, max: simd_float3)
```

This is computed during `createBatchGroup` as the min/max of all transformed vertex positions. It represents the tightest world-space bounding box over all geometry in the group.

The AABB serves two purposes:
1. **Cluster-level frustum culling** — the render pass tests this AABB against `currentFrameFrustum` before encoding the draw call, skipping entire groups that are outside the view.
2. **Future use** — HLOD transitions, occlusion culling, and GPU-driven rendering will all use this AABB as the cluster's spatial identity.

---

## With 100 Entities — Concrete Example

Suppose your 100 entities break down as:
- 60 entities: wood material, LOD 0, all in cell (0,0,0)
- 30 entities: stone material, LOD 0, cell (0,0,0)
- 10 entities: glass material (transparent) → **excluded from batching**

Result:
- **2 BatchGroups** for cell (0,0,0): one wood, one stone
- Each BatchGroup has its own world-space AABB covering all vertices in the group
- **2 draw calls** instead of 90 (the 10 transparent ones draw individually)
- Both groups are frustum-culled by AABB before encoding — if the whole cell is off-screen, 0 draw calls are issued
- On a LOD change (say 20 wood entities switch to LOD 1), cell (0,0,0) is marked dirty → rebuild fires next eligible tick → now 3 BatchGroups (wood LOD0, wood LOD1, stone LOD0)
