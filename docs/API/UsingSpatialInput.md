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

## Raw Gesture Examples

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

To retrieve the exact world-space position where the user taps on a real-world surface, use `pickRealSurfacePosition`. This raycasts against ARKit-detected physical planes in the user's environment. This is useful for calibration workflows where you need to anchor a point on the ground and scale a model relative to it.

The `filter` parameter controls which planes are considered by **alignment** and, optionally, by **surface classification**. The function always returns the single closest hit that passes the filter.

### Alignment presets

- `.horizontalAny` — horizontal planes only (floor, ceiling, table, seat). **Warning:** this includes tables and seats — use `.floorOnly` when you need the floor specifically.
- `.verticalAny` — vertical planes only (wall, door, window)
- `.any` — all detected planes regardless of alignment

### Classification presets

- `.floorOnly` — floor planes only (recommended for ground anchoring)
- `.tableOnly` — table planes only
- `.wallOnly` — wall planes only

### Picking whichever surface the user is pointing at

When your app needs to respond to floor or table (whichever the user taps), use a **single call** with a multi-kind filter and inspect `surfaceKind` in the result. Because the function returns the closest qualifying hit, this correctly returns the table when pointing at the table and the floor when pointing at the floor.

```swift
let state = InputSystem.shared.xrSpatialInputState

if state.spatialTapActive {
    let filter = RealSurfaceFilter(alignment: .horizontal, kinds: [.floor, .table])

    if let hit = pickRealSurfacePosition(
        rayOrigin: state.rayOriginWorld,
        rayDirection: state.rayDirectionWorld,
        filter: filter
    ) {
        switch hit.surfaceKind {
        case .floor:
            Logger.log(message: "Floor hit", vector: hit.worldPosition)
        case .table:
            Logger.log(message: "Table hit", vector: hit.worldPosition)
        default:
            break
        }
    }
}
```

> **Anti-pattern — do not call `pickRealSurfacePosition` twice in the same tap handler with different classification filters.** Each call is an independent ray cast. When pointing at a table, a `.floorOnly` call will skip the table plane and keep going until it hits the large floor plane behind it — so both calls return a hit even though the user only pointed at one surface. Use a single call and branch on `surfaceKind`.

### Other filter examples

```swift
let state = InputSystem.shared.xrSpatialInputState

if state.spatialTapActive {
    // Floor only — always ignores tables, seats, and ceilings
    if let hit = pickRealSurfacePosition(
        rayOrigin: state.rayOriginWorld,
        rayDirection: state.rayDirectionWorld,
        filter: .floorOnly
    ) {
        Logger.log(message: "Floor hit", vector: hit.worldPosition)
    }

    // Any horizontal surface — inspect kind after the fact
    if let hit = pickRealSurfacePosition(
        rayOrigin: state.rayOriginWorld,
        rayDirection: state.rayDirectionWorld,
        filter: .horizontalAny
    ) {
        Logger.log(message: "Surface type: \(hit.surfaceKind)", vector: hit.worldPosition)
    }

    // Vertical surface (wall, door, window)
    if let hit = pickRealSurfacePosition(
        rayOrigin: state.rayOriginWorld,
        rayDirection: state.rayDirectionWorld,
        filter: .verticalAny
    ) {
        Logger.log(message: "Surface type: \(hit.surfaceKind)", vector: hit.worldPosition)
    }
}
```

### Choosing the right filter

| Goal | Filter to use |
|---|---|
| Always anchor to the floor, ignore furniture | `.floorOnly` |
| Always anchor to the table, ignore floor | `.tableOnly` |
| Whichever surface the user taps | `kinds: [.floor, .table]` + check `surfaceKind` |
| Any horizontal surface | `.horizontalAny` + check `surfaceKind` |

### Diagnosing unexpected classification

If surfaces are not being detected as expected, call this at any point to print every plane ARKit currently tracks, including its classification, Y position, and size:

```swift
RealSurfacePlaneStore.shared.logAllPlanes()
```

Sample output:

```
── RealSurfacePlaneStore: 3 plane(s) ──────────────────
  [a1b2c3d4] alignment=horizontal  classification=floor    y=-0.02m  size=4.20x3.80
  [e5f6a7b8] alignment=horizontal  classification=unknown  y=+0.74m  size=1.10x0.60
  [c9d0e1f2] alignment=vertical    classification=wall     y=+1.20m  size=2.40x0.10
────────────────────────────────────────────────────────────────────
```

This reveals a common issue: **ARKit frequently classifies desks and tables as `.unknown`** rather than `.table`, especially when the surface has not been scanned from multiple angles or the room lighting is poor. Waiting and walking around the furniture can help ARKit reclassify.

### Targeting surfaces by height (Y-range filter)

When ARKit does not classify a desk or table correctly, use the `hitYRange` parameter to restrict hits by the world-space Y coordinate of the intersection point. This is reliable regardless of classification.

Floor is always near Y≈0. A standard desk or table is typically between 0.5m and 1.1m:

```swift
let state = InputSystem.shared.xrSpatialInputState

if state.spatialTapActive {
    // Floor — accept hits within ±20 cm of ground level
    if let hit = pickRealSurfacePosition(
        rayOrigin: state.rayOriginWorld,
        rayDirection: state.rayDirectionWorld,
        filter: .horizontalAny,
        hitYRange: (-0.2)...0.2
    ) {
        Logger.log(message: "Floor hit (Y=\(hit.worldPosition.y))", vector: hit.worldPosition)
    }

    // Desk or table — accept hits between 0.5m and 1.1m
    if let hit = pickRealSurfacePosition(
        rayOrigin: state.rayOriginWorld,
        rayDirection: state.rayDirectionWorld,
        filter: .horizontalAny,
        hitYRange: 0.5...1.1
    ) {
        Logger.log(message: "Desk hit (Y=\(hit.worldPosition.y))", vector: hit.worldPosition)
    }
}
```

You can combine `hitYRange` with a classification filter. When ARKit does classify surfaces correctly this gives the tightest constraint:

```swift
if let hit = pickRealSurfacePosition(
    rayOrigin: state.rayOriginWorld,
    rayDirection: state.rayDirectionWorld,
    filter: .floorOnly,
    hitYRange: (-0.2)...0.2
) { ... }
```

### Note on ARKit classification timing

ARKit can initially report a newly-detected horizontal plane as `.unknown` before it has gathered enough geometry to classify it as floor or table. If placement feels unreliable immediately after startup, wait a few seconds and walk around the surface to give ARKit more data. Use `logAllPlanes()` to monitor classification as it updates.

------------------------------------------------------------------------

## Spatial Helper Functions

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
