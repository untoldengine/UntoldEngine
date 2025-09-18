//
//  EntityAABBTest.swift
//
//
//  Created by Harold Serrano on 9/17/25.
//

import Foundation
import simd
@testable import UntoldEngine
import XCTest

final class EntityAABBTest: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }
    
    private func makeTransform(translation t: simd_float3,
                               rotationZDegrees rz: Float = 0,
                               scale s: simd_float3 = .init(repeating: 1)) -> simd_float4x4 {
        let rad = rz * .pi / 180
        let c = cos(rad), n = sin(rad)
        let R = simd_float3x3(columns: (
            simd_float3( c,  n, 0),
            simd_float3(-n,  c, 0),
            simd_float3( 0,  0, 1)
        ))
        // L = R * S → scale each rotation column by s.x/y/z
        let c0 = simd_float3(R.columns.0 * s.x)
        let c1 = simd_float3(R.columns.1 * s.y)
        let c2 = simd_float3(R.columns.2 * s.z)
        return simd_float4x4(columns: (
            simd_float4(c0, 0),
            simd_float4(c1, 0),
            simd_float4(c2, 0),
            simd_float4(t,  1)
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
                                   file: StaticString = #filePath, line: UInt = #line) {
        approxEqual(aMin, bMin, tol: tol, file: file, line: line)
        approxEqual(aMax, bMax, tol: tol, file: file, line: line)
    }
    
    func test_MinMax_identity() {
            let localMin = simd_float3(-1, -2, -3)
            let localMax = simd_float3( 1,  2,  3)
            let M = matrix_identity_float4x4

            let (outMin, outMax) = worldAABB_MinMax(localMin: localMin, localMax: localMax, worldMatrix: M)
            approxEqualMinMax(outMin, outMax, localMin, localMax)
        }
    
    func test_CenterExtent_identity() {
            let localMin = simd_float3(-1, -2, -3)
            let localMax = simd_float3( 1,  2,  3)
            let M = matrix_identity_float4x4

            let (c, e) = worldAABB_CenterExtent(localMin: localMin, localMax: localMax, worldMatrix: M)
            approxEqual(c, .init(0,0,0))
            approxEqual(e, .init(1,2,3))
        }
    
    
    func test_makeObjectAABB_packsFields() {
            let localMin = simd_float3(-1, -2, -3)
            let localMax = simd_float3( 3,  4,  5)
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
    
}
