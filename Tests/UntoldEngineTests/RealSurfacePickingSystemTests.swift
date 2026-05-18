//
//  RealSurfacePickingSystemTests.swift
//  UntoldEngineTests
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
final class RealSurfacePickingSystemTests: XCTestCase {
    override func setUp() async throws {
        resetEngineTestState()
        SceneRootTransform.shared.position = .zero
        SceneRootTransform.shared.rotation = simd_quatf()
        SceneRootTransform.shared.scale = .one
        SceneRootTransform.shared.updateIfNeeded()
        RealSurfacePlaneStore.shared.clear()
    }

    override func tearDown() async throws {
        RealSurfacePlaneStore.shared.clear()
        SceneRootTransform.shared.position = .zero
        SceneRootTransform.shared.rotation = simd_quatf()
        SceneRootTransform.shared.scale = .one
        SceneRootTransform.shared.updateIfNeeded()
    }

    // MARK: - Helpers

    /// Create a horizontal floor plane at a given Y height, centered at (cx, y, cz),
    /// with the given width (X) and depth (Z) extents.
    private func makeHorizontalPlane(
        id: UUID = UUID(),
        centerX: Float = 0,
        centerY: Float = 0,
        centerZ: Float = 0,
        width: Float = 10,
        depth: Float = 10,
        classification: RealSurfaceKind = .floor
    ) -> TrackedPlane {
        // ARKit horizontal plane: local Y is up (normal), plane lies in XZ.
        // Translation places center in world space.
        let transform = float4x4(
            simd_float4(1, 0, 0, 0),
            simd_float4(0, 1, 0, 0),
            simd_float4(0, 0, 1, 0),
            simd_float4(centerX, centerY, centerZ, 1)
        )
        return TrackedPlane(
            id: id,
            originFromAnchorTransform: transform,
            extentWidth: width,
            extentHeight: depth,
            alignment: .horizontal,
            classification: classification
        )
    }

    /// Create a vertical wall plane at a given position, facing along -Z by default.
    private func makeVerticalPlane(
        id: UUID = UUID(),
        centerX: Float = 0,
        centerY: Float = 1,
        centerZ: Float = 5,
        width: Float = 4,
        height: Float = 3,
        classification: RealSurfaceKind = .wall
    ) -> TrackedPlane {
        // Vertical plane facing -Z: local Y axis = (0, 0, -1) → the plane normal.
        // local X axis = (1, 0, 0), local Z axis = (0, 1, 0) (up).
        let transform = float4x4(
            simd_float4(1, 0, 0, 0), // column 0: local X
            simd_float4(0, 0, -1, 0), // column 1: local Y = normal = -Z
            simd_float4(0, 1, 0, 0), // column 2: local Z = world up
            simd_float4(centerX, centerY, centerZ, 1)
        )
        return TrackedPlane(
            id: id,
            originFromAnchorTransform: transform,
            extentWidth: width,
            extentHeight: height,
            alignment: .vertical,
            classification: classification
        )
    }

    // MARK: - Basic Hit

    func testBasicHorizontalFloorHit() {
        let plane = makeHorizontalPlane(centerY: 0, width: 10, depth: 10)
        RealSurfacePlaneStore.shared.update(planes: [plane])

        let hit = pickRealSurfacePosition(
            rayOrigin: simd_float3(0, 5, 0),
            rayDirection: simd_float3(0, -1, 0),
            filter: .horizontalAny
        )

        guard let hit else {
            XCTFail("Expected a valid surface hit")
            return
        }

        XCTAssertEqual(hit.worldPosition.x, 0.0, accuracy: 0.001)
        XCTAssertEqual(hit.worldPosition.y, 0.0, accuracy: 0.001)
        XCTAssertEqual(hit.worldPosition.z, 0.0, accuracy: 0.001)
        XCTAssertEqual(hit.distance, 5.0, accuracy: 0.001)
        XCTAssertEqual(hit.surfaceKind, .floor)
    }

    func testHitAtElevatedPlane() {
        // Floor at y=2.5
        let plane = makeHorizontalPlane(centerY: 2.5, width: 10, depth: 10)
        RealSurfacePlaneStore.shared.update(planes: [plane])

        let hit = pickRealSurfacePosition(
            rayOrigin: simd_float3(1, 8, 1),
            rayDirection: simd_float3(0, -1, 0),
            filter: .horizontalAny
        )

        guard let hit else {
            XCTFail("Expected a valid surface hit")
            return
        }

        XCTAssertEqual(hit.worldPosition.y, 2.5, accuracy: 0.001)
        XCTAssertEqual(hit.distance, 5.5, accuracy: 0.001)
    }

