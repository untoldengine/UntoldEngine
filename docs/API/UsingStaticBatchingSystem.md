# Static Batching System

UntoldEngine supports two batching modes in practice:

| Mode | Use for |
|---|---|
| Manual batch generation | Always-resident static content |
| Runtime cell-based batching | Tiled streaming scenes |

## Manual Batching for Always-Resident Content

Mark loaded entities as static, enable batching, then build the initial artifacts.

```swift
let cube1 = createEntity()
setEntityMesh(entityId: cube1, filename: "cube", withExtension: "untold")
translateTo(entityId: cube1, position: simd_float3(0, 0, 0))
setEntityStaticBatchComponent(entityId: cube1)

let cube2 = createEntity()
setEntityMesh(entityId: cube2, filename: "cube", withExtension: "untold")
translateTo(entityId: cube2, position: simd_float3(2, 0, 0))
setEntityStaticBatchComponent(entityId: cube2)

setBatching(.enabled(true))
generateBatches()
```

For async loading, mark entities static in the completion block:

```swift
let building = createEntity()

setEntityMeshAsync(entityId: building, filename: "office_building", withExtension: "untold") { success in
    guard success else { return }
    setEntityStaticBatchComponent(entityId: building)
    setBatching(.enabled(true))
    generateBatches()
}
```

## Runtime Batching in Tiled Scenes

For tiled scenes, the flow is different:

```swift
let sceneRoot = createEntity()
setEntityName(entityId: sceneRoot, name: "city")

setEntityStreamScene(entityId: sceneRoot, manifest: "city", withExtension: "json") { success in
    setSceneReady(success)
}
```

In this mode:

- `registerTiledScene(...)` enables batching automatically
- full-load tiles notify batching through `notifyTileEntitiesResident(_:)`
- OCC sub-mesh uploads join batching incrementally through normal residency events
- per-tile LOD and HLOD representations can also participate when enabled

You do **not** call `generateBatches()` every time a tile loads. The batching system rebuilds dirty cells incrementally based on residency changes.

## Streamed vs Non-Streamed Scenes

For tiled/streamed scenes, the engine manages static batching automatically. When a tile finishes loading, the engine assigns a `StaticBatchComponent` to all of its entities and schedules an incremental batch rebuild for only the spatial cells affected by that tile. This happens internally on a background queue via the engine's `tick()` loop.

Do **not** call `generateBatches()` for streamed scenes. That function performs a full global rebuild — it queries every entity in the scene simultaneously, merges entities from different tiles into shared batch groups, and allocates all GPU buffers synchronously on the render thread. This overrides the engine's incremental system and causes a noticeable stall.

For streamed scenes, only call `setBatching(.enabled(true))` after the scene loads. The engine handles the rest:

```swift
setEntityStreamScene(entityId: sceneRoot, manifest: "city", withExtension: "json") { success in
    setBatching(.enabled(true))
    setSceneReady(success)
}
```

For non-streamed scenes (single `.untold`), call `setEntityStaticBatchComponent`, `generateBatches()`, and `setBatching(.enabled(true))` as normal. The same applies to any operation that mutates material state (color, opacity) — wrap it with `setBatching(.enabled(false))` before and `generateBatches()` + `setBatching(.enabled(true))` after, but only for non-streamed scenes:

```swift
// Non-streamed only — do not use this pattern in tiled/streamed scenes
setBatching(.enabled(false))
setEntityColor(entityId: prop, color: simd_float4(1, 0, 0, 1))
generateBatches()
setBatching(.enabled(true))
```

## Core APIs

### `setEntityStaticBatchComponent(entityId:)`

Marks an entity hierarchy as eligible for batching.

```swift
setEntityStaticBatchComponent(entityId: entity)
```

### `removeEntityStaticBatchComponent(entityId:)`

Removes static batching tags from the entity hierarchy.

```swift
removeEntityStaticBatchComponent(entityId: entity)
```

### `setBatching(_:)`

Configures runtime batching.

```swift
setBatching(.enabled(true))
setBatching(.cellSize(32.0))
setBatching(.maxDirtyCellsPerTick(8))
setBatching(.visibilityGatedBuild(true))
setBatching(.backgroundArtifactBuild(true))
```

### `generateBatches()`

Builds batch artifacts for the currently marked static entities. This is mainly for always-resident/manual workflows.

```swift
generateBatches()
```

### `clearSceneBatches()`

Clears all generated batch artifacts.

```swift
clearSceneBatches()
```

## Good Candidates

- environment geometry
- buildings and structures
- terrain chunks
- furniture and static props

## Poor Candidates

- characters and NPCs
- vehicles
- projectiles
- animated or skinned meshes
- objects that move frequently

## Notes for the New Architecture

- The batching system is now cell-based and visibility-gated.
- Tile streaming and batching are tightly integrated; residency events are no longer the old per-entity event storm for full-load tiles.
- `TileLODTagComponent` lets batching treat per-tile LODs and HLODs as distinct LOD groups even though they are not entity-level `LODComponent` assets.
- Scene channels separate context geometry from selectable geometry. Entities marked `.preserveIdentity` are excluded from batching, and batch groups are separated by channel mask so channel visibility can be toggled without rebuilding batches.

For architectural details, see [Batching System](../Architecture/batchingSystem).
