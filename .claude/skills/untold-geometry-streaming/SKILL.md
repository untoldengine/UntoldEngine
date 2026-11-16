---
name: untold-geometry-streaming
description: Use when loading or configuring a large, manifest-driven tiled scene that streams geometry in and out of memory as the camera moves — city districts, campuses, dungeons, large real-world scans — rather than one always-resident model. Covers setEntityStreamScene (local and remote manifests), concurrency/candidate tuning, and switching between streamed scenes/sessions. Triggers on "this scene is too big to load at once", "stream tiles as the camera moves", "load a remote manifest", "switch to a different city/level". Not for exporting the tiled manifest itself (see untold-asset-pipeline, "Tiled / large streamed scenes"), triaging streaming performance after it's running (see untold-performance-diagnostics), non-streamed single-asset loading (see untold-entity-scene), or per-entity LOD on one always-resident model outside a tiled manifest (see untold-lod-system).
version: 0.1.0
---

# Geometry Streaming (Tiled Scenes) in Untold Engine

Use this when a scene is large enough that loading it as one resident model isn't viable — city blocks, campuses, dungeons, large scans. The engine streams a manifest-described set of tiles in and out of memory based on camera distance. This is the runtime counterpart to the exporter's tiled-scene output (`untold-asset-pipeline`), which produces the manifest this skill loads.

## 1. Decide: streamed scene vs. resident asset

- `setEntityMeshAsync(...)` — normal models that should stay resident (see `untold-entity-scene`).
- `setEntityStreamScene(...)` — a scene large enough that only nearby geometry should be loaded at once.

Don't reach for streaming for a scene that fits comfortably as one resident asset — it adds tile-residency bookkeeping you don't need.

## 2. Enable streaming and load a manifest

```swift
setGeometryStreaming(.enabled(true))

let cityRoot = createEntity()
setEntityName(entityId: cityRoot, name: "LowPolyCity")

setEntityStreamScene(entityId: cityRoot, manifest: "LowPolyCity", withExtension: "json") { success in
    setSceneReady(success)
}
```

The manifest (`LowPolyCity.json`) and its tile folder (`LowPolyCity/`) live under `GameData/StreamModels/`. `setEntityStreamScene` registers lightweight tile stub entities immediately; the engine then loads/unloads actual tile geometry as the camera moves. The engine's default concurrency/query-radius/candidate-selection values are sensible — enabling streaming is enough to see tiles load/unload before you tune anything (see [§4](#4-tune-streaming-behavior)).

**Never call `generateBatches()` for streamed tiles.** The streaming path updates static batching incrementally as tile/LOD/HLOD representations become resident — an explicit `generateBatches()` call is only for always-resident static content (`setEntityStaticBatchComponent` + `setBatching(.enabled(true))` + `generateBatches()`).

## 3. Remote manifests

Same API, a URL instead of a bundled filename:

```swift
if let url = URL(string: "https://cdn.example.com/City/City.json") {
    setEntityStreamScene(entityId: cityRoot, url: url) { success in
        setSceneReady(success)
    }
}
```

Remote manifests are downloaded and cached locally; tile/LOD/HLOD/texture URLs resolve relative to the manifest URL and fetch on demand. Get local manifests working first — manifest structure, tile bounds, LODs, memory behavior — before moving to remote streaming, so a remote-specific bug (network, caching) isn't confused with a manifest bug.

## 4. Tune streaming behavior

Concurrency:

```swift
setGeometryStreaming(.tileConcurrency(2))
setGeometryStreaming(.meshConcurrency(3))
setGeometryStreaming(.lodConcurrency(4))
setGeometryStreaming(.hlodConcurrency(4))
```

Candidate selection:

```swift
setGeometryStreaming(.queryRadius(120.0))
setGeometryStreaming(.frustumGate(.enabled(meshPadding: 6.0, tilePadding: 8.0)))
setGeometryStreaming(.velocityLookAhead(time: 0.5, minSpeed: 1.5))
setGeometryStreaming(.candidateSorting(importance: true, occlusion: true))
```

These calls only configure behavior — they don't load content by themselves, and they're meaningless before a manifest-backed scene is registered. Keep `queryRadius` at or above the manifest's largest `unload_radius`; too small a radius means out-of-range tiles are never discovered for unloading.

## 5. Switching streamed scenes/sessions

When moving from one streamed scene to another, clear parsed tile memory first instead of relying on distance-based unload:

```swift
GeometryStreamingSystem.shared.forceUnloadAllParsedTiles()
destroyEntity(entityId: oldRoot)
clearSceneBatches()   // if the demo/app also used static batching alongside streaming

let newRoot = createEntity()
setEntityName(entityId: newRoot, name: "NewScene")
setEntityStreamScene(entityId: newRoot, manifest: "NewScene", withExtension: "json") { success in
    setSceneReady(success)
}
```

**Do not call `forceUnloadAllParsedTiles()` during normal camera movement** — ordinary traversal is handled by distance-based unload. Reserve it for scene/session transitions.

## 6. Camera movement and large-jump locomotion

Any camera movement (free-fly WASD for debug builds, XR scene-root drag, or a teleport) drives tile residency — the streaming system re-queries candidates whenever the camera's position relative to the scene root changes. For Vision Pro, combine fine positioning (pinch-drag/two-hand rotate via `SpatialManipulationSystem.shared.processAnchoredSceneManipulationLifecycle`, see `untold-xr-spatial`) with tap-to-teleport for large jumps across a big scene:

```swift
if state.spatialTapActive,
   let hitPos = state.pickedEntityWorldPosition,
   let normal = state.pickedEntityWorldNormal,
   isWalkable(normal),
   simd_length(simd_float3(hitPos.x, 0, hitPos.z)) <= maxTeleportDistanceMeters
{
    translateSceneBy(delta: simd_float3(-hitPos.x, 0, -hitPos.z))
}
```

Keep `maxTeleportDistanceMeters` at or below the manifest's `queryRadius` so a teleport destination is guaranteed to already be inside streaming range — otherwise the user lands somewhere with nothing loaded yet.

## 7. Manifest concepts (for reference, not authoring)

The manifest is produced by the exporter (`untoldengine export-tiles`, see `untold-asset-pipeline`) — don't hand-author it. Key fields when reasoning about tuning:

| Field | Purpose |
| --- | --- |
| `streaming_radius` | Distance where a tile's full representation becomes visible |
| `unload_radius` | Distance where the tile can be unloaded |
| `prefetch_radius` | Distance where background parsing can begin before the tile is needed |
| `lod_levels` | Intermediate per-tile representations |
| `hlod_levels` | Coarse far-distance representations |

## 8. Inspecting what's happening

For a quick look while developing, read live stats (full diagnostics + triage workflow lives in `untold-performance-diagnostics`):

```swift
let stats = GeometryStreamingSystem.shared.getStats()
Logger.log(message: stats.description)
// or
GeometryStreamingSystem.shared.printStats()
```

Full reference: `docs/API/UsingGeometryStreamingSystem.md`, `docs/API/UsingLOD-Batching-Streaming.md`, `docs/Architecture/tilebasedstreaming.md`, `docs/Architecture/asset_remote_streaming.md`.
