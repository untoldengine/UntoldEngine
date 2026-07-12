# Spatial Input (Vision Pro)

Spatial input in Untold Engine follows a simple pipeline:

1. visionOS emits raw spatial events.
2. UntoldEngineXR converts each event into an XRSpatialInputSnapshot.
3. Snapshots are queued in InputSystem.
4. XRSpatialGestureRecognizer processes snapshots each frame.
5. The engine publishes a single XRSpatialInputState your game reads in handleInput().

That separation keeps the system flexible: the OS-facing code stays in UntoldEngineXR, while gesture classification stays in the recognizer.

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

You must enable XR event ingestion in your init:

```swift
func gameInit() {
    registerXREvents()
}
```

If you skip this, the callback still receives OS events, but the engine ignores them.

## XR Input Configuration

Configure XR input behaviour with `setInput` before the scene starts:

```swift
// Spatial picking backend
setInput(.xr(.pickingBackend(.octreeGPUPreferred)))

// Two-hand rotate axis derivation
setInput(.xr(.twoHandRotateAxisMode(.dynamicSnapped)))

// Signal scene readiness
setInput(.xr(.sceneReady(true)))
```

Tune spatial manipulation thresholds with `setSpatialManipulation`:

```swift
setSpatialManipulation(.intentTranslationThreshold(0.01))
setSpatialManipulation(.intentRotationThreshold(0.08))
setSpatialManipulation(.classificationFrames(3))
setSpatialManipulation(.rotationSmoothing(factor: 0.25, deadzone: 0.002))
setSpatialManipulation(.zoomScale(min: 0.05, max: 20.0))
```

## Typical Frame Usage

In your handleInput():

- Poll `getXRSpatialInputState()` to get the current frame's input.
- React to edge-triggered gestures like tap.
- Apply continuous updates for drag/zoom/rotate while active.

For object manipulation, use the spatial manipulation free functions for robust pinch-driven transforms, then layer custom behaviour on top when needed.

## Quick Example

This example shows how to drag and rotate a mesh using the engine:

```swift
func handleInput() {
    if gameMode == false { return }

    let state = getXRSpatialInputState()

    if state.spatialTapActive, let entityId = state.pickedEntityId {
        Logger.log(message: "Tapped entity: \(entityId)")
    }

    // Handles drag-based translate + twist rotation on picked entity
    processPinchTransformLifecycle(from: state)
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

If ray picking hits a child mesh and you want to manipulate the parent actor:

```swift
var state = getXRSpatialInputState()

if let picked = state.pickedEntityId,
   let parent = getEntityParent(entityId: picked) {
    state.pickedEntityId = parent
}

processPinchTransformLifecycle(from: state)
```

This is useful when:

-   A character has multiple meshes
-   A building has sub-meshes
-   You want to move the root actor instead of individual geometry pieces

------------------------------------------------------------------------

### Important Note

Do not early-return only because `pickedEntityId == nil` before calling lifecycle processing.

End/cancel phases must still propagate to properly close manipulation sessions.
Failing to do so can leave the engine in an inconsistent transform state.

------------------------------------------------------------------------

## Picking Participation And Hit Representation

Use these APIs to control whether an entity can be selected by spatial tap/ray picking and what hit representation it uses.

```swift
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

-   `.none` — Never pickable.
-   `.bounds` — Pick using bounds intersection.
-   `.mesh` — Pick using mesh-capable path (default behavior).

Behavior rules:

-   Default for existing entities: pick participation is enabled, hit mode is `.mesh`.
-   `enabled == false` means the entity is never returned by picking, regardless of mode.
-   `mode == .none` also means the entity is never returned by picking.
-   CPU and octree/GPU-preferred backends both respect these settings.

------------------------------------------------------------------------

## Raw Gesture Examples

It is strongly recommended to use the spatial free functions instead of raw gesture access.

Raw access is useful when:

-   You want custom manipulation behavior
-   You are building a custom editor
-   You want non-standard gesture responses

------------------------------------------------------------------------

## Tap (Selection)

Vision Pro air-tap gesture.

```swift
let state = getXRSpatialInputState()
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

```swift
if InputSystem.shared.hasSpatialPinch() {
    // pinch is active
}
```

This does **not** imply dragging yet — only that a pinch is currently held.

------------------------------------------------------------------------

## Pinch Position

World-space position of pinch.

```swift
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

