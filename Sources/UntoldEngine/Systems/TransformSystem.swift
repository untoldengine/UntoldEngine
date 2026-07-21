
//
//  TransformSystem.swift
//  Untold Engine
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

private func syncCameraTransformIfNeeded(entityId: EntityID, localTransformComponent: LocalTransformComponent) {
    guard let cameraComponent = scene.get(component: CameraComponent.self, for: entityId) else {
        return
    }

    cameraComponent.localPosition = localTransformComponent.position
    cameraComponent.rotation = localTransformComponent.rotation
    updateCameraViewMatrix(entityId: entityId)
}

func syncWorldTransformAndMarkOctreeDirty(entityId: EntityID) {
    resetLightPortalAreaLightCache()

    // Keep world transforms and octree bounds current for the whole hierarchy.
    // Imported multi-mesh assets usually have renderable children under a non-render root.
    guard scene.get(component: ScenegraphComponent.self, for: entityId) != nil else {
        OctreeSystem.shared.markDirty(entityId)
        return
    }

    var queue: [EntityID] = [entityId]
    var index = 0
    while index < queue.count {
        let current = queue[index]
        index += 1

        if scene.get(component: LocalTransformComponent.self, for: current) != nil,
           scene.get(component: WorldTransformComponent.self, for: current) != nil,
           scene.get(component: ScenegraphComponent.self, for: current) != nil
        {
            updateTransformSystem(entityId: current)
        }

        OctreeSystem.shared.markDirty(current)
        queue.append(contentsOf: getEntityChildren(parentId: current))
    }
}

public func getLocalPosition(entityId: EntityID) -> simd_float3 {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return simd_float3(0.0, 0.0, 0.0)
    }

    let x: Float = localTransformComponent.position.x
    let y: Float = localTransformComponent.position.y
    let z: Float = localTransformComponent.position.z

    return simd_float3(x, y, z)
}

/// Retrives world position for entity id
public func getPosition(entityId: EntityID) -> simd_float3 {
    guard let worldTransformComponent = scene.get(component: WorldTransformComponent.self, for: entityId) else {
        handleError(.noWorldTransformComponent, entityId)
        return simd_float3(0.0, 0.0, 0.0)
    }

    let x: Float = worldTransformComponent.space.columns.3.x
    let y: Float = worldTransformComponent.space.columns.3.y
    let z: Float = worldTransformComponent.space.columns.3.z

    return simd_float3(x, y, z)
}

public func getLocalOrientation(entityId: EntityID) -> simd_float3x3 {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return simd_float3x3()
    }

    return transformQuaternionToMatrix3x3(q: localTransformComponent.rotation)
}

/// Retrieves world orientation for entity id
public func getOrientation(entityId: EntityID) -> simd_float3x3 {
    guard let worldTransformComponent = scene.get(component: WorldTransformComponent.self, for: entityId) else {
        handleError(.noWorldTransformComponent, entityId)
        return simd_float3x3()
    }

    return matrix3x3_upper_left(worldTransformComponent.space)
}

public func getLocalOrientationEuler(entityId: EntityID) -> (pitch: Float, yaw: Float, roll: Float) {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return (0.0, 0.0, 0.0)
    }

    let m = transformQuaternionToMatrix3x3(q: localTransformComponent.rotation)
    let q = transformMatrix3nToQuaternion(m: m)

    let euler = transformQuaternionToEulerAngles(q: q)

    return (euler.pitch, euler.yaw, euler.roll)
}

public func getOrientationEuler(entityId: EntityID) -> (pitch: Float, yaw: Float, roll: Float) {
    guard let worldTransformComponent = scene.get(component: WorldTransformComponent.self, for: entityId) else {
        handleError(.noWorldTransformComponent, entityId)
        return (0.0, 0.0, 0.0)
    }

    let m = matrix3x3_upper_left(worldTransformComponent.space)
    let q = transformMatrix3nToQuaternion(m: m)

    let euler = transformQuaternionToEulerAngles(q: q)

    return (euler.pitch, euler.yaw, euler.roll)
}

public func getForwardAxisVector(entityId: EntityID) -> simd_float3 {
    // get the transform for the entity
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return simd_float3(0.0, 0.0, 0.0)
    }

    let m: simd_float3x3 = transformQuaternionToMatrix3x3(q: localTransformComponent.rotation)

    var forward = simd_float3(
        m.columns.2.x,
        m.columns.2.y,
        m.columns.2.z
    )

    forward = normalize(forward)

    return forward
}

public func getRightAxisVector(entityId: EntityID) -> simd_float3 {
    // get the transform for the entity
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return simd_float3(0.0, 0.0, 0.0)
    }

    let m: simd_float3x3 = transformQuaternionToMatrix3x3(q: localTransformComponent.rotation)

    var right = simd_float3(
        m.columns.0.x,
        m.columns.0.y,
        m.columns.0.z
    )

    right = normalize(right)

    return right
}

