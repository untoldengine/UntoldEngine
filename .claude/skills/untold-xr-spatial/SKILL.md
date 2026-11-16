---
name: untold-xr-spatial
description: Use when building or debugging Vision Pro / visionOS app behavior in Untold Engine — matching SwiftUI ImmersiveSpace to engine immersion mode, environment/IBL rendering, real-world lighting estimates, or spatial input (tap-to-select, pinch/drag/rotate/zoom manipulation of an entity or the whole scene root). Triggers on "set up mixed immersion", "the passthrough environment doesn't match", "let the user grab and move this object", "reposition the whole scene in the room", "two-hand rotate". Not for the XR runtime's internal frame loop (engine-internal work, see CLAUDE.md §5), scene-channel passthrough ghosting or light portals (see untold-scene-channels), or non-XR camera/entity work (see untold-entity-scene).
version: 0.1.0
---

# XR Basics and Spatial Input in Untold Engine

visionOS apps use `UntoldEngineXR`, a structurally different runtime from the macOS/iOS `MTKView` path — no `MTKView`, its own frame loop, foveation, and device-anchor handling. This skill covers the application-facing surface: immersion mode, environment/lighting, and spatial (gesture) input.

## 1. Match SwiftUI immersion style to the engine immersion mode

These must agree, or passthrough/background rendering won't match the engine's assumptions:

```swift
// Mixed passthrough
@State private var immersionStyle: ImmersionStyle = .mixed
xr.setImmersionMode(xrImmersionMode: .mixed)
.immersionStyle(selection: $immersionStyle, in: .mixed)

// Full immersion
@State private var immersionStyle: ImmersionStyle = .full
xr.setImmersionMode(xrImmersionMode: .full)
.immersionStyle(selection: $immersionStyle, in: .full)
```

## 2. Environment rendering and lighting

```swift
setRendering(.environment(.visible(true)))                       // show environment in full immersion
setRendering(.environment(.ibl(true)))                            // use environment for IBL
setRendering(.environment(.asset("suburban_garden_2k.hdr")))      // custom HDR
```

In mixed immersion, passthrough is the background — the environment can still contribute lighting even when not visible.

Real-world lighting estimates (Vision Pro only):

```swift
setRendering(.environment(.lightingMode(.realWorldEstimate)))
setRendering(.environment(.realWorldLightingContribution(1.0)))   // tune at runtime, e.g. 0.75
```

Diagnose with `xr.xrEnvironmentLightingDiagnostics()`. Probe updates aren't expected every frame — watch accepted probe count, timestamp, and intensity scale when testing real room-light changes, don't assume a missing update is a bug.

## 3. Register and configure spatial input

```swift
registerXREvents()   // during scene initialization

setInput(.xr(.pickingBackend(.octreeGPUPreferred)))
setInput(.xr(.twoHandRotateAxisMode(.dynamicSnapped)))
setInput(.xr(.sceneReady(true)))
```

Tune manipulation thresholds only if the defaults feel wrong on-device:

```swift
setSpatialManipulation(.intentTranslationThreshold(0.01))
setSpatialManipulation(.intentRotationThreshold(0.08))
setSpatialManipulation(.classificationFrames(3))
setSpatialManipulation(.rotationSmoothing(factor: 0.25, deadzone: 0.002))
setSpatialManipulation(.zoomScale(min: 0.05, max: 20.0))
```

## 4. Read spatial state per frame

```swift
func handleInput() {
    guard gameMode, isSceneReady() else { return }
    let state = getXRSpatialInputState()
}
```

`state` carries tap, pinch, drag, zoom, rotate, and the picked entity.

## 5. Tap to select

```swift
if state.spatialTapActive, let entityId = state.pickedEntityId {
    // selection, focus, activation, inspection
}
```

## 6. Manipulate a single entity — use the lifecycle helper, don't hand-roll it

```swift
func handleInput() {
    guard gameMode, isSceneReady() else { return }
    let state = getXRSpatialInputState()
    processPinchTransformLifecycle(from: state)
}
```

`processPinchTransformLifecycle` handles begin/update/end/cancel so a manipulation session can't get stuck. **Do not** early-return just because `pickedEntityId` is nil — end/cancel phases still need to reach the helper, or a drag can hang.

To manipulate a parent actor when picking hits a child mesh (common for multi-mesh characters or split architectural assets):

```swift
var state = getXRSpatialInputState()
if let picked = state.pickedEntityId,
   let parent = getEntityParent(entityId: picked) {
    state.pickedEntityId = parent
}
processPinchTransformLifecycle(from: state)
```

## 7. Manipulate the whole scene (spatial placement)

Use this when the user needs to position a building, room, model, or streamed scene in the real world — not per-entity transforms:

```swift
SpatialManipulationSystem.shared.processAnchoredSceneManipulationLifecycle(
    from: state,
    dragSensitivity: 10.0,
    rotateSensitivity: 1.0
)
```

This gives pinch-drag + two-hand-rotate for the scene root.

## 8. Picking participation

Per-entity:

```swift
setEntityPickParticipation(entityId: entityId, enabled: false)
setEntityPickHitRepresentationMode(entityId: entityId, mode: .bounds)   // or .mesh
```

For whole categories of background/context objects, prefer a scene channel over per-entity flags — see `untold-scene-channels`:

```swift
setSceneChannel(.contextGeometry, .pickParticipation(false))
```

## 9. Pairing with scene channels for passthrough window surfaces

```swift
extension SceneChannel {
    static let windowGeometry = SceneChannel.userCustom(index: 1)
}
registerSceneChannelPrefix("WIN_", channels: .windowGeometry)
setSceneChannel(.windowGeometry, .renderMode(.passthroughGhost(opacity: 0.0)))
setSceneChannel(.windowGeometry, .lightPortal(.enabled(useRealWorldTint: true)))
```

Full detail on channel/portal semantics belongs to `untold-scene-channels`, not here.

Full reference: `docs/API/UsingXRImmersionMode.md`, `docs/API/UsingXRLighting.md`, `docs/API/UsingSpatialInput.md`.
