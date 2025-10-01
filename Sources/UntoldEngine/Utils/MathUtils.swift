//
//  MathUtils.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//  This Math functions were extracted from Apple various examples such as RenderingASceneWithDeferredLightingInC. I literally just ported them to swift.

import Foundation
import simd

// trig
public func degreesToRadians(degrees: Float) -> Float {
    degrees * .pi / 180.0
}

public func radiansToDegrees(radians: Float) -> Float {
    radians * 180.0 / .pi
}

public func safeACos(x: inout Double) -> Double {
    if x < -1.0 {
        x = -1.0
    } else if x > 1.0 {
        x = 1.0
    }
    return acos(x)
}

public func convertToPositiveAngle(degrees: Float) -> Float {
    var angle: Float = fmod(degrees, 360.0)

    if angle < 0.0 {
        angle += 360.0
    }

    return angle
}

public func areEqualAbs(_ uNumber1: Float, _ uNumber2: Float, uEpsilon: Float) -> Bool {
    abs(uNumber1 - uNumber2) <= uEpsilon
}

public func areEqualRel(_ uNumber1: Float, _ uNumber2: Float, uEpsilon: Float) -> Bool {
    abs(uNumber1 - uNumber2) <= uEpsilon * max(abs(uNumber1), abs(uNumber2))
}

public func areEqual(_ uNumber1: Float, _ uNumber2: Float, uEpsilon: Float) -> Bool {
    abs(uNumber1 - uNumber2) <= uEpsilon * max(1.0, max(abs(uNumber1), abs(uNumber2)))
}

// Generic matrix math utility functions

public func matrix4x4Identity() -> matrix_float4x4 {
    matrix_float4x4(
        columns: (
            vector_float4(1, 0, 0, 0),
            vector_float4(0, 1, 0, 0),
            vector_float4(0, 0, 1, 0),
            vector_float4(0, 0, 0, 1)
        ))
}

public func getMatrix4x4FromQuaternion(q: simd_quatf) -> matrix_float4x4 {
    let xx: Float = q.vector.x * q.vector.x
    let xy: Float = q.vector.x * q.vector.y
    let xz: Float = q.vector.x * q.vector.z
    let xw: Float = q.vector.x * q.real
    let yy: Float = q.vector.y * q.vector.y
    let yz: Float = q.vector.y * q.vector.z
    let yw: Float = q.vector.y * q.real
    let zz: Float = q.vector.z * q.vector.z
    let zw: Float = q.vector.z * q.real

    // indices are m<column><row>
    let m00: Float = 1 - 2 * (yy + zz)
    let m10: Float = 2 * (xy - zw)
    let m20: Float = 2 * (xz + yw)

    let m01: Float = 2 * (xy + zw)
    let m11: Float = 1 - 2 * (xx + zz)
    let m21: Float = 2 * (yz - xw)

    let m02: Float = 2 * (xz - yw)
    let m12: Float = 2 * (yz + xw)
    let m22: Float = 1 - 2 * (xx + yy)

    let matrix = matrix_float4x4(
        columns: (
            vector_float4(m00, m01, m02, 0.0),
            vector_float4(m10, m11, m12, 0.0),
            vector_float4(m20, m21, m22, 0.0),
            vector_float4(0.0, 0.0, 0.0, 1.0)
        ))

    return matrix
}

public func matrix4x4Rotation(radians: Float, axis: SIMD3<Float>) -> matrix_float4x4 {
    let unitAxis = normalize(axis)
    let ct = cosf(radians)
    let st = sinf(radians)
    let ci = 1 - ct
    let x = unitAxis.x
    let y = unitAxis.y
    let z = unitAxis.z
    return matrix_float4x4.init(
        columns: (
            vector_float4(ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0),
            vector_float4(x * y * ci - z * st, ct + y * y * ci, z * y * ci + x * st, 0),
            vector_float4(x * z * ci + y * st, y * z * ci - x * st, ct + z * z * ci, 0),
            vector_float4(0, 0, 0, 1)
        ))
}

