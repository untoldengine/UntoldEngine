# XR App Basics

This tutorial outlines the engine APIs that matter when moving from macOS demos
to a Vision Pro app: immersion mode, environment rendering, real-world lighting,
spatial input, and scene manipulation.

## Match SwiftUI And Engine Immersion

The SwiftUI `ImmersiveSpace` style and the engine immersion mode must match.

Mixed passthrough:

```swift
@State private var immersionStyle: ImmersionStyle = .mixed
```

```swift
xr.setImmersionMode(xrImmersionMode: .mixed)
```

```swift
.immersionStyle(selection: $immersionStyle, in: .mixed)
```

Full immersion:

```swift
@State private var immersionStyle: ImmersionStyle = .full
xr.setImmersionMode(xrImmersionMode: .full)
.immersionStyle(selection: $immersionStyle, in: .full)
```

If these disagree, passthrough and background rendering will not match the
engine's assumptions.

## Environment Rendering

Show the environment in full immersion:

```swift
setRendering(.environment(.visible(true)))
```

Use the environment for IBL:

```swift
setRendering(.environment(.ibl(true)))
```

Load a custom HDR:

```swift
setRendering(.environment(.asset("suburban_garden_2k.hdr")))
```

In mixed immersion, passthrough is the background. The environment can still
contribute lighting even when it is not visible.

## Real-World XR Lighting

Enable Vision Pro real-world lighting estimates:

```swift
setRendering(.environment(.lightingMode(.realWorldEstimate)))
setRendering(.environment(.realWorldLightingContribution(1.0)))
```

Tune contribution at runtime:

```swift
setRendering(.environment(.realWorldLightingContribution(0.75)))
```

Diagnostics are available from the XR instance:

```swift
print("XR Lighting:", xr.xrEnvironmentLightingDiagnostics())
```

Probe updates are not expected every frame. Watch accepted probe count,
timestamp, and intensity scale when testing real room-light changes.

## Register Spatial Input

Enable XR input ingestion during scene setup:

```swift
registerXREvents()
```

Configure the XR input backend:

```swift
setInput(.xr(.pickingBackend(.octreeGPUPreferred)))
setInput(.xr(.twoHandRotateAxisMode(.dynamicSnapped)))
setInput(.xr(.sceneReady(true)))
```

Then read state in `handleInput()`:

```swift
let state = getXRSpatialInputState()
```

## Manipulate The Scene Root

For spatial placement workflows, use the anchored scene manipulation lifecycle:

```swift
func handleInput() {
    guard gameMode, isSceneReady() else { return }

    let state = getXRSpatialInputState()

    SpatialManipulationSystem.shared.processAnchoredSceneManipulationLifecycle(
        from: state,
        dragSensitivity: 10.0,
        rotateSensitivity: 1.0
    )
}
```

This gives users a stable pinch-drag and two-hand-rotate pattern for positioning
the scene.

## Combine With Scene Channels

XR apps often use scene channels to manage passthrough:

```swift
extension SceneChannel {
    static let windowGeometry = SceneChannel.userCustom(index: 1)
}

registerSceneChannelPrefix("WIN_", channels: .windowGeometry)

setSceneChannel(
    .windowGeometry,
    .renderMode(.passthroughGhost(opacity: 0.0))
)
```

For spatial twins, pair that with light portals:

```swift
setSceneChannel(
    .windowGeometry,
    .lightPortal(.enabled(useRealWorldTint: true))
)
```

## Related Documentation

- [XR Immersion Modes](../API/UsingXRImmersionMode.md)
- [XR Lighting](../API/UsingXRLighting.md)
- [Spatial Input](../API/UsingSpatialInput.md)
- [Scene Channels](../API/UsingSceneChannels.md)
- [Light Portals](../API/UsingLightPortals.md)

