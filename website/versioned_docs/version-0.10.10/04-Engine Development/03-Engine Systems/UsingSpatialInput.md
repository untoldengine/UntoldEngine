---
id: spatialinput
title: Spatial Input VisionPro
sidebar_position: 13
---

# Spatial Input (vision Pro)

Spatial input in Untold Engine follows a simple pipeline:

1. visionOS emits raw spatial events.
2. UntoldEngineXR converts each event into an XRSpatialInputSnapshot.
3. Snapshots are queued in InputSystem.
4. XRSpatialGestureRecognizer processes snapshots each frame.
5. The engine publishes a single XRSpatialInputState your game reads in handleInput().

That separation keeps the system flexible: the OS-facing code stays in UntoldEngineXR, while gesture classification stays in
the recognizer.

## What You Get in Game Code

From XRSpatialInputState, you can read:

- spatialTapActive
- spatialDragActive
- spatialPinchActive
- spatialPinchDragDelta
- spatialZoomActive + spatialZoomDelta
- spatialRotateActive + spatialRotateDeltaRadians
- pickedEntityId

So your game logic can stay focused on behavior (select, move, rotate, scale), not event parsing.

## Important Setup Step

You must enable XR event ingestion:

InputSystem.shared.registerXREvents()

If you skip this, the callback still receives OS events, but the engine ignores them.

## Typical Frame Usage

In your handleInput():

- Poll InputSystem.shared.xrSpatialInputState.
- React to edge-triggered gestures like tap.
- Apply continuous updates for drag/zoom/rotate while active.

For object manipulation, use SpatialManipulationSystem for robust pinch-driven transforms, then layer custom behavior on top
when needed.
  
## Quick Example

This example shows how to drag and rotate a mesh using the engine:

``` swift
func handleInput() {
    if gameMode == false { return }

    let state = InputSystem.shared.xrSpatialInputState

    if state.spatialTapActive, let entityId = state.pickedEntityId {
        Logger.log(message: "Tapped entity: \(entityId)")
    }

    // Handles drag-based translate + twist rotation on picked entity
    SpatialManipulationSystem.shared.processPinchTransformLifecycle(from: state)
}
```

### What This Does

-   **Tap** → selects entity (via raycast picking)
-   **Pinch + Drag** → translates entity in world space
-   **Pinch + Twist** → rotates entity around a computed axis

`processPinchTransformLifecycle` handles:

-   Begin
-   Update
-   End
-   Cancel

This lifecycle model prevents stuck manipulation sessions.

------------------------------------------------------------------------

### Manipulate Parent Instead Of Picked Child

If ray picking hits a child mesh and you want to manipulate the parent
actor:

``` swift
var state = InputSystem.shared.xrSpatialInputState

if let picked = state.pickedEntityId,
   let parent = getEntityParent(entityId: picked) {
    state.pickedEntityId = parent
}

SpatialManipulationSystem.shared.processPinchTransformLifecycle(from: state)
```

This is useful when:

-   A character has multiple meshes
-   A building has sub-meshes
-   You want to move the root actor instead of individual geometry
    pieces

------------------------------------------------------------------------

### Important Note

Do not early-return only because `pickedEntityId == nil` before calling
lifecycle processing.

End/cancel phases must still propagate to properly close manipulation
sessions.\
Failing to do so can leave the engine in an inconsistent transform
state.

------------------------------------------------------------------------

# Raw Gesture Examples

It is strongly recommended to use the Spatial Helper functions instead
of raw gesture access.

Raw access is useful when:

-   You want custom manipulation behavior
-   You are building a custom editor
-   You want non-standard gesture responses

------------------------------------------------------------------------

## Tap (Selection)

Vision Pro air-tap gesture.

``` swift
let state = InputSystem.shared.xrSpatialInputState
if state.spatialTapActive, let entityId = state.pickedEntityId {
    // selectEntity(entityId)
}
```

Use this to:

-   Select objects
-   Trigger UI
-   Activate gameplay logic

------------------------------------------------------------------------

## Pinch Active

Single-hand pinch detected.

``` swift
if InputSystem.shared.hasSpatialPinch() {
    // pinch is active
}
```

This does **not** imply dragging yet --- only that a pinch is currently
held.

------------------------------------------------------------------------

## Pinch Position

World-space position of pinch.

``` swift
if let pinchPosition = InputSystem.shared.getPinchPosition() {
    // use pinchPosition
}
```

Useful for:

-   Placing objects
-   Spawning actors
-   Visual debugging

------------------------------------------------------------------------

## Pinch Drag Delta

Drag delta while pinch is active.

``` swift
let state = InputSystem.shared.xrSpatialInputState
if state.spatialPinchActive {
    let dragDelta = InputSystem.shared.getPinchDragDelta()
    // app-defined translation/scaling response
}
```

Common use cases:

-   Translate object along plane
-   Move UI panels
-   Drag actors in world space

------------------------------------------------------------------------

## Anchored Pinch Drag Helper

For stable translation (no per-frame delta accumulation), use the
anchored lifecycle helper:

``` swift
func handleInput() {
    let state = InputSystem.shared.xrSpatialInputState

    SpatialManipulationSystem.shared.processAnchoredPinchDragLifecycle(
        from: state,
        entityId: sceneRootEntity
    )
}
```

