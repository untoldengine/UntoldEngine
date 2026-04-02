---
id: lodstaticbatchinstreaminggsystem
title: Lod + Static Batching + Streaming System
sidebar_position: 12
---

# Combining LOD, Batching, and Geometry Streaming

The Untold Engine provides three complementary systems for optimizing rendering performance:

- **LOD (Level of Detail)**: Automatically switches between different mesh resolutions based on distance from the camera. Closer objects use high-detail meshes, while distant objects use simplified versions.
- **Static Batching**: Combines multiple static meshes with the same material into a single draw call, reducing CPU overhead.
- **Geometry Streaming**: Dynamically loads and unloads geometry based on proximity to the camera, keeping only nearby objects in memory.

When used together, these systems provide powerful performance optimization:
- LOD reduces GPU load by rendering appropriate detail levels
- Batching reduces CPU overhead by minimizing draw calls
- Streaming reduces memory usage by only keeping nearby geometry loaded

Before using the examples below, assume your scene has:
- A valid active camera (used for LOD switching and streaming distance checks)
- Entity transforms in world space before runtime optimization kicks in
- Mesh/material naming consistency across LOD levels (to avoid mismatched assets)
- A clear decision on whether setup happens procedurally at runtime or from a serialized scene file

In practice, there are two common workflows:
- **Procedural setup**: You create entities and configure LOD/batching/streaming in code during scene initialization.
- **Scene deserialization**: You load a saved scene where components were already authored, then finalize runtime systems in completion callbacks.

## LOD + Batching

This combination is ideal for scenes with many static objects that remain loaded throughout the scene lifetime. The LOD system manages visual quality based on distance, while batching reduces draw calls for objects using the same material.

**Key Points:**
- All entities must have their meshes loaded before calling `generateBatches()`
- Use the completion callback from `addLODLevels()` to ensure meshes are ready
- Enable batching and generate batches only after all entities are configured

Why this order matters: batching relies on mesh/material data that is only guaranteed after async LOD loading completes. If `generateBatches()` runs too early, some entities may be missing from batches, causing inconsistent draw-call reduction.

```swift
private func setupLODWithBatching() {
    var loadedCount = 0
    let totalTrees = 20
    
    for i in 0 ..< totalTrees {
        let tree = createEntity()
        setEntityName(entityId: tree, name: "Tree_\(i)")

        // Capture position values for the closure
        let x = Float(i % 5) * 10.0
        let z = Float(i / 5) * 10.0

        setEntityLodComponent(entityId: tree)

        addLODLevels(entityId: tree, levels: [
            (0, "tree_LOD0", "usdz", 50.0, 0.0),
            (1, "tree_LOD1", "usdz", 100.0, 0.0),
            (2, "tree_LOD2", "usdz", 200.0, 0.0),
        ]) { success in
            if success {
                // Apply transform AFTER mesh is loaded
                translateTo(entityId: tree, position: simd_float3(x, 0, z))
                setEntityStaticBatchComponent(entityId: tree)
            }
            
            // Track completion
            loadedCount += 1
            if loadedCount == totalTrees {
                enableBatching(true)
                generateBatches()
                print("\(totalTrees) trees configured with LOD + Batching")
            }
        }
    }

}
```

For procedurally-created always-resident objects, the completion callback from `addLODLevels()` is the right place to generate batches — it fires after all async mesh loads complete.

## LOD + Batching + Streaming

This combination is ideal for large open-world scenes where you have many objects spread across a large area. Streaming ensures only nearby geometry is loaded into memory, LOD manages visual quality, and batching reduces draw calls for loaded objects.

The canonical path for streamable geometry is a **manifest-driven tiled scene**. Streaming radii, prefetch distance, and LOD configuration are declared in the manifest JSON; no runtime streaming flags are needed. The tile streaming system handles load/unload automatically as the camera moves.

```swift
loadTiledScene(manifest: "city") { success in
    setSceneReady(success)
}
```

Batching and LOD are configured per-tile in the manifest and activated automatically by the streaming system when each tile finishes parsing.

### Always-resident objects with LOD + Batching

For objects that should always be in GPU memory (characters, gameplay props), use `setEntityMeshAsync` with LOD levels and static batching:

```swift
private func setupLODWithBatching() {
    var loadedCount = 0
    let totalTrees = 20
    
    for i in 0 ..< totalTrees {
        let tree = createEntity()
        setEntityName(entityId: tree, name: "Tree_\(i)")

        let x = Float(i % 5) * 10.0
        let z = Float(i / 5) * 10.0

        setEntityLodComponent(entityId: tree)

        addLODLevels(entityId: tree, levels: [
            (0, "tree_LOD0", "usdz", 50.0, 0.0),
            (1, "tree_LOD1", "usdz", 100.0, 0.0),
            (2, "tree_LOD2", "usdz", 200.0, 0.0),
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

**Radius Guidelines (for per-tile LOD in manifests):**
- LOD switch distances should be smaller than the tile's `streaming_radius`
- `unload_radius` should be significantly larger than `streaming_radius` to avoid thrashing (e.g., 120 when streaming radius is 80)

## Best Practices

### When to Use Each Combination

**LOD Only:**
- Small scenes with few objects
- When objects are always visible and memory isn't a concern
- Dynamic objects that move frequently

**LOD + Batching:**
- Medium-sized scenes with many static objects
- Objects share materials and remain loaded
- Memory usage is acceptable
- Example: Interior spaces, small outdoor areas

**LOD + Batching + Streaming:**
- Large open-world scenes
- Many objects spread across large distances
- Memory optimization is critical
- Example: Forests, cities, large outdoor environments

### Performance Tips

1. **LOD Distances**: Set LOD transition distances based on your object size and visual importance. Smaller objects can transition earlier.

2. **Batching Materials**: Entities must share the same material to be batched together. Group objects by material when possible.

3. **Streaming Priorities**: Use higher priority values (e.g., 10) for important objects like landmarks, lower values (e.g., 1) for background details.

4. **Testing**: Monitor frame rate and memory usage to fine-tune your radius values and LOD distances for your specific scene.

5. **Completion Callbacks**: Always use the completion callback from `addLODLevels()` to ensure meshes are fully loaded before enabling other systems.