public func getUpAxisVector(entityId: EntityID) -> simd_float3 {
    // get the transform for the entity
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return simd_float3(0.0, 0.0, 0.0)
    }
    let m: simd_float3x3 = transformQuaternionToMatrix3x3(q: localTransformComponent.rotation)

    var up = simd_float3(
        m.columns.1.x,
        m.columns.1.y,
        m.columns.1.z
    )

    up = normalize(up)

    return up
}

public func translateTo(entityId: EntityID, position: simd_float3) {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }

    guard isValid(position) else {
        handleError(.valueisNaN, "Position", entityId)
        return
    }

    localTransformComponent.position = position
    syncCameraTransformIfNeeded(entityId: entityId, localTransformComponent: localTransformComponent)
    syncWorldTransformAndMarkOctreeDirty(entityId: entityId)
}

public func translateBy(entityId: EntityID, position: simd_float3) {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }

    guard isValid(position) else {
        handleError(.valueisNaN, "Position", entityId)
        return
    }

    if scene.get(component: CameraComponent.self, for: entityId) != nil {
        let xAxis = rightDirectionVector(from: localTransformComponent.rotation)
        let yAxis = upDirectionVector(from: localTransformComponent.rotation)
        let zAxis = forwardDirectionVector(from: localTransformComponent.rotation)

        localTransformComponent.position += position.x * xAxis + position.y * yAxis + position.z * zAxis
        syncCameraTransformIfNeeded(entityId: entityId, localTransformComponent: localTransformComponent)
        syncWorldTransformAndMarkOctreeDirty(entityId: entityId)
        return
    }

    localTransformComponent.position.x += position.x
    localTransformComponent.position.y += position.y
    localTransformComponent.position.z += position.z
    syncWorldTransformAndMarkOctreeDirty(entityId: entityId)
}

public func rotateTo(entityId: EntityID, angle: Float, axis: simd_float3) {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }

    guard isValid(axis) else {
        handleError(.valueisNaN, "Axis", entityId)
        return
    }

    guard isValid(angle) else {
        handleError(.valueisNaN, "Angle", entityId)
        return
    }

    let q = simd_normalize(simd_quatf(angle: degreesToRadians(degrees: angle), axis: axis))
    let m: simd_float3x3 = transformQuaternionToMatrix3x3(q: q)

    var n: simd_float3x3 = .init(diagonal: simd_float3(repeating: 1.0))

    n.columns.0 = m.columns.0
    n.columns.1 = m.columns.1
    n.columns.2 = m.columns.2

    localTransformComponent.rotation = transformMatrix3nToQuaternion(m: n)
    syncCameraTransformIfNeeded(entityId: entityId, localTransformComponent: localTransformComponent)
    syncWorldTransformAndMarkOctreeDirty(entityId: entityId)
}

/// Orient an entity so its forward axis points at a target position.
/// - Parameters:
///   - entityId: entity to rotate
///   - targetPosition: world position to face
///   - up: world up vector (defaults to +Y)
///   - eyePositionOverride: optional eye position if the entity position is being animated externally
public func lookAt(entityId: EntityID,
                   targetPosition: simd_float3,
                   up: simd_float3 = simd_float3(0, 1, 0),
                   eyePositionOverride: simd_float3? = nil)
{
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }

    let eye = eyePositionOverride ?? getPosition(entityId: entityId)
    let forward = normalize(targetPosition - eye)
    let right = normalize(simd_cross(up, forward))
    let trueUp = normalize(simd_cross(forward, right))

    var rotationMatrix = simd_float3x3(columns: (right, trueUp, forward))
    // Orthonormalize with a simple Gram-Schmidt step to avoid drift
    let r = normalize(rotationMatrix.columns.0)
    let u = normalize(rotationMatrix.columns.1 - simd_dot(rotationMatrix.columns.1, r) * r)
    let f = normalize(simd_cross(r, u))
    rotationMatrix = simd_float3x3(columns: (r, u, f))

    localTransformComponent.rotation = transformMatrix3nToQuaternion(m: rotationMatrix)
    syncCameraTransformIfNeeded(entityId: entityId, localTransformComponent: localTransformComponent)
    syncWorldTransformAndMarkOctreeDirty(entityId: entityId)
}

