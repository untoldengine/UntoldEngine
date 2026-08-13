# Showcase Demo

The Showcase Demo is the broadest demo in the repository. It combines the core
patterns from the focused tutorials: renderer setup, entity lifecycle, asset
loading, tiled scene streaming, static batching, rendering quality controls,
spatial debug overlays, and camera interaction.

Run it from the repository root:

```bash
swift run ShowcaseDemo
```

## Source Files

| File | Role |
| --- | --- |
| `Sources/Demos/ShowcaseDemo/AppDelegate.swift` | Creates the application window, renderer, HUD, and callbacks. |
| `Sources/Demos/ShowcaseDemo/GameScene.swift` | Bridges UI actions to engine APIs for loading, streaming, batching, debug views, and camera input. |
| `Sources/Demos/ShowcaseDemo/DemoHUD.swift` | Defines the larger demo control surface. |
| `Sources/Demos/ShowcaseDemo/DemoState.swift` | Stores UI state used by the HUD. |

## What This Demo Teaches

Use the Showcase Demo after the focused demos. Its purpose is not to introduce
one new system. Its purpose is to show how several engine APIs can be exposed
through one runtime tool.

The source file includes a useful API map:

```swift
// Entity lifecycle: createEntity, setEntityName, destroyAllEntities
// Camera/input: createGameCamera, findGameCamera, moveCameraWithInput, orbitCameraAround
// Asset loading: setEntityMeshAsync, setEntityStreamScene
// Performance: setEntityStaticBatchComponent, setBatching, generateBatches, setGeometryStreaming
// Debug overlays: setSpatialDebug
```

## Default Scene Objects

The demo creates a camera and directional light manually:

```swift
let gameCamera = createEntity()
setEntityName(entityId: gameCamera, name: "Main Camera")
createGameCamera(entityId: gameCamera)

let light = createEntity()
setEntityName(entityId: light, name: "Directional Light")
createDirLight(entityId: light)

setDirectionalLight(.active(light))
setCamera(.active(gameCamera))
```

This is the same entity-driven pattern used throughout the tutorials.

## Loading Always-Resident Assets

For normal `.untold` assets, the demo uses `setEntityMeshAsync(...)`:

```swift
let entity = createEntity()
setEntityName(entityId: entity, name: path)

setEntityMeshAsync(
    entityId: entity,
    filename: path,
    withExtension: "untold"
) { success in
    loadedEntity = success ? entity : nil
    loadedContent = success ? .mesh(entity) : .none
    setCamera(.active(findGameCamera()))
    completion(success)
}
```

Before loading a mesh, the demo disables streaming and clears batch artifacts:

```swift
clearSceneBatches()
setGeometryStreaming(.enabled(false))
```

That keeps always-resident mesh loading separate from tiled scene loading.

## Loading Tiled Scenes

For large scenes, the demo creates a root entity and registers a manifest URL:

```swift
let sceneRoot = createEntity()
setEntityName(entityId: sceneRoot, name: sceneID)

setEntityStreamScene(entityId: sceneRoot, url: url) { success in
    if success {
        loadedEntity = nil
        loadedContent = .tiledScene(sceneRoot)
        setRendering(.environment(.visible(Self.shouldRenderEnvironment(for: sceneID))))
    }
    completion(success)
}
```

The `LoadedContent` enum tracks whether the current scene is a mesh, a tiled
scene, or empty:

```swift
private enum LoadedContent {
    case none
    case mesh(EntityID)
    case tiledScene(EntityID)
}
```

This lets the demo destroy the right kind of content before loading the next
thing.

## Scene-Authored Data

The Showcase Demo can also load scene-authored data:

```swift
loadSceneAuthored(filename: path, withExtension: "untold", completion: completion)
loadSceneAuthored(url: url, completion: completion)
```

Scene-authored data is separate from normal mesh loading. It is used for
exported scene-level settings such as authored environment and color management
data.

## Batching Controls

For always-resident static content, the demo can mark the loaded entity for
batching:

```swift
setEntityStaticBatchComponent(entityId: entity)
UntoldEngine.setBatching(.enabled(true))
generateBatches()
```

When disabled, it turns batching off:

```swift
UntoldEngine.setBatching(.enabled(false))
```

This manual batching flow is for non-streamed content. Tiled streaming scenes
use their own incremental batching path.

## Rendering And Debug Controls

The demo exposes the same rendering quality API used by the Rendering Quality
Demo:

```swift
setPostFX(.colorGrading(.enabled(enabled)))
setPostFX(.ssao(.enabled(enabled)))
setRendering(.antiAliasing(mode))
setRendering(.debugView(mode))
```

It also exposes spatial debug overlays:

```swift
UntoldEngine.setSpatialDebug(.lodLevels(enabled))
UntoldEngine.setSpatialDebug(.textureStreamingTiers(enabled))
UntoldEngine.setSpatialDebug(.tileBounds(enabled: enabled))
```

For octree bounds, it uses:

```swift
UntoldEngine.setSpatialDebug(.octreeLeafBounds(.enabled(
    maxLeafNodeCount: 0,
    occupiedOnly: occupiedOnly,
    colorMode: colorMode
)))
```

The Showcase Demo is useful for learning how these engine settings can be wired
to a larger UI without changing the underlying API.

## Camera Behavior

The demo supports both free movement and orbit behavior:

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
    speed: Constants.cameraMoveSpeed,
    deltaTime: Constants.cameraInputDeltaTime
)
```

Right mouse drag can either rotate the camera or orbit around a target:

```swift
if input.keyState.shiftPressed {
    rotateCamera(entityId: camera, pitch: 0, yaw: input.mouseDeltaX, sensitivity: -0.01)
} else {
    orbitCameraAround(entityId: camera, uDelta: simd_float2(dx, dy))
}
```

The demo changes orbit behavior depending on what kind of scene is loaded. Large
city scenes use fly/orbit behavior. object-focused scenes orbit around the world
origin.

## API Pattern To Remember

The Showcase Demo is mostly a bridge from UI state to engine calls. The useful
pattern is to keep the engine operations small and explicit:

```swift
loadFile(...)
loadTileScene(...)
setBatching(...)
setAntiAliasing(...)
setRenderDebugView(...)
setSpatialDebug(...)
handleInput()
```

Each method wraps one coherent group of engine APIs. That keeps the larger demo
understandable even though it touches many systems.

## What To Change First

Try these changes in `Sources/Demos/ShowcaseDemo/GameScene.swift`:

| Goal | API To Change |
| --- | --- |
| Add a new single asset | Route it through `loadFile(path:completion:)`. |
| Add a new streamed scene | Route it through `loadTileScene(sceneID:url:completion:)`. |
| Change default camera placement | Edit `cameraEye(for:)` or `applyCameraEye(for:)`. |
| Add a new render debug control | Add a UI option that calls `setRenderDebugView(...)`. |
| Add another spatial overlay | Add a wrapper around `setSpatialDebug(...)`. |
| Tune batching behavior | Adjust `setBatching(...)` and related batching settings. |

## Related Documentation

- [Usage Examples](../API/UsageExamples.md)
- [Async Loading](../API/UsingAsyncLoading.md)
- [Geometry Streaming](../API/UsingGeometryStreamingSystem.md)
- [Static Batching](../API/UsingStaticBatchingSystem.md)
- [Post Effects](../API/UsingPostFX.md)
- [Spatial Debugger](../API/SpatialDebugger.md)

