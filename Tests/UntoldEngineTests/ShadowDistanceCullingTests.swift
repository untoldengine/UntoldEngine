//
//  ShadowDistanceCullingTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldEngine
import XCTest

/// Tests for the shadow distance culling helper used in RenderPasses.shadowCasterEntityIds.
/// All tests exercise shadowEntityBeyondMaxDistance() directly — no Metal or scene state required.
@MainActor
final class ShadowDistanceCullingTests: XCTestCase {

    // MARK: - Basic inclusion / exclusion

    func testEntityWithinMaxDistanceIsIncluded() {
        let worldMin = simd_float3(4, -1, -1)
        let worldMax = simd_float3(6, 1, 1)
        XCTAssertFalse(shadowEntityBeyondMaxDistance(
            worldMin: worldMin, worldMax: worldMax,
            cameraPosition: .zero, maxDistance: 40.0
        ), "Entity 5m away should not be excluded with maxDistance=40")
    }

    func testEntityBeyondMaxDistanceIsExcluded() {
        let worldMin = simd_float3(49, -1, -1)
        let worldMax = simd_float3(51, 1, 1)
        XCTAssertTrue(shadowEntityBeyondMaxDistance(
            worldMin: worldMin, worldMax: worldMax,
            cameraPosition: .zero, maxDistance: 40.0
        ), "Entity 49m away should be excluded with maxDistance=40")
    }

    // MARK: - Boundary behaviour

    func testEntityWhoseClosestPointIsAtMaxDistanceIsIncluded() {
        // AABB starts at exactly maxDistance from camera → closest point is at the boundary → include
        let worldMin = simd_float3(40, -1, -1)
        let worldMax = simd_float3(42, 1, 1)
        // Closest point on AABB = (40, 0, 0), distance = 40.0 — NOT strictly greater than 40
        XCTAssertFalse(shadowEntityBeyondMaxDistance(
            worldMin: worldMin, worldMax: worldMax,
            cameraPosition: .zero, maxDistance: 40.0
        ), "Entity exactly at maxDistance boundary should be included (not strictly beyond)")
    }

    func testEntityJustBeyondMaxDistanceIsExcluded() {
        let worldMin = simd_float3(40.01, -1, -1)
        let worldMax = simd_float3(42.0, 1, 1)
        XCTAssertTrue(shadowEntityBeyondMaxDistance(
            worldMin: worldMin, worldMax: worldMax,
            cameraPosition: .zero, maxDistance: 40.0
        ), "Entity 40.01m away should be excluded")
    }

    // MARK: - Disabled culling

    func testZeroMaxDistanceDisablesCullingAlwaysIncludes() {
        // Even an entity 10km away must be included when maxDistance == 0
        let worldMin = simd_float3(9999, 0, 0)
        let worldMax = simd_float3(10001, 1, 1)
        XCTAssertFalse(shadowEntityBeyondMaxDistance(
            worldMin: worldMin, worldMax: worldMax,
            cameraPosition: .zero, maxDistance: 0.0
        ), "maxDistance=0 disables culling — entity should always be included")
    }

    // MARK: - Closest AABB point (not center)

    func testLargeEntityStraddlingCameraIsAlwaysIncluded() {
        // Camera is inside the AABB → closest point is the camera itself → distance = 0
        let worldMin = simd_float3(-10, -10, -10)
        let worldMax = simd_float3(100, 10, 10)  // center ~45m away
        XCTAssertFalse(shadowEntityBeyondMaxDistance(
            worldMin: worldMin, worldMax: worldMax,
            cameraPosition: .zero, maxDistance: 40.0
        ), "Entity surrounding the camera should never be excluded regardless of center distance")
    }

    func testSmallEntityBehindCameraIsCorrectlyMeasured() {
        // Entity is 30m behind camera (negative Z), max 40m → should be included
        let worldMin = simd_float3(-1, -1, -31)
        let worldMax = simd_float3(1, 1, -29)
        XCTAssertFalse(shadowEntityBeyondMaxDistance(
            worldMin: worldMin, worldMax: worldMax,
            cameraPosition: .zero, maxDistance: 40.0
        ), "Entity 30m behind camera should be included with maxDistance=40")
    }

    // MARK: - Non-origin camera

    func testNonOriginCameraCorrectlyMeasuresDistance() {
        // Camera at (−20, 0, 0); entity centered at (−70, 0, 0) → distance ≈ 50m > 40m → exclude
        let worldMin = simd_float3(-71, -1, -1)
        let worldMax = simd_float3(-69, 1, 1)
        XCTAssertTrue(shadowEntityBeyondMaxDistance(
            worldMin: worldMin, worldMax: worldMax,
            cameraPosition: simd_float3(-20, 0, 0), maxDistance: 40.0
        ), "Entity 50m from a non-origin camera should be excluded with maxDistance=40")
    }

    func testNonOriginCameraEntityWithinRange() {
        // Camera at (10, 0, 0); entity at (30, 0, 0) → distance = 20m < 40m → include
        let worldMin = simd_float3(29, -1, -1)
        let worldMax = simd_float3(31, 1, 1)
        XCTAssertFalse(shadowEntityBeyondMaxDistance(
            worldMin: worldMin, worldMax: worldMax,
            cameraPosition: simd_float3(10, 0, 0), maxDistance: 40.0
        ), "Entity 20m from camera should be included with maxDistance=40")
    }

    // MARK: - Config default

    func testDefaultMaxShadowCastingDistanceIs40() {
        XCTAssertEqual(RenderPasses.maxShadowCastingDistance, 40.0, accuracy: 0.001,
                       "Default maxShadowCastingDistance should be 40 world units")
    }
}
