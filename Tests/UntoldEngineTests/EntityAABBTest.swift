//
//  EntityAABBTest.swift
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd
@testable import UntoldEngine
import XCTest

@MainActor
final class EntityAABBTest: XCTestCase {
    private func makeTransform(translation t: simd_float3,
                               rotationZDegrees rz: Float = 0,
                               scale s: simd_float3 = .init(repeating: 1)) -> simd_float4x4
    {
        let rad = rz * .pi / 180
        let c = cos(rad), n = sin(rad)
        let R = simd_float3x3(columns: (
            simd_float3(c, n, 0),
            simd_float3(-n, c, 0),
            simd_float3(0, 0, 1)
        ))
        // L = R * S → scale each rotation column by s.x/y/z
        let c0 = simd_float3(R.columns.0 * s.x)
        let c1 = simd_float3(R.columns.1 * s.y)
        let c2 = simd_float3(R.columns.2 * s.z)
        return simd_float4x4(columns: (
            simd_float4(c0, 0),
            simd_float4(c1, 0),
            simd_float4(c2, 0),
            simd_float4(t, 1)
        ))
    }

    private func approxEqual(_ a: simd_float3, _ b: simd_float3, tol: Float = 1e-5, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(a.x, b.x, accuracy: tol, file: file, line: line)
        XCTAssertEqual(a.y, b.y, accuracy: tol, file: file, line: line)
        XCTAssertEqual(a.z, b.z, accuracy: tol, file: file, line: line)
    }

    private func approxEqualMinMax(_ aMin: simd_float3, _ aMax: simd_float3,
                                   _ bMin: simd_float3, _ bMax: simd_float3,
                                   tol: Float = 1e-5,
                                   file: StaticString = #filePath, line: UInt = #line)
    {
        approxEqual(aMin, bMin, tol: tol, file: file, line: line)
        approxEqual(aMax, bMax, tol: tol, file: file, line: line)
    }

    private func bruteForceWorldAABB(localMin: simd_float3,
                                     localMax: simd_float3,
                                     worldMatrix M: simd_float4x4) -> (min: simd_float3, max: simd_float3)
    {
        var worldMin = simd_float3(repeating: Float.infinity)
        var worldMax = simd_float3(repeating: -Float.infinity)

        for i in 0 ..< 8 {
            let localCorner = simd_float3(
                (i & 1) == 0 ? localMin.x : localMax.x,
                (i & 2) == 0 ? localMin.y : localMax.y,
                (i & 4) == 0 ? localMin.z : localMax.z
            )

            let worldCorner4 = M * simd_float4(localCorner, 1.0)
            let worldCorner = simd_float3(worldCorner4.x, worldCorner4.y, worldCorner4.z)
            worldMin = simd_min(worldMin, worldCorner)
            worldMax = simd_max(worldMax, worldCorner)
        }

        return (worldMin, worldMax)
    }

    func test_MinMax_identity() {
        let localMin = simd_float3(-1, -2, -3)
        let localMax = simd_float3(1, 2, 3)
        let M = matrix_identity_float4x4

        let (outMin, outMax) = worldAABB_MinMax(localMin: localMin, localMax: localMax, worldMatrix: M)
        approxEqualMinMax(outMin, outMax, localMin, localMax)
    }

    func test_CenterExtent_identity() {
        let localMin = simd_float3(-1, -2, -3)
        let localMax = simd_float3(1, 2, 3)
        let M = matrix_identity_float4x4

        let (c, e) = worldAABB_CenterExtent(localMin: localMin, localMax: localMax, worldMatrix: M)
        approxEqual(c, .init(0, 0, 0))
        approxEqual(e, .init(1, 2, 3))
    }

    func test_makeObjectAABB_packsFields() {
        let localMin = simd_float3(-1, -2, -3)
        let localMax = simd_float3(3, 4, 5)
        let T = simd_float3(3, -2, 1)
        let M = makeTransform(translation: T, rotationZDegrees: 45, scale: .init(2, 1, 0.5))
        let (c, e) = worldAABB_CenterExtent(localMin: localMin, localMax: localMax, worldMatrix: M)

        let idx: UInt32 = 123, ver: UInt32 = 7
        let aabb = makeObjectAABB(localMin: localMin, localMax: localMax, worldMatrix: M, index: idx, version: ver)

        approxEqual(simd_float3(aabb.center.x, aabb.center.y, aabb.center.z), c)
        approxEqual(simd_float3(aabb.halfExtent.x, aabb.halfExtent.y, aabb.halfExtent.z), e)
        XCTAssertEqual(aabb.center.w, 0)
        XCTAssertEqual(aabb.halfExtent.w, 0)
        XCTAssertEqual(aabb.index, idx)
        XCTAssertEqual(aabb.version, ver)
        XCTAssertEqual(aabb.pad0, 0)
        XCTAssertEqual(aabb.pad1, 0)
    }

    func test_worldAABB_matchesBruteForce_forArbitraryRotationScale() {
        let localMin = simd_float3(-5.0, -2.0, -0.05)
        let localMax = simd_float3(5.0, 2.0, 0.05)
        let rotation = simd_quatf(angle: .pi / 3.0, axis: simd_normalize(simd_float3(0.3, 0.7, 0.2)))

        var scaleMatrix = matrix_identity_float4x4
        scaleMatrix.columns.0.x = 1.0
        scaleMatrix.columns.1.y = 2.0
        scaleMatrix.columns.2.z = 0.5

        var translationMatrix = matrix_identity_float4x4
        translationMatrix.columns.3 = simd_float4(2.0, -1.0, 3.0, 1.0)

        let worldMatrix = translationMatrix * simd_float4x4(rotation) * scaleMatrix

        let expected = bruteForceWorldAABB(localMin: localMin, localMax: localMax, worldMatrix: worldMatrix)
        let (computedMin, computedMax) = worldAABB_MinMax(localMin: localMin, localMax: localMax, worldMatrix: worldMatrix)
        approxEqualMinMax(computedMin, computedMax, expected.min, expected.max, tol: 1e-4)

        let (center, extent) = worldAABB_CenterExtent(localMin: localMin, localMax: localMax, worldMatrix: worldMatrix)
        let rebuiltMin = center - extent
        let rebuiltMax = center + extent
        approxEqualMinMax(rebuiltMin, rebuiltMax, expected.min, expected.max, tol: 1e-4)
    }
}
