# Light Portals

Light portals let selected scene-channel geometry act as proxy real-world window
light. They are intended for spatial twin scenes where windows, doors, or other
openings should appear to admit light into the virtual model.

Light portals are configured through scene channels. They do not create
persistent ECS light entities.

## Basic Workflow

Define a project channel for windows:

```swift
extension SceneChannel {
    static let windowGeometry = SceneChannel.userCustom(index: 1)
}
```

Assign exported window objects by prefix:

```swift
registerSceneChannelPrefix("WIN_", channels: .windowGeometry)
```

Or assign a runtime entity directly:

```swift
setEntitySceneChannels(entityId: windowEntity, channels: .windowGeometry)
```

Enable light portals on that channel:

```swift
setSceneChannel(
    .windowGeometry,
    .lightPortal(.enabled(
        intensity: 0.5,
        range: 4.0,
        useRealWorldTint: true,
        maxActivePortals: 4,
        activationDistance: 10.0
    ))
)
```

Disable them with:

```swift
setSceneChannel(.windowGeometry, .lightPortal(.disabled))
```

## How Portals Render

The engine discovers renderable entities on portal-enabled channels. Each active
portal surface becomes a temporary two-sided area light derived from the
entity's transform and local bounds.

This means:

- portal surfaces should be actual window/opening geometry
- the geometry should have usable bounds
- portal contribution is bounded by `range`
- active portals are capped by `maxActivePortals`
- authored area lights still keep priority

## Real-World Tint

In XR, portals can scale their color and intensity from the Vision Pro real-world
lighting estimate:

```swift
setRendering(.environment(.lightingMode(.realWorldEstimate)))
setRendering(.environment(.realWorldLightingContribution(1.0)))

setSceneChannel(
    .windowGeometry,
    .lightPortal(.enabled(useRealWorldTint: true))
)
```

`useRealWorldTint` does not enable XR lighting by itself. Configure XR lighting
through `setRendering(.environment(...))` first.

## Pair With Passthrough Ghosts

Light portals do not make windows transparent. Use a scene-channel render mode
for that:

```swift
setSceneChannel(
    .windowGeometry,
    .renderMode(.passthroughGhost(opacity: 0.0))
)
```

This pairing is common for mixed passthrough:

- passthrough ghost mode lets the real world show through the window surface
- light portals use the same window channel to emit proxy light

## Diagnostics

Use discovery diagnostics to confirm which entities are eligible:

```swift
let candidates = discoverSceneLightPortalCandidates()
let discovery = getLightPortalDiscoveryDiagnostics()
print(candidates)
print(discovery)
```

Use resolution diagnostics to confirm which portals become active:

```swift
let proxies = resolveSceneLightPortalProxyLightsForActiveCamera()
let resolution = getLightPortalResolutionDiagnostics()
let performance = getLightPortalPerformanceDiagnostics()
let render = getLightPortalRenderDiagnostics()
print(proxies)
print(resolution)
print(performance)
print(render)
```

For a one-shot log:

```swift
setLogger(.category(.lightPortal, true))
LightPortalSystem.shared.logDiagnosticsNow()
setLogger(.category(.lightPortal, false))
```

## Performance Rules

Keep the portal channel narrow. Assign only actual opening/window surfaces, not
entire walls or room shells.

Good starting values:

```swift
setSceneChannel(
    .windowGeometry,
    .lightPortal(.enabled(
        intensity: 0.5,
        range: 4.0,
        useRealWorldTint: true,
        maxActivePortals: 4,
        activationDistance: 10.0
    ))
)
```

Increase `maxActivePortals` only when the visual improvement is clear on device.

## Related Documentation

- [Light Portals](../API/UsingLightPortals.md)
- [Scene Channels](../API/UsingSceneChannels.md)
- [XR Lighting](../API/UsingXRLighting.md)
- [Lighting System](../API/UsingLightingSystem.md)

