# Starter Demo

The Starter Demo is the smallest complete Untold Engine application in the
repository. It creates a macOS window, creates an `UntoldRenderer`, connects the
renderer to a SwiftUI `SceneView`, registers a camera and a light, creates one
renderable cube entity, and updates that cube every frame.

Run it from the repository root:

```bash
swift run StarterDemo
```

## Source Files

| File | Role |
| --- | --- |
| `Sources/Demos/StarterDemo/main.swift` | Starts the macOS application and installs the app delegate. |
| `Sources/Demos/StarterDemo/AppDelegate.swift` | Creates the window, renderer, `SceneView`, and frame callbacks. |
| `Sources/Demos/StarterDemo/GameScene.swift` | Configures engine state, creates scene entities, handles input, and updates the scene. |
| `Sources/Demos/DemoUtils/DemoUtils.swift` | Provides small demo helpers around the public engine APIs. |

## Application Entry Point

`main.swift` is intentionally minimal:

```swift
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
```

The engine work starts in `AppDelegate`. This keeps platform bootstrapping
separate from scene logic. In your own application, the surrounding app lifecycle
may be different, but the engine pattern is the same: create a renderer, present
a scene view, and register update/input callbacks.

## Renderer Setup

The demo creates the renderer with:

```swift
guard let renderer = UntoldRenderer.create() else {
    print("Failed to initialize UntoldRenderer.")
    NSApp.terminate(nil)
    return
}
```

`UntoldRenderer.create()` initializes the engine renderer for a standard macOS
Metal view. After creation, the demo passes the renderer into `SceneView`:

```swift
SceneView(renderer: renderer)
```

`SceneView` owns the SwiftUI-facing view layer. The renderer owns the Metal
render loop and engine frame execution.

## Frame Callbacks

The renderer calls back into the demo for per-frame scene logic:

```swift
renderer.setupCallbacks(
    gameUpdate: { [weak self] deltaTime in
        self?.gameScene.update(deltaTime: deltaTime)
    },
    handleInput: { [weak self] in
        self?.gameScene.handleInput()
    }
)
```

Use `gameUpdate` for simulation, animation, and other time-based scene changes.
Use `handleInput` for keyboard, mouse, touch, gamepad, or XR input state.

The important API shape is:

- `gameUpdate` receives `deltaTime`, so movement and animation can be frame-rate independent.
- `handleInput` runs separately, so input polling stays grouped in one place.
- The scene object does not own the renderer. It exposes update and input methods that the renderer calls.

## Engine Configuration

The Starter Demo calls:

```swift
configureDemoEngine(registerKeyboard: true)
```

This helper lives in `DemoUtils`. It wraps the engine setup that most demos need:

```swift
gameMode = true
setSceneReady(false)
setRendering(.postProcessing(.enabled))
setRendering(.antiAliasing(.fxaa))
setRendering(.environment(.ibl(true)))
setRendering(.environment(.visible(false)))
InputSystem.shared.registerKeyboardEvents()
InputSystem.shared.registerMouseEvents()
```

For your own project, the key idea is that engine state is configured through
small API calls:

- `gameMode = true` enables game runtime behavior.
- `setSceneReady(false)` prevents scene-dependent logic from running while setup or loading is incomplete.
- `setRendering(...)` changes renderer features such as post-processing, anti-aliasing, and environment lighting.
- `InputSystem.shared.registerKeyboardEvents()` and `InputSystem.shared.registerMouseEvents()` connect platform input events to the engine input system.

## Camera And Light

The demo creates its camera with:

```swift
makeDemoCamera(
    name: "Main Camera",
    eye: simd_float3(0.0, 2.0, 6.0),
    target: simd_float3(0.0, 0.0, 0.0),
    orbitOffset: 5.0
)
```

The helper expands to the normal camera API:

```swift
let camera = createEntity()
setEntityName(entityId: camera, name: name)
createGameCamera(entityId: camera)
cameraLookAt(entityId: camera, eye: eye, target: target, up: simd_float3(0, 1, 0))
setOrbitOffset(entityId: camera, uTargetOffset: offset)
setCamera(.active(camera))
```

This shows an important Untold Engine pattern: cameras are entities. You create
an entity, attach the camera behavior, aim it, and make it active.

The light uses the same pattern:

