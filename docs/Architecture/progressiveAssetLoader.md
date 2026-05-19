# Progressive Asset Loader

## TL;DR

`ProgressiveAssetLoader` is the CPU registry for native `.untold` out-of-core
geometry. It stores `CPURuntimeEntry` records for tile-owned OCC stub entities
and serves those records to `GeometryStreamingSystem` when a stub enters
streaming range.

The previous USDZ/ModelIO path (`MDLAsset`, `MDLObject`, `MDLMesh`,
`CPUMeshEntry`, LOD+OOC registries, texture prewarm locks, and cold
rehydration) has been removed from the streaming/OCC system. Runtime OCC now
operates on `.untold` `RuntimeAssetNode` data only.

`tick()` remains as a no-op compatibility shim.

---

## What It Stores

When a `.untold` tile is routed through the OCC path, registration creates
zero-GPU child stubs for each renderable runtime node. Each stub gets one CPU
entry:

```swift
struct CPURuntimeEntry {
    let node: RuntimeAssetNode
    let url: URL
    let uniqueAssetName: String
    let estimatedGPUBytes: Int
    let residencyPolicy: AssetLoadingPolicy
}
```

Entries live in:

```swift
private var cpuRuntimeRegistry: [EntityID: CPURuntimeEntry]
private var rootEntityChildren: [EntityID: [EntityID]]
```

The key is the OCC stub entity ID. `rootEntityChildren` groups those stub IDs
under the tile mesh-root entity so teardown can remove all CPU entries for a
tile at once.

`RuntimeAssetNode` owns self-contained vertex and index `Data` blobs, so no
parent `MDLAsset` or file container has to remain alive for buffer validity.

---

## Registration Flow

```
setEntityStreamScene(...)
  └─ GeometryStreamingSystem.loadTile(...)
      └─ setEntityMeshAsync(..., streamingPolicy: .auto, blockRenderLoop: false)
          ├─ NativeFormatLoader.loadAssetSync(...)  → RuntimeAsset
          ├─ classify tile as immediate or OCC
          └─ registerUntoldRuntimeAssetOCC(...)
              ├─ create child OCC stubs
              ├─ attach StreamingComponent(.unloaded)
              ├─ register each stub in the octree
              ├─ storeCPURuntimeEntry(entry, for: childStubId)
              └─ registerChildren(childStubIds, for: tileMeshRootId)
```

Renderable nodes are always represented by child stub entities, including
single-node assets. This keeps descendant counting and tile ownership checks
consistent.

For parented nodes, registration computes:

```swift
childLocal = inverse(parentWorld) * nodeWorld
```

After `setParent`, the stub lands at the node's intended world transform
without double-applying the parent transform.

---

## Upload Flow

When a stub enters range, `GeometryStreamingSystem` retrieves its CPU entry:

```swift
let entry = ProgressiveAssetLoader.shared.retrieveCPURuntimeEntry(for: entityId)
```

The upload path converts `entry.node.primitives` into engine `Mesh` values,
creates Metal buffers, registers a `RenderComponent`, and marks the
`StreamingComponent` as `.loaded`.

Normal unload clears GPU residency but keeps the `CPURuntimeEntry` warm, so
re-approaching the same stub re-uploads from CPU memory without reparsing the
`.untold` file.

---

## API Surface

| Method | Purpose |
|---|---|
| `storeCPURuntimeEntry(_:for:)` | Store one `.untold` runtime node entry for an OCC stub |
| `retrieveCPURuntimeEntry(for:)` | Fetch the entry for GPU upload |
| `hasCPURuntimeData(for:)` | Check whether a stub has CPU data ready |
| `removeCPURuntimeEntry(for:)` | Remove one stub entry |
| `registerChildren(_:for:)` | Associate child stub IDs with a tile/root entity |
| `getChildren(for:)` | Return registered OCC children for a root |
| `removeOutOfCoreAsset(rootEntityId:)` | Release all CPU entries for a root |
| `cancelAll()` | Release all CPU entries; used for scene reset and tests |
| `tick()` | No-op compatibility shim |

There is no longer a public or internal `storeAsset`, `releaseWarmAsset`,
`cpuLODRegistry`, `rootAssetRefs`, or per-asset texture lock in this system.

---

## Memory Model

```
CPU RAM:  RuntimeAssetNode Data blobs for unloaded/loaded OCC stubs
GPU RAM:  Only OCC stubs currently within streaming range
Disk:     Read when the tile is parsed
```

This trades CPU memory for predictable GPU residency. The CPU copy is retained
until the tile/root is destroyed or `removeOutOfCoreAsset(rootEntityId:)` is
called.

---

## Cleanup

Tile unload calls:

```swift
ProgressiveAssetLoader.shared.removeOutOfCoreAsset(rootEntityId: rootId)
```

This removes all `CPURuntimeEntry` records registered for that root.

For full teardown:

```swift
ProgressiveAssetLoader.shared.cancelAll()
```

Use this during scene resets and test teardown.
