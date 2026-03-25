---
id: gettingstarted
title: Getting Started
sidebar_position: 1
---

# Getting Started

This guide walks through a typical `GameScene` setup: loading a USDZ scene,
adding entities, configuring animation and physics, and placing the camera.

---

## Loading a Scene

`loadScene()` is the primary entry point for loading a USDZ world. It replaces
the current scene, creates a default camera and directional light, and handles
async mesh loading internally. You do not need to create entities or manage
cameras manually.

```swift
loadScene(
    filename: "stadium",
    withExtension: "usdz",
    enableBatching: true,
    enableGeometryStreaming: true
) { success in
    setSceneReady(success)
}
```

| Parameter | What it does |
|---|---|
| `enableBatching` | Merges static meshes into draw call batches after loading. |
| `enableGeometryStreaming` | Streams geometry in/out of core memory based on camera proximity. Defaults: `streamingRadius=100`, `unloadRadius=150`. To override, call `enableStreaming(entityId:streamingRadius:unloadRadius:priority:)` on the root entity inside the completion block. |

After `loadScene` completes, call `setSceneReady(true)` (or pass `success`
directly) to signal that input and game logic can safely run.

---

## Finding Entities in the Loaded Scene

If your USDZ file contains a named mesh (e.g. a player character), retrieve it
with `findEntity(name:)` inside the completion block or after `setSceneReady`.

```swift
if let player = findEntity(name: "player") {
    rotateTo(entityId: player, angle: 0, axis: simd_float3(0.0, 1.0, 0.0))

    // Attach animation clips
    setEntityAnimations(entityId: player, filename: "running", withExtension: "usdz", name: "running")
    setEntityAnimations(entityId: player, filename: "idle",    withExtension: "usdz", name: "idle")

    // Enable physics
    setEntityKinetics(entityId: player)
}
```

---

## Adding Entities to the Scene

Use `createEntity()` + `setEntityMesh()` to add props and objects that are not
embedded in the loaded USDZ scene.

```swift
let ball = createEntity()
setEntityMesh(entityId: ball, filename: "ball", withExtension: "usdz")
setEntityName(entityId: ball, name: "ball")
translateBy(entityId: ball, position: simd_float3(0.0, 0.5, 3.0))
setEntityKinetics(entityId: ball)
```

`setEntityMesh` is synchronous and suited for small, single-mesh assets. For
large or multi-mesh assets use `setEntityMeshAsync` instead (see
[Async Loading System](asyncloadingsystem)).

---

## Camera and Lighting

`loadScene` always provides a default camera and directional light. Move the
camera after the scene loads, or configure lighting intensity directly:

```swift
moveCameraTo(entityId: findGameCamera(), 0.0, 3.0, 10.0)
ambientIntensity = 0.4
```

---

## Putting It All Together

A complete `GameScene.init()` using the patterns above:

```swift
init() {
    setupAssetPaths()
    configureEngineSystems()

    loadScene(
        filename: "stadium",
        withExtension: "usdz",
        enableBatching: true,
        enableGeometryStreaming: true
    ) { success in

        if let player = findEntity(name: "player") {
            rotateTo(entityId: player, angle: 0, axis: simd_float3(0.0, 1.0, 0.0))
            setEntityAnimations(entityId: player, filename: "running", withExtension: "usdz", name: "running")
            setEntityAnimations(entityId: player, filename: "idle",    withExtension: "usdz", name: "idle")
            setEntityKinetics(entityId: player)
        }

        let ball = createEntity()
        setEntityMesh(entityId: ball, filename: "ball", withExtension: "usdz")
        setEntityName(entityId: ball, name: "ball")
        translateBy(entityId: ball, position: simd_float3(0.0, 0.5, 3.0))
        setEntityKinetics(entityId: ball)

        moveCameraTo(entityId: findGameCamera(), 0.0, 3.0, 10.0)
        ambientIntensity = 0.4

        setSceneReady(success)
    }
}
```
