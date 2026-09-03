//
//  SunElevationAzimuthTest.swift
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
final class SunElevationAzimuthTests: XCTestCase {
    var entityId: EntityID!

    override func setUp() async throws {
        resetEngineTestState()

        // These functions only depend on Local/WorldTransformComponent (via
        // getDirectionalLightShaderDirection), so a plain spatial entity is enough --
        // no need for createDirLight()'s mesh/texture setup, which requires a live
        // Metal device unavailable in this non-render test target.
        entityId = createEntity()
    }

    override func tearDown() async throws {
        destroyEntity(entityId: entityId)
    }

    private func assertDirection(_ elevation: Float, _ azimuth: Float, _ expected: simd_float3, accuracy: Float = 0.001) {
        setSunElevationAzimuth(entityId: entityId, elevation: elevation, azimuth: azimuth)
        let direction = getDirectionalLightShaderDirection(entityId: entityId)
        XCTAssertEqual(direction.x, expected.x, accuracy: accuracy, "elevation=\(elevation) azimuth=\(azimuth)")
        XCTAssertEqual(direction.y, expected.y, accuracy: accuracy, "elevation=\(elevation) azimuth=\(azimuth)")
        XCTAssertEqual(direction.z, expected.z, accuracy: accuracy, "elevation=\(elevation) azimuth=\(azimuth)")
    }

    func testZenith() {
        assertDirection(90.0, 0.0, simd_float3(0.0, 1.0, 0.0))
    }

    func testNadir() {
        assertDirection(-90.0, 0.0, simd_float3(0.0, -1.0, 0.0))
    }

    func testHorizonAzimuthZero() {
        assertDirection(0.0, 0.0, simd_float3(0.0, 0.0, 1.0))
    }

    func testHorizonAzimuthNinety() {
        assertDirection(0.0, 90.0, simd_float3(1.0, 0.0, 0.0))
    }

    func testHorizonAzimuthOneEighty() {
        assertDirection(0.0, 180.0, simd_float3(0.0, 0.0, -1.0))
    }

    func testFortyFiveDegreesElevation() {
        let s = Float(1.0 / 2.0.squareRoot())
        assertDirection(45.0, 0.0, simd_float3(0.0, s, s))
    }

    func testRoundTripAcrossElevationAndAzimuth() {
        let elevations: [Float] = [-80, -45, -10, 0, 10, 45, 80]
        let azimuths: [Float] = [0, 45, 90, 135, 180, 225, 270, 315]

        for elevation in elevations {
            for azimuth in azimuths {
                setSunElevationAzimuth(entityId: entityId, elevation: elevation, azimuth: azimuth)
                let readBack = getSunElevationAzimuth(entityId: entityId)

                XCTAssertEqual(readBack.elevation, elevation, accuracy: 0.01,
                               "elevation round-trip failed for (\(elevation), \(azimuth))")
                XCTAssertEqual(readBack.azimuth, azimuth, accuracy: 0.01,
                               "azimuth round-trip failed for (\(elevation), \(azimuth))")
            }
        }
    }

    func testAzimuthIsAlwaysNonNegative() {
        setSunElevationAzimuth(entityId: entityId, elevation: 10.0, azimuth: -30.0)
        let readBack = getSunElevationAzimuth(entityId: entityId)
        XCTAssertGreaterThanOrEqual(readBack.azimuth, 0.0)
        XCTAssertLessThan(readBack.azimuth, 360.0)
    }

    func testRollIsIrrelevantToDirection() {
        setSunElevationAzimuth(entityId: entityId, elevation: 30.0, azimuth: 60.0)
        let before = getDirectionalLightShaderDirection(entityId: entityId)

        rotateBy(entityId: entityId, angle: 77.0, axis: getLightTransformForwardAxis(entityId: entityId))
        let after = getDirectionalLightShaderDirection(entityId: entityId)

        XCTAssertEqual(before.x, after.x, accuracy: 0.001)
        XCTAssertEqual(before.y, after.y, accuracy: 0.001)
        XCTAssertEqual(before.z, after.z, accuracy: 0.001)
    }
}
