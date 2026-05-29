
//
//  CameraSystem.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

public final class CameraSystem: @unchecked Sendable {
    /// Thread-safe shared instance
    public static let shared: CameraSystem = .init()

    private let activeCameraLock = NSLock()
    private let pathStateLock = NSLock()

    private var _activeCamera: EntityID?
    private var _pathState: CameraPathState?

    private init() {}

    public var activeCamera: EntityID? {
        get {
            activeCameraLock.lock()
            defer { activeCameraLock.unlock() }
            return _activeCamera
        }
        set {
            activeCameraLock.lock()
            _activeCamera = newValue
            activeCameraLock.unlock()
        }
    }

    /// Camera path state (internal access for path functions)
    fileprivate var pathState: CameraPathState? {
        get {
            pathStateLock.lock()
            defer { pathStateLock.unlock() }
            return _pathState
        }
        set {
            pathStateLock.lock()
            _pathState = newValue
            pathStateLock.unlock()
        }
    }
}

public enum CameraMoveSpace {
    case local
    case world
}

public func findGameCamera() -> EntityID {
    for entityId in scene.getAllEntities() {
        if hasComponent(entityId: entityId, componentType: CameraComponent.self), !hasComponent(entityId: entityId, componentType: SceneCameraComponent.self) {
            return entityId
        }
    }

    // if scene camera was not found, then create one

    let gameCamera = createEntity()
    createGameCamera(entityId: gameCamera)
    return gameCamera
}

public func createGameCamera(entityId: EntityID) {
    setEntityName(entityId: entityId, name: "Game Camera")
    registerComponent(entityId: entityId, componentType: CameraComponent.self)

    cameraLookAt(entityId: entityId,
                 eye: cameraDefaultEye, target: cameraTargetDefault,
                 up: cameraUpDefault)
}

public func resetCameraToDefaultTransform(entityId: EntityID) {
    guard scene.get(component: CameraComponent.self, for: entityId) != nil else {
        handleError(.noActiveCamera)
        return
    }
    cameraLookAt(entityId: entityId,
                 eye: cameraDefaultEye, target: cameraTargetDefault,
                 up: cameraUpDefault)
}

public func moveCameraTo(entityId: EntityID, _ translationX: Float, _ translationY: Float, _ translationZ: Float) {
    translateTo(entityId: entityId, position: simd_float3(translationX, translationY, translationZ))
}

public func moveCameraBy(entityId: EntityID, delU: Float, delV: Float, delN: Float) {
    translateBy(entityId: entityId, position: simd_float3(delU, delV, delN))
}

public func cameraMoveBy(entityId: EntityID, delta: simd_float3, space: CameraMoveSpace = .local) {
    guard scene.get(component: CameraComponent.self, for: entityId) != nil else {
        return
    }

    switch space {
    case .local:
        moveCameraBy(entityId: entityId, delU: delta.x, delV: delta.y, delN: delta.z)
    case .world:
        guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
            return
        }
        applyCameraLocalTransform(entityId: entityId, position: localTransformComponent.position + delta)
    }
}

public func updateCameraViewMatrix(entityId: EntityID) {
    guard let cameraComponent = scene.get(component: CameraComponent.self, for: entityId) else {
        return
    }

    // if you are new to this: see this: http://www.songho.ca/opengl/gl_anglestoaxes.html

    cameraComponent.rotation = simd_normalize(cameraComponent.rotation)

    cameraComponent.xAxis = rightDirectionVector(from: cameraComponent.rotation)
    cameraComponent.yAxis = upDirectionVector(from: cameraComponent.rotation)
    cameraComponent.zAxis = forwardDirectionVector(from: cameraComponent.rotation)

    cameraComponent.viewSpace = getMatrix4x4FromQuaternion(q: cameraComponent.rotation)

    cameraComponent.viewSpace.columns.3 = simd_float4(
        -simd_dot(cameraComponent.xAxis, cameraComponent.localPosition),
        -simd_dot(cameraComponent.yAxis, cameraComponent.localPosition),
        -simd_dot(cameraComponent.zAxis, cameraComponent.localPosition),
        1.0
    )

    cameraComponent.localOrientation = cameraComponent.zAxis
}

