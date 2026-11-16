---
name: untold-lod-system
description: Use when giving a single always-resident entity multiple levels of detail that swap by camera distance or on-screen size — a tree, prop, vehicle, or building that should drop polygons as it gets farther away or smaller on screen. Covers setEntityLodComponent/addLODLevel(s), distance vs. screen-size selection, bias/hysteresis/fade tuning, and forced-LOD overrides. Triggers on "add LOD levels to this model", "swap to a lower-poly mesh at distance", "the LOD switch pops/flickers", "force this entity to a specific LOD for debugging". Not for manifest-driven tile/HLOD streaming of a large scene (see untold-geometry-streaming, which has its own lod_levels/hlod_levels per tile), Gaussian-splat LOD tiers (see untold-gaussian-splats), or spatial debug overlays/diagnostics for LOD (see untold-performance-diagnostics).
version: 0.1.0
---

# Per-Entity LOD in Untold Engine

Use this for a single entity that should switch between pre-authored mesh representations as it gets farther away or smaller on screen — not for streamed/tiled scenes (those have their own per-tile `lod_levels`/`hlod_levels` in the manifest; see `untold-geometry-streaming`).

## 1. Basic setup

```swift
let tree = createEntity()
setEntityLodComponent(entityId: tree)   // call before adding LOD levels

addLODLevel(entityId: tree, lodIndex: 0, fileName: "tree_LOD0", withExtension: "untold", maxDistance: 50.0)
addLODLevel(entityId: tree, lodIndex: 1, fileName: "tree_LOD1", withExtension: "untold", maxDistance: 100.0)
addLODLevel(entityId: tree, lodIndex: 2, fileName: "tree_LOD2", withExtension: "untold", maxDistance: 200.0)
addLODLevel(entityId: tree, lodIndex: 3, fileName: "tree_LOD3", withExtension: "untold", maxDistance: 400.0)
```

`lodIndex: 0` is the highest detail. Each level renders up to its own `maxDistance`; beyond the last level's `maxDistance`, the lowest level stays.

Prefer `addLODLevels` (plural) when loading more than one level — it loads all of them and calls one completion handler only once every level has finished, which matters when LOD is combined with static batching:

```swift
addLODLevels(entityId: tree, levels: [
    (0, "tree_LOD0", "untold", 50.0, 0.0),
    (1, "tree_LOD1", "untold", 100.0, 0.0),
    (2, "tree_LOD2", "untold", 200.0, 0.0),
]) { success in
    if success {
        translateTo(entityId: tree, position: simd_float3(10, 0, 5))
        // apply static batching here if needed
    }
}
```

**Apply transforms (`translateTo`/`rotateTo`/`scaleTo`) inside the completion handler**, not before — transforms applied before the mesh loads may not take effect. This is the same async-loading discipline as `setEntityMeshAsync` (see `untold-async-loading`).

Each LOD file lives in its own subfolder named after the file (no extension):

```text
GameData/Models/
  tree_LOD0/tree_LOD0.untold
  tree_LOD1/tree_LOD1.untold
  tree_LOD2/tree_LOD2.untold
```

## 2. Managing levels at runtime

```swift
removeLODLevel(entityId: tree, lodIndex: 2)
replaceLODLevel(entityId: tree, lodIndex: 1, fileName: "tree_LOD1_new", withExtension: "untold", maxDistance: 100.0)
let count = getLODLevelCount(entityId: tree)
```

Useful for adapting quality to device tier — e.g. drop the highest-detail level on low-end hardware (`removeLODLevel(entityId:lodIndex: 0)`).

## 3. Automatic LOD chains from a pack (no per-level authoring)

If the asset came from a `.untoldpack` with a baked LOD chain (built by `untoldengine export` or `untoldengine bake-lods`, see `docs/API/UsingUntoldEngineCLI.md#lod-chains-for-packs`), nothing changes in how you load it — the chain and `LODComponent` attach automatically:

