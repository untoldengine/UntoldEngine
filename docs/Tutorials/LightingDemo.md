# Lighting Demo

The Lighting Demo shows how Untold Engine represents lights in the ECS. Each
light starts as a normal entity, then receives a light component with one of the
light creation APIs:

- `createDirLight(entityId:)`
- `createPointLight(entityId:)`
- `createSpotLight(entityId:)`
- `createAreaLight(entityId:)`

After that, shared and type-specific light properties are updated with
`setLight(entityId:, _:)`.

Run it from the repository root:

```bash
swift run LightingDemo
```

## Source Files

| File | Role |
| --- | --- |
| `Sources/Demos/LightingDemo/AppDelegate.swift` | Creates the renderer, presents `SceneView`, and exposes UI controls for light values. |
| `Sources/Demos/LightingDemo/GameScene.swift` | Builds the test scene, creates each light type, and applies runtime light changes. |
| `Sources/Demos/DemoUtils/DemoUtils.swift` | Provides shared setup helpers for renderer settings, input, and camera creation. |

## What This Demo Teaches

The Starter Demo introduced the application shape: renderer, callbacks, scene
view, entities, transforms, and input. The Lighting Demo keeps that same shape
and focuses on one engine idea: lighting is entity-driven.

The same entity workflow applies to cameras, renderable objects, and lights:

```swift
let light = createEntity()
setEntityName(entityId: light, name: "Point Light")
createPointLight(entityId: light)
translateTo(entityId: light, position: simd_float3(3.5, 3.5, 2.0))
setLight(entityId: light, .color(simd_float3(1.0, 0.55, 0.1)))
setLight(entityId: light, .intensity(3.0))
setLight(entityId: light, .point(.radius(9.0)))
```

The entity owns transform and identity. The light component owns illumination
behavior. `setLight(...)` is the main API for changing how the light affects the
renderer.

## Scene Setup

Before creating lights, the demo builds a small scene with a floor, a back wall,
and three spheres. These objects use the same renderable entity pattern from the
Starter Demo:

```swift
let floor = createEntity()
setEntityName(entityId: floor, name: "Floor")
setEntityMeshDirect(
    entityId: floor,
    meshes: BasicPrimitives.createPlane(width: 14.0, depth: 12.0),
    assetName: "floor"
)
updateMaterialColor(entityId: floor, color: Color(red: 0.55, green: 0.55, blue: 0.57))
```

The wall adds scale and translation:

```swift
let wall = createEntity()
setEntityName(entityId: wall, name: "Back Wall")
setEntityMeshDirect(
    entityId: wall,
    meshes: BasicPrimitives.createCube(extent: 1.0),
    assetName: "wall"
)
scaleTo(entityId: wall, scale: simd_float3(14, 8, 0.2))
translateTo(entityId: wall, position: simd_float3(0, 4, -6))
updateMaterialColor(entityId: wall, color: Color(red: 0.70, green: 0.70, blue: 0.72))
```

This scene exists to make light behavior visible. The floor catches light from
above and the wall makes directional, spot, point, and area lights easier to
compare.

## Directional Light

Directional lights are used for sunlight or distant key lights. They do not
need a meaningful position. Their rotation defines the light direction.

```swift
let dir = createEntity()
setEntityName(entityId: dir, name: "Directional Light")
createDirLight(entityId: dir)
rotateTo(entityId: dir, angle: -50.0, axis: simd_float3(1, 0, 0))
setLight(entityId: dir, .color(simd_float3(1.0, 0.95, 0.85)))
setLight(entityId: dir, .intensity(1.2))
setLight(entityId: dir, .directional(.active))
```

The important call is:

```swift
setLight(entityId: dir, .directional(.active))
```

That marks this entity as the active directional light. Only one directional
light is active for directional shading and shadows at a time.

## Point Light

Point lights radiate from a position in all directions. The transform position
matters because the light is local to the scene.

```swift
let pt = createEntity()
setEntityName(entityId: pt, name: "Point Light")
createPointLight(entityId: pt)
translateTo(entityId: pt, position: simd_float3(3.5, 3.5, 2.0))
setLight(entityId: pt, .color(simd_float3(1.0, 0.55, 0.1)))
setLight(entityId: pt, .intensity(3.0))
setLight(entityId: pt, .point(.radius(9.0)))
```

The shared settings are:

- `.color(...)`
- `.intensity(...)`

The point-specific setting is:

```swift
setLight(entityId: pt, .point(.radius(9.0)))
```

Use point lights for lamps, bulbs, glowing props, and small local light sources.

## Spot Light

Spot lights have both position and direction. The demo places the light above
the scene, rotates it downward, then configures the cone:

