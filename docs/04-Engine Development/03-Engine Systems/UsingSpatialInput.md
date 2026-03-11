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

## Picking Participation And Hit Representation

Use these APIs to control whether an entity can be selected by spatial tap/ray picking and what hit representation it uses.

``` swift
setEntityPickParticipation(entityId: entityId, enabled: false) // visible, not pickable
setEntityPickHitRepresentationMode(entityId: entityId, mode: .bounds) // pick using bounds
setEntityPickHitRepresentationMode(entityId: entityId, mode: .mesh) // pick using mesh (default)
```

Available APIs:

-   `setEntityPickParticipation(entityId:enabled:)`
-   `getEntityPickParticipation(entityId:)`
-   `setEntityPickHitRepresentationMode(entityId:mode:)`
-   `getEntityPickHitRepresentationMode(entityId:)`

Hit representation modes:

-   `.none`\
    Never pickable.
-   `.bounds`\
    Pick using bounds intersection.
-   `.mesh`\
    Pick using mesh-capable path (default behavior).

Behavior rules:

-   Default for existing entities: pick participation is enabled, hit mode is `.mesh`.
-   `enabled == false` means the entity is never returned by picking, regardless of mode.
-   `mode == .none` also means the entity is never returned by picking.
-   CPU and octree/GPU-preferred backends both respect these settings.

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

## Anchored Scene Rotate Helper

For rotating the **entire scene root** around world up (`+Y`) while preserving static batching, use the anchored scene rotate lifecycle. This requires a **two-hand pinch + twist** gesture (`spatialRotateActive` with both hands pinching):

``` swift
func handleInput() {
    let state = InputSystem.shared.xrSpatialInputState

    SpatialManipulationSystem.shared.processAnchoredSceneRotateLifecycle(from: state)
}
```

This helper:

-   Activates only when both hands are pinching and a two-hand rotate gesture is recognized
-   Captures the initial two-hand vector direction + scene yaw on rotate start
-   Applies absolute yaw from gesture start via `rotateSceneToYaw`, keeping static batches intact
-   Ends automatically when either hand releases or the rotate gesture ends

You can adjust rotation speed with the `sensitivity` parameter (defaults to `1.0`):

``` swift
SpatialManipulationSystem.shared.processAnchoredSceneRotateLifecycle(from: state, sensitivity: 0.5)
```

To manually end rotation (e.g. on a mode change), call:

``` swift
SpatialManipulationSystem.shared.endAnchoredSceneRotate()
```

Use this when aligning or calibrating an already-loaded large scene in place without rebatching.

------------------------------------------------------------------------

## Unified Scene Manipulation Helper

To avoid drag/rotate gesture fighting, use the unified scene-root manipulation lifecycle:

``` swift
func handleInput() {
    let state = InputSystem.shared.xrSpatialInputState

    SpatialManipulationSystem.shared.processAnchoredSceneManipulationLifecycle(
        from: state,
        dragSensitivity: 1.0,
        rotateSensitivity: 0.5
    )
}
```

Arbitration rules:

-   When a pinch is first detected, classification is deferred for a few frames (`manipulationClassificationFrames`, default 3) so the second hand has time to arrive
-   Two-hand pinch + twist (`spatialRotateActive` + both hands pinching) routes to scene rotate
-   Otherwise, after the deferral window expires, pinch drag routes to scene drag
-   The non-winning session is ended automatically
-   Once a mode is chosen, it stays latched (`drag` or `rotate`) until the gesture ends/release happens

You can tune the deferral window (set to 0 to commit immediately):

``` swift
SpatialManipulationSystem.shared.manipulationClassificationFrames = 4  // ~44ms at 90 Hz
```

To manually end the unified lifecycle (e.g. on a mode change), call:

``` swift
SpatialManipulationSystem.shared.endAnchoredSceneManipulation()
```

Use this as the default scene-root helper when your app supports both panning and rotation.

------------------------------------------------------------------------

## Combining Scene Drag, Rotate and Zoom

All three scene-level gestures can live in the same input loop — they gate on different input conditions so they don't conflict:

``` swift
func handleInput() {
    let state = InputSystem.shared.xrSpatialInputState

    // Single-hand pinch + drag → pan the scene
    SpatialManipulationSystem.shared.processAnchoredSceneDragLifecycle(from: state)

    // Two-hand pinch + twist → rotate the scene (yaw)
    SpatialManipulationSystem.shared.processAnchoredSceneRotateLifecycle(from: state)

    // Two-hand pinch + spread/pinch → zoom an entity
    SpatialManipulationSystem.shared.applyTwoHandZoomIfNeeded(from: state)
}
```

For context-based entity vs. scene rotation — route two-hand twist to entity rotate when something is picked, and to scene rotate otherwise:

