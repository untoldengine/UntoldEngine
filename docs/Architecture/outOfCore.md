# Out-of-Core Geometry in the Current Architecture

## Overview

UntoldEngine still uses an out-of-core (OOC) geometry path, but it is now part of the **tile streaming architecture**, not a general public workflow for arbitrary standalone entities.

The public entry point for streamed geometry is:

```swift
setEntityStreamScene(entityId: sceneRoot, manifest: "city", withExtension: "json") { _ in }
```

Inside that pipeline, large tiles may be classified as **OCC/OOC** during the internal `setEntityMeshAsync(streamingPolicy: .auto)` tile parse.

## The Three Runtime Roles

| System | Responsibility |
|---|---|
| `RegistrationSystem` | Parses the `.untold` tile payload and chooses immediate vs OCC registration |
| `ProgressiveAssetLoader` | Stores CPU-resident `CPURuntimeEntry` records keyed by OCC stub entity |
| `GeometryStreamingSystem` | Uploads and evicts tile-owned OCC stubs by distance and budget |

`MeshResourceManager` serves cache-backed `.untold` loads for non-OCC paths. OCC residency is driven by `ProgressiveAssetLoader`.

## What OOC Means Now

When a large tile is routed to the OOC path:

1. The tile payload is parsed on the CPU.
2. Child stub entities are created with `StreamingComponent(state: .unloaded)`.
3. Their `RuntimeAssetNode` CPU data is stored in `ProgressiveAssetLoader`.
4. `GeometryStreamingSystem` uploads those stubs incrementally as the camera approaches.
5. Evicted stubs can re-upload from the warm CPU registry without reparsing the file.

Those `StreamingComponent` stubs are valid only when they are descendants of a `TileComponent` entity. `GeometryStreamingSystem.loadMesh(...)` enforces that ownership rule.

## Public API Boundary

The runtime still exposes `MeshStreamingPolicy`, but the architecture has moved:

- `setEntityMesh(...)` is synchronous and always immediate
- `setEntityMeshAsync(...)` defaults to `.immediate` and is for always-resident assets
- `setEntityMeshAsync(..., streamingPolicy: .immediate)` forces full upload
- `setEntityMeshAsync(..., streamingPolicy: .auto)` is used by tile loading so the runtime can choose immediate vs OCC
- `setEntityStreamScene(...)` is the supported public streaming path
- `StreamingComponent` and `enableStreaming(...)` are internal tile/OOC mechanisms
- `createStreamingEntity(...)` is a public function but a **known gap**: it creates a `StreamingComponent` on a standalone entity with no `TileComponent` ancestor, so the tile-ownership check in `loadMesh()` rejects it and it never actually streams. Don't use it.

That means the old pattern:

```swift
setEntityMeshAsync(..., streamingPolicy: .outOfCore)
enableStreaming(...)
```

is no longer the recommended app-level workflow. The engine now expects streamed geometry to come from a tiled scene manifest.

## OOC Lifecycle

### 1. Tile parse

`loadTile(entityId:)` resolves the tile URL, then calls:

```swift
setEntityMeshAsync(
    entityId: meshEntityId,
    filename: ...,
    withExtension: ...,
    streamingPolicy: .auto,
    blockRenderLoop: false
)
```

The asset admission/classification stage decides whether this tile becomes:

- a **full-load tile**: geometry is uploaded immediately
- an **OOC tile**: child stubs are registered and uploaded later

### 2. Stub registration

For an OOC tile, `registerUntoldProgressiveStubEntity(...)` creates one ECS stub per renderable `RuntimeAssetNode`:

- transform and bounds are registered immediately
- `StreamingComponent` starts as `.unloaded`
- the stub is inserted into the octree
- no GPU buffers are created yet
- renderable nodes are always child entities, including single-node assets, so descendant tracking is consistent

### 3. CPU registry

Each stub stores a `CPURuntimeEntry` in `ProgressiveAssetLoader`, including:

- source `RuntimeAssetNode`
- source `.untold` URL
- unique mesh name
- estimated GPU bytes
- original loading policy

This is the warm CPU copy used for re-upload.

### 4. Incremental GPU upload

On streaming ticks, `GeometryStreamingSystem` evaluates tile-owned OCC stubs:

- near-band stubs are serialized with `nearBandMaxConcurrentLoads`
- total mesh uploads are capped by `maxConcurrentLoads`
- geometry budget checks can trigger texture shedding and eviction before new uploads

Successful upload transitions the stub from `.loading` to `.loaded`, increments the parent tile's OCC-ready counters, and emits normal residency events for batching.

### 5. Eviction

When the camera moves away or geometry pressure rises:

- `unloadMesh(entityId:)` clears `RenderComponent.mesh`
- `MemoryBudgetManager` unregisters the GPU allocation
- the CPU entry remains warm unless the root asset is explicitly cooled

This is why a normal OOC re-approach can re-upload without a disk read.

## Interaction with Tile Streaming

OOC is just one representation inside the broader tile system:

- **full tile** for near field
- **per-tile LOD** for mid range
- **HLOD** for far range
- **OOC child stubs** for large tiles whose full geometry should not upload all at once

That is why the runtime documentation should describe OOC as an implementation detail of tile streaming rather than a separate public scene-loading mode.

## Key Takeaways

- OOC still exists, but it is now subordinate to tile ownership.
- `ProgressiveAssetLoader` is the `.untold` CPU runtime-node residency layer.
- `GeometryStreamingSystem` is the GPU residency scheduler.
- `setEntityStreamScene(...)` is the supported public streaming API surface.