```swift
let site = createEntity()
setEntityMeshAsync(entityId: site, filename: "site", withExtension: "untoldpack")
```

Placements of the same model share GPU buffers across every level; materials belong to the entity, so a material edited while one level is shown stays when another takes over. Chains select by screen size, not distance (see §4) — a small prop and a large tree both switch where their triangles cover about the same number of pixels, regardless of how different their absolute distances are.

## 4. Distance vs. screen-size selection

Distance-based (the default, via `maxDistance`) is simplest but distance-agnostic to object size and FOV. Screen-size selection switches by how much of the viewport the entity's bounding sphere covers — the same level switches consistently whether the camera zooms or the entity is scaled:

```swift
if let lodComponent = scene.get(component: LODComponent.self, for: tree) {
    lodComponent.lodLevels[1].screenPercentage = 0.5   // LOD1 takes over from half the viewport height down
    lodComponent.lodLevels[2].screenPercentage = 0.2
    lodComponent.selectsByScreenSize = true
}
```

A level with `screenPercentage == 0` falls back to its `maxDistance` (also what orthographic projections always use). `LODComponent.screenSizeRadius` overrides the bounding-sphere radius used for the measurement, in the entity's own space.

## 5. Global tuning

```swift
setLOD(.distanceBias(1.5))               // > 1.0 = switch to lower detail sooner (performance mode)
setLOD(.distanceBias(0.75))              // < 1.0 = quality mode
setLOD(.hysteresis(10.0))                // prevents flicker; capped at 1/10 of a level's own switch distance
setLOD(.fadeTransitions(.enabled(duration: 0.5)))   // dithered cross-fade between levels
setLOD(.updateFrameInterval(1))          // default throttles the full pass to every 4 frames
setLOD(.minimumCameraDisplacement(1.0))  // forces an off-cycle update past this much camera movement
setLOD(.distanceThresholds([25.0, 75.0, 200.0]))    // default per-index thresholds when a level omits maxDistance
```

`LODSystem.update()` doesn't re-evaluate every entity every frame — lowering `updateFrameInterval` trades performance for responsiveness; raising `minimumCameraDisplacement` makes fast camera motion less likely to force an extra pass. `LODConfig.shared` still works for compatibility, but prefer `setLOD(...)` for new code — it matches the style of scene channels, rendering, and PostFX settings.

## 6. Forced override (debugging)

```swift
if let lodComponent = scene.get(component: LODComponent.self, for: tree) {
    lodComponent.forcedLOD = 2    // always show LOD2
    // lodComponent.forcedLOD = nil  // resume automatic selection
}
```

Pair with the spatial debug overlay to see what's actually active across the scene: `setSpatialDebug(.lodLevels(true))` (see `untold-performance-diagnostics`).

## 7. Common pitfalls

- Setting transforms before `addLODLevel`/`addLODLevels` finishes — apply them in the completion handler.
- Choosing distance-based thresholds for objects of very different sizes without accounting for scale/FOV — screen-size selection (§4) avoids re-tuning thresholds per object.
- Expecting `LODSystem.update()` to react every frame — it's throttled by `updateFrameInterval`/`minimumCameraDisplacement`; lower/raise those rather than assuming a bug if a switch lags by a frame or two.
- Treating this as the same system as tiled-scene LOD/HLOD — this is per-entity; streamed scenes configure LOD/HLOD per tile in the manifest instead (`untold-geometry-streaming`).

Rough starting point for LOD counts/reduction: small props 2–3 levels, characters/vehicles 3–4, buildings 4–5, terrain 5–8; LOD1 ≈ 50% polygon reduction, LOD2 ≈ 75%, LOD3 ≈ 90% or a billboard.

Full reference: `docs/API/UsingLODSystem.md`, `docs/Architecture/lodSystem.md` (throttling behavior), `docs/API/UsingUntoldEngineCLI.md#lod-chains-for-packs`.