```swift
let state = getXRSpatialInputState()
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

For stable translation (no per-frame delta accumulation), use the anchored lifecycle helper:

```swift
func handleInput() {
    let state = getXRSpatialInputState()

    processAnchoredPinchDragLifecycle(
        from: state,
        entityId: sceneRootEntity,
        dragPlane: .xz
    )
}
```

This helper:

-   Captures initial hand + entity world positions
-   Applies absolute displacement from gesture start
-   Optionally constrains world-axis movement to `.xy`, `.xz`, or `.yz`
-   Optionally transforms the final world position before it is written
-   Cleans up session state on end/cancel

Use this when moving large roots (buildings/scenes) where incremental delta jitter can become visible.
Use `.xz` to preserve height while dragging across the floor axes, `.xy` to preserve depth for wall-style movement, and `.unconstrained` for free 3D movement.

`dragPlane` filters the hand displacement in world axes. It does not raycast the input ray against a mathematical plane. For ray-plane picking, use `pickGroundPosition` or `pickPlanePosition`.

Use `positionTransform` for continuous snapping, clamping, or custom placement rules:

```swift
processAnchoredPinchDragLifecycle(
    from: state,
    entityId: sceneRootEntity,
    dragPlane: .xz,
    positionTransform: { worldPosition in
        let gridSize: Float = 0.25
        return simd_float3(
            (worldPosition.x / gridSize).rounded() * gridSize,
            worldPosition.y,
            (worldPosition.z / gridSize).rounded() * gridSize
        )
    }
)
```

The closure receives and returns **world-space** position after sensitivity and `dragPlane` have been applied. Its return value is the final position, so it can intentionally override the constrained axis. If it returns a non-finite value, the engine skips that frame's position write.

------------------------------------------------------------------------

## Anchored Scene Drag Helper

For translating the **entire scene root** (rather than a single entity), use the anchored scene drag lifecycle:

```swift
func handleInput() {
    let state = getXRSpatialInputState()

    processAnchoredSceneDragLifecycle(from: state)
}
```

This helper:

-   Captures initial hand + scene root world positions on drag start
-   Applies absolute displacement from gesture start via `translateSceneTo`, keeping static batches intact
-   Cleans up session state on end/cancel

You can adjust movement speed with the `sensitivity` parameter (defaults to `1.0`):

```swift
processAnchoredSceneDragLifecycle(from: state, sensitivity: 0.5)
```

To manually end the drag (e.g. on a mode change), call:

```swift
endAnchoredSceneDrag()
```

Use this when panning an entire scene — for example, sliding a map, architectural model, or level layout in world space.

------------------------------------------------------------------------

## Anchored Scene Rotate Helper

For rotating the **entire scene root** around world up (`+Y`) while preserving static batching, use the anchored scene rotate lifecycle. This requires a **two-hand pinch + twist** gesture (`spatialRotateActive` with both hands pinching):

```swift
func handleInput() {
    let state = getXRSpatialInputState()

    processAnchoredSceneRotateLifecycle(from: state)
}
```

This helper:

-   Activates only when both hands are pinching and a two-hand rotate gesture is recognized
-   Captures the initial two-hand vector direction + scene yaw on rotate start
-   Applies absolute yaw from gesture start via `rotateSceneToYaw`, keeping static batches intact
-   Ends automatically when either hand releases or the rotate gesture ends

You can adjust rotation speed with the `sensitivity` parameter (defaults to `1.0`):

```swift
processAnchoredSceneRotateLifecycle(from: state, sensitivity: 0.5)
```

To manually end rotation (e.g. on a mode change), call:

```swift
endAnchoredSceneRotate()
```

Use this when aligning or calibrating an already-loaded large scene in place without rebatching.

------------------------------------------------------------------------

## Unified Scene Manipulation Helper

To avoid drag/rotate gesture fighting, use the unified scene-root manipulation lifecycle:

```swift
func handleInput() {
    let state = getXRSpatialInputState()

    processAnchoredSceneManipulationLifecycle(
        from: state,
        dragSensitivity: 1.0,
        rotateSensitivity: 0.5
    )
}
```

Arbitration rules:

-   When a pinch is first detected, classification is deferred for a few frames so the second hand has time to arrive
-   Two-hand pinch + twist (`spatialRotateActive` + both hands pinching) routes to scene rotate
-   Otherwise, after the deferral window expires, pinch drag routes to scene drag
-   The non-winning session is ended automatically
-   Once a mode is chosen, it stays latched (`drag` or `rotate`) until the gesture ends

You can tune the deferral window:

```swift
setSpatialManipulation(.classificationFrames(4))  // ~44ms at 90 Hz
```

To manually end the unified lifecycle (e.g. on a mode change), call:

```swift
endAnchoredSceneManipulation()
```

Use this as the default scene-root helper when your app supports both panning and rotation.

------------------------------------------------------------------------

## Combining Scene Drag, Rotate and Zoom

All three scene-level gestures can live in the same input loop — they gate on different input conditions so they don't conflict:

```swift
func handleInput() {
    let state = getXRSpatialInputState()

    // Single-hand pinch + drag → pan the scene
    processAnchoredSceneDragLifecycle(from: state)

    // Two-hand pinch + twist → rotate the scene (yaw)
    processAnchoredSceneRotateLifecycle(from: state)

    // Two-hand pinch + spread/pinch → zoom an entity
    applyTwoHandZoomIfNeeded(from: state)
}
```

For context-based entity vs. scene rotation — route two-hand twist to entity rotate when something is picked, and to scene rotate otherwise:

```swift
func handleInput() {
    let state = getXRSpatialInputState()

    // Scene-level drag (always active)
    processAnchoredSceneDragLifecycle(from: state)

    if state.pickedEntityId != nil {
        // Entity is picked → two-hand twist rotates the entity
        applyTwoHandRotateIfNeeded(from: state)
    } else {
        // Nothing picked → two-hand twist rotates the scene
        processAnchoredSceneRotateLifecycle(from: state)
    }

    applyTwoHandZoomIfNeeded(from: state)
}
```

------------------------------------------------------------------------

## Two-Hand Zoom

Apply the built-in zoom response:

```swift
let state = getXRSpatialInputState()

