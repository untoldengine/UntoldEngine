# Scene Builder / UntoldView

Untold Engine supports two SwiftUI entry points:

- `SceneView` hosts an `UntoldRenderer` and lets you set up the scene imperatively with the engine facade APIs.
- `UntoldView` hosts the same renderer, but lets you declare scene content with `SceneBuilder` nodes.

Both paths create normal Untold Engine entities and components. Use the builder when you want compact SwiftUI-style scene setup, and use the lower-level facade APIs when a demo or game needs explicit control over loading, registration, or runtime systems.

## SceneView

`SceneView` is the direct host for the renderer's `MTKView`.

```swift
import SwiftUI
import UntoldEngine

struct GameView: View {
    let renderer = UntoldRenderer.create()

    var body: some View {
        SceneView(renderer: renderer)
            .onInit {
                let entity = createEntity()
                setEntityMeshAsync(entityId: entity, filename: "robot", withExtension: "untold")
                translateTo(entityId: entity, position: simd_float3(0.0, 0.0, -2.0))

                let light = createEntity()
                createDirLight(entityId: light)
                setLight(entityId: light, .intensity(1.5))

                cameraLookAt(
                    entityId: findGameCamera(),
                    eye: simd_float3(0.0, 1.2, 4.0),
                    target: simd_float3(0.0, 0.8, 0.0)
                )
            }
    }
}
```

`onInit` runs once after the renderer exists, so resource loading calls have a Metal device available. It is the right place for mesh loading, entity creation, camera setup, light setup, input registration, and scene-channel configuration.

## UntoldView

`UntoldView` wraps `SceneView` and runs a `SceneBuilder` block once when the platform view is created.

```swift
import SwiftUI
import UntoldEngine

struct GameView: View {
    var body: some View {
        UntoldView {
            CameraNode(name: "Main Camera")
                .lookAt(
                    eye: simd_float3(0.0, 1.2, 4.0),
                    target: simd_float3(0.0, 0.8, 0.0)
                )

            DirectionalLightNode(name: "Sun")
                .intensity(1.5)

            MeshNode(resource: "robot.untold", name: "Robot")
                .translateTo(x: 0.0, y: 0.0, z: -2.0)
                .scaleTo(x: 1.0, y: 1.0, z: 1.0)
                .roughness(0.45)
        }
    }
}
```

`MeshNode` uses `setEntityMeshAsync` internally. Primitive nodes such as `CubeNode`, `SphereNode`, `PlaneNode`, `CylinderNode`, and `ConeNode` generate their meshes immediately.

## Node Hierarchies

Nodes can contain child nodes. The builder creates normal scene-graph relationships by calling `setParent(childId:parentId:)` for each child.

```swift
MeshNode(resource: "vehicle.untold", name: "Vehicle") {
    CubeNode(size: 0.25, name: "Marker")
        .translateTo(x: 0.0, y: 1.25, z: 0.0)
        .baseColor(1.0, 0.2, 0.1)
}
```

The child transform is local to the parent. You can still access the generated entity through `node.entityID` if you need to pass it to another engine API.

## Common Node Modifiers

Transform modifiers are available on all nodes:

```swift
.translateTo(x: 0.0, y: 0.0, z: -2.0)
.translateBy(x: 0.0, y: 0.1, z: 0.0)
.rotateTo(angle: 45.0, axis: [.y])
.rotateBy(angle: 10.0, axis: [.y])
.scaleTo(x: 1.0, y: 1.0, z: 1.0)
```

Material modifiers are available on `MeshNode` and primitive nodes:

```swift
.baseColor(0.8, 0.2, 0.1, 1.0)
.roughness(0.6)
.metallic(0.0)
.emissive(0.0, 0.0, 0.0)
.materialData(
    roughness: 0.45,
    metallic: 0.0,
    baseColorResource: "robot_albedo.png",
    normalResource: "robot_normal.png"
)
```

Light nodes expose light-specific modifiers:

```swift
DirectionalLightNode()
    .color(1.0, 0.95, 0.85)
    .intensity(1.4)

PointLightNode()
    .radius(4.0)
    .falloff(2.0)
    .attenuation(constant: 1.0, linear: 0.2, quadratic: 0.05)

SpotLightNode()
    .coneAngle(30.0)
    .radius(8.0)
```

## Per-Frame Updates

Use `onUpdate` for frame-driven game logic. Keep per-frame state in the ECS or in a reference type. Avoid mutating SwiftUI state that would rebuild the scene content every frame.

```swift
UntoldView {
    MeshNode(resource: "drone.untold", name: "Drone")
}
.onUpdate { event in
    if let drone = findEntity(name: "Drone") {
        rotateBy(entityId: drone, angle: 30.0 * Float(event.deltaTime), axis: simd_float3(0, 1, 0))
    }
}
```

## Runtime View Options

`UntoldViewOptions` controls settings that can be applied to the live `MTKView` without recreating the renderer or scene.

```swift
UntoldView(options: UntoldViewOptions(
    preferredFramesPerSecond: 90,
    isPaused: false,
    clearColor: simd_float4(0.02, 0.02, 0.025, 1.0)
)) {
    MeshNode(resource: "robot.untold")
}
```

You can also use modifiers:

```swift
UntoldView {
    MeshNode(resource: "robot.untold")
}
.preferredFramesPerSecond(90)
.paused(false)
```

Renderer or engine settings such as anti-aliasing, post effects, LOD, lighting, and scene channels should still be configured through the engine settings APIs.