```swift
let sun = createEntity()
setEntityName(entityId: sun, name: "Key Light")
createDirLight(entityId: sun)
rotateTo(entityId: sun, angle: -45.0, axis: simd_float3(1, 0, 0))
setLight(entityId: sun, .color(simd_float3(1.0, 0.92, 0.82)))
setLight(entityId: sun, .intensity(1.4))
setLight(entityId: sun, .directional(.active))
```

Lights are also entities. The entity gives the light a transform, and the light
component controls how it contributes to the renderer.

## Creating A Renderable Entity

The cube is created in `createStarterObject()`:

```swift
let entity = createEntity()
setEntityName(entityId: entity, name: "Starter Cube")
setEntityMeshDirect(
    entityId: entity,
    meshes: BasicPrimitives.createCube(extent: 1.25),
    assetName: "starter_cube"
)
translateTo(entityId: entity, position: simd_float3(0.0, 0.0, 0.0))
updateMaterialColor(entityId: entity, color: Color(red: 0.95, green: 0.42, blue: 0.18))
setSceneReady(true)
```

This is the basic ECS workflow:

1. `createEntity()` allocates an entity ID.
2. `setEntityName(...)` gives the entity a readable debug name.
3. `setEntityMeshDirect(...)` attaches renderable mesh data directly.
4. `translateTo(...)` places the entity in the scene.
5. `updateMaterialColor(...)` changes its material appearance.
6. `setSceneReady(true)` marks the scene ready after required setup has completed.

The Starter Demo uses `BasicPrimitives.createCube(...)`, so it does not require
external assets. When you want to load exported content instead, use
`setEntityMeshAsync(...)`:

```swift
let entity = createEntity()
setEntityName(entityId: entity, name: "My Model")
setEntityMeshAsync(entityId: entity, filename: "my_model", withExtension: "untold") { success in
    guard success else {
        setSceneReady(false)
        return
    }

    translateTo(entityId: entity, position: .zero)
    setSceneReady(true)
}
```

Apply transforms inside the completion handler when loading asynchronously. That
keeps placement tied to successful mesh registration.

## Updating The Scene

The demo rotates the cube each frame:

```swift
func update(deltaTime: Float) {
    guard let cube, gameMode else { return }

    rotateBy(
        entityId: cube,
        angle: 25.0 * deltaTime,
        axis: simd_float3(0.0, 1.0, 0.0)
    )

}
```

`rotateBy(...)` applies an incremental transform to the entity. Multiplying by
`deltaTime` keeps the rotation speed stable when frame rate changes.

The guard is also part of the engine pattern:

- Skip scene updates when the entity has not been created.
- Skip game logic when `gameMode` is disabled.
- Use `isSceneReady()` in input or gameplay paths that depend on loaded content.

## Handling Input

The demo reads keyboard and mouse state from the shared input system:

```swift
let input = InputSystem.shared
```

Camera movement uses the high-level camera helper:

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
    speed: 4.0,
    deltaTime: 1.0 / 60.0
)
```

Right mouse drag orbits the active camera:

```swift
if input.keyState.rightMousePressed {
    setOrbitOffset(entityId: camera, uTargetOffset: 5.0)
    orbitCameraAround(
        entityId: camera,
        uDelta: simd_float2(input.mouseDeltaX, input.mouseDeltaY)
    )
}
```

The important API lesson is that input state and camera behavior are separate.
`InputSystem` tells you what the user is doing. Camera APIs decide how that input
changes the active camera entity.

## What To Change First

Try these changes in `Sources/Demos/StarterDemo/GameScene.swift`:

| Goal | API To Change |
| --- | --- |
| Move the cube | Change the `translateTo(...)` position. |
| Change the cube size | Change `BasicPrimitives.createCube(extent:)`. |
| Change its color | Change `updateMaterialColor(...)`. |
| Rotate around another axis | Change the `axis` passed to `rotateBy(...)`. |
| Move the starting camera | Change the `eye` position passed to `makeDemoCamera(...)`. |
| Load your own asset | Replace `setEntityMeshDirect(...)` with `setEntityMeshAsync(...)`. |

## Related Documentation

- [Registration System](../API/UsingRegistrationSystem.md)
- [Transform System](../API/UsingTransformSystem.md)
- [Camera System](../API/UsingCameraSystem.md)
- [Input System](../API/UsingInputSystem.md)
- [Rendering System](../API/UsingRenderingSystem.md)
- [Materials](../API/UsingMaterials.md)
