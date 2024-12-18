//
//  MathFunctionsTest.swift
//
//
//  Created by Harold Serrano on 12/16/24.
//

import simd
@testable import UntoldEngine
import XCTest

final class MathFunctionsTests: XCTestCase {
    // MARK: - Trigonometric Functions

    func testDegreesToRadians() {
        XCTAssertEqual(degreesToRadians(degrees: 180), .pi, accuracy: 0.0001)
        XCTAssertEqual(degreesToRadians(degrees: 90), .pi / 2, accuracy: 0.0001)
        XCTAssertEqual(degreesToRadians(degrees: 0), 0)
    }

    func testRadiansToDegrees() {
        XCTAssertEqual(radiansToDegrees(radians: .pi), 180, accuracy: 0.0001)
        XCTAssertEqual(radiansToDegrees(radians: .pi / 2), 90, accuracy: 0.0001)
        XCTAssertEqual(radiansToDegrees(radians: 0), 0)
    }

    func testSafeACos() {
        var x1 = 2.0
        XCTAssertEqual(safeACos(x: &x1), acos(1.0), accuracy: 0.0001)
        XCTAssertEqual(x1, 1.0)

        var x2 = -2.0
        XCTAssertEqual(safeACos(x: &x2), acos(-1.0), accuracy: 0.0001)
        XCTAssertEqual(x2, -1.0)

        var x3 = 0.5
        XCTAssertEqual(safeACos(x: &x3), acos(0.5), accuracy: 0.0001)
    }

    func testConvertToPositiveAngle() {
        var angle1 = -450.0
        XCTAssertEqual(convertToPositiveAngle(degrees: &angle1), 270.0, accuracy: 0.0001)

        var angle2 = 720.0
        XCTAssertEqual(convertToPositiveAngle(degrees: &angle2), 0.0, accuracy: 0.0001)
    }

    // MARK: - Float Equality

    func testAreEqualAbs() {
        XCTAssertTrue(areEqualAbs(1.0, 1.0001, uEpsilon: 0.001))
        XCTAssertFalse(areEqualAbs(1.0, 1.01, uEpsilon: 0.001))
    }

    func testAreEqualRel() {
        XCTAssertTrue(areEqualRel(100.0, 100.001, uEpsilon: 0.0001))
        XCTAssertFalse(areEqualRel(100.0, 100.1, uEpsilon: 0.0001))
    }

    func testAreEqual() {
        XCTAssertTrue(areEqual(100.0, 100.001, uEpsilon: 0.001))
        XCTAssertFalse(areEqual(100.0, 101.0, uEpsilon: 0.001))
    }

    // MARK: - Matrix Functions

    func testMatrix4x4Identity() {
        let identity = matrix4x4Identity()
        XCTAssertEqual(identity, matrix_float4x4.identity)
    }

    func testMatrix4x4Translation() {
        let translationMatrix = matrix4x4Translation(1, 2, 3)
        XCTAssertEqual(translationMatrix.columns.3, vector_float4(1, 2, 3, 1))
    }

    func testMatrix4x4Scale() {
        let scaleMatrix = matrix4x4Scale(2, 3, 4)
        XCTAssertEqual(scaleMatrix.columns.0.x, 2)
        XCTAssertEqual(scaleMatrix.columns.1.y, 3)
        XCTAssertEqual(scaleMatrix.columns.2.z, 4)
    }

    func testMatrix4x4Rotation() {
        let angle: Float = .pi / 2
        let axis = simd_float3(0, 1, 0)
        let rotationMatrix = matrix4x4Rotation(radians: angle, axis: axis)
        XCTAssertEqual(rotationMatrix.columns.0.x, 0, accuracy: 0.0001)
    }

    func testMatrixPerspectiveRightHand() {
        let perspectiveMatrix = matrixPerspectiveRightHand(fovyRadians: .pi / 2, aspectRatio: 1, nearZ: 1, farZ: 100)
        XCTAssertEqual(perspectiveMatrix.columns.2.z, 100.0 / (1.0 - 100.0), accuracy: 0.0001)
    }

    // MARK: - Quaternion Tests

    func testQuaternionIdentity() {
        XCTAssertEqual(quaternion_identity(), quaternion(0, 0, 0, 1))
    }

    func testQuaternionNormalize() {
        let q = quaternion(1, 1, 1, 1)
        let normalized = quaternion_normalize(q: q)
        XCTAssertEqual(simd_length(normalized), 1.0, accuracy: 0.0001)
    }

    func testQuaternionMultiply() {
        let q1 = quaternion(0, 0, 0, 1)
        let q2 = quaternion(1, 0, 0, 0)
        let result = quaternion_multiply(q0: q1, q1: q2)
        XCTAssertEqual(result, quaternion(1, 0, 0, 0))
    }

    func testQuaternionLookAt() {
        let eye = simd_float3(0, 0, 0)
        let target = simd_float3(0, 0, -1)
        let up = simd_float3(0, 1, 0)
        let q = quaternion_lookAt(eye: eye, target: target, up: up)
        XCTAssertEqual(q.w, 1, accuracy: 0.0001)
    }

    // MARK: - Ray Tests

    func testRayIntersectsAABB() {
        let rayOrigin = simd_float3(0, 0, 0)
        let rayDir = simd_float3(1, 0, 0)
        let boxMin = simd_float3(-1, -1, -1)
        let boxMax = simd_float3(1, 1, 1)

        var tmin: Float = 0
        XCTAssertTrue(rayIntersectsAABB(rayOrigin: rayOrigin, rayDir: rayDir, boxMin: boxMin, boxMax: boxMax, tmin: &tmin))
    }

    func testRayIntersectPlane() {
        let rayOrigin = simd_float3(0, 0, 0)
        let rayDir = simd_float3(0, 0, -1)
        let planeNormal = simd_float3(0, 0, 1)
        let planeOrigin = simd_float3(0, 0, -5)

        let result = rayIntersectPlane(rayOrigin: rayOrigin, rayDir: rayDir, planeNormal: planeNormal, planeOrigin: planeOrigin)
        XCTAssertTrue(result.intersects)
        XCTAssertEqual(result.intersection, simd_float3(0, 0, -5))
    }
}