    // MARK: - Misses

    func testMissWhenParallel() {
        let plane = makeHorizontalPlane()
        RealSurfacePlaneStore.shared.update(planes: [plane])

        let hit = pickRealSurfacePosition(
            rayOrigin: simd_float3(0, 5, 0),
            rayDirection: simd_float3(1, 0, 0),
            filter: .horizontalAny
        )

        XCTAssertNil(hit, "Ray parallel to the plane should not produce a hit")
    }

    func testMissWhenPointingAway() {
        let plane = makeHorizontalPlane()
        RealSurfacePlaneStore.shared.update(planes: [plane])

        let hit = pickRealSurfacePosition(
            rayOrigin: simd_float3(0, 5, 0),
            rayDirection: simd_float3(0, 1, 0),
            filter: .horizontalAny
        )

        XCTAssertNil(hit, "Ray pointing away from the plane should not produce a hit")
    }

    func testMissWithZeroDirection() {
        let plane = makeHorizontalPlane()
        RealSurfacePlaneStore.shared.update(planes: [plane])

        let hit = pickRealSurfacePosition(
            rayOrigin: simd_float3(0, 5, 0),
            rayDirection: simd_float3(0, 0, 0)
        )

        XCTAssertNil(hit)
    }

    func testMissWhenNoPlanesTracked() {
        // Store is empty.
        let hit = pickRealSurfacePosition(
            rayOrigin: simd_float3(0, 5, 0),
            rayDirection: simd_float3(0, -1, 0)
        )

        XCTAssertNil(hit)
    }

    // MARK: - Extent Clipping

    func testMissWhenOutsidePlaneExtent() {
        // Small 2×2 plane centered at origin.
        let plane = makeHorizontalPlane(width: 2, depth: 2)
        RealSurfacePlaneStore.shared.update(planes: [plane])

        // Ray hits the infinite plane at (5, 0, 0) — outside the 2×2 extent.
        let hit = pickRealSurfacePosition(
            rayOrigin: simd_float3(5, 3, 0),
            rayDirection: simd_float3(0, -1, 0),
            filter: .horizontalAny
        )

        XCTAssertNil(hit, "Hit outside plane extent should be rejected")
    }

    func testHitInsidePlaneExtent() {
        // 4×4 plane centered at origin.
        let plane = makeHorizontalPlane(width: 4, depth: 4)
        RealSurfacePlaneStore.shared.update(planes: [plane])

        // Ray hits at (1.5, 0, 1.5) — inside the 4×4 extent (half = 2).
        let hit = pickRealSurfacePosition(
            rayOrigin: simd_float3(1.5, 3, 1.5),
            rayDirection: simd_float3(0, -1, 0),
            filter: .horizontalAny
        )

        XCTAssertNotNil(hit)
        XCTAssertEqual(hit?.worldPosition.x ?? 0, 1.5, accuracy: 0.001)
        XCTAssertEqual(hit?.worldPosition.z ?? 0, 1.5, accuracy: 0.001)
    }

    // MARK: - Multiple Planes — Closest Hit

    func testClosestPlaneWins() {
        // Two horizontal planes: one at y=1, one at y=3.
        let lower = makeHorizontalPlane(centerY: 1, width: 10, depth: 10, classification: .floor)
        let upper = makeHorizontalPlane(centerY: 3, width: 10, depth: 10, classification: .table)
        RealSurfacePlaneStore.shared.update(planes: [lower, upper])

        // Ray from y=5 going down — should hit upper plane first.
        let hit = pickRealSurfacePosition(
            rayOrigin: simd_float3(0, 5, 0),
            rayDirection: simd_float3(0, -1, 0),
            filter: .horizontalAny
        )

        guard let hit else {
            XCTFail("Expected a hit")
            return
        }

        XCTAssertEqual(hit.worldPosition.y, 3.0, accuracy: 0.001)
        XCTAssertEqual(hit.surfaceKind, .table)
        XCTAssertEqual(hit.distance, 2.0, accuracy: 0.001)
    }