public func rotateBy(entityId: EntityID, angle: Float, axis: simd_float3) {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }

    guard isValid(axis) else {
        handleError(.valueisNaN, "Axis", entityId)
        return
    }

    guard isValid(angle) else {
        handleError(.valueisNaN, "Angle", entityId)
        return
    }

    // previous matrix
    let previusM: simd_float3x3 = transformQuaternionToMatrix3x3(q: localTransformComponent.rotation)

    // transform to quat
    let pq: simd_quatf = transformMatrix3nToQuaternion(m: previusM)

    // new desired rotation
    let q = simd_quatf.init(angle: degreesToRadians(degrees: angle), axis: axis)

    // new rotation
    let newQ = simd_normalize(simd_mul(q, pq))

    localTransformComponent.rotation = newQ
    syncCameraTransformIfNeeded(entityId: entityId, localTransformComponent: localTransformComponent)
    syncWorldTransformAndMarkOctreeDirty(entityId: entityId)
}

public func rotateTo(entityId: EntityID, rotation: simd_float4x4) {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }

    let rotUpperLeft = matrix3x3_upper_left(rotation)
    let q = simd_normalize(simd_quatf(rotUpperLeft))

    localTransformComponent.rotation = q
    syncCameraTransformIfNeeded(entityId: entityId, localTransformComponent: localTransformComponent)
    syncWorldTransformAndMarkOctreeDirty(entityId: entityId)
}

public func rotateTo(entityId: EntityID, rotation: simd_quatf) {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }

    localTransformComponent.rotation = simd_normalize(rotation)
    syncCameraTransformIfNeeded(entityId: entityId, localTransformComponent: localTransformComponent)
    syncWorldTransformAndMarkOctreeDirty(entityId: entityId)
}

/// The entity's actual rotation, as stored on LocalTransformComponent. This is the source
/// of truth for rendering; rotationX/Y/Z (see getAxisRotations) are a separate Euler-angle
/// cache that quaternion-based rotators (rotateTo, gizmo drag) do not keep in sync.
public func getRotationQuaternion(entityId: EntityID) -> simd_quatf {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return simd_quatf()
    }

    return localTransformComponent.rotation
}

public func rotateTo(entityId: EntityID, pitch: Float, yaw: Float, roll: Float) {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }

    let q = simd_normalize(transformEulerAnglesToQuaternion(pitch: pitch, yaw: yaw, roll: roll))

    localTransformComponent.rotation = q
    syncCameraTransformIfNeeded(entityId: entityId, localTransformComponent: localTransformComponent)
    syncWorldTransformAndMarkOctreeDirty(entityId: entityId)
}

public func scaleTo(entityId: EntityID, scale: simd_float3) {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }

    localTransformComponent.scale.x = scale.x
    localTransformComponent.scale.y = scale.y
    localTransformComponent.scale.z = scale.z
    syncWorldTransformAndMarkOctreeDirty(entityId: entityId)
}

public func getScale(entityId: EntityID) -> simd_float3 {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return .zero
    }

    return localTransformComponent.scale
}

public func getAxisRotations(entityId: EntityID) -> simd_float3 {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return .zero
    }

    return simd_float3(localTransformComponent.rotationX, localTransformComponent.rotationY, localTransformComponent.rotationZ)
}

public func applyAxisRotations(entityId: EntityID, axis: simd_float3) {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }

    localTransformComponent.rotationX = axis.x
    localTransformComponent.rotationY = axis.y
    localTransformComponent.rotationZ = axis.z

    // Generate Rotation
    let rotXMatrix: simd_float4x4 = matrix4x4Rotation(
        radians: degreesToRadians(degrees: localTransformComponent.rotationX), axis: simd_float3(1.0, 0.0, 0.0)
    )
    let rotYMatrix: simd_float4x4 = matrix4x4Rotation(
        radians: degreesToRadians(degrees: localTransformComponent.rotationY), axis: simd_float3(0.0, 1.0, 0.0)
    )
    let rotZMatrix: simd_float4x4 = matrix4x4Rotation(
        radians: degreesToRadians(degrees: localTransformComponent.rotationZ), axis: simd_float3(0.0, 0.0, 1.0)
    )

    // combine the rotations
    let combinedRotation: simd_float4x4 = rotZMatrix * rotYMatrix * rotXMatrix

    rotateTo(entityId: entityId, rotation: combinedRotation)
    // Note: markDirty is called inside rotateTo, no need to call again
}

public func worldPositionToLocal(entityId: EntityID, worldPosition: simd_float3) -> simd_float3 {
    guard let parentId = getEntityParent(entityId: entityId),
          let parentWorld = scene.get(component: WorldTransformComponent.self, for: parentId)
    else {
        return worldPosition
    }

    let worldPoint = simd_float4(worldPosition.x, worldPosition.y, worldPosition.z, 1.0)
    let localPoint = simd_mul(simd_inverse(parentWorld.space), worldPoint)
    return simd_float3(localPoint.x, localPoint.y, localPoint.z)
}

// MARK: - Scene Root Transform

