# Spatial Input And Manipulation

Spatial input gives a Vision Pro app high-level gesture state instead of raw OS
events. Use it for picking, dragging, rotating, zooming, and manipulating either
individual entities or the scene root.

## Setup

Register XR events during scene initialization:

```swift
registerXREvents()
```

Configure picking and rotation behavior:

```swift
setInput(.xr(.pickingBackend(.octreeGPUPreferred)))
setInput(.xr(.twoHandRotateAxisMode(.dynamicSnapped)))
setInput(.xr(.sceneReady(true)))
```

Tune manipulation thresholds if needed:

```swift
setSpatialManipulation(.intentTranslationThreshold(0.01))
setSpatialManipulation(.intentRotationThreshold(0.08))
setSpatialManipulation(.classificationFrames(3))
setSpatialManipulation(.rotationSmoothing(factor: 0.25, deadzone: 0.002))
setSpatialManipulation(.zoomScale(min: 0.05, max: 20.0))
```

## Read Input State

Poll the current frame's spatial state in `handleInput()`:

```swift
func handleInput() {
    guard gameMode, isSceneReady() else { return }

    let state = getXRSpatialInputState()
}
```

The state includes tap, pinch, drag, zoom, rotate, and picked entity data.

## Tap To Select

```swift
let state = getXRSpatialInputState()

if state.spatialTapActive, let entityId = state.pickedEntityId {
    Logger.log(message: "Tapped entity: \(entityId)")
}
```

Use this for selection, focus, object activation, or editor-style inspection.

## Pinch Transform Lifecycle

For object manipulation, prefer the lifecycle helper:

```swift
func handleInput() {
    guard gameMode, isSceneReady() else { return }

    let state = getXRSpatialInputState()
    processPinchTransformLifecycle(from: state)
}
```

The helper handles begin, update, end, and cancel phases so manipulation sessions
do not get stuck.

Do not return early only because `pickedEntityId` is nil. End and cancel phases
still need to reach the lifecycle helper.

## Manipulate A Parent Entity

If picking hits a child mesh but you want to manipulate the parent actor:

```swift
var state = getXRSpatialInputState()

if let picked = state.pickedEntityId,
   let parent = getEntityParent(entityId: picked) {
    state.pickedEntityId = parent
}

processPinchTransformLifecycle(from: state)
```

This is useful for multi-mesh characters, grouped props, or split architectural
assets.

## Scene Root Manipulation

For spatial placement of a whole scene:

```swift
let state = getXRSpatialInputState()

SpatialManipulationSystem.shared.processAnchoredSceneManipulationLifecycle(
    from: state,
    dragSensitivity: 10.0,
    rotateSensitivity: 1.0
)
```

This is the pattern to use when users need to position a building, room, model,
or streamed scene in the real world.

## Picking Participation

Control whether entities can be picked:

```swift
setEntityPickParticipation(entityId: entityId, enabled: false)
setEntityPickHitRepresentationMode(entityId: entityId, mode: .bounds)
setEntityPickHitRepresentationMode(entityId: entityId, mode: .mesh)
```

For whole categories of objects, use scene channels:

```swift
setSceneChannel(.contextGeometry, .pickParticipation(false))
```

This keeps walls, floors, or merged background geometry out of picking while
interactive entities remain selectable.

## Related Documentation

- [Spatial Input](../API/UsingSpatialInput.md)
- [Input System](../API/UsingInputSystem.md)
- [Scene Channels](../API/UsingSceneChannels.md)
- [Transform System](../API/UsingTransformSystem.md)
- [Scene Graph](../API/UsingScenegraph.md)