    func testFloorOnlySkipsCloserTableAndHitsFloor() {
        // Paired assertion for testClosestPlaneWins: the table is closer, but .floorOnly
        // skips it and the ray continues to the floor.
        let floor = makeHorizontalPlane(centerY: 1, width: 10, depth: 10, classification: .floor)
        let table = makeHorizontalPlane(centerY: 3, width: 10, depth: 10, classification: .table)
        RealSurfacePlaneStore.shared.update(planes: [floor, table])

        let hit = pickRealSurfacePosition(
            rayOrigin: simd_float3(0, 5, 0),
            rayDirection: simd_float3(0, -1, 0),
            filter: .floorOnly
        )

        XCTAssertEqual(hit?.worldPosition.y ?? -1, 1.0, accuracy: 0.001)
        XCTAssertEqual(hit?.surfaceKind, .floor)
    }

    func testTableOnlySkipsFloor() {
        let floor = makeHorizontalPlane(centerY: 0, width: 10, depth: 10, classification: .floor)
        let table = makeHorizontalPlane(centerY: 2, width: 10, depth: 10, classification: .table)
        RealSurfacePlaneStore.shared.update(planes: [floor, table])

        let hit = pickRealSurfacePosition(
            rayOrigin: simd_float3(0, 5, 0),
            rayDirection: simd_float3(0, -1, 0),
            filter: .tableOnly
        )

        XCTAssertEqual(hit?.worldPosition.y ?? -1, 2.0, accuracy: 0.001)
        XCTAssertEqual(hit?.surfaceKind, .table)
    }

    // MARK: - Filter by Kind

    func testKindsFilterPicksClosestEligible() {
        // With kinds: [.floor, .table], the table is closer and should win.
        let floor = makeHorizontalPlane(centerY: 0, width: 10, depth: 10, classification: .floor)
        let table = makeHorizontalPlane(centerY: 2, width: 10, depth: 10, classification: .table)
        RealSurfacePlaneStore.shared.update(planes: [floor, table])

        let hit = pickRealSurfacePosition(
            rayOrigin: simd_float3(0, 5, 0),
            rayDirection: simd_float3(0, -1, 0),
            filter: RealSurfaceFilter(alignment: .horizontal, kinds: [.floor, .table])
        )

        XCTAssertEqual(hit?.worldPosition.y ?? -1, 2.0, accuracy: 0.001)
        XCTAssertEqual(hit?.surfaceKind, .table)
    }

    func testKindsFilterExcludesNonMatchingClassification() {
        // Ceiling is horizontal but not in the kinds set — should be skipped.
        let ceiling = makeHorizontalPlane(centerY: 3, width: 10, depth: 10, classification: .ceiling)
        let floor = makeHorizontalPlane(centerY: 0, width: 10, depth: 10, classification: .floor)
        RealSurfacePlaneStore.shared.update(planes: [ceiling, floor])

        let hit = pickRealSurfacePosition(
            rayOrigin: simd_float3(0, 5, 0),
            rayDirection: simd_float3(0, -1, 0),
            filter: RealSurfaceFilter(alignment: .horizontal, kinds: [.floor, .table])
        )

        // Ceiling at y=3 is closer but excluded; floor at y=0 should be returned.
        XCTAssertEqual(hit?.worldPosition.y ?? -1, 0.0, accuracy: 0.001)
        XCTAssertEqual(hit?.surfaceKind, .floor)
    }

    // MARK: - Hit Y-Range Filter

    func testHitYRangeExcludesFloorWhenTargetingDesk() {
        // Floor at y=0 is inside the ray path but outside the desk Y-range — should be skipped.
        let floor = makeHorizontalPlane(centerY: 0, width: 10, depth: 10, classification: .floor)
        RealSurfacePlaneStore.shared.update(planes: [floor])

        let hit = pickRealSurfacePosition(
            rayOrigin: simd_float3(0, 5, 0),
            rayDirection: simd_float3(0, -1, 0),
            filter: .horizontalAny,
            hitYRange: 0.5 ... 1.1
        )

        XCTAssertNil(hit, "Floor at y=0 should be excluded by hitYRange 0.5...1.1")
    }

    func testHitYRangeAcceptsHitWithinRange() {
        let desk = makeHorizontalPlane(centerY: 0.75, width: 10, depth: 10, classification: .unknown)
        RealSurfacePlaneStore.shared.update(planes: [desk])

        let hit = pickRealSurfacePosition(
            rayOrigin: simd_float3(0, 5, 0),
            rayDirection: simd_float3(0, -1, 0),
            filter: .horizontalAny,
            hitYRange: 0.5 ... 1.1
        )

        XCTAssertNotNil(hit, "Plane at y=0.75 should be accepted by hitYRange 0.5...1.1")
        XCTAssertEqual(hit?.worldPosition.y ?? -1, 0.75, accuracy: 0.001)
    }