private func applyCameraLocalTransform(entityId: EntityID, position: simd_float3? = nil, rotation: simd_quatf? = nil) {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }

    if let position {
        localTransformComponent.position = position
        localTransformComponent.transformDirty = true
        anyTransformDirty = true
    }

    if let rotation {
        localTransformComponent.rotation = simd_normalize(rotation)
        localTransformComponent.transformDirty = true
        anyTransformDirty = true
    }

    guard let cameraComponent = scene.get(component: CameraComponent.self, for: entityId) else {
        return
    }

    cameraComponent.localPosition = localTransformComponent.position
    cameraComponent.rotation = localTransformComponent.rotation
    updateCameraViewMatrix(entityId: entityId)
}

public func orbitAround(entityId: EntityID, uPosition: simd_float2) {
    guard let cameraComponent = scene.get(component: CameraComponent.self, for: entityId) else {
        return
    }

    let target: simd_float3 = cameraComponent.localPosition - cameraComponent.orbitTarget
    let length: Float = simd_length(target)
    var direction: simd_float3 = simd_normalize(target)

    // rot about yaw first — always anchor to world Y so the up axis
    // never drifts across frames and causes roll accumulation.
    let rotationX: simd_quatf = getRotationQuaternion(
        axis: simd_float3(0.0, 1.0, 0.0), angle: uPosition.x
    )
    direction = rotateVectorUsingQuaternion(q: rotationX, v: direction)
    var newUpAxis = simd_float3(0.0, 1.0, 0.0)

    direction = simd_normalize(direction)
    newUpAxis = simd_normalize(newUpAxis)

    // now compute the right axis
    var rightAxis: simd_float3 = simd_cross(newUpAxis, direction)
    rightAxis = simd_normalize(rightAxis)

    // then rotate about right axis
    let rotationY: simd_quatf = getRotationQuaternion(axis: rightAxis, angle: uPosition.y)
    direction = rotateVectorUsingQuaternion(q: rotationY, v: direction)
    newUpAxis = rotateVectorUsingQuaternion(q: rotationY, v: newUpAxis)

    direction = simd_normalize(direction)
    newUpAxis = simd_normalize(newUpAxis)

    let newPosition = cameraComponent.orbitTarget + direction * length

    // compute the matrix
    cameraLookAt(entityId: entityId, eye: newPosition, target: cameraComponent.orbitTarget, up: newUpAxis)
}

/// Returns a right-handed matrix which looks from a point (the "eye") at a target point, given the up vector.
public func cameraLookAt(entityId: EntityID, eye: simd_float3, target: simd_float3, up: simd_float3) {
    guard let cameraComponent = scene.get(component: CameraComponent.self, for: entityId) else {
        return
    }

    cameraComponent.eye = eye
    cameraComponent.up = up
    cameraComponent.target = target

    let q0 = quaternion_lookAt(eye: eye, target: target, up: up)
    let q1 = simd_conjugate(q0)
    applyCameraLocalTransform(entityId: entityId, position: eye, rotation: simd_normalize(q1))
}

public func getCameraEye(entityId: EntityID) -> simd_float3 {
    guard let cameraComponent = scene.get(component: CameraComponent.self, for: entityId) else {
        handleError(.noActiveCamera)
        return .zero
    }

    return cameraComponent.eye
}

public func getCameraUp(entityId: EntityID) -> simd_float3 {
    guard let cameraComponent = scene.get(component: CameraComponent.self, for: entityId) else {
        handleError(.noActiveCamera)
        return .zero
    }

    return cameraComponent.up
}

