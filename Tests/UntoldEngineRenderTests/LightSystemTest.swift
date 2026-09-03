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

    private func assertMatrixNotApproximatelyEqual(
        _ lhs: simd_float4x4,
        _ rhs: simd_float4x4,
        accuracy: Float = 0.001,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var maxDifference: Float = 0.0
        for column in 0 ..< 4 {
            for row in 0 ..< 4 {
                maxDifference = max(maxDifference, abs(lhs[column][row] - rhs[column][row]))
            }
        }

        XCTAssertGreaterThan(maxDifference, accuracy, file: file, line: line)
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

        // Directional lights are the one exception: createDirLight() sets a sun-appropriate
        // default (elevation=19deg, azimuth=150deg) for the procedural sky background instead of
        // the shared straight-down default the other light types use below.
        let directional = createEntity()
        createDirLight(entityId: directional)
        assertVector(getLightTransformForwardAxis(entityId: directional), equals: simd_float3(0.47275954, 0.3255682, -0.81884295))
        assertVector(getLightEmissionDirection(entityId: directional), equals: simd_float3(-0.47275954, -0.3255682, 0.81884295))
        assertVector(getDirectionalLightShaderDirection(entityId: directional), equals: simd_float3(0.47275954, 0.3255682, -0.81884295))

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

    func testLightShaderUniformABIStaysStable() {
        XCTAssertEqual(MemoryLayout<PointLight>.stride, MemoryLayout<PointLightUniform>.stride)
        XCTAssertEqual(MemoryLayout<PointLight>.alignment, MemoryLayout<PointLightUniform>.alignment)
        XCTAssertEqual(MemoryLayout<PointLightUniform>.stride, 64)
        XCTAssertEqual(MemoryLayout<PointLightUniform>.alignment, 16)
        XCTAssertEqual(MemoryLayout.offset(of: \PointLightUniform.attenuation), 0)
        XCTAssertEqual(MemoryLayout.offset(of: \PointLightUniform.position), 16)
        XCTAssertEqual(MemoryLayout.offset(of: \PointLightUniform.color), 32)
        XCTAssertEqual(MemoryLayout.offset(of: \PointLightUniform.intensity), 48)
        XCTAssertEqual(MemoryLayout.offset(of: \PointLightUniform.radius), 52)

        XCTAssertEqual(MemoryLayout<PointShadowUniforms>.stride, 48)
        XCTAssertEqual(MemoryLayout<PointShadowUniforms>.alignment, 16)
        XCTAssertEqual(MemoryLayout.offset(of: \PointShadowUniforms.lightPosition), 0)
        XCTAssertEqual(MemoryLayout.offset(of: \PointShadowUniforms.farDistance), 16)
        XCTAssertEqual(MemoryLayout.offset(of: \PointShadowUniforms.lightIndex), 20)
        XCTAssertEqual(MemoryLayout.offset(of: \PointShadowUniforms.enabled), 24)
        XCTAssertEqual(MemoryLayout.offset(of: \PointShadowUniforms.shadowSoftness), 28)
        XCTAssertEqual(MemoryLayout.offset(of: \PointShadowUniforms.bias), 32)

        XCTAssertEqual(MemoryLayout<SpotLight>.stride, MemoryLayout<SpotLightUniform>.stride)
        XCTAssertEqual(MemoryLayout<SpotLight>.alignment, MemoryLayout<SpotLightUniform>.alignment)
        XCTAssertEqual(MemoryLayout<SpotLightUniform>.stride, 80)
        XCTAssertEqual(MemoryLayout<SpotLightUniform>.alignment, 16)
        XCTAssertEqual(MemoryLayout.offset(of: \SpotLightUniform.attenuation), 0)
        XCTAssertEqual(MemoryLayout.offset(of: \SpotLightUniform.direction), 16)
        XCTAssertEqual(MemoryLayout.offset(of: \SpotLightUniform.position), 32)
        XCTAssertEqual(MemoryLayout.offset(of: \SpotLightUniform.color), 48)
        XCTAssertEqual(MemoryLayout.offset(of: \SpotLightUniform.intensity), 64)
        XCTAssertEqual(MemoryLayout.offset(of: \SpotLightUniform.innerCone), 68)
        XCTAssertEqual(MemoryLayout.offset(of: \SpotLightUniform.outerCone), 72)
        XCTAssertEqual(MemoryLayout.offset(of: \SpotLightUniform.radius), 76)

        XCTAssertEqual(MemoryLayout<SpotShadowUniforms>.stride, 80)
        XCTAssertEqual(MemoryLayout<SpotShadowUniforms>.alignment, 16)
        XCTAssertEqual(MemoryLayout.offset(of: \SpotShadowUniforms.lightSpaceMatrix), 0)
        XCTAssertEqual(MemoryLayout.offset(of: \SpotShadowUniforms.lightIndex), 64)
        XCTAssertEqual(MemoryLayout.offset(of: \SpotShadowUniforms.enabled), 68)
        XCTAssertEqual(MemoryLayout.offset(of: \SpotShadowUniforms.shadowSoftness), 72)
        XCTAssertEqual(MemoryLayout.offset(of: \SpotShadowUniforms.bias), 76)

        XCTAssertEqual(MemoryLayout<AreaLight>.stride, MemoryLayout<AreaLightUniform>.stride)
        XCTAssertEqual(MemoryLayout<AreaLight>.alignment, MemoryLayout<AreaLightUniform>.alignment)
        XCTAssertEqual(MemoryLayout<AreaLightUniform>.stride, 112)
        XCTAssertEqual(MemoryLayout<AreaLightUniform>.alignment, 16)
        XCTAssertEqual(MemoryLayout.offset(of: \AreaLightUniform.position), 0)
        XCTAssertEqual(MemoryLayout.offset(of: \AreaLightUniform.color), 16)
        XCTAssertEqual(MemoryLayout.offset(of: \AreaLightUniform.forward), 32)
        XCTAssertEqual(MemoryLayout.offset(of: \AreaLightUniform.right), 48)
        XCTAssertEqual(MemoryLayout.offset(of: \AreaLightUniform.up), 64)
        XCTAssertEqual(MemoryLayout.offset(of: \AreaLightUniform.bounds), 80)
        XCTAssertEqual(MemoryLayout.offset(of: \AreaLightUniform.intensity), 88)
        XCTAssertEqual(MemoryLayout.offset(of: \AreaLightUniform.range), 92)
        XCTAssertEqual(MemoryLayout.offset(of: \AreaLightUniform.nearSourceSuppressionRadius), 96)
        XCTAssertEqual(MemoryLayout.offset(of: \AreaLightUniform.twoSided), 100)
    }

    func testAreaLightShaderUniformLayoutIncludesPortalFields() {
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

    func testSetLightPowerEnablesRadiometricUnits() {
        let entityId: EntityID = createEntity()
        createPointLight(entityId: entityId)

        setLight(entityId: entityId, .power(300.0))

        XCTAssertEqual(getLightIntensity(entityId: entityId), 300.0, accuracy: 0.0001)
        XCTAssertTrue(scene.get(component: LightComponent.self, for: entityId)?.usesRadiometricUnits ?? false)
    }

    func testGetDirLightParameters() {
        destroyAllEntities()
        // destroyAllEntities() defers actual destruction to frame finalization, so the
        // fixture scene's directional light (loaded in setUp()) is still "active" at this
        // point. Force it to flush now so LightingSystem.shared.activeDirectionalLight is
        // cleared before this test creates and queries its own light.
        finalizePendingDestroys()

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

        // Default sun position/brightness for newly-created directional lights, tuned for the
        // procedural sky background: elevation=19deg, azimuth=150deg, intensity=20.
        XCTAssertEqual(lightParameters.color, .one, "color should be all 1's")
        XCTAssertEqual(lightParameters.intensity, 20.0, "intensity should default to 20")
        XCTAssertEqual(lightParameters.direction.x, 0.47275954, accuracy: 0.001, "direction.x should match elevation=19/azimuth=150")
        XCTAssertEqual(lightParameters.direction.y, 0.3255682, accuracy: 0.001, "direction.y should match elevation=19/azimuth=150")
        XCTAssertEqual(lightParameters.direction.z, -0.81884295, accuracy: 0.001, "direction.z should match elevation=19/azimuth=150")

        destroyEntity(entityId: entityId)
    }

    func testPointLightParameters() {
        destroyAllEntities()
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
        XCTAssertEqual(pointLightParameter[0].attenuation.w, 1.0, "range should match radius")
        XCTAssertEqual(pointLightParameter[0].radius, 1.0, "radius should be 1")

        destroyEntity(entityId: entityId)
    }

    func testRadiometricPointLightSeparatesSourceRadiusFromInfluenceRange() throws {
        destroyAllEntities()

        let entityId = createEntity()
        createPointLight(entityId: entityId)
        let light = try XCTUnwrap(scene.get(component: LightComponent.self, for: entityId))
        let point = try XCTUnwrap(scene.get(component: PointLightComponent.self, for: entityId))
        light.intensity = 1000.0
        light.usesRadiometricUnits = true
        point.radius = 0.1
        point.range = 12.0
        point.castsShadow = true

        let parameters = try XCTUnwrap(getPointLights().first)
        XCTAssertLessThan(parameters.attenuation.x, 0.0)
        XCTAssertEqual(parameters.attenuation.w, 12.0, accuracy: 0.001)
        XCTAssertEqual(parameters.radius, 0.1, accuracy: 0.001)

        var shadowState = PointShadowState()
        shadowState.update()
        XCTAssertEqual(shadowState.farDistance, 12.0, accuracy: 0.001)
        XCTAssertEqual(shadowState.makeUniforms().shadowSoftness, 0.1, accuracy: 0.001)

        destroyEntity(entityId: entityId)
    }

    func testPointLightShadowFlagDefaultsOffAndCanBeEnabledThroughAPI() {
        destroyAllEntities()

        let entityId: EntityID = createEntity()
        createPointLight(entityId: entityId)

        XCTAssertFalse(getPointLightCastsShadow(entityId: entityId))
        XCTAssertNil(getShadowCastingPointLight())

        setLight(entityId: entityId, .point(.castsShadow(true)))

        XCTAssertTrue(getPointLightCastsShadow(entityId: entityId))
        let shadowLight = getShadowCastingPointLight()
        XCTAssertEqual(shadowLight?.entityId, entityId)
        XCTAssertEqual(shadowLight?.index, 0)

        destroyEntity(entityId: entityId)
    }

    func testRenderComponentShadowCastingFlagDefaultsOnAndCanBeDisabled() {
        destroyAllEntities()

        let entityId: EntityID = createEntity()
        setEntityMeshDirect(entityId: entityId, meshes: BasicPrimitives.createCube(), assetName: "Cube")

        XCTAssertTrue(getEntityCastsShadow(entityId: entityId))

        setEntityCastsShadow(entityId: entityId, false)
        XCTAssertFalse(getEntityCastsShadow(entityId: entityId))

        setEntityCastsShadow(entityId: entityId, true)
        XCTAssertTrue(getEntityCastsShadow(entityId: entityId))

        destroyEntity(entityId: entityId)
    }

    func testPointShadowStateBuildsSixCubeFaceMatrices() {
        destroyAllEntities()

        let entityId: EntityID = createEntity()
        createPointLight(entityId: entityId)
        setLight(entityId: entityId, .point(.castsShadow(true)))

        var state = PointShadowState()
        state.update()

        XCTAssertTrue(state.isActive)
        XCTAssertEqual(state.lightSpaceMatrices.count, 6)
        XCTAssertEqual(state.farDistance, minimumPointShadowDistance, accuracy: 0.001)
        XCTAssertEqual(state.makeUniforms().lightIndex, 0)
        XCTAssertEqual(state.makeUniforms().enabled, 1.0)

        let firstFace = state.lightSpaceMatrices[0]
        XCTAssertGreaterThan(abs(firstFace.columns.0.x) + abs(firstFace.columns.1.y) + abs(firstFace.columns.2.z), 0.001)

        destroyEntity(entityId: entityId)
    }

    func testPointShadowProjectionHasPracticalDepthRange() {
        destroyAllEntities()

        let originalReverseZ = renderInfo.reverseZEnabled
        defer { renderInfo.reverseZEnabled = originalReverseZ }
        renderInfo.reverseZEnabled = true

        let entityId: EntityID = createEntity()
        createPointLight(entityId: entityId)
        setLight(entityId: entityId, .point(.castsShadow(true)))

        var state = PointShadowState()
        state.update()

        guard let shadowLight = state.light else {
            XCTFail("Expected an active shadow-casting point light")
            return
        }

        // Face 0 looks down +X (see pointShadowFaceDirections in ShadowSystem.swift).
        let matrix = state.lightSpaceMatrices[0]
        let nearPoint = shadowLight.light.position + simd_float3(0.1, 0.0, 0.0)
        // Beyond the point light's default radius (1.0), but still within the shadow
        // frustum's far plane (minimumPointShadowDistance == 10.0).
        let farPoint = shadowLight.light.position + simd_float3(3.0, 0.0, 0.0)
        let nearFarPlanePoint = shadowLight.light.position + simd_float3(9.0, 0.0, 0.0)

        let nearClip = matrix * simd_float4(nearPoint, 1.0)
        let farClip = matrix * simd_float4(farPoint, 1.0)
        let nearFarPlaneClip = matrix * simd_float4(nearFarPlanePoint, 1.0)

        let nearDepth = nearClip.z / nearClip.w
        let farDepth = farClip.z / farClip.w
        let nearFarPlaneDepth = nearFarPlaneClip.z / nearFarPlaneClip.w

        // Point shadows always use a standard (non-reverse) depth range regardless of the
        // main scene's reverse-Z setting, matching the spot/CSM shadow passes.
        XCTAssertGreaterThanOrEqual(nearDepth, 0.0)
        XCTAssertLessThanOrEqual(farDepth, 1.0)
        XCTAssertLessThan(nearDepth, farDepth)

        XCTAssertGreaterThanOrEqual(nearFarPlaneDepth, 0.0)
        XCTAssertLessThanOrEqual(nearFarPlaneDepth, 1.0)
        XCTAssertLessThan(farDepth, nearFarPlaneDepth)

        destroyEntity(entityId: entityId)
    }

    func testPointShadowBiasStaysInSpotShadowOrderOfMagnitude() {
        destroyAllEntities()

        let entityId: EntityID = createEntity()
        createPointLight(entityId: entityId)
        setLight(entityId: entityId, .point(.castsShadow(true)))

        var state = PointShadowState()
        state.update()

        let pointBias = state.makeUniforms().bias
        let spotBias = SpotShadowUniforms().bias

        // Regression guard: point shadow bias previously defaulted to 0.05 (33x spot's
        // 0.0015), which combined with the far-plane compression at small scene scales made
        // the shadow comparison resolve to "lit" almost everywhere, hiding real shadows.
        XCTAssertEqual(pointBias, spotBias, accuracy: 0.0001)

        destroyEntity(entityId: entityId)
    }

    func testPointShadowMatrixUpdatesWhenPointLightMoves() {
        destroyAllEntities()

        let entityId: EntityID = createEntity()
        createPointLight(entityId: entityId)
        setLight(entityId: entityId, .point(.castsShadow(true)))

        var state = PointShadowState()
        state.update()
        let initialMatrices = state.lightSpaceMatrices
        let initialPosition = state.light?.light.position ?? .zero

        translateTo(entityId: entityId, position: initialPosition + simd_float3(2.0, 1.0, 0.0))
        state.update()

        let updatedPosition = state.light?.light.position ?? .zero
        for face in 0 ..< 6 {
            assertMatrixNotApproximatelyEqual(state.lightSpaceMatrices[face], initialMatrices[face])
        }
        XCTAssertGreaterThan(simd_length(updatedPosition - initialPosition), 0.001)

        destroyEntity(entityId: entityId)
    }

    func testShadowCastingPointLightUsesPointLightOrderIndexAndRadius() {
        destroyAllEntities()

        let unshadowed: EntityID = createEntity()
        createPointLight(entityId: unshadowed)

        let shadowed: EntityID = createEntity()
        createPointLight(entityId: shadowed)
        setLight(entityId: shadowed, .point(.radius(4.0)))
        setLight(entityId: shadowed, .point(.castsShadow(true)))

        let shadowLight = getShadowCastingPointLight()
        let pointLights = getPointLights()
        let expectedIndex = pointLights.firstIndex {
            abs($0.attenuation.w - 4.0) < 0.001
        }

        XCTAssertEqual(shadowLight?.entityId, shadowed)
        XCTAssertEqual(Int(shadowLight?.index ?? -1), expectedIndex)
        XCTAssertEqual(shadowLight?.light.attenuation.w ?? 0.0, 4.0, accuracy: 0.001)

        destroyEntity(entityId: unshadowed)
        destroyEntity(entityId: shadowed)
    }

    func testSpotPointLightParameters() {
        destroyAllEntities()

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
        XCTAssertEqual(spotLightParameter[0].attenuation.w, 1.0, "range should match radius")
        XCTAssertEqual(spotLightParameter[0].outerCone, 0.523, accuracy: 0.001, "outer cone should be 1")
        XCTAssertEqual(spotLightParameter[0].innerCone, 0.427, accuracy: 0.001, "inner cone should be 1")

        XCTAssertEqual(spotLightParameter[0].direction.x, 0.0, accuracy: 0.001, "Rotation about X axis should match")
        XCTAssertEqual(spotLightParameter[0].direction.y, -1.0, accuracy: 0.001, "Rotation about Y axis should match")
        XCTAssertEqual(spotLightParameter[0].direction.z, 0.0, accuracy: 0.001, "Rotation about Z axis should match")

        destroyEntity(entityId: entityId)
    }

    func testSpotLightShadowFlagDefaultsOffAndCanBeEnabledThroughAPI() {
        destroyAllEntities()

        let entityId: EntityID = createEntity()
        createSpotLight(entityId: entityId)

        XCTAssertFalse(getSpotLightCastsShadow(entityId: entityId))
        XCTAssertNil(getShadowCastingSpotLight())

        setLight(entityId: entityId, .spot(.castsShadow(true)))

        XCTAssertTrue(getSpotLightCastsShadow(entityId: entityId))
        let shadowLight = getShadowCastingSpotLight()
        XCTAssertEqual(shadowLight?.entityId, entityId)
        XCTAssertEqual(shadowLight?.index, 0)

        destroyEntity(entityId: entityId)
    }

    func testShadowCastingSpotLightUsesSpotLightOrderIndexAndRadius() {
        destroyAllEntities()

        let unshadowed: EntityID = createEntity()
        createSpotLight(entityId: unshadowed)

        let shadowed: EntityID = createEntity()
        createSpotLight(entityId: shadowed)
        setLight(entityId: shadowed, .spot(.radius(4.0)))
        setLight(entityId: shadowed, .spot(.castsShadow(true)))

        let shadowLight = getShadowCastingSpotLight()
        let spotLights = getSpotLights()
        let expectedIndex = spotLights.firstIndex {
            abs($0.attenuation.w - 4.0) < 0.001
        }

        XCTAssertEqual(shadowLight?.entityId, shadowed)
        XCTAssertEqual(Int(shadowLight?.index ?? -1), expectedIndex)
        XCTAssertEqual(shadowLight?.light.attenuation.w ?? 0.0, 4.0, accuracy: 0.001)

        destroyEntity(entityId: unshadowed)
        destroyEntity(entityId: shadowed)
    }

    func testSpotShadowProjectionUsesNormalShadowDepthWhenSceneUsesReverseZ() {
        destroyAllEntities()

        let originalReverseZ = renderInfo.reverseZEnabled
        defer { renderInfo.reverseZEnabled = originalReverseZ }
        renderInfo.reverseZEnabled = true

        let entityId: EntityID = createEntity()
        createSpotLight(entityId: entityId)
        setLight(entityId: entityId, .spot(.radius(4.0)))
        setLight(entityId: entityId, .spot(.castsShadow(true)))

        var state = SpotShadowState()
        state.update()

        guard let shadowLight = state.light else {
            XCTFail("Expected an active shadow-casting spot light")
            return
        }

        let direction = simd_normalize(shadowLight.light.direction)
        let nearPoint = shadowLight.light.position + direction * 0.1
        let farPoint = shadowLight.light.position + direction * 3.0
        let nearClip = state.lightSpaceMatrix * simd_float4(nearPoint, 1.0)
        let farClip = state.lightSpaceMatrix * simd_float4(farPoint, 1.0)
        let nearDepth = nearClip.z / nearClip.w
        let farDepth = farClip.z / farClip.w

        XCTAssertGreaterThanOrEqual(nearDepth, 0.0)
        XCTAssertLessThanOrEqual(farDepth, 1.0)
        XCTAssertLessThan(nearDepth, farDepth)

        destroyEntity(entityId: entityId)
    }

    func testSpotShadowProjectionHasPracticalDefaultRange() {
        destroyAllEntities()

        let entityId: EntityID = createEntity()
        createSpotLight(entityId: entityId)
        setLight(entityId: entityId, .spot(.castsShadow(true)))

        var state = SpotShadowState()
        state.update()

        guard let shadowLight = state.light else {
            XCTFail("Expected an active shadow-casting spot light")
            return
        }

        let direction = simd_normalize(shadowLight.light.direction)
        let pointBeyondDefaultRadius = shadowLight.light.position + direction * 3.0
        let clip = state.lightSpaceMatrix * simd_float4(pointBeyondDefaultRadius, 1.0)
        let depth = clip.z / clip.w

        XCTAssertGreaterThanOrEqual(depth, 0.0)
        XCTAssertLessThanOrEqual(depth, 1.0)

        destroyEntity(entityId: entityId)
    }

    func testSpotShadowMatrixUpdatesWhenSpotLightRotates() {
        destroyAllEntities()

        let entityId: EntityID = createEntity()
        createSpotLight(entityId: entityId)
        setLight(entityId: entityId, .spot(.castsShadow(true)))

        var state = SpotShadowState()
        state.update()
        let initialMatrix = state.lightSpaceMatrix
        let initialDirection = state.light?.light.direction ?? .zero

        rotateBy(entityId: entityId, angle: 45.0, axis: simd_float3(0.0, 0.0, 1.0))
        state.update()

        let updatedDirection = state.light?.light.direction ?? .zero
        assertMatrixNotApproximatelyEqual(state.lightSpaceMatrix, initialMatrix)
        assertMatrixNotApproximatelyEqual(state.makeUniforms().lightSpaceMatrix, SpotShadowUniforms(lightSpaceMatrix: initialMatrix).lightSpaceMatrix)
        XCTAssertGreaterThan(simd_length(updatedDirection - initialDirection), 0.001)

        destroyEntity(entityId: entityId)
    }

    func testSpotLightDirectionUsesWorldOrientationFromParentTransform() {
        destroyAllEntities()

        let parentId: EntityID = createEntity()
        registerTransformComponent(entityId: parentId)
        registerSceneGraphComponent(entityId: parentId)

        let spotId: EntityID = createEntity()
        createSpotLight(entityId: spotId)
        setParent(childId: spotId, parentId: parentId)

        let initialDirection = getLightEmissionDirection(entityId: spotId)
        rotateBy(entityId: parentId, angle: 45.0, axis: simd_float3(0.0, 0.0, 1.0))
        let updatedDirection = getLightEmissionDirection(entityId: spotId)

        XCTAssertGreaterThan(simd_length(updatedDirection - initialDirection), 0.001)
        assertVector(getSpotLights().first?.direction ?? .zero, equals: updatedDirection)

        destroyEntity(entityId: spotId)
        destroyEntity(entityId: parentId)
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