```swift
let sp = createEntity()
setEntityName(entityId: sp, name: "Spot Light")
createSpotLight(entityId: sp)
translateTo(entityId: sp, position: simd_float3(-3.5, 6.0, 1.5))
rotateTo(entityId: sp, angle: -65.0, axis: simd_float3(1, 0, 0))
setLight(entityId: sp, .color(simd_float3(0.3, 0.65, 1.0)))
setLight(entityId: sp, .intensity(4.0))
setLight(entityId: sp, .spot(.coneAngle(20.0)))
setLight(entityId: sp, .spot(.falloff(0.8)))
```

The spot-specific APIs are:

```swift
setLight(entityId: sp, .spot(.coneAngle(20.0)))
setLight(entityId: sp, .spot(.falloff(0.8)))
```

Use spot lights for flashlights, stage lights, focused ceiling lights, and other
cone-shaped sources.

## Area Light

Area lights behave like rectangular emitters. Position, rotation, and scale all
matter. In this demo, the area light acts like an overhead panel:

```swift
let ar = createEntity()
setEntityName(entityId: ar, name: "Area Light")
createAreaLight(entityId: ar)
translateTo(entityId: ar, position: simd_float3(0.0, 5.5, -1.5))
rotateTo(entityId: ar, angle: -90.0, axis: simd_float3(1, 0, 0))
scaleTo(entityId: ar, scale: simd_float3(5, 5, 1))
setLight(entityId: ar, .color(simd_float3(0.75, 0.5, 1.0)))
setLight(entityId: ar, .intensity(2.0))
setLight(entityId: ar, .area(.twoSided(false)))
```

The scale controls the rectangle size. The type-specific setting controls
whether light emits from both faces:

```swift
setLight(entityId: ar, .area(.twoSided(false)))
```

Use area lights for windows, large panels, soft boxes, and broad architectural
lighting.

## Runtime Light Controls

The demo stores each light's `EntityID`:

```swift
private var dirLight: EntityID?
private var pointLight: EntityID?
private var spotLight: EntityID?
private var areaLight: EntityID?
```

That lets the SwiftUI controls change live engine state later:

```swift
func setPointLight(enabled: Bool, intensity: Float) {
    guard let pointLight else { return }
    setLight(entityId: pointLight, .intensity(enabled ? intensity : 0))
}
```

The enabled toggles do not destroy lights. They set intensity to `0`. This is a
simple pattern when you want runtime light controls without changing the scene
structure.

The spot light also updates its cone angle while enabled:

```swift
func setSpotLight(enabled: Bool, intensity: Float, coneAngle: Float) {
    guard let spotLight else { return }
    setLight(entityId: spotLight, .intensity(enabled ? intensity : 0))
    if enabled {
        setLight(entityId: spotLight, .spot(.coneAngle(coneAngle)))
    }
}
```

This is the same API used during setup. There is no separate "editor" path for
changing lights at runtime.

## Camera Input

The demo keeps the same right-drag orbit camera pattern introduced in the
Starter Demo:

```swift
guard let camera = CameraSystem.shared.activeCamera else { return }
let input = InputSystem.shared

if input.keyState.rightMousePressed {
    setOrbitOffset(entityId: camera, uTargetOffset: 10.0)
    orbitCameraAround(
        entityId: camera,
        uDelta: simd_float2(input.mouseDeltaX, input.mouseDeltaY)
    )
}
```

This is useful for lighting work because camera movement is independent from the
light setup. You can inspect the same light configuration from different angles
without changing the scene.

## API Pattern To Remember

Most lighting code follows this sequence:

```swift
let light = createEntity()
setEntityName(entityId: light, name: "Light Name")
createPointLight(entityId: light)
translateTo(entityId: light, position: simd_float3(0, 2, 0))
setLight(entityId: light, .color(simd_float3(1, 0.8, 0.6)))
setLight(entityId: light, .intensity(2.0))
setLight(entityId: light, .point(.radius(4.0)))
```

Change the creation call and type-specific `setLight` cases for the light type
you need.

## What To Change First

Try these changes in `Sources/Demos/LightingDemo/GameScene.swift`:

| Goal | API To Change |
| --- | --- |
| Make the scene warmer | Change `.color(...)` on the directional or point light. |
| Turn off a light by default | Set its `.intensity(0)` after creation. |
| Move the point light | Change `translateTo(...)` on the point light. |
| Make the spot wider | Increase `.spot(.coneAngle(...))`. |
| Make the area light larger | Change `scaleTo(...)` on the area light. |
| Emit from both sides of the area light | Change `.area(.twoSided(false))` to `.area(.twoSided(true))`. |

## Related Documentation

- [Lighting System](../API/UsingLightingSystem.md)
- [Transform System](../API/UsingTransformSystem.md)
- [Camera System](../API/UsingCameraSystem.md)
- [Rendering System](../API/UsingRenderingSystem.md)