public func getCameraTarget(entityId: EntityID) -> simd_float3 {
    guard let cameraComponent = scene.get(component: CameraComponent.self, for: entityId) else {
        handleError(.noActiveCamera)
        return .zero
    }

    return cameraComponent.target
}

public func cameraLookAboutAxis(entityId: EntityID, uDelta: simd_float2) {
    guard let cameraComponent = scene.get(component: CameraComponent.self, for: entityId) else {
        return
    }

    let rotationAngleX: Float = uDelta.x * 0.01
    let rotationAngleY: Float = uDelta.y * 0.01

    let rotationX: simd_quatf = getRotationQuaternion(
        axis: simd_float3(0.0, 1.0, 0.0), angle: rotationAngleX
    )
    let rotationY: simd_quatf = getRotationQuaternion(
        axis: simd_float3(1.0, 0.0, 0.0), angle: rotationAngleY
    )

    let newRotation: simd_quatf = simd_mul(rotationY, cameraComponent.rotation)

    applyCameraLocalTransform(entityId: entityId, rotation: simd_mul(newRotation, rotationX))
}

public func moveCameraAlongAxis(entityId: EntityID, uDelta: simd_float3) {
    guard scene.get(component: CameraComponent.self, for: entityId) != nil else {
        return
    }
    moveCameraBy(entityId: entityId, delU: uDelta.x * -1.0, delV: uDelta.y, delN: uDelta.z * -1.0)
}

public func setOrbitOffset(entityId: EntityID, uTargetOffset: Float) {
    guard let cameraComponent = scene.get(component: CameraComponent.self, for: entityId) else {
        return
    }

    let direction: simd_float3 = -1.0 * cameraComponent.localOrientation

    cameraComponent.orbitTarget = cameraComponent.localPosition + direction * uTargetOffset
}

public func orbitCameraAround(entityId: EntityID, uDelta: simd_float2) {
    var delta: simd_float2 = uDelta
    delta.x *= -0.01
    delta.y *= -0.01

    orbitAround(entityId: entityId, uPosition: delta)
}

public func getCameraPosition(entityId: EntityID) -> simd_float3 {
    if let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) {
        return localTransformComponent.position
    }

    guard let cameraComponent = scene.get(component: CameraComponent.self, for: entityId) else {
        return .zero
    }

    return cameraComponent.localPosition
}

public func moveCameraWithInput(entityId: EntityID, input: (w: Bool, a: Bool, s: Bool, d: Bool, q: Bool, e: Bool), speed: Float, deltaTime: Float) {
    guard scene.get(component: CameraComponent.self, for: entityId) != nil else {
        return
    }

    if InputSystem.shared.cameraControlMode == .orbiting {
        return
    }

    // calculate movement deltas based on input
    var delU: Float = 0.0 // movement along the right axis (xAxis)
    var delN: Float = 0.0 // movement along the forward axis (zAxis)
    var delV: Float = 0.0 // movement along the up axis (yAxis)

    if input.w {
        delN -= speed * deltaTime // Move forward
    }

    if input.s {
        delN += speed * deltaTime // Move backward
    }

    if input.a {
        delU -= speed * deltaTime // Move left
    }

    if input.d {
        delU += speed * deltaTime // Move right
    }

    if input.q {
        delV += speed * deltaTime // Move up
    }

    if input.e {
        delV -= speed * deltaTime // Move down
    }

    // Translate camera position by deltas
    moveCameraBy(entityId: entityId, delU: delU, delV: delV, delN: delN)
}