public func matrix4x4Rotation(pitch: Float, yaw: Float, roll: Float) -> matrix_float4x4 {
    let cp = cosf(pitch)
    let sp = sinf(pitch)
    let cy = cosf(yaw)
    let sy = sinf(yaw)
    let cr = cosf(roll)
    let sr = sinf(roll)

    let col1 = vector_float4(
        cy * cr,
        sp * sy * cr - cp * sr,
        cp * sy * cr + sp * sr,
        0
    )

    let col2 = vector_float4(
        cy * sr,
        sp * sy * sr + cp * cr,
        cp * sy * sr - sp * cr,
        0
    )

    let col3 = vector_float4(
        -sy,
        sp * cy,
        cp * cy,
        0
    )

    let col4 = vector_float4(0, 0, 0, 1)

    return matrix_float4x4(columns: (col1, col2, col3, col4))
}

public func matrix4x4Translation(_ translationX: Float, _ translationY: Float, _ translationZ: Float)
    -> matrix_float4x4
{
    matrix_float4x4.init(
        columns: (
            vector_float4(1, 0, 0, 0),
            vector_float4(0, 1, 0, 0),
            vector_float4(0, 0, 1, 0),
            vector_float4(translationX, translationY, translationZ, 1)
        ))
}

public func matrix4x4Scale(_ scaleX: Float, _ scaleY: Float, _ scaleZ: Float) -> matrix_float4x4 {
    matrix_float4x4.init(
        columns: (
            vector_float4(scaleX, 0, 0, 0),
            vector_float4(0, scaleY, 0, 0),
            vector_float4(0, 0, scaleZ, 0),
            vector_float4(0, 0, 0, 1)
        ))
}

public func matrix3x3_upper_left(_ m: matrix_float4x4) -> matrix_float3x3 {
    let x = vector_float3(m.columns.0.x, m.columns.0.y, m.columns.0.z)
    let y = vector_float3(m.columns.1.x, m.columns.1.y, m.columns.1.z)
    let z = vector_float3(m.columns.2.x, m.columns.2.y, m.columns.2.z)

    return matrix_float3x3.init(columns: (x, y, z))
}

public func matrix_float4x4_from_double4x4(_ m: simd_double4x4) -> matrix_float4x4 {
    matrix_float4x4.init(
        columns: (
            simd_make_float4(
                Float(m.columns.0.x), Float(m.columns.0.y), Float(m.columns.0.z), Float(m.columns.0.w)
            ),
            simd_make_float4(
                Float(m.columns.1.x), Float(m.columns.1.y), Float(m.columns.1.z), Float(m.columns.1.w)
            ),
            simd_make_float4(
                Float(m.columns.2.x), Float(m.columns.2.y), Float(m.columns.2.z), Float(m.columns.2.w)
            ),
            simd_make_float4(
                Float(m.columns.3.x), Float(m.columns.3.y), Float(m.columns.3.z), Float(m.columns.3.w)
            )
        ))
}

public func matrixPerspectiveRightHand(
    fovyRadians fovy: Float, aspectRatio: Float, nearZ: Float, farZ: Float
) -> matrix_float4x4 {
    let ys = 1 / tanf(fovy * 0.5)
    let xs = ys / aspectRatio
    let zs = farZ / (nearZ - farZ)
    return matrix_float4x4.init(
        columns: (
            vector_float4(xs, 0, 0, 0),
            vector_float4(0, ys, 0, 0),
            vector_float4(0, 0, zs, -1),
            vector_float4(0, 0, zs * nearZ, 0)
        ))
}

public func matrix_look_at_right_hand(_ eye: simd_float3, _ target: simd_float3, _ up: simd_float3)
    -> simd_float4x4
{
    let z: simd_float3 = normalize(eye - target)
    let x: simd_float3 = normalize(cross(up, z))
    let y: simd_float3 = cross(z, x)

    let t = simd_float3(-dot(x, eye), -dot(y, eye), -dot(z, eye))

    return matrix_float4x4.init(
        columns: (
            vector_float4(x.x, y.x, z.x, 0),
            vector_float4(x.y, y.y, z.y, 0),
            vector_float4(x.z, y.z, z.z, 0),
            vector_float4(t.x, t.y, t.z, 1.0)
        ))
}

