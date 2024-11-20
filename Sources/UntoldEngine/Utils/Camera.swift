
//
//  Camera.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 5/17/23.
//

import Foundation
import simd

public struct Camera {
    public mutating func translateTo(_ translationX: Float, _ translationY: Float, _ translationZ: Float) {
        localPosition.x = translationX
        localPosition.y = translationY
        localPosition.z = translationZ

        updateViewMatrix()
    }

    public mutating func translateBy(delU: Float, delV: Float, delN: Float) {
        localPosition.x += delU * xAxis.x + delV * yAxis.x + delN * zAxis.x
        localPosition.y += delU * xAxis.y + delV * yAxis.y + delN * zAxis.y
        localPosition.z += delU * xAxis.z + delV * yAxis.z + delN * zAxis.z
        updateViewMatrix()
    }

    public mutating func updateViewMatrix() {
        // if you are new to this: see this: http://www.songho.ca/opengl/gl_anglestoaxes.html

        rotation = quaternion_normalize(q: rotation)

        xAxis = rightDirectionVector(from: rotation)
        yAxis = upDirectionVector(from: rotation)
        zAxis = forwardDirectionVector(from: rotation)

        viewSpace = getMatrix4x4(from: rotation)

        viewSpace.columns.3 = simd_float4(
            -simd_dot(xAxis, localPosition),
            -simd_dot(yAxis, localPosition),
            -simd_dot(zAxis, localPosition),
            1.0
        )

        localOrientation = zAxis
    }

    public mutating func orbitAround(_ uPosition: simd_float2) {
        let target: simd_float3 = localPosition - orbitTarget
        let length: Float = simd_length(target)
        var direction: simd_float3 = simd_normalize(target)

        // rot about yaw first
        let rotationX: quaternion = getRotationQuaternion(
            axis: simd_float3(0.0, 1.0, 0.0), radians: uPosition.x
        )
        direction = rotateVectorUsingQuaternion(q: rotationX, v: direction)
        var newUpAxis = rotateVectorUsingQuaternion(q: rotationX, v: yAxis)

        direction = simd_normalize(direction)
        newUpAxis = simd_normalize(newUpAxis)

        // now compute the right axis
        var rightAxis: simd_float3 = simd_cross(newUpAxis, direction)
        rightAxis = simd_normalize(rightAxis)

        // then rotate about right axis
        let rotationY: quaternion = getRotationQuaternion(axis: rightAxis, radians: uPosition.y)
        direction = rotateVectorUsingQuaternion(q: rotationY, v: direction)
        newUpAxis = rotateVectorUsingQuaternion(q: rotationY, v: newUpAxis)

        direction = simd_normalize(direction)
        newUpAxis = simd_normalize(newUpAxis)

        localPosition = orbitTarget + direction * length

        // compute the matrix
        lookAt(eye: localPosition, target: orbitTarget, up: newUpAxis)
    }

    // Returns a right-handed matrix which looks from a point (the "eye") at a target point, given the up vector.
    public mutating func lookAt(eye: simd_float3, target: simd_float3, up: simd_float3) {
        rotation = quaternion_normalize(
            q: quaternion_conjugate(q: quaternion_lookAt(eye: eye, target: target, up: up)))

        localPosition = eye

        updateViewMatrix()
    }

    public mutating func cameraLookAboutAxis(uDelta: simd_float2) {
        let rotationAngleX: Float = uDelta.x * 0.01
        let rotationAngleY: Float = uDelta.y * 0.01

        let rotationX: quaternion = getRotationQuaternion(
            axis: simd_float3(0.0, 1.0, 0.0), radians: rotationAngleX
        )
        let rotationY: quaternion = getRotationQuaternion(
            axis: simd_float3(1.0, 0.0, 0.0), radians: rotationAngleY
        )

        let newRotation: quaternion = quaternion_multiply(q0: rotationY, q1: rotation)

        rotation = quaternion_multiply(q0: newRotation, q1: rotationX)

        updateViewMatrix()
    }

    mutating func moveCameraAlongAxis(uDelta: simd_float3) {
        translateBy(delU: uDelta.x * -1.0, delV: uDelta.y, delN: uDelta.z * -1.0)
    }

    mutating func setOrbitOffset(uTargetOffset: Float) {
        let direction: simd_float3 = -1.0 * localOrientation

        orbitTarget = localPosition + direction * uTargetOffset
    }

    mutating func orbitCameraAround(uDelta: inout simd_float2) {
        uDelta.x *= -0.01
        uDelta.y *= -0.01

        orbitAround(uDelta)
    }

    public func getPosition() -> simd_float3 {
        return simd_float3(viewSpace.columns.3.x, viewSpace.columns.3.y, viewSpace.columns.3.z)
    }

    public mutating func moveCameraWithInput(input: (w: Bool, a: Bool, s: Bool, d: Bool, q: Bool, e: Bool), speed: Float, deltaTime: Float) {
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
        translateBy(delU: delU, delV: delV, delN: delN)
    }

    // Function to rotate the camera based on mouse movement
    public mutating func rotateCamera(yaw: Float, pitch: Float, sensitivity: Float) {
        // Calculate rotation angles (scaled by sensitivity)
        let rotationAngleX = yaw * sensitivity
        let rotationAngleY = pitch * sensitivity

        let rotationX: quaternion = getRotationQuaternion(
            axis: simd_float3(0.0, 1.0, 0.0), radians: rotationAngleX
        )
        let rotationY: quaternion = getRotationQuaternion(
            axis: simd_float3(1.0, 0.0, 0.0), radians: rotationAngleY
        )

        let newRotation: quaternion = quaternion_multiply(q0: rotationY, q1: rotation)

        rotation = quaternion_multiply(q0: newRotation, q1: rotationX)

        // Recompute view matrix to update the orientation vectors
        updateViewMatrix()
    }

    // data
    public var viewSpace = simd_float4x4.init(1.0)
    public var xAxis: simd_float3 = .init(0.0, 0.0, 0.0)
    public var yAxis: simd_float3 = .init(0.0, 0.0, 0.0)
    public var zAxis: simd_float3 = .init(0.0, 0.0, 0.0)

    // quaternion
    var rotation: quaternion = quaternion_identity()
    var localOrientation: simd_float3 = .init(0.0, 0.0, 0.0)
    var localPosition: simd_float3 = .init(0.0, 0.0, 0.0)
    var orbitTarget: simd_float3 = .init(0.0, 0.0, 0.0)
}
