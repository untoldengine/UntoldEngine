# Large Scene Streaming Demo

The Large Scene Streaming Demo shows the manifest-driven tiled scene workflow.
It loads remote scene manifests, lets the geometry streaming system bring tiles
in and out as the camera moves, and exposes spatial debug overlays for streamed
content.

Run it from the repository root:

```bash
swift run LargeSceneStreamingDemo
```

## Source Files

| File | Role |
| --- | --- |
| `Sources/Demos/LargeSceneStreamingDemo/AppDelegate.swift` | Presents scene selection, manifest loading, and debug overlay controls. |
| `Sources/Demos/LargeSceneStreamingDemo/GameScene.swift` | Configures streaming, loads remote manifests, builds a fallback field, and handles camera input. |
| `Sources/Demos/DemoUtils/DemoUtils.swift` | Provides shared setup helpers for camera, light, renderer settings, and input. |

## What This Demo Teaches

For normal models, use:

```swift
setEntityMeshAsync(...)
```

For large worlds, use:

```swift
setEntityStreamScene(entityId: root, url: manifestURL) { success in
    setSceneReady(success)
}
```

`setEntityStreamScene(...)` registers a manifest-backed scene under an entity
root. The engine then streams tile geometry as the camera moves.

## Streaming Configuration

The demo enables geometry streaming and tunes concurrency:

```swift
setGeometryStreaming(.enabled(true))
setGeometryStreaming(.tileConcurrency(2))
setGeometryStreaming(.meshConcurrency(3))
setGeometryStreaming(.lodConcurrency(4))
setGeometryStreaming(.hlodConcurrency(4))
```

It also configures candidate selection:

```swift
setGeometryStreaming(.queryRadius(650.0))
setGeometryStreaming(.frustumGate(.enabled(meshPadding: 6.0, tilePadding: 30.0)))
setGeometryStreaming(.velocityLookAhead(time: 0.5, minSpeed: 1.5))
setGeometryStreaming(.candidateSorting(importance: true, occlusion: true))
```

These calls do not load content by themselves. They configure how the streaming
system behaves once a tiled scene is registered.

## Loading A Remote Manifest

The demo defines remote presets:

```swift
enum RemoteScenePreset: String, CaseIterable {
    case dungeon = "Dungeon"
    case city = "City"
}
```

Loading a preset creates a root entity, names it, and registers the manifest:

```swift
let root = createEntity()
setEntityName(entityId: root, name: "\(label) Stream Root")
streamedSceneRoot = root

setEntityStreamScene(entityId: root, url: url) { success in
    if success {
        setSceneReady(true)
    } else {
        setSceneReady(true)
    }
}
```

The root entity gives the streamed scene a stable handle. When switching scenes,
the demo can destroy that root and clear the previous session.

## Scene Transitions

Before loading new content, the demo clears the previous streaming state:

```swift
GeometryStreamingSystem.shared.forceUnloadAllParsedTiles()

if let streamedSceneRoot {
    destroyEntity(entityId: streamedSceneRoot)
    self.streamedSceneRoot = nil
}

clearSceneBatches()
```

`forceUnloadAllParsedTiles()` is important when switching tiled scenes. It frees
resident tile memory immediately instead of waiting for normal distance-based
unload behavior.

## Camera Movement Drives Streaming

The demo uses the free-fly camera pattern:

```swift
moveCameraWithInput(
    entityId: camera,
    input: (
        w: input.keyState.wPressed,
        a: input.keyState.aPressed,
        s: input.keyState.sPressed,
        d: input.keyState.dPressed,
        q: input.keyState.qPressed,
        e: input.keyState.ePressed
    ),
    speed: 9.0,
    deltaTime: 1.0 / 60.0
)
```

As the camera moves, the geometry streaming system queries nearby tiles,
prioritizes candidates, loads new geometry, and unloads tiles that leave range.

## Spatial Debug Overlays

The demo exposes three useful debug overlays:

```swift
func setTileBoundsDebug(_ enabled: Bool) {
    setSpatialDebug(.tileBounds(enabled: enabled))
}

func setLodDebug(_ enabled: Bool) {
    setSpatialDebug(.lodLevels(enabled))
}

func setTextureTierDebug(_ enabled: Bool) {
    setSpatialDebug(.textureStreamingTiers(enabled))
}
```

Use tile bounds to see manifest structure. Use LOD levels to inspect which
representation is active. Use texture tiers to inspect texture streaming state.

## Offline Fallback Field

The demo also includes a procedural fallback field for offline testing:

```swift
let entity = createEntity()
setEntityName(entityId: entity, name: "Fallback_\(x)_\(z)")
setEntityMeshDirect(entityId: entity, meshes: cubeMesh, assetName: "fallback_cube")
translateTo(entityId: entity, position: position)
setEntityStaticBatchComponent(entityId: entity)
```

After creating the field, it enables static batching:

```swift
setBatching(.enabled(true))
generateBatches()
```

This fallback does not demonstrate true tile streaming. It demonstrates how a
large always-resident static field can be marked for batching.

## API Pattern To Remember

For a remote streamed scene:

```swift
setGeometryStreaming(.enabled(true))

let root = createEntity()
setEntityName(entityId: root, name: "City")

setEntityStreamScene(entityId: root, url: manifestURL) { success in
    setSceneReady(success)
}
```

For an always-resident fallback or small static scene:

```swift
setEntityStaticBatchComponent(entityId: entity)
setBatching(.enabled(true))
generateBatches()
```

Do not call `generateBatches()` for normal streamed tile loads. The streaming
path updates batching incrementally as tile residency changes.

## What To Change First

Try these changes in `Sources/Demos/LargeSceneStreamingDemo/GameScene.swift`:

| Goal | API To Change |
| --- | --- |
| Load a different manifest | Add a new `RemoteScenePreset` URL. |
| Increase streaming reach | Increase `setGeometryStreaming(.queryRadius(...))`. |
| Load fewer tiles at once | Lower `.tileConcurrency(...)` or `.meshConcurrency(...)`. |
| Disable tile bounds by default | Change `setSpatialDebug(.tileBounds(enabled: true))`. |
| Change camera speed | Edit `Constants.cameraMoveSpeed`. |
| Make the fallback field larger | Increase `Constants.fallbackGridSize`. |

## Related Documentation

- [Geometry Streaming](../API/UsingGeometryStreamingSystem.md)
- [LOD System](../API/UsingLODSystem.md)
- [Static Batching](../API/UsingStaticBatchingSystem.md)
- [Spatial Debugger](../API/SpatialDebugger.md)
- [Tile-Based Streaming](../Architecture/tilebasedstreaming.md)

