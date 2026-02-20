---
id: spatialinput
title: Spatial Input VisionPro
sidebar_position: 13
---

# Spatial Input (vision Pro)

This guide explains how Apple Vision Pro hand gestures map into Untold
Engine's spatial input system, and how to translate those signals into
entity manipulation inside your scene.

All gestures are processed through the engine's `InputSystem+XR` and exposed via
`XRSpatialInputState`.

------------------------------------------------------------------------

## Required Setup

You must enable XR input events when gameplay starts:

``` swift
InputSystem.shared.registerXREvents() // Required
```

Disable XR input events when gameplay ends:

``` swift
InputSystem.shared.unregisterXREvents()
```

This ensures the engine begins listening to Vision Pro spatial hand
tracking events.\
Without registering XR events, `xrSpatialInputState` will remain
inactive.

------------------------------------------------------------------------

## Understanding the Gesture Model

Vision Pro gestures are mapped into three major categories inside Untold
Engine:

1.  **Tap (Selection)**
2.  **Pinch + Drag (Single-Hand Manipulation)**
3.  **Two-Hand Gestures (Zoom + Rotate)** (in development)

The engine separates *gesture detection* from *entity manipulation*.

-   `InputSystem` detects and tracks gesture state.
-   `SpatialManipulationSystem` applies transformations.

This separation keeps your game logic clean and predictable.

------------------------------------------------------------------------

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

------------------------------------------------------------------------

# Spatial Helper Functions

Use these helpers from `SpatialManipulationSystem.shared`:

-   `processPinchTransformLifecycle(from:)`\
    Recommended default. Handles translation + twist rotation lifecycle
    safely.

-   `applyPinchDragIfNeeded(from:entityId:sensitivity:)`\
    Lower-level translation helper if you want full control.

-   `applyTwoHandZoomIfNeeded(from:sensitivity:)`\
    Provides zoom delta signal. You must define what zoom means in your
    app.

------------------------------------------------------------------------

# Recommended Pattern for Production

In most games:

-   Use **tap** for selection
-   Use **single-hand pinch** for move/rotate
-   Use **two-hand gestures** for scaling large actors or world
    manipulation
-   Keep camera manipulation separate from object manipulation

This prevents gesture ambiguity and improves UX consistency.

