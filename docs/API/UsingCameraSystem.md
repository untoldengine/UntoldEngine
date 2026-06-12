# Using the Camera System

This document explains how to move, rotate, and control cameras using the APIs in `CameraSystem.swift`.

## Get the Game Camera

For gameplay, always use the game camera (not the editor/scene camera). Call `findGameCamera()` and make it active:

```swift
let camera = findGameCamera()
setCamera(.active(camera))
```

If no game camera exists, `findGameCamera()` creates one and sets it up with default values.

Configure global projection defaults at startup:

```swift
setCamera(.defaultFOV(70.0))
setCamera(.clipPlanes(near: 0.1, far: 1000.0))
```

## Translate (Move) the Camera

Use absolute or relative movement:

```swift
// Absolute position
moveCameraTo(entityId: camera, 0.0, 3.0, 7.0)

// Relative movement in camera local space
cameraMoveBy(entityId: camera, delta: simd_float3(0.0, 0.0, -1.0), space: .local)

// Relative movement in world space
cameraMoveBy(entityId: camera, delta: simd_float3(1.0, 0.0, 0.0), space: .world)
```

## Rotate the Camera

Use `rotateCamera` for pitch/yaw rotation, or `cameraLookAt` to aim at a target.

```swift
// Rotate by pitch/yaw (radians), with optional sensitivity
rotateCamera(entityId: camera, pitch: 0.02, yaw: 0.01, sensitivity: 1.0)

// Look-at orientation
cameraLookAt(
    entityId: camera,
    eye: simd_float3(0.0, 3.0, 7.0),
    target: simd_float3(0.0, 0.0, 0.0),
    up: simd_float3(0.0, 1.0, 0.0)
)
```

## Camera Follow

Follow a target entity with a fixed offset. You can optionally smooth the motion.

```swift
let target = findEntity(name: "player") ?? createEntity()
let offset = simd_float3(0.0, 2.0, 6.0)

// Instant follow
cameraFollow(entityId: camera, targetEntity: target, offset: offset)

// Smoothed follow
cameraFollow(entityId: camera, targetEntity: target, offset: offset, smoothFactor: 6.0, deltaTime: deltaTime)
```

### Dead-Zone Follow

`cameraFollowDeadZone` only moves the camera when the target leaves a box around it. This is useful for platformers and shoulder cameras.

```swift
let deadZone = simd_float3(1.0, 0.5, 1.0)
cameraFollowDeadZone(
    entityId: camera,
    targetEntity: target,
    offset: offset,
    deadZoneExtents: deadZone,
    smoothFactor: 6.0,
    deltaTime: deltaTime
)
```

## Camera Path Following

The camera path system moves the active camera through a sequence of waypoints with smooth interpolation.

### Start a Path

```swift
let waypoints = [
    CameraWaypoint(
        position: simd_float3(0, 5, 10),
        rotation: simd_quatf(angle: 0, axis: simd_float3(0, 1, 0)),
        segmentDuration: 2.0
    ),
    CameraWaypoint(
        position: simd_float3(10, 5, 10),
        rotation: simd_quatf(angle: Float.pi / 4, axis: simd_float3(0, 1, 0)),
        segmentDuration: 2.0
    )
]

startCameraPath(waypoints: waypoints, mode: .once)
```

You can also build waypoints that look at a target:

```swift
let waypoint = CameraWaypoint(
    position: simd_float3(0, 5, 10),
    lookAt: simd_float3(0, 0, 0),
    up: simd_float3(0, 1, 0),
    segmentDuration: 2.0
)
```

### Update Every Frame

Call `updateCameraPath(deltaTime:)` from your main update loop:

```swift
func update(deltaTime: Float) {
    updateCameraPath(deltaTime: deltaTime)
}
```

### Looping and Completion

```swift
startCameraPath(waypoints: waypoints, mode: .loop)

let settings = CameraPathSettings(startImmediately: true) {
    print("Camera path completed")
}
startCameraPath(waypoints: waypoints, mode: .once, settings: settings)
```

## Notes

- `startCameraPath` and `updateCameraPath` operate on the active camera set with `setCamera(.active(...))`.
- `segmentDuration` is the time to move from the current waypoint to the next.
- For gameplay, always acquire the camera with `findGameCamera()` and set it active before path playback or follow logic.
