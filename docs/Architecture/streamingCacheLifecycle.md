# Streaming Cache Lifecycle

This document describes how the current streaming architecture manages geometry across three layers:

| Layer | Owns |
|---|---|
| `GeometryStreamingSystem` | Distance-based residency decisions |
| `ProgressiveAssetLoader` | Warm CPU `RuntimeAssetNode` state for tile-owned OCC assets |
| `MeshResourceManager` | Shared GPU mesh cache for immediate/cache-backed `.untold` paths |

## Two Residency Modes

### Full-load / cache-backed meshes

For eager loads, `MeshResourceManager` owns the shared mesh data:

- `loadMesh(url:meshName:)` returns cached or freshly loaded meshes
- `retain(...)` increments residency ownership for an entity
- `release(entityId:)` decrements the reference count
- `evictUnused()` frees GPU data when the ref count reaches zero

### Tile-owned OOC meshes

For large streamed tiles, `ProgressiveAssetLoader` owns the CPU source data:

- `CPURuntimeEntry` stores the parsed `RuntimeAssetNode`
- `GeometryStreamingSystem` uploads those buffers on demand
- eviction normally drops only GPU residency
- tile teardown releases the CPU entries for that root

## Current Lifecycle

### 1. Tiled scene registration

`setEntityStreamScene(...)` registers lightweight `TileComponent` stubs only, parented under the supplied root entity. No geometry is resident yet.

### 2. Tile parse

When a tile enters prefetch range, `loadTile(entityId:)` parses the tile payload.

At that point the runtime chooses one of two outcomes:

- **full-load tile**: render entities are GPU-resident immediately
- **OCC tile**: child `StreamingComponent` stubs are registered and backed by `CPURuntimeEntry`

### 3. OOC upload

For OOC stubs, `GeometryStreamingSystem.loadMesh(...)`:

1. checks tile ownership
2. reserves an active streaming slot
3. uploads from `ProgressiveAssetLoader`
4. marks the entity loaded and emits residency change events

### 4. Full-load cache use

For eager/disk-backed meshes, the load path uses `MeshResourceManager`:

1. `loadMesh(...)`
2. `retain(...)`
3. entity-local `copyWithNewUniformBuffers()`
4. apply to `RenderComponent`

The copied uniform buffers are per-entity, but the underlying cached geometry is shared.

### 5. Eviction

When geometry leaves range or memory pressure rises:

- `unloadMesh(...)` clears the entity's live mesh reference
- `MeshResourceManager.release(entityId:)` decrements shared cache refs when applicable
- OCC stubs keep their CPU source warm until tile/root teardown

### 6. Cache cleanup

`MeshResourceManager.evictUnused()` removes zero-ref cached meshes. This is the first stage of geometry relief before more aggressive runtime eviction.

## Why the Split Exists

The split cache model supports both fast reuse and bounded memory:

- `MeshResourceManager` is efficient for shared eager meshes and disk-backed reloads
- `ProgressiveAssetLoader` avoids reparsing large tiles on every near/far traversal
- `GeometryStreamingSystem` arbitrates both with the same distance, frustum, and budget logic

## Practical Reading

When reviewing a streamed tile today, think of residency in this order:

1. Is the tile stub in range?
2. Did the tile classify as full-load or OOC?
3. If OOC, does the child stub have a `CPURuntimeEntry`?
4. Is the GPU copy currently resident?
5. Is batching representing the entity directly or via a cell artifact?