``` swift
func handleInput() {
    let state = InputSystem.shared.xrSpatialInputState

    // Scene-level drag (always active)
    SpatialManipulationSystem.shared.processAnchoredSceneDragLifecycle(from: state)

    if state.pickedEntityId != nil {
        // Entity is picked → two-hand twist rotates the entity
        SpatialManipulationSystem.shared.applyTwoHandRotateIfNeeded(from: state)
    } else {
        // Nothing picked → two-hand twist rotates the scene
        SpatialManipulationSystem.shared.processAnchoredSceneRotateLifecycle(from: state)
    }

    SpatialManipulationSystem.shared.applyTwoHandZoomIfNeeded(from: state)
}
```

------------------------------------------------------------------------

## Two-Hand Zoom

Apply the built-in zoom response:

```swift
let state = InputSystem.shared.xrSpatialInputState

SpatialManipulationSystem.shared.applyTwoHandZoomIfNeeded(
    from: state,
    sensitivity: 1.0
)
```

By default, the helper scales the parent of the picked entity when available.
If you want to choose the exact target, pass `entityId`:

```swift
let state = InputSystem.shared.xrSpatialInputState

if let picked = state.pickedEntityId {
    // Scale exactly what was hit
    SpatialManipulationSystem.shared.applyTwoHandZoomIfNeeded(
        from: state,
        entityId: picked,
        sensitivity: 1.0
    )

    // Or scale its parent explicitly
    if let parent = getEntityParent(entityId: picked) {
        SpatialManipulationSystem.shared.applyTwoHandZoomIfNeeded(
            from: state,
            entityId: parent,
            sensitivity: 1.0
        )
    }
}
```

------------------------------------------------------------------------

## Two-Hand Rotate

Use `setXRTwoHandRotateAxisMode` to control how the rotation axis is derived:

```swift
InputSystem.shared.setXRTwoHandRotateAxisMode(.dynamicSnapped)
```

Available modes:

-   `.cameraForward`: rotates around camera-forward axis (screen-style twist)
-   `.dynamic`: derives axis from actual two-hand motion
-   `.dynamicSnapped`: dynamic axis snapped to dominant world axis (`x`, `y`, or `z`)

Apply the built-in rotate response:

```swift
let state = InputSystem.shared.xrSpatialInputState

SpatialManipulationSystem.shared.applyTwoHandRotateIfNeeded(
    from: state,
    sensitivity: 1.5
)
```

By default, the helper rotates the parent of the picked entity when available.
If you want to choose the exact target, pass `entityId`:

```swift
let state = InputSystem.shared.xrSpatialInputState

if let picked = state.pickedEntityId {
    // Rotate exactly what was hit
    SpatialManipulationSystem.shared.applyTwoHandRotateIfNeeded(
        from: state,
        entityId: picked,
        sensitivity: 1.5
    )

    // Or rotate its parent explicitly
    if let parent = getEntityParent(entityId: picked) {
        SpatialManipulationSystem.shared.applyTwoHandRotateIfNeeded(
            from: state,
            entityId: parent,
            sensitivity: 1.5
        )
    }
}
```

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

## Get Ground/Plane Hit Position

To retrieve the exact world-space position where the user taps on the ground, use `pickRealSurfacePosition`. This is useful for calibration workflows where you need to anchor a point on the ground and scale a model relative to it.

```swift
let state = InputSystem.shared.xrSpatialInputState

if state.spatialTapActive{
    if let hit = pickRealSurfacePosition(
          rayOrigin: state.rayOriginWorld,
          rayDirection: state.rayDirectionWorld,
          filter: .horizontalAny
      ) {
          Logger.log(message: "Surface type: \(hit.surfaceKind)", vector: hit.worldPosition)
      }
}
```

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

-   `processAnchoredSceneRotateLifecycle(from:sensitivity:)`\
    Anchored rotate for the entire scene root using two-hand pinch + twist.
    Applies absolute yaw via `rotateSceneToYaw`.

-   `endAnchoredSceneRotate()`\
    Manually ends an in-progress anchored scene rotate session.

-   `processAnchoredSceneManipulationLifecycle(from:dragSensitivity:rotateSensitivity:)`\
    Unified scene-root helper with drag/rotate arbitration to prevent
    gesture-fighting. Uses a deferral window (`manipulationClassificationFrames`) before
    committing to drag so the second hand has time to arrive for rotate.

-   `endAnchoredSceneManipulation()`\
    Ends any in-progress unified scene manipulation (drag, rotate, or pending classification).

-   `applyTwoHandZoomIfNeeded(from:sensitivity:)`\
    Provides zoom delta signal. You must define what zoom means in your
    app.