/// Function to rotate the camera based on mouse movement
public func rotateCamera(entityId: EntityID, pitch: Float, yaw: Float, sensitivity: Float = 1.0) {
    guard let cameraComponent = scene.get(component: CameraComponent.self, for: entityId) else {
        return
    }
    // Calculate rotation angles (scaled by sensitivity)
    let rotationAngleX = yaw * sensitivity
    let rotationAngleY = pitch * sensitivity

    let rotationX: simd_quatf = getRotationQuaternion(
        axis: simd_float3(0.0, 1.0, 0.0), angle: rotationAngleX
    )
    let rotationY: simd_quatf = getRotationQuaternion(
        axis: simd_float3(1.0, 0.0, 0.0), angle: rotationAngleY
    )

    let newRotation: simd_quatf = simd_mul(rotationY, cameraComponent.rotation)

    applyCameraLocalTransform(entityId: entityId, rotation: simd_mul(newRotation, rotationX))
}

public func cameraFollow(entityId: EntityID,
                         targetEntity: EntityID,
                         offset: simd_float3,
                         smoothFactor: Float = 0.0,
                         deltaTime: Float = 0.0)
{
    guard scene.get(component: CameraComponent.self, for: entityId) != nil else {
        return
    }
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        return
    }
    guard let targetTransform = scene.get(component: LocalTransformComponent.self, for: targetEntity) else {
        return
    }

    let desiredPosition = targetTransform.position + offset
    let currentPosition = localTransformComponent.position

    if smoothFactor > 0, deltaTime > 0 {
        let t = min(smoothFactor * deltaTime, 1.0)
        applyCameraLocalTransform(entityId: entityId, position: currentPosition + (desiredPosition - currentPosition) * t)
    } else {
        applyCameraLocalTransform(entityId: entityId, position: desiredPosition)
    }
}

public func cameraFollowLocal(entityId: EntityID,
                              targetEntity: EntityID,
                              localOffset: simd_float3,
                              smoothFactor: Float = 0.0,
                              deltaTime: Float = 0.0)
{
    guard scene.get(component: CameraComponent.self, for: entityId) != nil else {
        return
    }
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        return
    }
    guard let targetTransform = scene.get(component: LocalTransformComponent.self, for: targetEntity) else {
        return
    }

    // Rotate local offset by target rotation to world space
    let rotationMatrix = transformQuaternionToMatrix3x3(q: targetTransform.rotation)
    let rotatedOffset = rotationMatrix * localOffset
    let desiredPosition = targetTransform.position + rotatedOffset
    let currentPosition = localTransformComponent.position

    if smoothFactor > 0, deltaTime > 0 {
        let t = min(smoothFactor * deltaTime, 1.0)
        applyCameraLocalTransform(entityId: entityId, position: currentPosition + (desiredPosition - currentPosition) * t)
    } else {
        applyCameraLocalTransform(entityId: entityId, position: desiredPosition)
    }
}

public func cameraFollowDeadZone(entityId: EntityID,
                                 targetEntity: EntityID,
                                 offset: simd_float3 = simd_float3(0, 0, 0),
                                 deadZoneExtents: simd_float3,
                                 smoothFactor: Float = 0.0,
                                 deltaTime: Float = 0.0)
{
    guard let cameraComponent = scene.get(component: CameraComponent.self, for: entityId) else {
        return
    }
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        return
    }
    guard let targetTransform = scene.get(component: LocalTransformComponent.self, for: targetEntity) else {
        return
    }

    let cameraPosition = localTransformComponent.position
    let targetPosition = targetTransform.position + offset
    let toTarget = targetPosition - cameraPosition

    let xAxis = rightDirectionVector(from: cameraComponent.rotation)
    let yAxis = upDirectionVector(from: cameraComponent.rotation)
    let zAxis = forwardDirectionVector(from: cameraComponent.rotation)

    let localTarget = simd_float3(
        simd_dot(toTarget, xAxis),
        simd_dot(toTarget, yAxis),
        simd_dot(toTarget, zAxis)
    )

    let extents = simd_abs(deadZoneExtents)
    var correctionLocal = simd_float3(0, 0, 0)

    if localTarget.x > extents.x {
        correctionLocal.x = localTarget.x - extents.x
    } else if localTarget.x < -extents.x {
        correctionLocal.x = localTarget.x + extents.x
    }

    if localTarget.y > extents.y {
        correctionLocal.y = localTarget.y - extents.y
    } else if localTarget.y < -extents.y {
        correctionLocal.y = localTarget.y + extents.y
    }

    if localTarget.z > extents.z {
        correctionLocal.z = localTarget.z - extents.z
    } else if localTarget.z < -extents.z {
        correctionLocal.z = localTarget.z + extents.z
    }

    if length(correctionLocal) <= 0.0001 {
        return
    }

    let correctionWorld = xAxis * correctionLocal.x + yAxis * correctionLocal.y + zAxis * correctionLocal.z
    let desiredPosition = cameraPosition + correctionWorld

    if smoothFactor > 0, deltaTime > 0 {
        let t = min(smoothFactor * deltaTime, 1.0)
        applyCameraLocalTransform(entityId: entityId, position: cameraPosition + (desiredPosition - cameraPosition) * t)
    } else {
        applyCameraLocalTransform(entityId: entityId, position: desiredPosition)
    }
}

