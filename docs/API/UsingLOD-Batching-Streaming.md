---
id: lodstaticbatchinstreaminggsystem
title: Lod + Static Batching + Streaming System
sidebar_position: 12
---

# Combining LOD, Batching, and Streaming

UntoldEngine now has two distinct optimization workflows:

| Workflow | Use for |
|---|---|
| Entity-level LOD + manual batching | Always-resident props, structures, authored gameplay objects |
| Manifest-driven tile streaming + automatic batching | Large worlds, terrain, cities, remote streamed scenes |

## 1. Always-Resident Objects

For normal entities that should stay resident, combine `LODComponent` with `StaticBatchComponent`:

```swift
private func setupLODWithBatching() {
    var loadedCount = 0
    let totalTrees = 20

    for i in 0 ..< totalTrees {
        let tree = createEntity()
        setEntityName(entityId: tree, name: "Tree_\(i)")
        setEntityLodComponent(entityId: tree)

        let x = Float(i % 5) * 10.0
        let z = Float(i / 5) * 10.0

        addLODLevels(entityId: tree, levels: [
            (0, "tree_LOD0", "untold", 50.0, 0.0),
            (1, "tree_LOD1", "untold", 100.0, 0.0),
            (2, "tree_LOD2", "untold", 200.0, 0.0),
        ]) { success in
            if success {
                translateTo(entityId: tree, position: simd_float3(x, 0, z))
                setEntityStaticBatchComponent(entityId: tree)
            }

            loadedCount += 1
            if loadedCount == totalTrees {
                enableBatching(true)
                generateBatches()
            }
        }
    }
}
```

This is still the correct pattern when all meshes are present up front and stay resident.

## 2. Streamed Worlds

For large worlds, do **not** build a manual LOD + `enableStreaming(...)` stack on standalone entities. Use the tiled-scene pipeline:

```swift
let sceneRoot = createEntity()
setEntityName(entityId: sceneRoot, name: "city")

setEntityStreamScene(entityId: sceneRoot, manifest: "city", withExtension: "json") { success in
    setSceneReady(success)
}
```

In this workflow:

- full-tile streaming is driven by manifest radii
- per-tile `lod_levels` supply intermediate representations
- `hlod_levels` cover the far field
- OCC mesh stubs are created internally for large tiles
- static batching is updated automatically as tiles, LODs, and OCC meshes become resident

You do **not** call `generateBatches()` per tile. The runtime hands new resident tile geometry directly to `BatchingSystem`.

## Choosing Between the Two

### Use entity-level LOD + batching when:

- the asset should remain in memory
- you are placing a bounded number of authored objects
- you want direct programmatic control over LOD levels per entity

### Use tile streaming when:

- the scene is large enough that full residency is wasteful
- you need prefetch, HLOD, per-tile LOD, and eviction
- you want local or remote manifest-driven world streaming

## Practical Rules

- Keep dynamic or animated entities out of static batching.
- Use `.untold` for static runtime geometry whenever possible.
- Keep entity-level LOD for authored objects; keep tile LOD/HLOD in the manifest.
- Treat `StreamingComponent` as internal to the tiled streaming architecture.

## Related Docs

- [Geometry Streaming System](./UsingGeometryStreamingSystem.md)
- [Static Batching System](./UsingStaticBatchingSystem.md)
- [LOD System](./UsingLODSystem.md)
- [Tile-Based Streaming Architecture](../Architecture/tilebasedstreaming)
