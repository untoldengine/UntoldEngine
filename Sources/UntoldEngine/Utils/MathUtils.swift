//
//  MathUtils.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 5/17/23.
//  This Math functions were extracted from Apple various examples such as RenderingASceneWithDeferredLightingInC. I literally just ported them to swift.

import Foundation
import simd

public typealias quaternion = vector_float4

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

public func getMatrix4x4FromQuaternion(q: quaternion) -> matrix_float4x4 {
    let xx: Float = q.x * q.x
    let xy: Float = q.x * q.y
    let xz: Float = q.x * q.z
    let xw: Float = q.x * q.w
    let yy: Float = q.y * q.y
    let yz: Float = q.y * q.z
    let yw: Float = q.y * q.w
    let zz: Float = q.z * q.z
    let zw: Float = q.z * q.w

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

public func quaternion_identity() -> quaternion {
    quaternion(0.0, 0.0, 0.0, 1.0)
}

public func quaternion_normalize(q: quaternion) -> quaternion {
    simd_normalize(q)
}

public func quaternion_conjugate(q: quaternion) -> quaternion {
    quaternion(-q.x, -q.y, -q.z, q.w)
}

public func quaternion_multiply(q0: quaternion, q1: quaternion) -> quaternion {
    var q: quaternion = quaternion_identity()

    q.x = q0.w * q1.x + q0.x * q1.w + q0.y * q1.z - q0.z * q1.y
    q.y = q0.w * q1.y - q0.x * q1.z + q0.y * q1.w + q0.z * q1.x
    q.z = q0.w * q1.z + q0.x * q1.y - q0.y * q1.x + q0.z * q1.w
    q.w = q0.w * q1.w - q0.x * q1.x - q0.y * q1.y - q0.z * q1.z

    return q
}

public func quaternion_lookAt(eye: simd_float3, target: simd_float3, up: simd_float3) -> quaternion {
    let forward: simd_float3 = simd_normalize(eye - target)
    let right: simd_float3 = simd_normalize(simd_cross(up, forward))
    let newUp: simd_float3 = simd_cross(forward, right)

    var q: quaternion = quaternion_identity()

    let trace: Float = right.x + newUp.y + forward.z

    if trace > 0.0 {
        let s: Float = 0.5 / sqrt(trace + 1.0)
        q.w = 0.25 / s
        q.x = (newUp.z - forward.y) * s
        q.y = (forward.x - right.z) * s
        q.z = (right.y - newUp.x) * s
    } else {
        if right.x > newUp.y, right.x > forward.z {
            let s: Float = 2.0 * sqrt(1.0 + right.x - newUp.y - forward.z)
            q.w = (newUp.z - forward.y) / s
            q.x = 0.25 * s
            q.y = (newUp.x + right.y) / s
            q.z = (forward.x + right.z) / s

        } else if newUp.y > forward.z {
            let s: Float = 2.0 * sqrt(1.0 + newUp.y - right.x - forward.z)
            q.w = (forward.x - right.z) / s
            q.x = (newUp.x + right.y) / s
            q.y = 0.25 * s
            q.z = (forward.y + newUp.z) / s

        } else {
            let s: Float = 2.0 * sqrt(1.0 + forward.z - right.x - newUp.y)
            q.w = (right.y - newUp.x) / s
            q.x = (forward.x + right.z) / s
            q.y = (forward.y + newUp.z) / s
            q.z = 0.25 * s
        }
    }

    return q
}

public func getRotationQuaternion(axis: simd_float3, radians: Float) -> quaternion {
    let t: Float = radians * 0.5
    return quaternion(x: axis.x * sinf(t), y: axis.y * sinf(t), z: axis.z * sinf(t), w: cosf(t))
}

public func forwardDirectionVector(from q: quaternion) -> simd_float3 {
    var direction = simd_float3(0.0, 0.0, 0.0)
    direction.x = 2.0 * (q.x * q.z - q.w * q.y)
    direction.y = 2.0 * (q.y * q.z + q.w * q.x)
    direction.z = 1.0 - 2.0 * ((q.x * q.x) + (q.y * q.y))

    direction = simd_normalize(direction)
    return direction
}

public func upDirectionVector(from q: quaternion) -> simd_float3 {
    var direction = simd_float3(0.0, 0.0, 0.0)
    direction.x = 2.0 * (q.x * q.y + q.w * q.z)
    direction.y = 1.0 - 2.0 * ((q.x * q.x) + (q.z * q.z))
    direction.z = 2.0 * (q.y * q.z - q.w * q.x)

    direction = simd_normalize(direction)
    // Negate for a right-handed coordinate system
    return direction
}

public func rightDirectionVector(from q: quaternion) -> simd_float3 {
    var direction = simd_float3(0.0, 0.0, 0.0)
    direction.x = 1.0 - 2.0 * ((q.y * q.y) + (q.z * q.z))
    direction.y = 2.0 * (q.x * q.y - q.w * q.z)
    direction.z = 2.0 * (q.x * q.z + q.w * q.y)

    direction = simd_normalize(direction)
    // Negate for a right-handed coordinate system
    return direction
}

public func rotateVectorUsingQuaternion(q: quaternion, v: simd_float3) -> simd_float3 {
    let qp = simd_float3(q.x, q.y, q.z)
    let w: Float = q.w

    let v: simd_float3 =
        2.0 * simd_dot(qp, v) * qp + ((w * w) - simd_dot(qp, qp)) * v + 2 * w * simd_cross(qp, v)

    return v
}

public func transformQuaternionToMatrix3x3(q: quaternion) -> matrix_float3x3 {
    /*
     // 3x3 matrix - column major. X vector is 0, 1, 2, etc.
     //    0    3    6
     //    1    4    7
     //    2    5    8

     */

    var m = simd_float3x3.init(diagonal: simd_float3(1.0, 1.0, 1.0))

    m.columns.0.x = 2 * (q.w * q.w + q.x * q.x) - 1
    m.columns.1.x = 2 * (q.x * q.y - q.w * q.z)
    m.columns.2.x = 2 * (q.x * q.z + q.w * q.y)

    m.columns.0.y = 2 * (q.x * q.y + q.w * q.z)
    m.columns.1.y = 2 * (q.w * q.w + q.y * q.y) - 1
    m.columns.2.y = 2 * (q.y * q.z - q.w * q.x)

    m.columns.0.z = 2 * (q.x * q.z - q.w * q.y)
    m.columns.1.z = 2 * (q.y * q.z + q.w * q.x)
    m.columns.2.z = 2 * (q.w * q.w + q.z * q.z) - 1

    return m
}

public func transformMatrix3nToQuaternion(m: matrix_float3x3) -> quaternion {
    // 3x3 matrix - column major. X vector is 0, 1, 2, etc.
    //    0    3    6
    //    1    4    7
    //    2    5    8

    // calculate the sum of the diagonal elements
    let trace: Float = m.columns.0.x + m.columns.1.y + m.columns.2.z
    var q: quaternion = quaternion_identity()

    if trace > 0 { // s=4*qw
        q.w = 0.5 * sqrt(1 + trace)
        let S: Float = 0.25 / q.w

        q.x = S * (m.columns.1.z - m.columns.2.y)
        q.y = S * (m.columns.2.x - m.columns.0.z)
        q.z = S * (m.columns.0.y - m.columns.1.x)

    } else if m.columns.0.x > m.columns.1.y, m.columns.0.x > m.columns.2.z { // s=4*qx
        q.x = 0.5 * sqrt(1 + m.columns.0.x - m.columns.1.y - m.columns.2.z)
        let X: Float = 0.25 / q.x

        q.y = X * (m.columns.1.x + m.columns.0.y)
        q.z = X * (m.columns.2.x + m.columns.0.z)
        q.w = X * (m.columns.1.z - m.columns.2.y)

    } else if m.columns.1.y > m.columns.2.z { // s=4*qy
        q.y = 0.5 * sqrt(1 - m.columns.0.x + m.columns.1.y - m.columns.2.z)
        let Y: Float = 0.25 / q.y
        q.x = Y * (m.columns.1.x + m.columns.0.y)
        q.z = Y * (m.columns.2.y + m.columns.1.z)
        q.w = Y * (m.columns.2.x - m.columns.0.z)

    } else { // s=4*qz
        q.z = 0.5 * sqrt(1 - m.columns.0.x - m.columns.1.y + m.columns.2.z)
        let Z: Float = 0.25 / q.z
        q.x = Z * (m.columns.2.x + m.columns.0.z)
        q.y = Z * (m.columns.2.y + m.columns.1.z)
        q.w = Z * (m.columns.0.y - m.columns.1.x)
    }

    return q
}

public func transformQuaternionToEulerAngles(q: quaternion) -> (pitch: Float, yaw: Float, roll: Float) {
    // 3x3 matrix - column major. X vector is 0, 1, 2, etc.
    //    0    3    6
    //    1    4    7
    //    2    5    8

    var x: Float = 0.0
    var y: Float = 0.0
    var z: Float = 0.0

    let test: Float = 2 * (q.x * q.z - q.w * q.y)

    if test != 1, test != -1 {
        x = atan2(q.y * q.z + q.w * q.x, 0.5 - (q.x * q.x + q.y * q.y))
        y = asin(-2 * (q.x * q.z - q.w * q.y))
        z = atan2(q.x * q.y + q.w * q.z, 0.5 - (q.y * q.y + q.z * q.z))

    } else if test == 1 {
        z = atan2(q.x * q.y + q.w * q.z, 0.5 - (q.y * q.y + q.z * q.z))
        y = -.pi / 2.0
        x = -z + atan2(q.x * q.y - q.w * q.z, q.x * q.z + q.w * q.y)

    } else if test == -1 {
        z = atan2(q.x * q.y + q.w * q.z, 0.5 - (q.y * q.y + q.z * q.z))
        y = .pi / 2.0
        x = z + atan2(q.x * q.y - q.w * q.z, q.x * q.z + q.w * q.y)
    }

    x = radiansToDegrees(radians: x)
    y = radiansToDegrees(radians: y)
    z = radiansToDegrees(radians: z)

    return (pitch: x, yaw: y, roll: z)
}

public func transformEulerAnglesToQuaternion(pitch: Float, yaw: Float, roll: Float) -> quaternion {
    var x: Float = convertToPositiveAngle(degrees: pitch)
    var y: Float = convertToPositiveAngle(degrees: yaw)
    var z: Float = convertToPositiveAngle(degrees: roll)

    x = degreesToRadians(degrees: x)
    y = degreesToRadians(degrees: y)
    z = degreesToRadians(degrees: z)

    x = x / 2.0
    y = y / 2.0
    z = z / 2.0

    var q: quaternion = quaternion_identity()

    q.w = cos(z) * cos(y) * cos(x) + sin(z) * sin(y) * sin(x)
    q.x = cos(z) * cos(y) * sin(x) - sin(z) * sin(y) * cos(x)
    q.y = cos(z) * sin(y) * cos(x) + sin(z) * cos(y) * sin(x)
    q.z = sin(z) * cos(y) * cos(x) - cos(z) * sin(y) * sin(x)

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
