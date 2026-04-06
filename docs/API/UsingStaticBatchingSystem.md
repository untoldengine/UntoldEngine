---
id: staticbatchingsystem
title: Static Batching System
sidebar_position: 11
---

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

enableBatching(true)
generateBatches()
```

For async loading, mark entities static in the completion block:

```swift
let building = createEntity()

setEntityMeshAsync(entityId: building, filename: "office_building", withExtension: "untold") { success in
    guard success else { return }
    setEntityStaticBatchComponent(entityId: building)
    enableBatching(true)
    generateBatches()
}
```

## Runtime Batching in Tiled Scenes

For tiled scenes, the flow is different:

```swift
loadTiledScene(manifest: "city", withExtension: "json") { success in
    setSceneReady(success)
}
```

In this mode:

- `registerTiledScene(...)` enables batching automatically
- full-load tiles notify batching through `notifyTileEntitiesResident(_:)`
- OCC sub-mesh uploads join batching incrementally through normal residency events
- per-tile LOD and HLOD representations can also participate when enabled

You do **not** call `generateBatches()` every time a tile loads. The batching system rebuilds dirty cells incrementally based on residency changes.

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

### `enableBatching(_:)`

Globally enables or disables runtime batching.

```swift
enableBatching(true)
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

For architectural details, see [Batching System](../Architecture/batchingSystem).
