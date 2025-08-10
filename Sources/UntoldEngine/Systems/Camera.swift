
//
//  Camera.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 5/17/23.
//

import Foundation
import simd

public func getMainCamera() -> EntityID {
    if gameMode == true {
        return findGameCamera()
    } else {
        return findSceneCamera()
    }
}

public func findSceneCamera() -> EntityID {
    for entityId in scene.getAllEntities() {
        if hasComponent(entityId: entityId, componentType: CameraComponent.self), hasComponent(entityId: entityId, componentType: SceneCameraComponent.self) {
            return entityId
        }
    }

    // if scene camera was not found, then create one

    let sceneCamera = createEntity()
    createSceneCamera(entityId: sceneCamera)
    return sceneCamera
}

public func findGameCamera() -> EntityID {
    for entityId in scene.getAllEntities() {
        if hasComponent(entityId: entityId, componentType: CameraComponent.self), !hasComponent(entityId: entityId, componentType: SceneCameraComponent.self) {
            return entityId
        }
    }
    return .invalid
}

func createSceneCamera(entityId: EntityID) {
    setEntityName(entityId: entityId, name: "Scene Camera")
    registerComponent(entityId: entityId, componentType: CameraComponent.self)
    registerComponent(entityId: entityId, componentType: SceneCameraComponent.self)

    cameraLookAt(entityId: entityId,
                 eye: cameraDefaultEye, target: cameraTargetDefault,
                 up: cameraUpDefault)
}

func createGameCamera(entityId: EntityID) {
    registerComponent(entityId: entityId, componentType: CameraComponent.self)

    cameraLookAt(entityId: entityId,
                 eye: cameraDefaultEye, target: cameraTargetDefault,
                 up: cameraUpDefault)
}

func resetCameraToDefaultTransform(entityId: EntityID){
  
    guard scene.get(component: CameraComponent.self, for: entityId) != nil else {
        handleError(.noActiveCamera)
        return
    }
    cameraLookAt(entityId: entityId,
                 eye: cameraDefaultEye, target: cameraTargetDefault,
                 up: cameraUpDefault)
}

public func moveCameraTo(entityId: EntityID, _ translationX: Float, _ translationY: Float, _ translationZ: Float) {
    guard let cameraComponent = scene.get(component: CameraComponent.self, for: entityId) else {
        return
    }

    cameraComponent.localPosition.x = translationX
    cameraComponent.localPosition.y = translationY
    cameraComponent.localPosition.z = translationZ

    updateCameraViewMatrix(entityId: entityId)
}

public func moveCameraBy(entityId: EntityID, delU: Float, delV: Float, delN: Float) {
    guard let cameraComponent = scene.get(component: CameraComponent.self, for: entityId) else {
        return
    }

    cameraComponent.localPosition.x += delU * cameraComponent.xAxis.x + delV * cameraComponent.yAxis.x + delN * cameraComponent.zAxis.x
    cameraComponent.localPosition.y += delU * cameraComponent.xAxis.y + delV * cameraComponent.yAxis.y + delN * cameraComponent.zAxis.y
    cameraComponent.localPosition.z += delU * cameraComponent.xAxis.z + delV * cameraComponent.yAxis.z + delN * cameraComponent.zAxis.z
    updateCameraViewMatrix(entityId: entityId)
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

public func orbitAround(entityId: EntityID, uPosition: simd_float2) {
    guard let cameraComponent = scene.get(component: CameraComponent.self, for: entityId) else {
        return
    }

    let target: simd_float3 = cameraComponent.localPosition - cameraComponent.orbitTarget
    let length: Float = simd_length(target)
    var direction: simd_float3 = simd_normalize(target)

    // rot about yaw first
    let rotationX: simd_quatf = getRotationQuaternion(
        axis: simd_float3(0.0, 1.0, 0.0), angle: uPosition.x
    )
    direction = rotateVectorUsingQuaternion(q: rotationX, v: direction)
    var newUpAxis = rotateVectorUsingQuaternion(q: rotationX, v: cameraComponent.yAxis)

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

    cameraComponent.localPosition = cameraComponent.orbitTarget + direction * length

    // compute the matrix
    cameraLookAt(entityId: entityId, eye: cameraComponent.localPosition, target: cameraComponent.orbitTarget, up: newUpAxis)
}

// Returns a right-handed matrix which looks from a point (the "eye") at a target point, given the up vector.
public func cameraLookAt(entityId: EntityID, eye: simd_float3, target: simd_float3, up: simd_float3) {
    guard let cameraComponent = scene.get(component: CameraComponent.self, for: entityId) else {
        return
    }

    cameraComponent.eye = eye
    cameraComponent.up = up
    cameraComponent.target = target

    let q0 = quaternion_lookAt(eye: eye, target: target, up: up)
    let q1 = simd_conjugate(q0)
    cameraComponent.rotation = simd_normalize(q1)

    cameraComponent.localPosition = eye

    updateCameraViewMatrix(entityId: entityId)
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

    cameraComponent.rotation = simd_mul(newRotation, rotationX)

    updateCameraViewMatrix(entityId: entityId)
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
    guard let cameraComponent = scene.get(component: CameraComponent.self, for: entityId) else {
        return .zero
    }

    return simd_float3(cameraComponent.viewSpace.columns.3.x, cameraComponent.viewSpace.columns.3.y, cameraComponent.viewSpace.columns.3.z)
}

public func moveCameraWithInput(entityId: EntityID, input: (w: Bool, a: Bool, s: Bool, d: Bool, q: Bool, e: Bool), speed: Float, deltaTime: Float) {
    guard scene.get(component: CameraComponent.self, for: entityId) != nil else {
        return
    }

    if inputSystem.cameraControlMode == .orbiting {
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

// Function to rotate the camera based on mouse movement
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

    cameraComponent.rotation = simd_mul(newRotation, rotationX)

    // Recompute view matrix to update the orientation vectors
    updateCameraViewMatrix(entityId: entityId)
}
