//
//  SceneRootTransformTests.swift
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldEngine
import XCTest


@MainActor
final class SceneRootTransformTests: XCTestCase {
    let srt = SceneRootTransform.shared
    let eps: Float = 1e-4

    override func setUp() async throws {
        // Reset to identity before each test
        srt.position = .zero
        srt.rotation = simd_quatf()
        srt.scale = .one
        srt.updateIfNeeded()
    }

    // MARK: - Identity state

    func testInitialStateIsIdentity() {
        XCTAssertTrue(srt.isIdentity)
        XCTAssertEqual(srt.matrix, simd_float4x4.identity)
        XCTAssertEqual(srt.inverseMatrix, simd_float4x4.identity)
    }

    func testIsIdentityFalseAfterTranslation() {
        srt.position = simd_float3(1, 0, 0)
        XCTAssertFalse(srt.isIdentity)
    }

    func testIsIdentityFalseAfterRotation() {
        srt.rotation = simd_quatf(angle: .pi / 4, axis: simd_float3(0, 1, 0))
        XCTAssertFalse(srt.isIdentity)
    }

    func testIsIdentityFalseAfterScale() {
        srt.scale = simd_float3(2, 2, 2)
        XCTAssertFalse(srt.isIdentity)
    }

    func testIsIdentityTrueAfterReset() {
        srt.position = simd_float3(5, 5, 5)
        srt.updateIfNeeded()
        XCTAssertFalse(srt.isIdentity)

        srt.position = .zero
        XCTAssertTrue(srt.isIdentity)
    }

    // MARK: - updateIfNeeded / dirty flag

    func testUpdateIfNeededComputesMatrix() {
        srt.position = simd_float3(10, 20, 30)
        srt.updateIfNeeded()

        // Translation should appear in column 3
        XCTAssertEqual(srt.matrix.columns.3.x, 10, accuracy: eps)
        XCTAssertEqual(srt.matrix.columns.3.y, 20, accuracy: eps)
        XCTAssertEqual(srt.matrix.columns.3.z, 30, accuracy: eps)
    }

    func testUpdateIfNeededIsIdempotent() {
        srt.position = simd_float3(5, 0, 0)
        srt.updateIfNeeded()
        let matrixAfterFirst = srt.matrix

        // Calling again without changes should produce the same result
        srt.updateIfNeeded()
        XCTAssertEqual(srt.matrix, matrixAfterFirst)
    }

    func testMatrixNotUpdatedBeforeCallingUpdate() {
        // After setUp, matrix is identity
        srt.position = simd_float3(99, 0, 0)
        // matrix should still be identity because updateIfNeeded hasn't been called
        XCTAssertEqual(srt.matrix, simd_float4x4.identity)

        srt.updateIfNeeded()
        XCTAssertEqual(srt.matrix.columns.3.x, 99, accuracy: eps)
    }

    // MARK: - Matrix composition (T * R * S)

    func testPureTranslation() {
        srt.position = simd_float3(3, 4, 5)
        srt.updateIfNeeded()

        let expected = matrix4x4Translation(3, 4, 5)
        assertMatricesEqual(srt.matrix, expected)
    }

    func testPureScale() {
        srt.scale = simd_float3(2, 3, 4)
        srt.updateIfNeeded()

        let expected = matrix4x4Scale(2, 3, 4)
        assertMatricesEqual(srt.matrix, expected)
    }

    func testTranslationAndScale() {
        srt.position = simd_float3(10, 0, 0)
        srt.scale = simd_float3(2, 2, 2)
        srt.updateIfNeeded()

        // T * S: translation in column 3, scale on diagonal
        XCTAssertEqual(srt.matrix.columns.3.x, 10, accuracy: eps)
        XCTAssertEqual(srt.matrix.columns.0.x, 2, accuracy: eps)
        XCTAssertEqual(srt.matrix.columns.1.y, 2, accuracy: eps)
        XCTAssertEqual(srt.matrix.columns.2.z, 2, accuracy: eps)
    }

    // MARK: - Inverse matrix

    func testInverseMatrixIsCorrect() {
        srt.position = simd_float3(10, -5, 3)
        srt.scale = simd_float3(2, 2, 2)
        srt.updateIfNeeded()

        let product = simd_mul(srt.matrix, srt.inverseMatrix)
        assertMatricesEqual(product, simd_float4x4.identity)
    }

    func testInverseMatrixWithRotation() {
        srt.position = simd_float3(1, 2, 3)
        srt.rotation = simd_quatf(angle: .pi / 3, axis: simd_normalize(simd_float3(1, 1, 0)))
        srt.scale = simd_float3(1.5, 1.5, 1.5)
        srt.updateIfNeeded()

        let product = simd_mul(srt.matrix, srt.inverseMatrix)
        assertMatricesEqual(product, simd_float4x4.identity)
    }

    // MARK: - effectiveViewMatrix

    func testEffectiveViewMatrixIdentityPassthrough() {
        let cameraView = matrix4x4Translation(0, 0, -10)
        let result = srt.effectiveViewMatrix(cameraView)
        assertMatricesEqual(result, cameraView)
    }