    func testHitYRangeSkipsCloserPlaneOutsideRangeAndHitsFarther() {
        // Table at y=3 is closer but above the desk range; floor at y=0.75 is within range.
        let aboveRange = makeHorizontalPlane(centerY: 3, width: 10, depth: 10, classification: .table)
        let inRange = makeHorizontalPlane(centerY: 0.75, width: 10, depth: 10, classification: .unknown)
        RealSurfacePlaneStore.shared.update(planes: [aboveRange, inRange])

        let hit = pickRealSurfacePosition(
            rayOrigin: simd_float3(0, 5, 0),
            rayDirection: simd_float3(0, -1, 0),
            filter: .horizontalAny,
            hitYRange: 0.5 ... 1.1
        )

        XCTAssertEqual(hit?.worldPosition.y ?? -1, 0.75, accuracy: 0.001)
    }

    // MARK: - Filter by Alignment

    func testHorizontalFilterIgnoresVerticalPlanes() {
        let floor = makeHorizontalPlane(centerY: 0, width: 10, depth: 10)
        let wall = makeVerticalPlane()
        RealSurfacePlaneStore.shared.update(planes: [floor, wall])

        // Ray aimed at the wall (going toward +Z), but filtering horizontalAny.
        let hit = pickRealSurfacePosition(
            rayOrigin: simd_float3(0, 1, 0),
            rayDirection: simd_float3(0, 0, 1),
            filter: .horizontalAny
        )

        XCTAssertNil(hit, "Horizontal filter should reject the vertical wall hit")
    }

    func testVerticalFilterIgnoresHorizontalPlanes() {
        let floor = makeHorizontalPlane(centerY: 0, width: 10, depth: 10)
        let wall = makeVerticalPlane()
        RealSurfacePlaneStore.shared.update(planes: [floor, wall])

        // Ray going down — would hit the floor, but verticalAny filter skips it.
        let hit = pickRealSurfacePosition(
            rayOrigin: simd_float3(0, 5, 0),
            rayDirection: simd_float3(0, -1, 0),
            filter: .verticalAny
        )

        XCTAssertNil(hit, "Vertical filter should reject the horizontal floor hit")
    }

    func testAnyFilterAcceptsBothAlignments() {
        let floor = makeHorizontalPlane(centerY: 0, width: 10, depth: 10)
        RealSurfacePlaneStore.shared.update(planes: [floor])

        let hit = pickRealSurfacePosition(
            rayOrigin: simd_float3(0, 3, 0),
            rayDirection: simd_float3(0, -1, 0),
            filter: .any
        )

        XCTAssertNotNil(hit)
    }

    // MARK: - SceneRootTransform Integration

    func testHitWithSceneRootTranslation() {
        SceneRootTransform.shared.position = simd_float3(10, 0, 0)
        SceneRootTransform.shared.updateIfNeeded()

        let plane = makeHorizontalPlane(centerY: 0, width: 20, depth: 20)
        RealSurfacePlaneStore.shared.update(planes: [plane])

        let hit = pickRealSurfacePosition(
            rayOrigin: simd_float3(2, 4, 0),
            rayDirection: simd_float3(0, -1, 0),
            filter: .horizontalAny
        )

        guard let hit else {
            XCTFail("Expected a valid hit with scene root offset")
            return
        }

        // The hit Y should still be at the real-world plane level.
        XCTAssertEqual(hit.worldPosition.y, 0.0, accuracy: 0.01)
        XCTAssertEqual(hit.distance, 4.0, accuracy: 0.01)
    }

    // MARK: - Diagonal Ray

    func testDiagonalRayHit() {
        let plane = makeHorizontalPlane(centerY: 0, width: 30, depth: 30)
        RealSurfacePlaneStore.shared.update(planes: [plane])

        // 45° ray from y=10.
        let hit = pickRealSurfacePosition(
            rayOrigin: simd_float3(0, 10, 0),
            rayDirection: simd_float3(1, -1, 0),
            filter: .horizontalAny
        )

        guard let hit else {
            XCTFail("Expected a hit for diagonal ray")
            return
        }

        XCTAssertEqual(hit.worldPosition.x, 10.0, accuracy: 0.001)
        XCTAssertEqual(hit.worldPosition.y, 0.0, accuracy: 0.001)
        XCTAssertEqual(hit.worldPosition.z, 0.0, accuracy: 0.001)
    }

