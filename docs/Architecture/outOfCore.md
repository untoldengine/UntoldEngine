# Out-of-Core Geometry in the Current Architecture

## Overview

UntoldEngine still uses an out-of-core (OOC) geometry path, but it is now part of the **tile streaming architecture**, not a general public workflow for arbitrary standalone entities.

The public entry point for streamed geometry is:

```swift
setEntityStreamScene(entityId: sceneRoot, manifest: "city")
```

Inside that pipeline, large tiles may be classified as **OOC** during `setEntityMeshAsync(streamingPolicy: .auto)`.

## The Three Runtime Roles

| System | Responsibility |
|---|---|
| `RegistrationSystem` | Parses the tile payload and chooses `fullLoad` vs OOC registration |
| `ProgressiveAssetLoader` | Stores CPU-resident `CPUMeshEntry` records and warm/cold rehydration context |
| `GeometryStreamingSystem` | Uploads and evicts tile-owned OCC stubs by distance and budget |

`MeshResourceManager` still serves disk/cache-backed mesh loads for non-OOC paths, but OOC residency is fundamentally driven by `ProgressiveAssetLoader`.

## What OOC Means Now

When a large tile is routed to the OOC path:

1. The tile payload is parsed on the CPU.
2. Child stub entities are created with `StreamingComponent(state: .unloaded)`.
3. Their CPU mesh data is stored in `ProgressiveAssetLoader`.
4. `GeometryStreamingSystem` uploads those stubs incrementally as the camera approaches.
5. Evicted stubs can re-upload from the warm CPU registry without reparsing the file.

Those `StreamingComponent` stubs are valid only when they are descendants of a `TileComponent` entity. `GeometryStreamingSystem.loadMesh(...)` enforces that ownership rule.

## Public API Boundary

The runtime still exposes `MeshStreamingPolicy`, but the architecture has moved:

- `setEntityMeshAsync(..., streamingPolicy: .auto)` is fine for normal always-resident assets
- `setEntityMeshAsync(..., streamingPolicy: .immediate)` forces full upload
- `setEntityStreamScene(...)` is the supported public streaming path
- `StreamingComponent` and `enableStreaming(...)` are internal tile/OOC mechanisms

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

For an OOC tile, `registerProgressiveStubEntity(...)` creates one ECS stub per mesh leaf:

- transform and bounds are registered immediately
- `StreamingComponent` starts as `.unloaded`
- the stub is inserted into the octree
- no GPU buffers are created yet

### 3. CPU registry

Each stub stores a `CPUMeshEntry` in `ProgressiveAssetLoader`, including:

- source `MDLObject`
- vertex descriptor
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

### 6. Warm-to-cold transition

On critical pressure, the engine may release warm CPU state:

```swift
ProgressiveAssetLoader.shared.releaseWarmAsset(rootEntityId:)
```

This frees the retained `MDLAsset` tree and CPU mesh buffers but preserves the rehydration context. A later re-approach reparses the root asset once and rebuilds the CPU registry.

## Interaction with Tile Streaming

OOC is just one representation inside the broader tile system:

- **full tile** for near field
- **per-tile LOD** for mid range
- **HLOD** for far range
- **OOC child stubs** for large tiles whose full geometry should not upload all at once

That is why the runtime documentation should describe OOC as an implementation detail of tile streaming rather than a separate public scene-loading mode.

## Key Takeaways

- OOC still exists, but it is now subordinate to tile ownership.
- `ProgressiveAssetLoader` is the CPU residency layer.
- `GeometryStreamingSystem` is the GPU residency scheduler.
- `setEntityStreamScene(...)` is the supported public streaming API surface.
