---
id: asyncloadingsystem
title: Async Loading System
sidebar_position: 9
---

# Async Loading System

UntoldEngine loads meshes asynchronously so scene setup does not stall the render loop. This applies to native `.untold` assets and to legacy USD/USDZ runtime paths.

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

It does **not** indicate whether the asset used an out-of-core path.

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

For ordinary `setEntityMeshAsync(...)` and `loadTiledScene(...)` flows, the engine already uses internal loading gates. `setSceneReady(...)` is mainly for your own multi-step scene setup.

## Choosing the Right Loading Path

| Use case | API |
|---|---|
| Single always-resident asset | `setEntityMeshAsync(...)` |
| Large streamed world | `loadTiledScene(...)` |

### Always-resident asset

Use `setEntityMeshAsync` for props, characters, gameplay objects, HUD meshes, and any asset that should stay resident.

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

Use `loadTiledScene` for geometry that should stream by camera distance:

```swift
loadTiledScene(manifest: "dungeon", withExtension: "json") { success in
    setSceneReady(success)
}
```

Or load a remote manifest directly:

```swift
if let url = URL(string: "https://cdn.example.com/dungeon/dungeon.json") {
    loadTiledScene(url: url) { success in
        setSceneReady(success)
    }
}
```

This is the public streaming workflow. Do not build app-level streaming logic around `StreamingComponent` or `enableStreaming(...)`; those are internal to the tile/OCC pipeline.

## `streamingPolicy`

`setEntityMeshAsync` still exposes `streamingPolicy`, but the public guidance is:

- Use `.auto` for normal asset loading
- Use `.immediate` when you explicitly want direct full upload
- Use `loadTiledScene(...)` for streamable worlds instead of forcing `.outOfCore`

```swift
setEntityMeshAsync(
    entityId: entity,
    filename: "small_prop",
    withExtension: "untold",
    streamingPolicy: .immediate
)
```

`.outOfCore` is part of the engine's internal streaming architecture and test surface. The runtime streaming system now enforces tile ownership for `StreamingComponent`, so manifest-driven tiled scenes are the supported public path for streamed geometry.

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

- `.untold` is the preferred runtime format for static geometry.
- Animation clips still use `.usdz`.
- `loadTiledScene(...)` automatically aligns texture streaming distances to the manifest radii and enables the full tile/HLOD/LOD/OCC streaming pipeline.