applyTwoHandZoomIfNeeded(from: state, sensitivity: 1.0)
```

By default, the helper scales the parent of the picked entity when available. If you want to choose the exact target, pass `entityId`:

```swift
let state = getXRSpatialInputState()

if let picked = state.pickedEntityId {
    // Scale exactly what was hit
    applyTwoHandZoomIfNeeded(from: state, entityId: picked, sensitivity: 1.0)

    // Or scale its parent explicitly
    if let parent = getEntityParent(entityId: picked) {
        applyTwoHandZoomIfNeeded(from: state, entityId: parent, sensitivity: 1.0)
    }
}
```

------------------------------------------------------------------------

## Two-Hand Rotate

Configure how the rotation axis is derived:

```swift
setInput(.xr(.twoHandRotateAxisMode(.dynamicSnapped)))
```

Available modes:

-   `.cameraForward` — rotates around camera-forward axis (screen-style twist)
-   `.dynamic` — derives axis from actual two-hand motion
-   `.dynamicSnapped` — dynamic axis snapped to dominant world axis (`x`, `y`, or `z`)

Apply the built-in rotate response:

```swift
let state = getXRSpatialInputState()

applyTwoHandRotateIfNeeded(from: state, sensitivity: 1.5)
```

By default, the helper rotates the parent of the picked entity when available. If you want to choose the exact target, pass `entityId`:

```swift
let state = getXRSpatialInputState()