This helper:

-   Captures initial hand + entity world positions
-   Applies absolute displacement from gesture start
-   Cleans up session state on end/cancel

Use this when moving large roots (buildings/scenes) where incremental
delta jitter can become visible.

------------------------------------------------------------------------

## Anchored Scene Drag Helper

For translating the **entire scene root** (rather than a single entity), use the anchored scene drag lifecycle:

``` swift
func handleInput() {
    let state = InputSystem.shared.xrSpatialInputState

    SpatialManipulationSystem.shared.processAnchoredSceneDragLifecycle(from: state)
}
```

This helper:

-   Captures initial hand + scene root world positions on drag start
-   Applies absolute displacement from gesture start via `translateSceneTo`, keeping static batches intact
-   Cleans up session state on end/cancel

You can adjust movement speed with the `sensitivity` parameter (defaults to `1.0`):

``` swift
SpatialManipulationSystem.shared.processAnchoredSceneDragLifecycle(from: state, sensitivity: 0.5)
```

To manually end the drag (e.g. on a mode change), call:

``` swift
SpatialManipulationSystem.shared.endAnchoredSceneDrag()
```

Use this when panning an entire scene — for example, sliding a map, architectural model, or level layout in world space.

------------------------------------------------------------------------

## Two-Hand Zoom Signal (Coming soon)

Two hands pinching and moving closer/farther.

``` swift
let state = InputSystem.shared.xrSpatialInputState
if state.leftHandPinching, state.rightHandPinching, state.spatialZoomActive {
    let zoomDelta = InputSystem.shared.getSpatialZoomDelta()
    // app-defined zoom response
}
```

### Typical Behavior Options

You decide what zoom means:

-   Scale selected object
-   Move object closer/farther in world space
-   Adjust camera rig distance
-   Modify FOV (if using custom projection control)

Untold Engine does not automatically change camera FOV.\
You define the semantic meaning of zoom.

------------------------------------------------------------------------

## Two-Hand Rotate Signal (Coming soon)

Two hands pinching and rotating around each other.

``` swift
let state = InputSystem.shared.xrSpatialInputState
if state.leftHandPinching, state.rightHandPinching, state.spatialRotateActive {
    let deltaRadians = InputSystem.shared.getSpatialRotateDelta()
    let axisWorld = InputSystem.shared.getSpatialRotateAxisWorld()
    // app-defined rotate response
}
```

Typical usage:

-   Rotate object in world space
-   Rotate parent actor
-   Rotate UI panel in 3D

`axisWorld` allows you to apply physically intuitive rotations rather
than arbitrary axes.

## Get distance to hit-entity

To get the distance to an entity use the following:

```swift
// Get distance to hit-entity
let state = InputSystem.shared.xrSpatialInputState
if state.spatialTapActive, let entityId = state.pickedEntityId {
    // get distance
    let distance = state.pickedEntityDistance
    print("Object distance: \(distance) meters")
}
```

------------------------------------------------------------------------

## Get Ground Hit Position

To retrieve the exact world-space position where the user taps on the ground, use `pickGroundPosition`. This is useful for calibration workflows where you need to anchor a point on the ground and scale a model relative to it.

```swift
let state = InputSystem.shared.xrSpatialInputState
if state.spatialTapActive {
    if let groundHit = pickGroundPosition(
        rayOrigin: state.rayOriginWorld,
        rayDirection: state.rayDirectionWorld
    ) {
        // groundHit.worldPosition is the exact 3D point on the ground
        // groundHit.distance is the ray travel distance to that point
        anchorCalibrationPoint(at: groundHit.worldPosition) // pseudo-code to anchor entity
    }
}
```

By default the ground plane is at y = 0. Pass a custom height with the `planeY` parameter:

```swift
let groundHit = pickGroundPosition(
    rayOrigin: state.rayOriginWorld,
    rayDirection: state.rayDirectionWorld,
    planeY: 1.5  // ground at y = 1.5
)
```

For arbitrary planes (walls, ramps, etc.), use `pickPlanePosition`:

```swift
let wallHit = pickPlanePosition(
    rayOrigin: state.rayOriginWorld,
    rayDirection: state.rayDirectionWorld,
    planePoint: simd_float3(0, 0, 5),    // a point on the wall
    planeNormal: simd_float3(0, 0, -1)   // wall faces toward camera
)
```

Both functions return `nil` when the ray is parallel to the plane or pointing away from it.

------------------------------------------------------------------------

# Spatial Helper Functions

Use these helpers from `SpatialManipulationSystem.shared`:

-   `processPinchTransformLifecycle(from:)`\
    Recommended default. Handles translation + twist rotation lifecycle
    safely.

-   `applyPinchDragIfNeeded(from:entityId:sensitivity:)`\
    Lower-level translation helper if you want full control.

-   `processAnchoredSceneDragLifecycle(from:sensitivity:)`\
    Anchored drag for the entire scene root. Applies absolute
    displacement via `translateSceneTo`.

-   `endAnchoredSceneDrag()`\
    Manually ends an in-progress anchored scene drag session.

-   `applyTwoHandZoomIfNeeded(from:sensitivity:)`\
    Provides zoom delta signal. You must define what zoom means in your
    app.
