//
//  GroundPickingSystemTests.swift
//  UntoldEngineTests
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import simd
@testable import UntoldEngine
import XCTest

final class GroundPickingSystemTests: XCTestCase {
    override func setUp() {
        super.setUp()
        resetEngineTestState()
        SceneRootTransform.shared.position = .zero
        SceneRootTransform.shared.rotation = simd_quatf()
        SceneRootTransform.shared.scale = .one
        SceneRootTransform.shared.updateIfNeeded()
    }

    override func tearDown() {
        SceneRootTransform.shared.position = .zero
        SceneRootTransform.shared.rotation = simd_quatf()
        SceneRootTransform.shared.scale = .one
        SceneRootTransform.shared.updateIfNeeded()
        super.tearDown()
    }

    // MARK: - pickGroundPosition

    func testPickGroundPositionBasicHit() {
        // Ray pointing downward from y=5 should hit the ground at y=0.
        let hit = pickGroundPosition(
            rayOrigin: simd_float3(3, 5, 7),
            rayDirection: simd_float3(0, -1, 0)
        )

        guard let hit else {
            XCTFail("Expected a valid ground hit")
            return
        }

        XCTAssertEqual(hit.worldPosition.x, 3.0, accuracy: 0.0001)
        XCTAssertEqual(hit.worldPosition.y, 0.0, accuracy: 0.0001)
        XCTAssertEqual(hit.worldPosition.z, 7.0, accuracy: 0.0001)
        XCTAssertEqual(hit.distance, 5.0, accuracy: 0.0001)
    }

    func testPickGroundPositionCustomPlaneY() {
        let hit = pickGroundPosition(
            rayOrigin: simd_float3(0, 10, 0),
            rayDirection: simd_float3(0, -1, 0),
            planeY: 2.0
        )

        guard let hit else {
            XCTFail("Expected a valid ground hit")
            return
        }

        XCTAssertEqual(hit.worldPosition.y, 2.0, accuracy: 0.0001)
        XCTAssertEqual(hit.distance, 8.0, accuracy: 0.0001)
    }

    func testPickGroundPositionDiagonalRay() {
        // Ray at 45° from y=10 should hit ground at an offset.
        let hit = pickGroundPosition(
            rayOrigin: simd_float3(0, 10, 0),
            rayDirection: simd_float3(1, -1, 0)
        )

        guard let hit else {
            XCTFail("Expected a valid ground hit")
            return
        }

        XCTAssertEqual(hit.worldPosition.x, 10.0, accuracy: 0.0001)
        XCTAssertEqual(hit.worldPosition.y, 0.0, accuracy: 0.0001)
        XCTAssertEqual(hit.worldPosition.z, 0.0, accuracy: 0.0001)
    }

    func testPickGroundPositionMissesWhenParallel() {
        // Ray parallel to ground should not hit.
        let hit = pickGroundPosition(
            rayOrigin: simd_float3(0, 5, 0),
            rayDirection: simd_float3(1, 0, 0)
        )

        XCTAssertNil(hit, "Ray parallel to the ground plane should not produce a hit")
    }

    func testPickGroundPositionMissesWhenPointingAway() {
        // Ray pointing upward from above ground should not hit.
        let hit = pickGroundPosition(
            rayOrigin: simd_float3(0, 5, 0),
            rayDirection: simd_float3(0, 1, 0)
        )

        XCTAssertNil(hit, "Ray pointing away from the ground should not produce a hit")
    }

    func testPickGroundPositionReturnsNilForZeroDirection() {
        let hit = pickGroundPosition(
            rayOrigin: simd_float3(0, 5, 0),
            rayDirection: simd_float3(0, 0, 0)
        )

        XCTAssertNil(hit)
    }

    func testPickGroundPositionReturnsNilForNaNDirection() {
        let hit = pickGroundPosition(
            rayOrigin: simd_float3(0, 5, 0),
            rayDirection: simd_float3(.nan, 0, -1)
        )

        XCTAssertNil(hit)
    }

    // MARK: - pickPlanePosition

    func testPickPlanePositionArbitraryPlane() {
        // Vertical wall at z=5 facing -z.
        let hit = pickPlanePosition(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(0, 0, 1),
            planePoint: simd_float3(0, 0, 5),
            planeNormal: simd_float3(0, 0, -1)
        )

        guard let hit else {
            XCTFail("Expected a valid plane hit")
            return
        }

        XCTAssertEqual(hit.worldPosition.x, 0.0, accuracy: 0.0001)
        XCTAssertEqual(hit.worldPosition.y, 0.0, accuracy: 0.0001)
        XCTAssertEqual(hit.worldPosition.z, 5.0, accuracy: 0.0001)
        XCTAssertEqual(hit.distance, 5.0, accuracy: 0.0001)
    }

    func testPickPlanePositionReturnsNilForZeroNormal() {
        let hit = pickPlanePosition(
            rayOrigin: simd_float3(0, 5, 0),
            rayDirection: simd_float3(0, -1, 0),
            planePoint: simd_float3(0, 0, 0),
            planeNormal: simd_float3(0, 0, 0)
        )

        XCTAssertNil(hit, "Zero plane normal should be rejected")
    }

    // MARK: - SceneRootTransform integration

    func testPickGroundPositionWithSceneRootTranslation() {
        // Shift the scene root so entities appear offset.
        SceneRootTransform.shared.position = simd_float3(10, 0, 0)
        SceneRootTransform.shared.updateIfNeeded()

        let hit = pickGroundPosition(
            rayOrigin: simd_float3(3, 5, 0),
            rayDirection: simd_float3(0, -1, 0)
        )

        guard let hit else {
            XCTFail("Expected a valid ground hit with scene root offset")
            return
        }

        // The hit Y should still be at ground level.
        XCTAssertEqual(hit.worldPosition.y, 0.0, accuracy: 0.001)
        XCTAssertEqual(hit.distance, 5.0, accuracy: 0.001)
    }
}
