# BatchingSystem — How It Works

The goal is simple: instead of issuing 100 separate draw calls (one per entity), merge entities that share the same material into a single combined GPU buffer and issue **one draw call per material group**. This is called **static batching**.

---

## Step 0: The World is Divided into Cells

The 3D world is partitioned into a 3D grid of **cells**, each 32 units wide (`batchCellSize = 32.0`). Every entity is assigned to a cell based on the world-space center of its bounding box:

```
cellId(x, y, z) = floor(worldCenter / 32.0)
```

**Why cells?** Batching 100 entities scattered across a huge world into one mesh is wasteful — you'd rebuild everything when anything changes. Cells localize the damage.

---

## Step 1: Entity Registration

When your 100 entities load, each one that has a `StaticBatchComponent` gets registered:

- **Eligibility check** (`resolveBatchCandidate`): the entity must have a `RenderComponent`, `WorldTransformComponent`, no skeleton/animation, no transparency, no gizmo/light component, and its mesh must already be resident in memory.
- If eligible → it gets assigned to a cell and added to `cellToEntities[cellId]`.
- The cell is marked **dirty** and its state becomes `renderableUnbatched`.

---

## Step 2: Per-Frame Tick — The Pipeline

Every frame, `tick()` runs through this pipeline:

### 2a. Process Removals & Additions
Any entities that changed (LOD switch, mesh evicted/streamed in) are removed from their old cell and re-registered in their current cell. This marks the affected cells dirty.

### 2b. Update Visibility History
The system checks which cells currently contain visible entities and records `cellLastVisibleFrame[cellId]`. This drives **visibility gating** — the system won't waste CPU rebuilding cells you can't see.

### 2c. Promote Dirty Cells → `batchPending`
For each dirty cell in state `renderableUnbatched` or `streaming`:
- Is it visible (or recently visible within 120 frames)?
- Has it been stable for at least `quiescenceFramesBeforeBatchBuild` frames (default: 1)?

If yes → state becomes **`batchPending`**.

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
  - Allocate new `MTLBuffer`s for the merged position/normal/UV/tangent/index data.
- The result is a `PreparedCellArtifact` containing `[BatchGroup]`.

So 100 entities all sharing the same wood-plank material → **1 BatchGroup** with 1 merged MTLBuffer.

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

The renderer checks `entityToBatch` — if an entity is in a batch, it **skips the per-entity draw call** and instead the batch groups are rendered directly. Each `BatchGroup` is one draw call with its merged buffer. 100 entities sharing one material = **1 draw call**.

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
renderableUnbatched
   ↓ (promoted, budget available)
batchPending
   ↓ (build dispatched + applied)
renderableBatched
   ↓ (entity removed or LOD change)
retiring → unloaded
```

---

## With 100 Entities — Concrete Example

Suppose your 100 entities break down as:
- 60 entities: wood material, LOD 0, all in cell (0,0,0)
- 30 entities: stone material, LOD 0, cell (0,0,0)
- 10 entities: glass material (transparent) → **excluded from batching**

Result:
- **2 BatchGroups** for cell (0,0,0): one wood, one stone
- **2 draw calls** instead of 90 (the 10 transparent ones draw individually)
- On a LOD change (say 20 wood entities switch to LOD 1), cell (0,0,0) is marked dirty → rebuild fires next eligible tick → now 3 BatchGroups (wood LOD0, wood LOD1, stone LOD0)