    // MARK: - Plane Store

    func testPlaneStoreClear() {
        let plane = makeHorizontalPlane()
        RealSurfacePlaneStore.shared.update(planes: [plane])
        XCTAssertFalse(RealSurfacePlaneStore.shared.snapshot().isEmpty)

        RealSurfacePlaneStore.shared.clear()
        XCTAssertTrue(RealSurfacePlaneStore.shared.snapshot().isEmpty)
    }

    func testPlaneStoreUpdateReplaces() {
        let plane1 = makeHorizontalPlane(centerY: 0)
        let plane2 = makeHorizontalPlane(centerY: 5)
        RealSurfacePlaneStore.shared.update(planes: [plane1, plane2])
        XCTAssertEqual(RealSurfacePlaneStore.shared.snapshot().count, 2)

        let plane3 = makeHorizontalPlane(centerY: 10)
        RealSurfacePlaneStore.shared.update(planes: [plane3])
        XCTAssertEqual(RealSurfacePlaneStore.shared.snapshot().count, 1)
    }

    // MARK: - Max Distance

    func testMaxDistanceRejectsFarHit() {
        let plane = makeHorizontalPlane(centerY: 0, width: 10, depth: 10)
        RealSurfacePlaneStore.shared.update(planes: [plane])

        // Plane is 5m away; maxDistance=3 should reject.
        let miss = pickRealSurfacePosition(
            rayOrigin: simd_float3(0, 5, 0),
            rayDirection: simd_float3(0, -1, 0),
            filter: .horizontalAny,
            maxDistance: 3.0
        )
        XCTAssertNil(miss, "Hit beyond maxDistance should be rejected")
    }

    func testMaxDistanceAcceptsNearHit() {
        let plane = makeHorizontalPlane(centerY: 0, width: 10, depth: 10)
        RealSurfacePlaneStore.shared.update(planes: [plane])

        // Plane is 5m away; maxDistance=6 should accept.
        let hit = pickRealSurfacePosition(
            rayOrigin: simd_float3(0, 5, 0),
            rayDirection: simd_float3(0, -1, 0),
            filter: .horizontalAny,
            maxDistance: 6.0
        )
        XCTAssertNotNil(hit)
        XCTAssertEqual(hit?.distance ?? 0, 5.0, accuracy: 0.001)
    }

    // MARK: - Offset Extent Transform

    func testHitWithOffsetExtentTransform() {
        // Anchor at origin, but extent center is offset 2m in +X.
        let extentOffset = float4x4(
            simd_float4(1, 0, 0, 0),
            simd_float4(0, 1, 0, 0),
            simd_float4(0, 0, 1, 0),
            simd_float4(2, 0, 0, 1)
        )
        let plane = TrackedPlane(
            id: UUID(),
            originFromAnchorTransform: .identity,
            anchorFromExtentTransform: extentOffset,
            extentWidth: 2,
            extentHeight: 2,
            alignment: .horizontal,
            classification: .table
        )
        RealSurfacePlaneStore.shared.update(planes: [plane])

        // Ray at x=2.5 — inside the offset extent (centered at x=2, half-width=1).
        let hit = pickRealSurfacePosition(
            rayOrigin: simd_float3(2.5, 5, 0),
            rayDirection: simd_float3(0, -1, 0),
            filter: .horizontalAny
        )
        XCTAssertNotNil(hit, "Hit should register within offset extent")
    }

    func testMissAtAnchorOriginWithOffsetExtent() {
        // Anchor at origin, but extent center is offset 2m in +X.
        let extentOffset = float4x4(
            simd_float4(1, 0, 0, 0),
            simd_float4(0, 1, 0, 0),
            simd_float4(0, 0, 1, 0),
            simd_float4(2, 0, 0, 1)
        )
        let plane = TrackedPlane(
            id: UUID(),
            originFromAnchorTransform: .identity,
            anchorFromExtentTransform: extentOffset,
            extentWidth: 2,
            extentHeight: 2,
            alignment: .horizontal,
            classification: .table
        )
        RealSurfacePlaneStore.shared.update(planes: [plane])

        // Ray at x=0 — at the anchor origin, but outside the offset extent.
        let miss = pickRealSurfacePosition(
            rayOrigin: simd_float3(0, 5, 0),
            rayDirection: simd_float3(0, -1, 0),
            filter: .horizontalAny
        )
        XCTAssertNil(miss, "Hit at anchor origin should miss the offset extent")
    }
}