/// Translate the entire scene by a delta without modifying individual entity transforms.
/// This keeps static batches intact — no rebatching is needed.
public func translateSceneBy(delta: simd_float3) {
    SceneRootTransform.shared.position += delta
}

/// Translate the entire scene to an absolute position without modifying individual entity transforms.
/// This keeps static batches intact — no rebatching is needed.
public func translateSceneTo(position: simd_float3) {
    SceneRootTransform.shared.position = position
}

/// Scale the entire scene uniformly without modifying individual entity transforms.
///
/// Use this — **not** `scaleTo(entityId:scale:)` on the scene root entity — when you need to
/// shrink a tiled scene for inspection (e.g. calibration mode) and then restore it to full size.
///
/// `scaleTo(entityId:)` on the scene root propagates the new world transform through every tile
/// stub and its parsed children, which can be hundreds of expensive ECS writes for a large tiled
/// scene. On scale-up, it also causes every tile to appear instantly within streaming range,
/// potentially triggering a memory burst on memory-constrained devices (e.g. Vision Pro).
///
/// This function uses the virtual-camera trick: no entity transforms are modified.
/// The streaming system's `effectiveCameraPosition()` accounts for the scale automatically,
/// so streaming distances shrink proportionally — tiles only load when the camera is within
/// `streamingRadius × scale` world-space units of a tile.
public func scaleSceneTo(_ scale: Float) {
    guard scale.isFinite, scale > 0 else {
        handleError(.valueisNaN, "Scene scale must be finite and positive", .invalid)
        return
    }
    SceneRootTransform.shared.scale = simd_float3(scale, scale, scale)
}

/// Scale the entire scene non-uniformly without modifying individual entity transforms.
/// Prefer the uniform overload `scaleSceneTo(_ scale: Float)` for most use cases.
public func scaleSceneTo(_ scale: simd_float3) {
    guard scale.x.isFinite, scale.y.isFinite, scale.z.isFinite else {
        handleError(.valueisNaN, "Scene scale must be finite", .invalid)
        return
    }
    SceneRootTransform.shared.scale = scale
}

/// Convert a point from scene-local/entity space to visual world space.
public func sceneLocalToVisualWorld(_ position: simd_float3) -> simd_float3 {
    SceneRootTransform.shared.sceneLocalToVisualWorld(position)
}

/// Convert a point from visual world space to scene-local/entity space.
public func visualWorldToSceneLocal(_ position: simd_float3) -> simd_float3 {
    SceneRootTransform.shared.visualWorldToSceneLocal(position)
}

/// Returns an entity's visual world position after scene-root transform is applied.
public func getVisualPosition(entityId: EntityID) -> simd_float3 {
    sceneLocalToVisualWorld(getPosition(entityId: entityId))
}

/// Reset the scene root transform to identity and refresh matrices immediately.
public func resetSceneRootTransform() {
    SceneRootTransform.shared.reset()
}

@inline(__always)
private func normalizeSceneYawRadians(_ radians: Float) -> Float {
    let twoPi = 2.0 * Float.pi
    var wrapped = fmod(radians + Float.pi, twoPi)
    if wrapped < 0.0 {
        wrapped += twoPi
    }
    return wrapped - Float.pi
}

@inline(__always)
func sceneYawRadians(from rotation: simd_quatf) -> Float {
    let q = simd_normalize(rotation)
    let sinyCosp = 2.0 * (q.real * q.imag.y + q.imag.x * q.imag.z)
    let cosyCosp = 1.0 - 2.0 * (q.imag.y * q.imag.y + q.imag.z * q.imag.z)
    return atan2(sinyCosp, cosyCosp)
}

/// Rotate the entire scene around world up (+Y) by a delta without modifying
/// individual entity transforms. This keeps static batches intact.
public func rotateSceneByYaw(_ deltaRadians: Float) {
    guard deltaRadians.isFinite else {
        handleError(.valueisNaN, "Scene yaw delta", .invalid)
        return
    }

    let currentYaw = sceneYawRadians(from: SceneRootTransform.shared.rotation)
    let targetYaw = normalizeSceneYawRadians(currentYaw + deltaRadians)
    SceneRootTransform.shared.rotation = simd_normalize(
        simd_quatf(angle: targetYaw, axis: simd_float3(0.0, 1.0, 0.0))
    )
}

/// Rotate the entire scene to an absolute yaw around world up (+Y) without
/// modifying individual entity transforms. This keeps static batches intact.
public func rotateSceneToYaw(_ radians: Float) {
    guard radians.isFinite else {
        handleError(.valueisNaN, "Scene yaw", .invalid)
        return
    }

    let targetYaw = normalizeSceneYawRadians(radians)
    SceneRootTransform.shared.rotation = simd_normalize(
        simd_quatf(angle: targetYaw, axis: simd_float3(0.0, 1.0, 0.0))
    )
}
