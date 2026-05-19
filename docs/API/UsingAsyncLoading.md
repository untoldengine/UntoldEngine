# Async Loading System

UntoldEngine loads meshes asynchronously so scene setup does not stall the render loop. Use native `.untold` assets for runtime geometry. USD/USDZ files remain authoring/import inputs for the exporter, but runtime mesh loading and streaming use `.untold`.

## What the API Does

`setEntityMeshAsync` is the primary async asset-loading API for always-resident assets:

```swift
let entity = createEntity()

setEntityMeshAsync(
    entityId: entity,
    filename: "robot",
    withExtension: "untold"
) { success in
    guard success else { return }
    translateTo(entityId: entity, position: simd_float3(0, 0, 0))
}
```

The completion `Bool` is a **success flag**:

- `true`: the asset loaded and registered successfully
- `false`: loading failed and the engine fell back to the default placeholder mesh

For ordinary public use, this API loads the asset immediately into GPU residency. It does not opt the asset into tile streaming.

## Scene Readiness Guard

Use scene readiness when your own setup performs multiple dependent mutations:

```swift
setSceneReady(false)

let entity = createEntity()
setEntityMeshAsync(entityId: entity, filename: "robot", withExtension: "untold") { success in
    if success {
        setEntityKinetics(entityId: entity)
        translateTo(entityId: entity, position: simd_float3(0, 0, 0))
    }
    setSceneReady(success)
}
```

For ordinary `setEntityMeshAsync(...)` and `setEntityStreamScene(...)` flows, the engine already uses internal loading gates. `setSceneReady(...)` is mainly for your own multi-step scene setup.

## Choosing the Right Loading Path

| Use case | API |
|---|---|
| Small asset needed immediately on the next line | `setEntityMesh(...)` |
| Single always-resident asset | `setEntityMeshAsync(...)` |
| Large streamed world | `setEntityStreamScene(...)` |

### Synchronous always-resident asset

Use `setEntityMesh` when setup code needs the mesh registered before the next statement runs:

```swift
let player = createEntity()
setEntityMesh(entityId: player, filename: "player", withExtension: "untold")
translateTo(entityId: player, position: simd_float3(0, 0, 0))
```

This is a blocking immediate load. Do not use it for large runtime assets or tile-streamed worlds.

### Always-resident asset

Use `setEntityMeshAsync` for props, characters, gameplay objects, HUD meshes, and any asset that should stay resident but can load off the main setup path.

```swift
setEntityMeshAsync(
    entityId: entity,
    filename: "stadium",
    withExtension: "untold"
) { success in
    if success {
        setEntityStaticBatchComponent(entityId: entity)
    }
}
```

### Streamed world

Use `setEntityStreamScene` for geometry that should stream by camera distance:

```swift
let sceneRoot = createEntity()
setEntityName(entityId: sceneRoot, name: "dungeon")

setEntityStreamScene(entityId: sceneRoot, manifest: "dungeon", withExtension: "json") { success in
    setSceneReady(success)
}
```

Or load a remote manifest directly:

```swift
let sceneRoot = createEntity()
setEntityName(entityId: sceneRoot, name: "dungeon")

if let url = URL(string: "https://cdn.example.com/dungeon/dungeon.json") {
    setEntityStreamScene(entityId: sceneRoot, url: url) { success in
        setSceneReady(success)
    }
}
```

> **Legacy overloads** — `loadTiledScene(manifest:)` and `loadTiledScene(url:)` remain available for backwards compatibility.

This is the public streaming workflow. Do not build app-level streaming logic around `StreamingComponent` or `enableStreaming(...)`; those are internal to the tile/OCC pipeline.

## `streamingPolicy`

`setEntityMeshAsync` accepts a `streamingPolicy` parameter, but the public contract is intentionally narrow:

- `.immediate` — default for `setEntityMeshAsync`; uploads in one pass and leaves the asset GPU-resident.
- `.auto` — used by `setEntityStreamScene(...)` internally for tile payloads so the runtime can choose full-tile upload vs OCC stub registration.
- `.outOfCore` — internal/specialized tile OCC route; do not use it as an app-level streaming API.

```swift
setEntityMeshAsync(
    entityId: entity,
    filename: "small_prop",
    withExtension: "untold",
    streamingPolicy: .immediate
)
```

`.outOfCore` is reserved for the engine's internal tile streaming pipeline. Passing it
directly on a standalone entity is unsupported — `StreamingComponent` stubs created
outside of a `TileComponent` hierarchy are not managed by `GeometryStreamingSystem`.
Use `setEntityStreamScene(...)` instead when you need distance-based streaming.

## Progress Tracking

### Is anything loading?

```swift
Task {
    let isLoading = await AssetLoadingState.shared.isLoadingAny()
    print("Loading: \(isLoading)")
}
```

### Loading count

```swift
Task {
    let count = await AssetLoadingState.shared.loadingCount()
    print("Loading \(count) asset(s)")
}
```

### Aggregate progress

```swift
Task {
    let (current, total) = await AssetLoadingState.shared.totalProgress()
    let percentage = total > 0 ? Float(current) / Float(total) * 100.0 : 0.0
    print("Progress: \(percentage)% (\(current)/\(total))")
}
```

### Human-readable summary

```swift
Task {
    let summary = await AssetLoadingState.shared.loadingSummary()
    print(summary)
}
```

### Per-entity progress

```swift
Task {
    if let progress = await AssetLoadingState.shared.getProgress(for: entity) {
        print("\(progress.filename): \(progress.currentMesh)/\(progress.totalMeshes)")
    }
}
```

## Notes

- `.untold` is the runtime format for mesh loading and streaming.
- USD/USDZ assets should be converted to `.untold` before runtime use.
- Animation clips exported with `--animation` can be loaded as `.untold` assets.
- `setEntityStreamScene(...)` automatically aligns texture streaming distances to the manifest radii and enables the full tile/HLOD/LOD/OCC streaming pipeline.