if let picked = state.pickedEntityId {
    // Rotate exactly what was hit
    applyTwoHandRotateIfNeeded(from: state, entityId: picked, sensitivity: 1.5)

    // Or rotate its parent explicitly
    if let parent = getEntityParent(entityId: picked) {
        applyTwoHandRotateIfNeeded(from: state, entityId: parent, sensitivity: 1.5)
    }
}
```

## Get distance to hit-entity

To get the distance to an entity use the following:

```swift
let state = getXRSpatialInputState()
if state.spatialTapActive, let entityId = state.pickedEntityId {
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
let state = getXRSpatialInputState()

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
let state = getXRSpatialInputState()

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

`RealSurfaceHit` includes both the tap point and the detected plane normal:

```swift
if let hit = pickRealSurfacePosition(
    rayOrigin: state.rayOriginWorld,
    rayDirection: state.rayDirectionWorld,
    filter: .wallOnly
) {
    let wallPoint = hit.worldPosition
    let wallNormal = hit.surfaceNormal

    Logger.log(message: "Wall point", vector: wallPoint)
    Logger.log(message: "Wall normal", vector: wallNormal)
}
```

Use `.wallOnly` when the workflow specifically needs an ARKit-classified wall. Use `.verticalAny` when doors, windows, or temporarily unknown vertical planes are acceptable.

### Choosing the right filter

| Goal | Filter to use |
|---|---|
| Always anchor to the floor, ignore furniture | `.floorOnly` |
| Always anchor to the table, ignore floor | `.tableOnly` |
| Whichever surface the user taps | `kinds: [.floor, .table]` + check `surfaceKind` |
| Any horizontal surface | `.horizontalAny` + check `surfaceKind` |
| Real wall normal for model alignment | `.wallOnly` + `surfaceNormal` |

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
let state = getXRSpatialInputState()

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

## Get Virtual Plane Hit Position

Virtual planes are purely mathematical — no ARKit scanning required. Use them when you want to cast a ray against a plane you define in code rather than one detected from the real environment. Common cases: snapping objects to the engine's ground level (`Y = 0`), placing content on a wall you defined, or constraining drag to an arbitrary surface.

Two functions are available, both returning a `PlanePickHit` with `worldPosition` and `distance`:

### Horizontal ground plane

`pickGroundPosition` casts against a horizontal plane at a given Y height. `planeY` defaults to `0`.

```swift
let state = getXRSpatialInputState()

if state.spatialTapActive {
    if let hit = pickGroundPosition(
        rayOrigin: state.rayOriginWorld,
        rayDirection: state.rayDirectionWorld,
        planeY: 0.0
    ) {
        Logger.log(message: "Virtual ground hit", vector: hit.worldPosition)
    }
}
```

Use `planeY` to match a raised or sunken surface — for example `planeY: 0.75` for a table-height virtual plane.

### Arbitrary virtual plane

`pickPlanePosition` casts against any plane defined by a world-space point and normal.

```swift
let state = getXRSpatialInputState()

if state.spatialTapActive {
    // Vertical plane facing +Z, passing through the origin
    if let hit = pickPlanePosition(
        rayOrigin: state.rayOriginWorld,
        rayDirection: state.rayDirectionWorld,
        planePoint: simd_float3(0, 0, 0),
        planeNormal: simd_float3(0, 0, 1)
    ) {
        Logger.log(message: "Virtual wall hit", vector: hit.worldPosition)
    }
}
```

`planePoint` can be any point that lies on the plane — the normal does not need to be pre-normalized.

### Choosing between virtual and real

| Goal | Function to use |
|---|---|
| Snap to engine ground (`Y = 0`) | `pickGroundPosition` |
| Snap to a raised virtual surface | `pickGroundPosition(planeY:)` |
| Cast against a wall or angled surface you defined | `pickPlanePosition` |
| Cast against an ARKit-detected physical surface | `pickRealSurfacePosition` |

Both `pickGroundPosition` and `pickPlanePosition` automatically account for scene root transforms, so the math stays correct even when the scene has been translated or rotated.

------------------------------------------------------------------------

## Spatial Helper Functions

Use these free functions for spatial manipulation. They all delegate to `SpatialManipulationSystem` internally so you never need to reference the shared singleton directly.

-   `processPinchTransformLifecycle(from:)`
    Recommended default. Handles translation + twist rotation lifecycle safely.

-   `applyPinchDragIfNeeded(from:entityId:sensitivity:)`
    Lower-level translation helper if you want full control.

-   `processAnchoredPinchDragLifecycle(from:entityId:sensitivity:dragPlane:positionTransform:)`
    Anchored drag for a single entity. Applies absolute displacement from gesture start, optionally constrained by world-axis displacement filtering.

-   `processAnchoredSceneDragLifecycle(from:sensitivity:)`
    Anchored drag for the entire scene root. Applies absolute displacement via `translateSceneTo`.

-   `endAnchoredSceneDrag()`
    Manually ends an in-progress anchored scene drag session.

-   `processAnchoredSceneRotateLifecycle(from:sensitivity:)`
    Anchored rotate for the entire scene root using two-hand pinch + twist.
    Applies absolute yaw via `rotateSceneToYaw`.

-   `endAnchoredSceneRotate()`
    Manually ends an in-progress anchored scene rotate session.

-   `processAnchoredSceneManipulationLifecycle(from:dragSensitivity:rotateSensitivity:)`
    Unified scene-root helper with drag/rotate arbitration to prevent gesture-fighting.

-   `endAnchoredSceneManipulation()`
    Ends any in-progress unified scene manipulation (drag, rotate, or pending classification).

-   `applyTwoHandZoomIfNeeded(from:entityId:sensitivity:)`
    Scales the picked entity (or its parent) using the two-hand spread/pinch gesture.

-   `applyTwoHandRotateIfNeeded(from:entityId:sensitivity:axisOverrideWorld:)`
    Rotates the picked entity (or its parent) using the two-hand twist gesture.

-   `endSpatialManipulation()`
    Ends the current pinch-transform manipulation session.

-   `resetSpatialManipulation()`
    Resets all manipulation session state (use when changing modes or reloading scenes).