public func cameraOrbitTarget(entityId: EntityID,
                              centerEntity: EntityID,
                              radius: Float,
                              angularSpeed: Float,
                              deltaTime: Float,
                              offsetY: Float = 0.0)
{
    guard let cameraComponent = scene.get(component: CameraComponent.self, for: entityId) else {
        return
    }
    guard let centerTransform = scene.get(component: LocalTransformComponent.self, for: centerEntity) else {
        return
    }

    // Compute current angle in XZ plane relative to center
    let currentPos = cameraComponent.localPosition
    let center = centerTransform.position + simd_float3(0, offsetY, 0)
    let rel = currentPos - center
    var angle = atan2(rel.z, rel.x)

    // Advance angle
    angle += angularSpeed * deltaTime

    // New position on orbit
    let newX = cos(angle) * radius
    let newZ = sin(angle) * radius
    let newPosition = simd_float3(newX, center.y, newZ) + center

    // Aim at the center entity
    cameraLookAt(entityId: entityId,
                 eye: newPosition,
                 target: centerTransform.position,
                 up: simd_float3(0, 1, 0))
}

// MARK: - Camera Path Types

/// Represents a single waypoint in a camera path with position, rotation, and duration to next waypoint
public struct CameraWaypoint {
    /// World position of the camera at this waypoint
    public var position: simd_float3
    /// Rotation of the camera at this waypoint (quaternion)
    public var rotation: simd_quatf
    /// Duration in seconds to travel from this waypoint to the next
    public var segmentDuration: Float

    public init(position: simd_float3, rotation: simd_quatf, segmentDuration: Float) {
        self.position = position
        self.rotation = rotation
        self.segmentDuration = segmentDuration
    }

    /// Convenience initializer using look-at direction
    public init(position: simd_float3, lookAt: simd_float3, up: simd_float3 = simd_float3(0, 1, 0), segmentDuration: Float) {
        self.position = position
        rotation = simd_normalize(simd_conjugate(quaternion_lookAt(eye: position, target: lookAt, up: up)))
        self.segmentDuration = segmentDuration
    }
}

/// Defines how the camera path should behave when reaching the end
public enum CameraPathMode {
    /// Play once and stop at the last waypoint
    case once
    /// Loop back to the first waypoint and repeat
    case loop
}

/// Settings for camera path playback
public struct CameraPathSettings: Sendable {
    /// Whether to start playback immediately upon calling startCameraPath
    public var startImmediately: Bool
    /// Optional callback invoked when path completes (not called in loop mode)
    public var onComplete: (@Sendable () -> Void)?

    public init(startImmediately: Bool = true, onComplete: (@Sendable () -> Void)? = nil) {
        self.startImmediately = startImmediately
        self.onComplete = onComplete
    }

    public static let `default` = CameraPathSettings()
}

/// Internal state for active camera path playback
struct CameraPathState {
    var waypoints: [CameraWaypoint]
    var mode: CameraPathMode
    var settings: CameraPathSettings