public func matrix_ortho_right_hand(
    _ left: Float, _ right: Float, _ bottom: Float, _ top: Float, _ nearZ: Float, farZ: Float
) -> simd_float4x4 {
    matrix_float4x4.init(
        columns: (
            vector_float4(2.0 / (right - left), 0.0, 0.0, 0.0),
            vector_float4(0.0, 2.0 / (top - bottom), 0.0, 0.0),
            vector_float4(0.0, 0.0, -1.0 / (farZ - nearZ), 0.0),
            vector_float4(
                (left + right) / (left - right), (top + bottom) / (bottom - top), nearZ / (nearZ - farZ),
                1.0
            )
        ))
}

public func quaternion_lookAt(eye: simd_float3, target: simd_float3, up: simd_float3) -> simd_quatf {
    let forward: simd_float3 = simd_normalize(eye - target)
    let right: simd_float3 = simd_normalize(simd_cross(up, forward))
    let newUp: simd_float3 = simd_cross(forward, right)

    var q = simd_quatf()

    let trace: Float = right.x + newUp.y + forward.z

    if trace > 0.0 {
        let s: Float = 0.5 / sqrt(trace + 1.0)
        q.real = 0.25 / s
        q.vector.x = (newUp.z - forward.y) * s
        q.vector.y = (forward.x - right.z) * s
        q.vector.z = (right.y - newUp.x) * s
    } else {
        if right.x > newUp.y, right.x > forward.z {
            let s: Float = 2.0 * sqrt(1.0 + right.x - newUp.y - forward.z)
            q.real = (newUp.z - forward.y) / s
            q.vector.x = 0.25 * s
            q.vector.y = (newUp.x + right.y) / s
            q.vector.z = (forward.x + right.z) / s

        } else if newUp.y > forward.z {
            let s: Float = 2.0 * sqrt(1.0 + newUp.y - right.x - forward.z)
            q.real = (forward.x - right.z) / s
            q.vector.x = (newUp.x + right.y) / s
            q.vector.y = 0.25 * s
            q.vector.z = (forward.y + newUp.z) / s

        } else {
            let s: Float = 2.0 * sqrt(1.0 + forward.z - right.x - newUp.y)
            q.real = (right.y - newUp.x) / s
            q.vector.x = (forward.x + right.z) / s
            q.vector.y = (forward.y + newUp.z) / s
            q.vector.z = 0.25 * s
        }
    }

    return q
}

public func getRotationQuaternion(axis: simd_float3, angle: Float) -> simd_quatf {
    let q: simd_quatf = .init(angle: angle, axis: axis)
    return q
}

public func forwardDirectionVector(from q: simd_quatf) -> simd_float3 {
    var direction = simd_float3(0.0, 0.0, 0.0)
    direction.x = 2.0 * (q.vector.x * q.vector.z - q.real * q.vector.y)
    direction.y = 2.0 * (q.vector.y * q.vector.z + q.real * q.vector.x)
    direction.z = 1.0 - 2.0 * ((q.vector.x * q.vector.x) + (q.vector.y * q.vector.y))

    direction = simd_normalize(direction)
    return direction
}

public func upDirectionVector(from q: simd_quatf) -> simd_float3 {
    var direction = simd_float3(0.0, 0.0, 0.0)
    direction.x = 2.0 * (q.vector.x * q.vector.y + q.real * q.vector.z)
    direction.y = 1.0 - 2.0 * ((q.vector.x * q.vector.x) + (q.vector.z * q.vector.z))
    direction.z = 2.0 * (q.vector.y * q.vector.z - q.real * q.vector.x)

    direction = simd_normalize(direction)
    // Negate for a right-handed coordinate system
    return direction
}

public func rightDirectionVector(from q: simd_quatf) -> simd_float3 {
    var direction = simd_float3(0.0, 0.0, 0.0)
    direction.x = 1.0 - 2.0 * ((q.vector.y * q.vector.y) + (q.vector.z * q.vector.z))
    direction.y = 2.0 * (q.vector.x * q.vector.y - q.real * q.vector.z)
    direction.z = 2.0 * (q.vector.x * q.vector.z + q.real * q.vector.y)

    direction = simd_normalize(direction)
    // Negate for a right-handed coordinate system
    return direction
}

