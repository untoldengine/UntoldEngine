//
//  LODScreenSizeTests.swift
//  UntoldEngine
//
//  Choosing a LOD level by the size of the entity on screen.
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
final class LODScreenSizeTests: XCTestCase {
    override func setUp() async throws {
        resetEngineTestState()
    }

    override func tearDown() async throws {
        destroyAllEntities()
    }

    /// A 90° field of view: half the height of the view is as long as the distance.
    private func perspective(fovYDegrees: Float = 90) -> simd_float4x4 {
        matrixPerspectiveRightHandReverseZ(fovyRadians: degreesToRadians(degrees: fovYDegrees), aspectRatio: 16.0 / 9.0, nearZ: 0.1, farZ: 1000)
    }

    /// Four levels that take over at a half, a quarter and a tenth of the viewport
    /// height. Their distances say something else on purpose.
    private var levels: [LODLevel] {
        [
            LODLevel(mesh: [], maxDistance: 1000),
            LODLevel(mesh: [], maxDistance: 2000, screenPercentage: 0.5),
            LODLevel(mesh: [], maxDistance: 3000, screenPercentage: 0.25),
            LODLevel(mesh: [], maxDistance: .greatestFiniteMagnitude, screenPercentage: 0.1),
        ]
    }

    private func selected(
        distance: Float,
        reach: Float,
        current: Int = 0,
        forced: Int? = nil,
        bias: Float = 1,
        hysteresis: Float = 0,
        levels: [LODLevel]? = nil,
        globalDistances: [Float] = []
    ) -> Int {
        selectLODIndex(
            levels: levels ?? self.levels,
            distance: distance,
            reach: reach,
            currentLOD: current,
            forcedLOD: forced,
            lodBias: bias,
            hysteresis: hysteresis,
            globalDistances: globalDistances
        )
    }

    // MARK: - What a screen size is worth in distance

    func testAUnitSphereFillsTheViewportAtTheReach() {
        // Radius 1 under 90°: the sphere is as tall as the view at distance 1.
        XCTAssertEqual(try XCTUnwrap(lodScreenSizeReach(projection: perspective())), 1, accuracy: 1e-5)
    }

    func testANarrowerFieldOfViewReachesFarther() throws {
        let wide = try XCTUnwrap(lodScreenSizeReach(projection: perspective(fovYDegrees: 90)))
        let narrow = try XCTUnwrap(lodScreenSizeReach(projection: perspective(fovYDegrees: 45)))

        XCTAssertEqual(narrow / wide, 1 / tan(degreesToRadians(degrees: 22.5)), accuracy: 1e-4)
    }

    func testTheShapeOfTheViewportDoesNotChangeTheReach() throws {
        let wide = matrixPerspectiveRightHandReverseZ(fovyRadians: degreesToRadians(degrees: 90), aspectRatio: 3, nearZ: 0.1, farZ: 1000)
        let tall = matrixPerspectiveRightHandReverseZ(fovyRadians: degreesToRadians(degrees: 90), aspectRatio: 0.5, nearZ: 0.1, farZ: 1000)

        XCTAssertEqual(try XCTUnwrap(lodScreenSizeReach(projection: wide)), 1, accuracy: 1e-5)
        XCTAssertEqual(try XCTUnwrap(lodScreenSizeReach(projection: tall)), 1, accuracy: 1e-5)
    }

    func testAViewWithoutPerspectiveHasNoReach() {
        let orthographic = simd_float4x4(diagonal: simd_float4(0.1, 0.1, 0.01, 1))

        XCTAssertNil(lodScreenSizeReach(projection: orthographic))
        XCTAssertNil(lodScreenSizeReach(projection: matrix_identity_float4x4))
    }

    // MARK: - Selection

    func testALevelTakesOverWhereTheEntityCoversItsScreenSize() {
        // With a reach of 10 the entity covers 0.5 at 20, 0.25 at 40 and 0.1 at 100.
        XCTAssertEqual(selected(distance: 19, reach: 10), 0)
        XCTAssertEqual(selected(distance: 21, reach: 10), 1)
        XCTAssertEqual(selected(distance: 39, reach: 10), 1)
        XCTAssertEqual(selected(distance: 41, reach: 10), 2)
        XCTAssertEqual(selected(distance: 99, reach: 10), 2)
        XCTAssertEqual(selected(distance: 101, reach: 10), 3)
        XCTAssertEqual(selected(distance: 1_000_000, reach: 10), 3, "the last level has no end")
    }