    var currentSegmentIndex: Int = 0
    var segmentT: Float = 0.0 // Normalized time [0, 1] within current segment
    var totalDuration: Float = 0.0
    var isActive: Bool = true

    init(waypoints: [CameraWaypoint], mode: CameraPathMode, settings: CameraPathSettings) {
        self.waypoints = waypoints
        self.mode = mode
        self.settings = settings
        totalDuration = waypoints.reduce(0) { $0 + $1.segmentDuration }
    }

    /// Returns the current and next waypoint for interpolation
    func getCurrentSegment() -> (current: CameraWaypoint, next: CameraWaypoint)? {
        guard currentSegmentIndex < waypoints.count else { return nil }

        let current = waypoints[currentSegmentIndex]

        // Determine next index based on mode
        let nextIndex: Int
        if mode == .loop {
            nextIndex = (currentSegmentIndex + 1) % waypoints.count
        } else {
            // In .once mode, check if there's a next waypoint
            guard currentSegmentIndex + 1 < waypoints.count else { return nil }
            nextIndex = currentSegmentIndex + 1
        }

        let next = waypoints[nextIndex]
        return (current, next)
    }
}

// MARK: - Camera Path Following API

/*
 Camera Path Following System

 This API enables the active camera to follow a deterministic path through a sequence of waypoints,
 interpolating both position and rotation smoothly over time. Designed for repeatable benchmark
 camera paths and cinematic sequences.

 ## Basic Usage

 ```swift
 // Define waypoints with explicit rotations
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
     ),
     CameraWaypoint(
         position: simd_float3(10, 5, 0),
         rotation: simd_quatf(angle: Float.pi / 2, axis: simd_float3(0, 1, 0)),
         segmentDuration: 2.0
     )
 ]

 // Start path in once mode (stops at end)
 startCameraPath(waypoints: waypoints, mode: .once)

 // Update every frame in your game loop
 updateCameraPath(deltaTime: deltaTime)
 ```

 ## Look-At Waypoints

 You can use the convenience initializer to create waypoints that look at a target:

 ```swift
 let waypoint = CameraWaypoint(
     position: simd_float3(0, 5, 10),
     lookAt: simd_float3(0, 0, 0),  // Look at origin
     up: simd_float3(0, 1, 0),      // World up
     segmentDuration: 2.0
 )
 ```

 ## Looping Paths

 ```swift
 // Path will loop continuously from last waypoint back to first
 startCameraPath(waypoints: waypoints, mode: .loop)
 ```

 ## Completion Callbacks

 ```swift
 let settings = CameraPathSettings(startImmediately: true) {
     print("Camera path completed!")
 }
 startCameraPath(waypoints: waypoints, mode: .once, settings: settings)
 ```

 ## Control Methods

 ```swift
 // Check if path is active
 if isCameraPathActive() {
     // Stop the path
     stopCameraPath()
 }
 ```

 */

/// Starts the active camera following a predefined path of waypoints
/// - Parameters:
///   - waypoints: Ordered array of waypoints defining the camera path
///   - mode: Playback mode (.once or .loop)
///   - settings: Additional settings for path playback
public func startCameraPath(waypoints: [CameraWaypoint], mode: CameraPathMode = .once, settings: CameraPathSettings = .default) {
    // Validate input
    guard !waypoints.isEmpty else {
        handleError(.missingCameraWaypoints)
        return
    }

    guard CameraSystem.shared.activeCamera != nil else {
        handleError(.noActiveCamera)
        return
    }

    // Handle single waypoint case - just snap to it
    if waypoints.count == 1 {
        let waypoint = waypoints[0]
        if let entityId = CameraSystem.shared.activeCamera {
            applyCameraTransform(entityId: entityId, position: waypoint.position, rotation: waypoint.rotation)
        }
        settings.onComplete?()
        return
    }

    // Initialize path state
    var state = CameraPathState(waypoints: waypoints, mode: mode, settings: settings)
    state.isActive = settings.startImmediately
    CameraSystem.shared.pathState = state

    // Apply initial position if starting immediately
    if settings.startImmediately, let entityId = CameraSystem.shared.activeCamera {
        let firstWaypoint = waypoints[0]
        applyCameraTransform(entityId: entityId, position: firstWaypoint.position, rotation: firstWaypoint.rotation)
    }
}