public func rotateVectorUsingQuaternion(q: simd_quatf, v: simd_float3) -> simd_float3 {
    let vec: simd_float3 = simd_act(q, v)
    return vec
}

public func transformQuaternionToMatrix3x3(q: simd_quatf) -> matrix_float3x3 {
    /*
     // 3x3 matrix - column major. X vector is 0, 1, 2, etc.
     //    0    3    6
     //    1    4    7
     //    2    5    8

     */

    var m = simd_float3x3.init(diagonal: simd_float3(1.0, 1.0, 1.0))

    m.columns.0.x = 2 * (q.real * q.real + q.vector.x * q.vector.x) - 1
    m.columns.1.x = 2 * (q.vector.x * q.vector.y - q.real * q.vector.z)
    m.columns.2.x = 2 * (q.vector.x * q.vector.z + q.real * q.vector.y)

    m.columns.0.y = 2 * (q.vector.x * q.vector.y + q.real * q.vector.z)
    m.columns.1.y = 2 * (q.real * q.real + q.vector.y * q.vector.y) - 1
    m.columns.2.y = 2 * (q.vector.y * q.vector.z - q.real * q.vector.x)

    m.columns.0.z = 2 * (q.vector.x * q.vector.z - q.real * q.vector.y)
    m.columns.1.z = 2 * (q.vector.y * q.vector.z + q.real * q.vector.x)
    m.columns.2.z = 2 * (q.real * q.real + q.vector.z * q.vector.z) - 1

    return m
}

public func transformMatrix3nToQuaternion(m: matrix_float3x3) -> simd_quatf {
    // 3x3 matrix - column major. X vector is 0, 1, 2, etc.
    //    0    3    6
    //    1    4    7
    //    2    5    8

    // calculate the sum of the diagonal elements
    let trace: Float = m.columns.0.x + m.columns.1.y + m.columns.2.z
    var q = simd_quatf()

    if trace > 0 { // s=4*qw
        q.real = 0.5 * sqrt(1 + trace)
        let S: Float = 0.25 / q.real

        q.vector.x = S * (m.columns.1.z - m.columns.2.y)
        q.vector.y = S * (m.columns.2.x - m.columns.0.z)
        q.vector.z = S * (m.columns.0.y - m.columns.1.x)

    } else if m.columns.0.x > m.columns.1.y, m.columns.0.x > m.columns.2.z { // s=4*qx
        q.vector.x = 0.5 * sqrt(1 + m.columns.0.x - m.columns.1.y - m.columns.2.z)
        let X: Float = 0.25 / q.vector.x

        q.vector.y = X * (m.columns.1.x + m.columns.0.y)
        q.vector.z = X * (m.columns.2.x + m.columns.0.z)
        q.vector.w = X * (m.columns.1.z - m.columns.2.y)

    } else if m.columns.1.y > m.columns.2.z { // s=4*qy
        q.vector.y = 0.5 * sqrt(1 - m.columns.0.x + m.columns.1.y - m.columns.2.z)
        let Y: Float = 0.25 / q.vector.y
        q.vector.x = Y * (m.columns.1.x + m.columns.0.y)
        q.vector.z = Y * (m.columns.2.y + m.columns.1.z)
        q.real = Y * (m.columns.2.x - m.columns.0.z)

    } else { // s=4*qz
        q.vector.z = 0.5 * sqrt(1 - m.columns.0.x - m.columns.1.y + m.columns.2.z)
        let Z: Float = 0.25 / q.vector.z
        q.vector.x = Z * (m.columns.2.x + m.columns.0.z)
        q.vector.y = Z * (m.columns.2.y + m.columns.1.z)
        q.vector.w = Z * (m.columns.0.y - m.columns.1.x)
    }

    return q
}

