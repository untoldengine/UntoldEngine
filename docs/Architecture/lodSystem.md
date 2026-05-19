# LOD in UntoldEngine: Two Independent Systems

UntoldEngine has two separate LOD mechanisms that operate at different granularities. Understanding the distinction is important before reading either system's details.

| | **Entity-level LOD** (this document) | **Per-tile LOD** (tile streaming) |
|---|---|---|
| Unit | Individual mesh entity (`LODComponent`) | Whole tile `.untold` file (`TileLODLevel`) |
| Control | `LODSystem` — runs every frame | `GeometryStreamingSystem.update()` — runs per tick |
| Switch trigger | Camera distance vs `LODLevel.maxDistance` | Camera distance vs `TileLODLevel.switchDistance` (with hysteresis) |
| Hysteresis | 5-unit inner band on finer-LOD transitions only | `lodHysteresisFactor` (default 0.90 = 10% band) on active level |
| Meshes in memory | All LOD levels GPU-resident simultaneously | Only the active LOD level is loaded |
| Use case | Individual detailed objects (buildings, props) | Tile-granularity intermediate representations for large scenes |
| Content pipeline | Separate `.untold` files per LOD level, wired via `LODComponent` | Separate `.untold` files per tile LOD, listed in manifest `lod_levels` array |
| Debug tagging | `LODComponent.currentLOD` read by LOD debug renderer | `TileLODTagComponent.levelIndex` placed on render descendants |

Per-tile LOD documentation: [`docs/Architecture/tilebasedstreaming.md`](tilebasedstreaming.md#per-tile-lod-levels).

---

## Entity-level LOD: City Block with 500 Buildings, 3 LODs Each

### Setup (before the system runs)

Each building entity has a `LODComponent` with an array of `LODLevel` entries sorted by detail:

```
Building Entity
  LODComponent.lodLevels[0] → LOD0: highDetailMesh,  maxDistance: 50.0
  LODComponent.lodLevels[1] → LOD1: medDetailMesh,   maxDistance: 100.0
  LODComponent.lodLevels[2] → LOD2: lowDetailMesh,   maxDistance: 200.0
```

Each `LODLevel` tracks its own `residencyState` (`.resident`, `.loading`, `.notResident`, `.unknown`) and a `url` so the streaming system knows where to reload it from.

---

### Every Frame: `LODSystem.update()`

The system runs once per frame. Here's what happens for all 500 buildings:

**Step 1 — Get camera position**
```
CameraSystem → activeCamera → CameraComponent.localPosition
```

**Step 2 — Query all LOD entities**
```swift
queryEntitiesWithComponentIds([LODComponent, WorldTransformComponent])
```
Returns all 500 building entities in one shot.

**Step 3 — For each building: `updateEntityLOD()`**

This is the core loop. Three sub-steps per building:

---

#### 3a. `calculateDistance()`

Takes the building's local AABB bounding box, finds its center, transforms it to world space via `WorldTransformComponent.space`, then computes the straight-line distance to the camera.

```
distance = |cameraPosition - worldCenter|
```

---

#### 3b. `selectLODLevel()`

Applies `lodBias` to the distance (default `1.0`, so no change), then walks through `lodLevels` in order, comparing against each level's `maxDistance`:

```
adjustedDistance = distance * lodBias

If adjustedDistance ≤ 50   → desiredLOD = 0  (high detail)
If adjustedDistance ≤ 100  → desiredLOD = 1  (medium)
If adjustedDistance ≤ 200  → desiredLOD = 2  (low)
Beyond all thresholds      → desiredLOD = 2  (lowest available)
```

**Hysteresis:** When switching to a *finer* LOD (e.g. camera approaching, LOD2→LOD1), the threshold is tightened by `5.0` units. This prevents flickering when the camera hovers right at a boundary. Switching to *coarser* LODs has no penalty — it happens immediately.

---

#### 3c. `resolveActualLOD()`

The desired LOD may not be resident yet (e.g. it's still streaming in). So:

```
Is desiredLOD mesh resident?
  YES → use it (isUsingFallback = false)
  NO  → findFallbackLOD():
          Try coarser LODs first  (LOD2, LOD3...)
          Then try finer LODs     (LOD0...)
          If nothing → stay at currentLOD
```

This means a building 30m away that wants LOD0 but hasn't finished loading will temporarily show LOD1 or LOD2 — always something visible, never a pop-in hole.

---

#### 3d. `applyLOD()`

This is the write step. Runs inside `withWorldMutationGate` to be thread-safe.

```
If newLOD == currentLOD and no transition in progress → skip (no-op)

Otherwise:
  - Update lodComponent.currentLOD = newLOD
  - Copy lodLevels[newLOD].mesh → renderComponent.mesh
  - Generate meshAssetID: "<url>_LOD<index>"
  - Store in lodComponent.activeMeshAssetID  (used by batching system)
  - If LOD actually changed → emit EntityLODChangedEvent to SystemEventBus
```

The `renderComponent.mesh` swap is the handoff to the renderer — whatever mesh array sits there is what gets drawn next frame.

---

### What the 500-Building Frame Looks Like

Given a camera standing near one end of the block:

| Distance | Buildings | Desired LOD | Typical Outcome |
|---|---|---|---|
| 0–50m | ~20 | LOD0 | High detail meshes |
| 50–100m | ~80 | LOD1 | Medium meshes |
| 100–200m | ~150 | LOD2 | Low meshes |
| 200m+ | ~250 | LOD2 (last) | Lowest available |

The system processes all 500 in sequence, but buildings where LOD hasn't changed are early-exited with no mutation (the `newLOD == previousLODIndex` guard). In a stable scene, the vast majority of buildings hit that fast path.

---

### Key Design Observations

- **Fallback-first streaming:** The system never waits for a mesh to load — it always degrades gracefully to whatever is resident.
- **`activeMeshAssetID`** is the bridge to the batching system. When a LOD switches, the new asset ID tells the batcher to move that entity into a different batch group.
- **`EntityLODChangedEvent`** on `SystemEventBus` is how downstream systems (geometry streaming, batching) learn that a switch happened — they react to the event rather than polling.
- **Fade transitions** exist in the code (`transitionProgress`, `previousLOD`) but `enableFadeTransitions` defaults to `false`, so currently all switches are instant.

---

### Relationship to OCC

The old ModelIO LOD+OOC path has been removed. There is no
`cpuLODRegistry`, `CPUMeshEntry`, or cold rehydration path in the current
native streaming architecture.

Current behavior is split by level:

- Entity-level LOD is an always-resident object workflow. LOD levels are loaded
  as `.untold` mesh assets and swapped by `LODSystem`.
- Tile-level LOD is part of `setEntityStreamScene(...)`. The manifest lists
  `.untold` LOD payloads, and `GeometryStreamingSystem` loads/unloads the active
  tile LOD representation by distance.
- OCC applies inside large full-tile `.untold` payloads. It creates child
  `StreamingComponent` stubs backed by `ProgressiveAssetLoader.CPURuntimeEntry`.
