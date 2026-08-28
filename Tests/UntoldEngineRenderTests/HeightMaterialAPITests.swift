//
//  HeightMaterialAPITests.swift
//  UntoldEngine
//
//  Direct coverage for the height-map/Parallax Occlusion Mapping public API:
//  getMaterialHeight*/updateMaterialHeight* (FuncUtils.swift) and POMQualitySettings/
//  setPOMQuality/getPOMQuality (Globals.swift). Neither had any test coverage anywhere
//  in the suite before this file.
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldEngine
import XCTest

final class HeightMaterialAPITests: BaseRenderSetup {
    private func addCubeEntity() -> EntityID {
        let entity = createEntity()
        let meshes = BasicPrimitives.createCube()
        if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
            renderComponent.mesh = meshes
        }
        _ = scene.assign(to: entity, component: LocalTransformComponent.self)
        _ = scene.assign(to: entity, component: WorldTransformComponent.self)
        return entity
    }

    // MARK: - Defaults

    func testHeightMaterialAPIDefaultsMatchDocumentedValues() {
        let entity = addCubeEntity()

        XCTAssertEqual(getMaterialHeightScale(entityId: entity), 0.05, accuracy: 0.0001)
        XCTAssertEqual(getMaterialHeightMidlevel(entityId: entity), 0.5, accuracy: 0.0001)
        XCTAssertEqual(getMaterialHeightRemapMin(entityId: entity), 0.0, accuracy: 0.0001)
        XCTAssertEqual(getMaterialHeightRemapMax(entityId: entity), 1.0, accuracy: 0.0001)
        XCTAssertTrue(getMaterialHeightEnabled(entityId: entity), "POM should be enabled by default")
    }

    // MARK: - Round trips

    func testUpdateMaterialHeightScaleRoundTrips() {
        let entity = addCubeEntity()
        updateMaterialHeightScale(entityId: entity, heightScale: 0.12)
        XCTAssertEqual(getMaterialHeightScale(entityId: entity), 0.12, accuracy: 0.0001)
    }

    func testUpdateMaterialHeightMidlevelRoundTrips() {
        let entity = addCubeEntity()
        updateMaterialHeightMidlevel(entityId: entity, heightMidlevel: 0.75)
        XCTAssertEqual(getMaterialHeightMidlevel(entityId: entity), 0.75, accuracy: 0.0001)
    }

    func testUpdateMaterialHeightRemapMinRoundTrips() {
        let entity = addCubeEntity()
        updateMaterialHeightRemapMin(entityId: entity, heightRemapMin: 0.2)
        XCTAssertEqual(getMaterialHeightRemapMin(entityId: entity), 0.2, accuracy: 0.0001)
    }

    func testUpdateMaterialHeightRemapMaxRoundTrips() {
        let entity = addCubeEntity()
        updateMaterialHeightRemapMax(entityId: entity, heightRemapMax: 0.85)
        XCTAssertEqual(getMaterialHeightRemapMax(entityId: entity), 0.85, accuracy: 0.0001)
    }

    func testUpdateMaterialHeightEnabledRoundTrips() {
        let entity = addCubeEntity()
        updateMaterialHeightEnabled(entityId: entity, heightEnabled: false)
        XCTAssertFalse(getMaterialHeightEnabled(entityId: entity))

        updateMaterialHeightEnabled(entityId: entity, heightEnabled: true)
        XCTAssertTrue(getMaterialHeightEnabled(entityId: entity))
    }

    func testHeightMaterialAPIRoundTripsIndependently() {
        // Changing one height field must not perturb the others.
        let entity = addCubeEntity()
        updateMaterialHeightScale(entityId: entity, heightScale: 0.09)
        updateMaterialHeightMidlevel(entityId: entity, heightMidlevel: 0.6)
        updateMaterialHeightRemapMin(entityId: entity, heightRemapMin: 0.15)
        updateMaterialHeightRemapMax(entityId: entity, heightRemapMax: 0.95)
        updateMaterialHeightEnabled(entityId: entity, heightEnabled: false)

        XCTAssertEqual(getMaterialHeightScale(entityId: entity), 0.09, accuracy: 0.0001)
        XCTAssertEqual(getMaterialHeightMidlevel(entityId: entity), 0.6, accuracy: 0.0001)
        XCTAssertEqual(getMaterialHeightRemapMin(entityId: entity), 0.15, accuracy: 0.0001)
        XCTAssertEqual(getMaterialHeightRemapMax(entityId: entity), 0.95, accuracy: 0.0001)
        XCTAssertFalse(getMaterialHeightEnabled(entityId: entity))
    }

    // MARK: - POMQualitySettings / setPOMQuality / getPOMQuality

    func testPOMQualitySettingsDefaultInitMatchesDocumentedValues() {
        let settings = POMQualitySettings()
        XCTAssertEqual(settings.minSteps, 8.0)
        XCTAssertEqual(settings.maxSteps, 32.0)
        XCTAssertEqual(settings.maxDistance, 20.0)
        XCTAssertEqual(settings.fadeStartDistance, 12.0)
    }

    func testPOMQualitySettingsPlatformDefaultIsCheaperOnVisionOS() {
        // visionOS gets a strictly cheaper tier (fewer steps, shorter fade distance) than the
        // non-XR default — this is the actual performance-control behavior the feature exists
        // for, and it had no test coverage anywhere.
        let platformDefault = POMQualitySettings.platformDefault
        #if os(visionOS)
            XCTAssertEqual(platformDefault.minSteps, 4.0)
            XCTAssertEqual(platformDefault.maxSteps, 16.0)
            XCTAssertEqual(platformDefault.maxDistance, 15.0)
            XCTAssertEqual(platformDefault.fadeStartDistance, 9.0)
        #else
            XCTAssertEqual(platformDefault, POMQualitySettings())
        #endif
        XCTAssertLessThanOrEqual(platformDefault.minSteps, POMQualitySettings().minSteps)
        XCTAssertLessThanOrEqual(platformDefault.maxSteps, POMQualitySettings().maxSteps)
        XCTAssertLessThan(platformDefault.fadeStartDistance, platformDefault.maxDistance, "fade must complete before maxDistance")
    }

    func testSetAndGetPOMQualityRoundTrips() {
        let original = getPOMQuality()
        defer { setPOMQuality(original) }

        let custom = POMQualitySettings(minSteps: 2.0, maxSteps: 6.0, maxDistance: 5.0, fadeStartDistance: 3.0)
        setPOMQuality(custom)
        XCTAssertEqual(getPOMQuality(), custom)
    }
}