public func transformQuaternionToEulerAngles(q: simd_quatf) -> (pitch: Float, yaw: Float, roll: Float) {
    // 3x3 matrix - column major. X vector is 0, 1, 2, etc.
    //    0    3    6
    //    1    4    7
    //    2    5    8

    var x: Float = 0.0
    var y: Float = 0.0
    var z: Float = 0.0

    let test: Float = 2 * (q.vector.x * q.vector.z - q.real * q.vector.y)

    if test != 1, test != -1 {
        x = atan2(q.vector.y * q.vector.z + q.real * q.vector.x, 0.5 - (q.vector.x * q.vector.x + q.vector.y * q.vector.y))
        let raw = -2 * (q.vector.x * q.vector.z - q.real * q.vector.y)
        let clamped = simd_clamp(raw, -1.0, 1.0)
        y = asin(clamped)
        z = atan2(q.vector.x * q.vector.y + q.real * q.vector.z, 0.5 - (q.vector.y * q.vector.y + q.vector.z * q.vector.z))

    } else if test == 1 {
        z = atan2(q.vector.x * q.vector.y + q.real * q.vector.z, 0.5 - (q.vector.y * q.vector.y + q.vector.z * q.vector.z))
        y = -.pi / 2.0
        x = -z + atan2(q.vector.x * q.vector.y - q.real * q.vector.z, q.vector.x * q.vector.z + q.real * q.vector.y)

    } else if test == -1 {
        z = atan2(q.vector.x * q.vector.y + q.real * q.vector.z, 0.5 - (q.vector.y * q.vector.y + q.vector.z * q.vector.z))
        y = .pi / 2.0
        x = z + atan2(q.vector.x * q.vector.y - q.real * q.vector.z, q.vector.x * q.vector.z + q.real * q.vector.y)
    }

    x = radiansToDegrees(radians: x)
    y = radiansToDegrees(radians: y)
    z = radiansToDegrees(radians: z)

    return (pitch: x, yaw: y, roll: z)
}

public func transformEulerAnglesToQuaternion(pitch: Float, yaw: Float, roll: Float) -> simd_quatf {
    var x: Float = convertToPositiveAngle(degrees: pitch)
    var y: Float = convertToPositiveAngle(degrees: yaw)
    var z: Float = convertToPositiveAngle(degrees: roll)

    x = degreesToRadians(degrees: x)
    y = degreesToRadians(degrees: y)
    z = degreesToRadians(degrees: z)

    x = x / 2.0
    y = y / 2.0
    z = z / 2.0

    var q = simd_quatf()

    q.real = cos(z) * cos(y) * cos(x) + sin(z) * sin(y) * sin(x)
    q.vector.x = cos(z) * cos(y) * sin(x) - sin(z) * sin(y) * cos(x)
    q.vector.y = cos(z) * sin(y) * cos(x) + sin(z) * cos(y) * sin(x)
    q.vector.z = sin(z) * cos(y) * cos(x) - cos(z) * sin(y) * sin(x)

    return q
}

public func makeAABB(uOrigin: simd_float3, uHalfWidth: simd_float3) -> [simd_float3] {
    // compute the min and max of the aabb
    let minDim = simd_float3(
        uOrigin.x - uHalfWidth.x, uOrigin.y - uHalfWidth.y, uOrigin.z - uHalfWidth.z
    )
    let maxDim = simd_float3(
        uOrigin.x + uHalfWidth.x, uOrigin.y + uHalfWidth.y, uOrigin.z + uHalfWidth.z
    )

    return makeAABB(uMin: minDim, uMax: maxDim)
}

public func makeAABB(uMin: simd_float3, uMax: simd_float3) -> [simd_float3] {
    let width: Float = abs(uMax.x - uMin.x) / 2.0
    let height: Float = abs(uMax.y - uMin.y) / 2.0
    let depth: Float = abs(uMax.z - uMin.z) / 2.0

    let v0 = simd_float3(width, height, depth)
    let v1 = simd_float3(width, height, -depth)
    let v2 = simd_float3(-width, height, -depth)
    let v3 = simd_float3(-width, height, depth)

    let v4 = simd_float3(width, -height, depth)
    let v5 = simd_float3(width, -height, -depth)
    let v6 = simd_float3(-width, -height, -depth)
    let v7 = simd_float3(-width, -height, depth)

    let aabb: [simd_float3] = [v0, v1, v2, v3, v4, v5, v6, v7]

    return aabb
}

