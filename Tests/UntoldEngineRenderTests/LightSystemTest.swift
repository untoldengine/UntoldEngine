//
//  LightSystemTest.swift
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Foundation
@testable import UntoldEngine
import XCTest

final class LightSystemTest: BaseRenderSetup {
    // MARK: - Setup and Teardown

    override func setUp() async throws {
        try await super.setUp()
    }

    override func tearDown() async throws {
        try await super.tearDown()
        destroyAllEntities()
    }

    // MARK: - Light Tests

    private func assertVector(
        _ value: simd_float3,
        equals expected: simd_float3,
        accuracy: Float = 0.001,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(value.x, expected.x, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(value.y, expected.y, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(value.z, expected.z, accuracy: accuracy, file: file, line: line)
    }

    func testDirectionalLight() {
        let entityId: EntityID = createEntity()

        createDirLight(entityId: entityId)

        XCTAssertTrue(hasComponent(entityId: entityId, componentType: LightComponent.self), "Should have a Light component")

        XCTAssertTrue(hasComponent(entityId: entityId, componentType: DirectionalLightComponent.self), "Should have a Directional Light component")

        destroyEntity(entityId: entityId)
    }

    func testPointLight() {
        let entityId: EntityID = createEntity()

        createPointLight(entityId: entityId)

        XCTAssertTrue(hasComponent(entityId: entityId, componentType: LightComponent.self), "Should have a Light component")

        XCTAssertTrue(hasComponent(entityId: entityId, componentType: PointLightComponent.self), "Should have a Point Light component")

        destroyEntity(entityId: entityId)
    }

    func testSpotLight() {
        let entityId: EntityID = createEntity()

        createSpotLight(entityId: entityId)

        XCTAssertTrue(hasComponent(entityId: entityId, componentType: LightComponent.self), "Should have a Light component")

        XCTAssertTrue(hasComponent(entityId: entityId, componentType: SpotLightComponent.self), "Should have a Spot Light component")

        destroyEntity(entityId: entityId)
    }

    func testAreaLight() {
        let entityId: EntityID = createEntity()

        createAreaLight(entityId: entityId)

        XCTAssertTrue(hasComponent(entityId: entityId, componentType: LightComponent.self), "Should have a Light component")

        XCTAssertTrue(hasComponent(entityId: entityId, componentType: AreaLightComponent.self), "Should have an Area Light component")

        destroyEntity(entityId: entityId)
    }

    func testDefaultLightsUseLocalNegativeZEmissionConvention() {
        destroyAllEntities()

        let directional = createEntity()
        createDirLight(entityId: directional)
        assertVector(getLightTransformForwardAxis(entityId: directional), equals: simd_float3(0.0, 1.0, 0.0))
        assertVector(getLightEmissionDirection(entityId: directional), equals: simd_float3(0.0, -1.0, 0.0))
        assertVector(getDirectionalLightShaderDirection(entityId: directional), equals: simd_float3(0.0, 1.0, 0.0))

        let spot = createEntity()
        createSpotLight(entityId: spot)
        assertVector(getLightTransformForwardAxis(entityId: spot), equals: simd_float3(0.0, 1.0, 0.0))
        assertVector(getLightEmissionDirection(entityId: spot), equals: simd_float3(0.0, -1.0, 0.0))
        assertVector(getSpotLights().first?.direction ?? .zero, equals: simd_float3(0.0, -1.0, 0.0))

        let area = createEntity()
        createAreaLight(entityId: area)
        assertVector(getLightTransformForwardAxis(entityId: area), equals: simd_float3(0.0, 1.0, 0.0))
        assertVector(getLightEmissionDirection(entityId: area), equals: simd_float3(0.0, -1.0, 0.0))
        assertVector(getAreaLights().first?.forward ?? .zero, equals: simd_float3(0.0, 1.0, 0.0))
        XCTAssertEqual(getAreaLights().first?.nearSourceSuppressionRadius ?? -1.0, 0.0)
    }

    func testAreaLightShaderUniformLayoutIncludesPortalFields() {
        XCTAssertEqual(MemoryLayout<AreaLight>.stride, MemoryLayout<AreaLightUniform>.stride)
        XCTAssertEqual(MemoryLayout<AreaLight>.alignment, MemoryLayout<AreaLightUniform>.alignment)

        var light = AreaLight()
        light.position = simd_float3(1.0, 2.0, 3.0)
        light.color = simd_float3(0.75, 0.5, 0.25)
        light.forward = simd_float3(0.0, 0.0, 1.0)
        light.right = simd_float3(1.0, 0.0, 0.0)
        light.up = simd_float3(0.0, 1.0, 0.0)
        light.bounds = simd_float2(4.0, 2.0)
        light.intensity = 1.5
        light.range = 6.0
        light.nearSourceSuppressionRadius = 0.35
        light.twoSided = true

        let uniform = [light].withUnsafeBufferPointer { buffer in
            UnsafeRawBufferPointer(
                start: buffer.baseAddress,
                count: MemoryLayout<AreaLight>.stride
            ).load(as: AreaLightUniform.self)
        }

        assertVector(uniform.position, equals: light.position)
        assertVector(uniform.color, equals: light.color)
        assertVector(uniform.forward, equals: light.forward)
        assertVector(uniform.right, equals: light.right)
        assertVector(uniform.up, equals: light.up)
        XCTAssertEqual(uniform.bounds.x, light.bounds.x, accuracy: 0.0001)
        XCTAssertEqual(uniform.bounds.y, light.bounds.y, accuracy: 0.0001)
        XCTAssertEqual(uniform.intensity, light.intensity, accuracy: 0.0001)
        XCTAssertEqual(uniform.range, light.range, accuracy: 0.0001)
        XCTAssertEqual(uniform.nearSourceSuppressionRadius, light.nearSourceSuppressionRadius, accuracy: 0.0001)
        XCTAssertTrue(uniform.twoSided)
    }

    func testGetDirLightParameters() {
        let entityId: EntityID = createEntity()

        createDirLight(entityId: entityId)

        guard scene.get(component: LightComponent.self, for: entityId) != nil else {
            handleError(.noLightComponent, entityId)
            return
        }

        guard scene.get(component: DirectionalLightComponent.self, for: entityId) != nil else {
            handleError(.noDirLightComponent, entityId)
            return
        }

        let lightParameters: LightParameters = getDirectionalLightParameters()

        XCTAssertEqual(lightParameters.color, .one, "color should be all 1's")
        XCTAssertEqual(lightParameters.intensity, 1.0, "intensity should be 1")
        XCTAssertEqual(lightParameters.direction.x, 0.0, accuracy: 0.001, "Rotation about X axis should match")
        XCTAssertEqual(lightParameters.direction.y, 1.0, accuracy: 0.001, "Rotation about Y axis should match")
        XCTAssertEqual(lightParameters.direction.z, 0.0, accuracy: 0.001, "Rotation about Z axis should match")

        destroyEntity(entityId: entityId)
    }

    func testPointLightParameters() {
        let entityId: EntityID = createEntity()

        createPointLight(entityId: entityId)

        guard scene.get(component: LightComponent.self, for: entityId) != nil else {
            handleError(.noLightComponent, entityId)
            return
        }

        guard scene.get(component: PointLightComponent.self, for: entityId) != nil else {
            handleError(.noPointLightComponent, entityId)
            return
        }

        let pointLightParameter: [PointLight] = getPointLights()

        XCTAssertEqual(pointLightParameter[0].intensity, 1.0, "intensity should be 1")
        XCTAssertEqual(pointLightParameter[0].attenuation.x, 1.0, "constant should be 1")
        XCTAssertEqual(pointLightParameter[0].attenuation.y, 0.05, "linear should be 1")
        XCTAssertEqual(pointLightParameter[0].attenuation.z, 0.5, "quadratic should be 1")
        XCTAssertEqual(pointLightParameter[0].radius, 1.0, "radius should be 1")

        destroyEntity(entityId: entityId)
    }

    func testSpotPointLightParameters() {
        let entityId: EntityID = createEntity()

        createSpotLight(entityId: entityId)

        guard scene.get(component: LightComponent.self, for: entityId) != nil else {
            handleError(.noLightComponent, entityId)
            return
        }

        guard scene.get(component: SpotLightComponent.self, for: entityId) != nil else {
            handleError(.noSpotLightComponent, entityId)
            return
        }

        let spotLightParameter: [SpotLight] = getSpotLights()

        XCTAssertEqual(spotLightParameter[0].intensity, 1.0, "intensity should be 1")
        XCTAssertEqual(spotLightParameter[0].attenuation.x, 1.0, "constant should be 1")
        XCTAssertEqual(spotLightParameter[0].attenuation.y, 0.05, "linear should be 1")
        XCTAssertEqual(spotLightParameter[0].attenuation.z, 0.5, "quadratic should be 1")
        XCTAssertEqual(spotLightParameter[0].outerCone, 0.523, accuracy: 0.001, "outer cone should be 1")
        XCTAssertEqual(spotLightParameter[0].innerCone, 0.427, accuracy: 0.001, "inner cone should be 1")

        XCTAssertEqual(spotLightParameter[0].direction.x, 0.0, accuracy: 0.001, "Rotation about X axis should match")
        XCTAssertEqual(spotLightParameter[0].direction.y, -1.0, accuracy: 0.001, "Rotation about Y axis should match")
        XCTAssertEqual(spotLightParameter[0].direction.z, 0.0, accuracy: 0.001, "Rotation about Z axis should match")

        destroyEntity(entityId: entityId)
    }

    func testSpotLightParametersUseAuthoredInnerAndOuterCones() {
        destroyAllEntities()

        let entityId: EntityID = createEntity()
        createSpotLight(entityId: entityId)

        guard let spotLightComponent = scene.get(component: SpotLightComponent.self, for: entityId) else {
            handleError(.noSpotLightComponent, entityId)
            return
        }

        spotLightComponent.innerCone = 12.0
        spotLightComponent.outerCone = 34.0
        spotLightComponent.coneAngle = 45.0
        spotLightComponent.falloff = 0.5

        let spotLightParameters = getSpotLights()

        XCTAssertEqual(spotLightParameters.count, 1)
        XCTAssertEqual(spotLightParameters[0].innerCone, degreesToRadians(degrees: 12.0), accuracy: 0.001)
        XCTAssertEqual(spotLightParameters[0].outerCone, degreesToRadians(degrees: 34.0), accuracy: 0.001)

        destroyEntity(entityId: entityId)
    }

    func testGetPointLightCount() {
        destroyAllEntities()
        let entityId0: EntityID = createEntity()
        let entityId1: EntityID = createEntity()

        createPointLight(entityId: entityId0)
        createPointLight(entityId: entityId1)

        XCTAssertEqual(getPointLightCount(), 2, "There should be two point lights")

        destroyEntity(entityId: entityId0)
        destroyEntity(entityId: entityId1)
    }

    func testGetSpotLightCount() {
        destroyAllEntities()
        let entityId0: EntityID = createEntity()
        let entityId1: EntityID = createEntity()

        createSpotLight(entityId: entityId0)
        createSpotLight(entityId: entityId1)

        XCTAssertEqual(getSpotLightCount(), 2, "There should be two spot lights")

        destroyEntity(entityId: entityId0)
        destroyEntity(entityId: entityId1)
    }

    func testGetLightColor() {
        let entityId: EntityID = createEntity()
        createDirLight(entityId: entityId)

        guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
            handleError(.noLightComponent, entityId)
            return
        }

        lightComponent.color = .one

        XCTAssertEqual(lightComponent.color, .one, "color should be all 1's")
        destroyEntity(entityId: entityId)
    }

    func testGetLightIntensity() {
        let entityId: EntityID = createEntity()
        createDirLight(entityId: entityId)

        guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
            handleError(.noLightComponent, entityId)
            return
        }

        lightComponent.intensity = 1.0

        XCTAssertEqual(lightComponent.intensity, 1.0, "Intensity should be all 1's")
        destroyEntity(entityId: entityId)
    }
}
