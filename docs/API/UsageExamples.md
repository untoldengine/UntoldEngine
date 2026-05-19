# Usage Examples

This page collects common Untold Engine setup patterns in one place. Use it when
you want a concrete example first, then open the focused API pages for details.

For a broader first project walkthrough, see [Getting Started](GettingStarted.md).

## Export Assets First

Untold Engine uses `.untold` as its runtime asset format. Keep USD/USDZ
as your authoring format, then export it before loading it in the engine.

Convert one asset:

```bash
./scripts/export-untold \
  --input GameData/Models/robot/robot.usdz \
  --output GameData/Models/robot/robot.untold \
  --ConvertOrientation \
  --source-orientation blender-native
```

Export an animation clip:

```bash
./scripts/export-untold \
  --input GameData/Models/robot/running.usdz \
  --output GameData/Models/robot/running.untold \
  --ConvertOrientation \
  --source-orientation blender-native \
  --animation
```

Export a large streamed scene:

```bash
./scripts/export-untold-tiles \
  --input GameData/Models/city/city.usdz \
  --output-dir GameData/Models/city/tile_exports \
  --tile-size-x 25 \
  --tile-size-z 25 \
  --generate-hlod \
  --generate-lod
```

For exporter options and expected output layout, see
[Using The Exporter](UsingTheExporter.md). For texture compression and LZ4
compression, see [Optimizations](Optimizations.md).

## Create an Entity

Entities are lightweight IDs. Systems add behavior by attaching components or by
calling helper APIs that register the right components for you.

```swift
let robot = createEntity()
setEntityName(entityId: robot, name: "robot")
```

For direct entity/component lifecycle APIs, see
[Using the Registration System](UsingRegistrationSystem.md).

## Load a Mesh Immediately

Use `setEntityMesh` when you want a small asset loaded immediately on the calling
thread. This is useful for simple examples, tiny props, tests, and editor-style
setup.

```swift
let crate = createEntity()
setEntityName(entityId: crate, name: "crate")

setEntityMesh(entityId: crate, filename: "crate", withExtension: "untold")
translateTo(entityId: crate, position: simd_float3(0.0, 0.0, 0.0))
```

For most game scene setup, prefer `setEntityMeshAsync` so loading does not stall
the render loop.

## Load a Mesh Asynchronously

Use `setEntityMeshAsync` when a model is large enough that loading it on the
calling thread could stall the engine. The asset still becomes always-resident
after it loads, but parsing and GPU upload happen asynchronously so the render
loop can keep running.

```swift
setSceneReady(false)

let robot = createEntity()
setEntityName(entityId: robot, name: "robot")

setEntityMeshAsync(entityId: robot, filename: "robot", withExtension: "untold") { success in
    if success {
        translateTo(entityId: robot, position: simd_float3(0.0, 0.0, 0.0))
        rotateTo(entityId: robot, angle: 0.0, axis: simd_float3(0.0, 1.0, 0.0))
    }

    setSceneReady(success)
}
```

`setEntityMeshAsync` calls the completion block after parsing and GPU upload
finish. Apply dependent transforms, physics setup, animation setup, and batching
inside the completion block when they depend on the loaded mesh.

For loading behavior and progress APIs, see
[Using Async Loading](UsingAsyncLoading.md).

## Add Camera and Lighting

Most examples need a game camera and at least one light.

```swift
let camera = createEntity()
setEntityName(entityId: camera, name: "Main Camera")
createGameCamera(entityId: camera)
CameraSystem.shared.activeCamera = camera
moveCameraTo(entityId: camera, 0.0, 3.0, 10.0)

let sun = createEntity()
setEntityName(entityId: sun, name: "Sun")
createDirLight(entityId: sun)

ambientIntensity = 0.4
```

For camera controls and path following, see
[Using the Camera System](UsingCameraSystem.md). For light types, see
[Using the Lighting System](UsingLightingSystem.md).

## Play an Animation

Load the rigged mesh, then register one or more exported animation clips on the
same entity. Use `changeAnimation` to choose the active clip.

```swift
let player = createEntity()
setEntityName(entityId: player, name: "player")

setEntityMeshAsync(entityId: player, filename: "redplayer", withExtension: "untold") { success in
    guard success else {
        setSceneReady(false)
        return
    }

    setEntityAnimations(entityId: player, filename: "running", withExtension: "untold", name: "running")
    setEntityAnimations(entityId: player, filename: "idle", withExtension: "untold", name: "idle")

    changeAnimation(entityId: player, name: "idle")
    setSceneReady(true)
}
```

Switch animations later:

```swift
changeAnimation(entityId: player, name: "running")
```

Pause or resume the current animation:

```swift
pauseAnimationComponent(entityId: player, isPaused: true)
pauseAnimationComponent(entityId: player, isPaused: false)
```