/// Stops any active camera path playback
public func stopCameraPath() {
    CameraSystem.shared.pathState = nil
}

/// Returns true if a camera path is currently active
public func isCameraPathActive() -> Bool {
    CameraSystem.shared.pathState?.isActive ?? false
}

/// Updates the camera path state and applies interpolated transform to the active camera
/// - Parameter deltaTime: Time elapsed since last update in seconds
/// - Note: This should be called every frame from the main update loop
public func updateCameraPath(deltaTime: Float) {
    guard var state = CameraSystem.shared.pathState, state.isActive else { return }
    guard let entityId = CameraSystem.shared.activeCamera else {
        handleError(.noActiveCamera)
        CameraSystem.shared.pathState = nil
        return
    }

    // Get current segment
    guard let segment = state.getCurrentSegment() else {
        // No valid segment - we've reached the end in .once mode
        // Snap to final waypoint and stop
        if state.mode == .once, !state.waypoints.isEmpty {
            let finalWaypoint = state.waypoints[state.waypoints.count - 1]
            applyCameraTransform(entityId: entityId, position: finalWaypoint.position, rotation: finalWaypoint.rotation)
            state.isActive = false
            CameraSystem.shared.pathState = state
            state.settings.onComplete?()
        } else {
            CameraSystem.shared.pathState = nil
        }
        return
    }

    let currentWaypoint = segment.current
    let nextWaypoint = segment.next

    // Validate segment duration
    guard currentWaypoint.segmentDuration > 0 else {
        // Invalid duration, advance to next segment
        state.currentSegmentIndex += 1
        state.segmentT = 0.0
        CameraSystem.shared.pathState = state
        return
    }

    // Advance time within segment
    state.segmentT += deltaTime / currentWaypoint.segmentDuration

    // Check if we've completed the current segment
    if state.segmentT >= 1.0 {
        // Handle segment overflow by carrying excess time to next segment
        let overflow = state.segmentT - 1.0
        state.segmentT = 0.0
        state.currentSegmentIndex += 1

        // In loop mode, wrap around to start
        if state.mode == .loop, state.currentSegmentIndex >= state.waypoints.count {
            state.currentSegmentIndex = 0
        }
        // In once mode, getCurrentSegment() will return nil on next update when we reach the end

        // Store state and recursively handle the overflow time to ensure smooth transition
        // This prevents flickering when transitioning between segments
        CameraSystem.shared.pathState = state
        if overflow > 0, state.mode == .loop {
            // Recursively update with remaining time to smooth the transition
            updateCameraPath(deltaTime: overflow * currentWaypoint.segmentDuration)
            return
        }
    }

    // Clamp t to [0, 1] for safety
    let t = min(max(state.segmentT, 0.0), 1.0)

    // Interpolate position (linear)
    let position = currentWaypoint.position + (nextWaypoint.position - currentWaypoint.position) * t

    // Interpolate rotation (slerp for smooth rotation)
    let rotation = simd_slerp(currentWaypoint.rotation, nextWaypoint.rotation, t)

    // Apply transform to camera
    applyCameraTransform(entityId: entityId, position: position, rotation: rotation)

    // Store updated state
    CameraSystem.shared.pathState = state
}

/// Applies position and rotation to a camera entity
private func applyCameraTransform(entityId: EntityID, position: simd_float3, rotation: simd_quatf) {
    applyCameraLocalTransform(entityId: entityId, position: position, rotation: simd_normalize(rotation))
}