public func rayDirectionInWorldSpace(
    uMouseLocation: simd_float2, uViewPortDim: simd_float2, uPerspectiveSpace: simd_float4x4,
    uViewSpace: simd_float4x4
) -> simd_float3 {
    // step 1. convert to normalize device coordinates
    // range [-1:1,-1:1,-1:1]
    let x: Float = (2.0 * uMouseLocation.x) / uViewPortDim.x - 1.0
    var y: Float = 1.0 - (2.0 * uMouseLocation.y) / uViewPortDim.y

    y *= -1.0
    let z: Float = 1.0

    let rayNDS = simd_float3(x, y, z)

    // step 2. convert to homogeneous clip coordiates
    // range [-1:1,-1:1,-1:1]
    let rayClip = simd_float4(rayNDS.x, rayNDS.y, -1.0, 1.0)

    // step 3. convert to camera coordinates
    // range [-x:x,-y:y,-z:z,-w:w]
    var rayCamera: simd_float4 = simd_mul(simd_inverse(uPerspectiveSpace), rayClip)
    rayCamera.z = -1.0
    rayCamera.w = 0.0

    // step 4. convert to world coordinates
    // range[-x:x,-y:y,-z:z,-w:w]

    var rayWorld: simd_float4 = simd_mul(simd_inverse(uViewSpace), rayCamera)
    rayWorld = simd_normalize(rayWorld)

    return simd_make_float3(rayWorld)
}

public func rayIntersectsAABB(
    rayOrigin: simd_float3, rayDir: simd_float3, boxMin: simd_float3, boxMax: simd_float3,
    tmin: inout Float
) -> Bool {
    let invDir = 1.0 / rayDir

    let t1 = (boxMin.x - rayOrigin.x) * invDir.x
    let t2 = (boxMax.x - rayOrigin.x) * invDir.x
    let t3 = (boxMin.y - rayOrigin.y) * invDir.y
    let t4 = (boxMax.y - rayOrigin.y) * invDir.y
    let t5 = (boxMin.z - rayOrigin.z) * invDir.z
    let t6 = (boxMax.z - rayOrigin.z) * invDir.z

    let tminLocal = max(max(min(t1, t2), min(t3, t4)), min(t5, t6))
    let tmax = min(min(max(t1, t2), max(t3, t4)), max(t5, t6))

    if tmax >= max(0.0, tminLocal) {
        tmin = tminLocal
        return true
    }

    return false
}

public func rayIntersectsAABB(
    rayOrigin: simd_float3, rayDir: simd_float3, boxMin: simd_float3, boxMax: simd_float3
) -> Bool {
    let invDir = 1.0 / rayDir

    let t1 = (boxMin.x - rayOrigin.x) * invDir.x
    let t2 = (boxMax.x - rayOrigin.x) * invDir.x
    let t3 = (boxMin.y - rayOrigin.y) * invDir.y
    let t4 = (boxMax.y - rayOrigin.y) * invDir.y
    let t5 = (boxMin.z - rayOrigin.z) * invDir.z
    let t6 = (boxMax.z - rayOrigin.z) * invDir.z

    let tmin = max(max(min(t1, t2), min(t3, t4)), min(t5, t6))
    let tmax = min(min(max(t1, t2), max(t3, t4)), max(t5, t6))

    return tmax >= max(0.0, tmin)
}

public func rayIntersectPlane(
    rayOrigin: simd_float3, rayDir: simd_float3, planeNormal: simd_float3, planeOrigin: simd_float3
) -> (intersects: Bool, intersection: simd_float3?) {
    let denom = simd_dot(planeNormal, rayDir)

    if abs(denom) > 0.0001 {
        let t = simd_dot(planeOrigin - rayOrigin, planeNormal) / denom
        if t > 0.0001 {
            let intersection = rayOrigin + t * rayDir
            return (true, intersection)
        }
    }

    return (false, nil)
}

extension simd_float4x4 {
    static var identity: simd_float4x4 {
        matrix_identity_float4x4
    }

    init(translation: simd_float3) {
        let matrix = float4x4(
            [1, 0, 0, 0],
            [0, 1, 0, 0],
            [0, 0, 1, 0],
            [translation.x, translation.y, translation.z, 1]
        )
        self = matrix
    }
}

func safeNormalize(_ vector: simd_float3) -> simd_float3 {
    let length = simd.length(vector)
    return length > 0 ? vector / length : vector
}
