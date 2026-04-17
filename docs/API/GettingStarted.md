---
id: gettingstarted
title: Getting Started
sidebar_position: 1
---

# Getting Started

This guide walks through a typical `GameScene` setup: loading `.untold` assets,
adding entities, configuring physics, and placing the camera.

---

## Native Asset Format: `.untold`

Untold Engine uses `.untold` as its native runtime asset format. USDZ/USD remains
the authoring format — you model assets in your DCC tool, export to USDZ, then
convert to `.untold` before loading them in the engine.

The `.untold` format is a binary container optimised for fast runtime parsing with
no ModelIO dependency. It supports static meshes, PBR materials, texture references,
transforms, and bounds. It does **not** support animation or skinning — animation
clips continue to use `.usdz`.

### Converting assets

Use the `export-untold` script to convert a single USDZ asset:

```bash
./scripts/export-untold \
  --input GameData/Models/robot/robot.usdz \
  --output GameData/Models/robot/robot.untold \
  --ConvertOrientation \
  --source-orientation blender-native
```

For animation usdz assets, use the --animation flag

```bash
./scripts/export-untold \
  --input GameData/Models/robot/robot.usdz \
  --output GameData/Models/robot/robot.untold \
  --ConvertOrientation \
  --source-orientation blender-native \
  --animation
```

For large scenes that need tile-based streaming, use `export-untold-tiles` to
partition the scene and generate a manifest JSON:

```bash
./scripts/export-untold-tiles \
  --input GameData/Models/dungeon/dungeon.usdz \
  --output-dir GameData/Models/dungeon/tile_exports \
  --tile-size-x 25 \
  --tile-size-z 25 \
  --generate-hlod \
  --generate-lod
```

For the full list of options, validation flags, and expected output layout see
[Using The Exporter](UsingTheExporter).

---

## Loading a Single Asset

Use `setEntityMeshAsync` to load an `.untold` file as an always-resident asset.
This is the right choice for props, characters, and any object that should stay
in memory for the lifetime of the scene.

```swift
let entity = createEntity()
setEntityName(entityId: entity, name: "robot")

setEntityMeshAsync(entityId: entity, filename: "robot", withExtension: "untold") { success in
    if success {
        translateBy(entityId: entity, position: simd_float3(0.0, 0.0, 0.0))
        setEntityKinetics(entityId: entity)
    }
    setSceneReady(success)
}
```

`setEntityMeshAsync` is non-blocking. The completion block fires on the main thread
once the mesh is parsed and uploaded to GPU memory.

> **Animation clips** are the one case where `.usdz` is still used directly.
> The `.untold` format does not support animation or skinning.
>
> ```swift
> setEntityAnimations(entityId: entity, filename: "running", withExtension: "usdz", name: "running")
> setEntityAnimations(entityId: entity, filename: "idle",    withExtension: "usdz", name: "idle")
> ```

---

## Loading a Tiled Scene

Use `loadTiledScene` to load a large scene that streams tiles in and out of GPU
memory based on camera proximity. Pass either a local manifest path or a remote
`https://` URL — the engine handles downloading and caching automatically.

```swift
// Local manifest
loadTiledScene(manifest: "dungeon", withExtension: "json") { success in
    setSceneReady(success)
}

// Remote manifest (downloaded and cached on demand)
if let url = URL(string: "https://cdn.example.com/dungeon/dungeon.json") {
    loadTiledScene(url: url) { success in
        setSceneReady(success)
    }
}
```

`loadTiledScene` registers lightweight stub entities for every tile in the manifest
(no geometry is parsed at this point). `GeometryStreamingSystem` then loads and
unloads tile geometry as the camera moves. See [Tile-Based Streaming](../Architecture/tilebasedstreaming)
for the full streaming architecture.

---

## Finding Entities in the Loaded Scene

Retrieve a named entity with `findEntity(name:)` inside the completion block or
after `setSceneReady`:

```swift
setEntityMeshAsync(entityId: entity, filename: "stadium", withExtension: "untold") { success in
    if let player = findEntity(name: "player") {
        rotateTo(entityId: player, angle: 0, axis: simd_float3(0.0, 1.0, 0.0))
        setEntityKinetics(entityId: player)
    }
    setSceneReady(success)
}
```

---

## Camera and Lighting

Create a camera and directional light manually in your scene setup, then position
the camera after assets load:

```swift
let gameCamera = createEntity()
setEntityName(entityId: gameCamera, name: "Main Camera")
createGameCamera(entityId: gameCamera)
CameraSystem.shared.activeCamera = gameCamera

let light = createEntity()
setEntityName(entityId: light, name: "Directional Light")
createDirLight(entityId: light)
```

After loading:

```swift
moveCameraTo(entityId: findGameCamera(), 0.0, 3.0, 10.0)
ambientIntensity = 0.4
```

---

## Putting It All Together

A complete `GameScene` using the patterns above:

```swift
final class GameScene {

    init() {
        // Camera and light
        let gameCamera = createEntity()
        setEntityName(entityId: gameCamera, name: "Main Camera")
        createGameCamera(entityId: gameCamera)
        CameraSystem.shared.activeCamera = gameCamera

        let light = createEntity()
        setEntityName(entityId: light, name: "Directional Light")
        createDirLight(entityId: light)

        // Load a single always-resident asset
        let entity = createEntity()
        setEntityName(entityId: entity, name: "robot")

        setEntityMeshAsync(entityId: entity, filename: "robot", withExtension: "untold") { success in
            if let player = findEntity(name: "player") {
                rotateTo(entityId: player, angle: 0, axis: simd_float3(0.0, 1.0, 0.0))
                // Animation clips remain .usdz — .untold does not support animation
                setEntityAnimations(entityId: player, filename: "running", withExtension: "untold", name: "running")
                setEntityAnimations(entityId: player, filename: "idle",    withExtension: "untold", name: "idle")
                setEntityKinetics(entityId: player)
            }

            moveCameraTo(entityId: findGameCamera(), 0.0, 3.0, 10.0)
            ambientIntensity = 0.4
            setSceneReady(success)
        }
    }
}
```

For a large streaming scene, replace the `setEntityMeshAsync` call with `loadTiledScene`:

```swift
loadTiledScene(manifest: "dungeon", withExtension: "json") { success in
    moveCameraTo(entityId: findGameCamera(), 0.0, 3.0, 10.0)
    ambientIntensity = 0.4
    setSceneReady(success)
}
```