For the full animation workflow, see
[Using the Animation System](UsingAnimationSystem.md).

## Add Physics

Call `setEntityKinetics` after creating or loading the entity. Then configure mass,
gravity, or forces as needed.

```swift
let ball = createEntity()
setEntityName(entityId: ball, name: "ball")

setEntityMeshAsync(entityId: ball, filename: "ball", withExtension: "untold") { success in
    guard success else {
        setSceneReady(false)
        return
    }

    translateTo(entityId: ball, position: simd_float3(0.0, 2.0, 0.0))
    setEntityKinetics(entityId: ball)
    setMass(entityId: ball, mass: 1.0)
    setGravityScale(entityId: ball, gravityScale: 1.0)

    setSceneReady(true)
}
```

Apply a force when a gameplay event happens:

```swift
applyForce(entityId: ball, force: simd_float3(0.0, 5.0, 0.0))
```

For physics properties and steering helpers, see
[Using the Physics System](UsingPhysicsSystem.md) and
[Using the Steering System](UsingSteeringSystem.md).

## Load a Streamed Scene

Use `setEntityStreamScene` for large worlds, cities, terrain, and remote streamed
scenes. The manifest is generated by `export-untold-tiles`.

```swift
setSceneReady(false)

let sceneRoot = createEntity()
setEntityName(entityId: sceneRoot, name: "city")

setEntityStreamScene(entityId: sceneRoot, manifest: "city", withExtension: "json") { success in
    if success {
        moveCameraTo(entityId: findGameCamera(), 0.0, 4.0, 12.0)
        ambientIntensity = 0.4
    }

    setSceneReady(success)
}
```

Load a remote manifest:

```swift
let sceneRoot = createEntity()
setEntityName(entityId: sceneRoot, name: "city")

if let url = URL(string: "https://cdn.example.com/city/city.json") {
    setEntityStreamScene(entityId: sceneRoot, url: url) { success in
        setSceneReady(success)
    }
}
```

Do not attach `StreamingComponent` manually for app-level streaming. The tiled
scene pipeline creates and manages the streaming components internally.

For the public streaming API, see
[Using Geometry Streaming](UsingGeometryStreamingSystem.md). For the deeper
architecture, see [Tile-Based Streaming](../Architecture/tilebasedstreaming.md).

## Complete Small Scene

This example creates a camera, light, animated player, and physics-enabled ball.

```swift
final class GameScene {

    private var pendingLoads = 2
    private var sceneFailed = false

    init() {
        setSceneReady(false)
        setupCameraAndLight()
        loadPlayer()
        loadBall()
    }

    private func setupCameraAndLight() {
        let camera = createEntity()
        setEntityName(entityId: camera, name: "Main Camera")
        createGameCamera(entityId: camera)
        CameraSystem.shared.activeCamera = camera
        moveCameraTo(entityId: camera, 0.0, 3.0, 10.0)

        let sun = createEntity()
        setEntityName(entityId: sun, name: "Sun")
        createDirLight(entityId: sun)

        ambientIntensity = 0.4
    }

    private func loadPlayer() {
        let player = createEntity()
        setEntityName(entityId: player, name: "player")

        setEntityMeshAsync(entityId: player, filename: "redplayer", withExtension: "untold") { success in
            if success {
                translateTo(entityId: player, position: simd_float3(0.0, 0.0, 0.0))
                setEntityAnimations(entityId: player, filename: "idle", withExtension: "untold", name: "idle")
                setEntityAnimations(entityId: player, filename: "running", withExtension: "untold", name: "running")
                changeAnimation(entityId: player, name: "idle")
                setEntityKinetics(entityId: player)
            }

            self.finishLoad(success)
        }
    }

    private func loadBall() {
        let ball = createEntity()
        setEntityName(entityId: ball, name: "ball")

        setEntityMeshAsync(entityId: ball, filename: "ball", withExtension: "untold") { success in
            if success {
                translateTo(entityId: ball, position: simd_float3(2.0, 1.0, 0.0))
                setEntityKinetics(entityId: ball)
                setMass(entityId: ball, mass: 1.0)
                setGravityScale(entityId: ball, gravityScale: 1.0)
            }

            self.finishLoad(success)
        }
    }

    private func finishLoad(_ success: Bool) {
        if !success {
            sceneFailed = true
        }

        pendingLoads -= 1

        if pendingLoads == 0 {
            setSceneReady(!sceneFailed)
        }
    }
}
```

## Related Pages

- [Getting Started](GettingStarted.md)
- [Using The Exporter](UsingTheExporter.md)
- [Using the Registration System](UsingRegistrationSystem.md)
- [Using Async Loading](UsingAsyncLoading.md)
- [Using the Animation System](UsingAnimationSystem.md)
- [Using the Physics System](UsingPhysicsSystem.md)
- [Using Geometry Streaming](UsingGeometryStreamingSystem.md)