    func testEffectiveViewMatrixAppliesSceneRoot() {
        srt.position = simd_float3(5, 0, 0)
        srt.updateIfNeeded()

        let cameraView = simd_float4x4.identity
        let result = srt.effectiveViewMatrix(cameraView)

        // effectiveView = cameraView * matrix
        // An entity at origin should appear at (5, 0, 0) through this view
        let entityPos = simd_float4(0, 0, 0, 1)
        let viewPos = simd_mul(result, entityPos)
        XCTAssertEqual(viewPos.x, 5, accuracy: eps)
        XCTAssertEqual(viewPos.y, 0, accuracy: eps)
        XCTAssertEqual(viewPos.z, 0, accuracy: eps)
    }

    func testEffectiveViewMatrixDirection() {
        // Scene moved right by 10 → entity at origin should appear at +10 in X
        srt.position = simd_float3(10, 0, 0)
        srt.updateIfNeeded()

        let cameraView = simd_float4x4.identity
        let result = srt.effectiveViewMatrix(cameraView)
        let viewPos = simd_mul(result, simd_float4(0, 0, 0, 1))

        XCTAssertEqual(viewPos.x, 10, accuracy: eps, "Scene shift should move entities in the SAME direction")
    }

    // MARK: - effectiveCameraPosition

    func testEffectiveCameraPositionIdentityPassthrough() {
        let camPos = simd_float3(0, 5, -10)
        let result = srt.effectiveCameraPosition(camPos)
        XCTAssertEqual(result.x, camPos.x, accuracy: eps)
        XCTAssertEqual(result.y, camPos.y, accuracy: eps)
        XCTAssertEqual(result.z, camPos.z, accuracy: eps)
    }

    func testEffectiveCameraPositionWithTranslation() {
        // Scene at (10, 0, 0). Camera at world (0, 0, 0).
        // In entity space, camera should be at (-10, 0, 0).
        srt.position = simd_float3(10, 0, 0)
        srt.updateIfNeeded()

        let result = srt.effectiveCameraPosition(simd_float3(0, 0, 0))
        XCTAssertEqual(result.x, -10, accuracy: eps)
        XCTAssertEqual(result.y, 0, accuracy: eps)
        XCTAssertEqual(result.z, 0, accuracy: eps)
    }

    func testEffectiveCameraPositionWithScale() {
        // Scene scaled 2x. Camera at world (4, 0, 0).
        // inverse(S(2)) = S(0.5), so entity-space camera = (2, 0, 0)
        srt.scale = simd_float3(2, 2, 2)
        srt.updateIfNeeded()

        let result = srt.effectiveCameraPosition(simd_float3(4, 0, 0))
        XCTAssertEqual(result.x, 2, accuracy: eps)
        XCTAssertEqual(result.y, 0, accuracy: eps)
        XCTAssertEqual(result.z, 0, accuracy: eps)
    }

    // MARK: - effectiveLightMatrix

    func testEffectiveLightMatrixIdentityPassthrough() {
        let lightMatrix = matrix4x4Translation(0, 100, 0)
        let result = srt.effectiveLightMatrix(lightMatrix)
        assertMatricesEqual(result, lightMatrix)
    }

    func testEffectiveLightMatrixAppliesSceneRoot() {
        srt.position = simd_float3(5, 0, 0)
        srt.updateIfNeeded()

        let lightMatrix = simd_float4x4.identity
        let result = srt.effectiveLightMatrix(lightMatrix)

        // lightMatrix * matrix — same composition as effectiveViewMatrix
        let expected = simd_mul(lightMatrix, srt.matrix)
        assertMatricesEqual(result, expected)
    }

    // MARK: - View + CameraPosition consistency

    func testViewAndCameraPositionAreConsistent() {
        // The view direction computed in the shader as normalize(cameraPos - surfacePos)
        // must be consistent with the view matrix transform.
        // surfacePos is in entity space (un-shifted), so cameraPos must also be in entity space.
        srt.position = simd_float3(7, -3, 2)
        srt.updateIfNeeded()

        let worldCamPos = simd_float3(0, 10, -20)

        // Build a simple lookAt-style view for testing
        let cameraView = matrix4x4Translation(-worldCamPos.x, -worldCamPos.y, -worldCamPos.z)

        let effView = srt.effectiveViewMatrix(cameraView)
        let effCamPos = srt.effectiveCameraPosition(worldCamPos)

        // Transform an entity at origin through the effective view
        let entityOrigin = simd_float4(0, 0, 0, 1)
        let viewSpacePos = simd_mul(effView, entityOrigin)

        // The vector from effectiveCameraPosition to entity origin (in entity space)
        let entitySpaceViewDir = simd_float3(0, 0, 0) - effCamPos

        // viewSpacePos should point in a direction consistent with entitySpaceViewDir
        let viewDir3 = simd_float3(viewSpacePos.x, viewSpacePos.y, viewSpacePos.z)
        let dotProduct = simd_dot(simd_normalize(viewDir3), simd_normalize(entitySpaceViewDir))
        XCTAssertGreaterThan(dotProduct, 0.99, "View matrix and camera position should agree on view direction")
    }

    // MARK: - Helpers

    private func assertMatricesEqual(_ a: simd_float4x4, _ b: simd_float4x4,
                                     accuracy: Float = 1e-4, file: StaticString = #file, line: UInt = #line)
    {
        for col in 0 ..< 4 {
            for row in 0 ..< 4 {
                XCTAssertEqual(a[col][row], b[col][row], accuracy: accuracy,
                               "Mismatch at [\(col)][\(row)]", file: file, line: line)
            }
        }
    }
}
