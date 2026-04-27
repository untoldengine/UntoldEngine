# Geometry Streaming System

UntoldEngine streams large worlds through a **manifest-driven tiled scene** pipeline.

The public rule is simple:

| Use case | API |
|---|---|
| Streamed world geometry (manifest-driven) | `setEntityStreamScene(entityId:manifest:withExtension:completion:)` |
| Handcrafted streaming zones (no manifest) | `StreamingRegionManager` — register `StreamingRegion` AABB + asset lists directly |
| Always-resident assets | `setEntityMeshAsync(entityId:filename:withExtension:completion:)` |

`GeometryStreamingSystem` manages the runtime once a streamed scene is loaded. It is not a public component-authoring workflow for standalone entities.

> For handcrafted zone streaming without a manifest (e.g. dungeon rooms, level sectors), use `StreamingRegionManager.shared`. See the [StreamingRegionManager architecture doc](../Architecture/streamingRegionManager) for the full API.

## Public Workflow

### Local manifest

```swift
let sceneRoot = createEntity()
setEntityName(entityId: sceneRoot, name: "city")

setEntityStreamScene(entityId: sceneRoot, manifest: "city", withExtension: "json") { success in
    setSceneReady(success)
}
```

### Remote manifest

```swift
let sceneRoot = createEntity()
setEntityName(entityId: sceneRoot, name: "city")

if let url = URL(string: "https://cdn.example.com/city/city.json") {
    setEntityStreamScene(entityId: sceneRoot, url: url) { success in
        setSceneReady(success)
    }
}
```

> **Legacy overloads** — `loadTiledScene(manifest:)` and `loadTiledScene(url:)` remain available for backwards compatibility. They create an internal root entity automatically. Prefer `setEntityStreamScene(entityId:...)` when you need a stable handle to the scene.

Remote manifests are downloaded and cached locally. Tile, HLOD, and per-tile LOD URLs are resolved relative to the manifest URL and fetched on demand.

## What Streams

The engine uses multiple geometry layers:

- **Full tile**: the main tile payload loaded by `loadTile()`
- **Per-tile LOD**: intermediate meshes shown while the full tile is still out of range
- **HLOD**: coarse far-distance proxy
- **OCC sub-mesh stubs**: fine-grained `StreamingComponent` entities created internally inside large tiles

`StreamingComponent` is internal to the tile-owned OCC path. External callers should not attach it manually or rely on `enableStreaming(...)`.

## Manifest Fields That Matter

These are the important fields for geometry streaming:

| Field | Meaning |
|---|---|
| `streaming_radius` | Full tile display zone |
| `unload_radius` | Tile teardown threshold |
| `prefetch_radius` | Background parse threshold before the tile becomes visible |
| `priority` | Tile load ordering when many tiles compete |
| `hlod_levels` | Optional far proxy meshes |
| `lod_levels` | Optional per-tile intermediate LOD meshes |
| `file_size_bytes` | Parse-budget hint used by the runtime gate |

If `prefetch_radius` is omitted, the engine computes it automatically from the gap between `streaming_radius` and `unload_radius`.

## Runtime Behavior

Each update tick, `GeometryStreamingSystem`:

1. Queries the octree within `maxQueryRadius`.
2. Chooses tile parse candidates using predictive camera motion and a frustum gate.
3. Parses up to `maxConcurrentTileLoads` tiles, subject to `tileParseMemoryBudgetMB`.
4. Streams OCC child meshes inside loaded tiles using `maxConcurrentLoads`.
5. Unloads tiles, LODs, HLODs, and OCC meshes when they leave range or memory pressure requires eviction.

Important defaults:

- `maxConcurrentTileLoads = 2`
- `maxConcurrentLoads = 3`
- `maxConcurrentLODLoads = 4`
- `maxConcurrentHLODLoads = 4`
- `updateInterval = 0.1`
- `burstTickInterval = 0.016`

## Useful Runtime Knobs

```swift
GeometryStreamingSystem.shared.maxConcurrentTileLoads = 2
GeometryStreamingSystem.shared.maxConcurrentLoads = 3
GeometryStreamingSystem.shared.enableFrustumGate = true
GeometryStreamingSystem.shared.tileFrustumGatePadding = 20.0
GeometryStreamingSystem.shared.maxQueryRadius = 500.0
```

Use `maxQueryRadius` large enough to cover the farthest `unload_radius` in the scene, or out-of-range tiles may not be discovered for teardown.

## Interaction with Other Systems

- **Texture streaming**: `setEntityStreamScene(...)` automatically aligns texture distance bands to the manifest radii.
- **Batching**: full-load tiles, per-tile LODs, and HLODs notify `BatchingSystem` automatically. OCC sub-mesh uploads join batching incrementally through normal residency events.
- **Memory pressure**: texture quality is shed first; geometry eviction follows only when geometry pressure remains high.

## Common Problems

### Tiles pop in on camera rotation

- Increase `GeometryStreamingSystem.shared.tileFrustumGatePadding`
- Keep `enableFrustumGate = true`

### Tiles unload and reload too aggressively

- Increase the gap between `streaming_radius` and `unload_radius`
- Increase or explicitly author `prefetch_radius`

### Tile parse bursts spike memory

- Lower `maxConcurrentTileLoads`
- Reduce per-tile file sizes in the exported manifest

### Streaming does nothing

- Verify you loaded the scene through `setEntityStreamScene(...)`
- Verify the manifest radii are reasonable for your scene scale
- Do not expect standalone `StreamingComponent` entities to stream; tile ownership is enforced

## Related Docs

- [Tile-Based Streaming](../Architecture/tilebasedstreaming)
- [Geometry Streaming Architecture](../Architecture/geometryStreamingSystem)
- [Texture Streaming](../Architecture/textureStreamingSystem)
- [Remote Asset Streaming](../Architecture/asset_remote_streaming)