    func testALargerEntityOrALargerViewKeepsTheFinerLevelForLonger() {
        // Three times the radius, or a field of view to that effect.
        XCTAssertEqual(selected(distance: 59, reach: 30), 0)
        XCTAssertEqual(selected(distance: 61, reach: 30), 1)
        XCTAssertEqual(selected(distance: 301, reach: 30), 3)
    }

    func testTheBiasMovesEverySwitchTogether() {
        XCTAssertEqual(selected(distance: 11, reach: 10, bias: 2), 1, "twice as early")
        XCTAssertEqual(selected(distance: 30, reach: 10, bias: 0.5), 0, "half as early")
    }

    func testTheHysteresisHoldsTheCoarserLevelJustInsideTheSwitch() {
        // The switch is at 20. Coming back, a hysteresis of 1 puts it at 19.
        XCTAssertEqual(selected(distance: 19.5, reach: 10, current: 1, hysteresis: 1), 1)
        XCTAssertEqual(selected(distance: 18.5, reach: 10, current: 1, hysteresis: 1), 0)
        // It never holds more than a tenth of the switch distance.
        XCTAssertEqual(selected(distance: 17.9, reach: 10, current: 1, hysteresis: 50), 0)
        XCTAssertEqual(selected(distance: 18.1, reach: 10, current: 1, hysteresis: 50), 1)
    }

    func testAForcedLevelWins() {
        XCTAssertEqual(selected(distance: 5, reach: 10, forced: 2), 2)
        XCTAssertEqual(selected(distance: 5, reach: 10, forced: 9), 3)
    }

    func testALevelWithoutAScreenSizeTakesOverAtTheDistanceOfTheOneBefore() {
        var levels = levels
        levels[2].screenPercentage = 0
        levels[1].maxDistance = 70

        XCTAssertEqual(selected(distance: 21, reach: 10, levels: levels), 1)
        XCTAssertEqual(selected(distance: 69, reach: 10, levels: levels), 1, "level 1 ends at its own distance")
        XCTAssertEqual(selected(distance: 71, reach: 10, levels: levels), 2)
        XCTAssertEqual(selected(distance: 101, reach: 10, levels: levels), 3)
    }

    func testAnEntityWithoutASizeFallsBackToTheDistances() {
        XCTAssertEqual(selected(distance: 999, reach: 0), 0)
        XCTAssertEqual(selected(distance: 1001, reach: 0), 1)
        XCTAssertEqual(selected(distance: 2500, reach: .nan), 2)
    }

    // MARK: - The sphere an entity is measured by

    func testTheRadiusIsTheSphereAroundTheBoundsUnderTheWorldScale() throws {
        let entity = createEntity()
        registerTransformComponent(entityId: entity)
        let local = try XCTUnwrap(scene.get(component: LocalTransformComponent.self, for: entity))
        local.boundingBox = (min: simd_float3(-1, -2, -2), max: simd_float3(1, 2, 2))
        translateTo(entityId: entity, position: simd_float3(0, 0, -50))
        scaleTo(entityId: entity, scale: simd_float3(repeating: 3))
        traverseSceneGraph()

        let measured = entityDistanceAndRadius(entityId: entity, cameraPosition: simd_float3(0, 0, 10), localRadius: 0)

        XCTAssertEqual(measured.distance, 60, accuracy: 1e-3)
        XCTAssertEqual(measured.radius, 9, accuracy: 1e-3, "half the diagonal of 2 x 4 x 4, three times")
    }

    func testAPartOfAModelIsMeasuredByTheRadiusItCarries() {
        let entity = createEntity()
        registerTransformComponent(entityId: entity)
        scaleTo(entityId: entity, scale: simd_float3(2, 2, 2))
        traverseSceneGraph()

        let measured = entityDistanceAndRadius(entityId: entity, cameraPosition: simd_float3(0, 0, 10), localRadius: 25)

        XCTAssertEqual(measured.radius, 50, accuracy: 1e-3)
    }

    func testTheComponentSelectsByDistanceUnlessTold() {
        let component = LODComponent()

        XCTAssertFalse(component.selectsByScreenSize)
        XCTAssertEqual(component.screenSizeRadius, 0)
    }
}
