//
//  LightPortalSystemTests.swift
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
final class LightPortalSystemTests: XCTestCase {
    override func setUp() async throws {
        resetEngineTestState()
    }

    func testDiscoveryReturnsRenderableEntitiesWithEnabledPortalChannels() {
        let windowChannel = SceneChannel.userCustom(index: 0)
        setSceneChannel(
            windowChannel,
            .lightPortal(.enabled(intensity: 2.0, range: 8.0, useRealWorldTint: true, maxActivePortals: 4, activationDistance: 12.0))
        )

        let entityId = makeRenderableEntity(channels: windowChannel)
        let candidates = discoverSceneLightPortalCandidates()

        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates.first?.entityId, entityId)
        XCTAssertEqual(candidates.first?.channels, windowChannel)
        XCTAssertEqual(candidates.first?.mode, .enabled(intensity: 2.0, range: 8.0, useRealWorldTint: true, maxActivePortals: 4, activationDistance: 12.0))
        XCTAssertEqual(candidates.first?.localBoundsMin, simd_float3(-1.0, -1.0, -0.05))
        XCTAssertEqual(candidates.first?.localBoundsMax, simd_float3(1.0, 1.0, 0.05))

        XCTAssertEqual(
            getLightPortalDiscoveryDiagnostics(),
            LightPortalDiscoveryDiagnostics(
                scannedRenderableEntityCount: 1,
                candidateCount: 1,
                skippedHiddenCount: 0,
                skippedInvisibleRenderComponentCount: 0,
                skippedDisabledPortalCount: 0,
                skippedInvalidGeometryCount: 0
            )
        )
    }

    func testDiscoveryUsesRegisteredPrefixFallbackChannels() {
        let windowChannel = SceneChannel.userCustom(index: 1)
        registerSceneChannelPrefix("WIN_", channels: windowChannel)
        setSceneChannel(windowChannel, .lightPortal(.enabled()))

        let entityId = makeRenderableEntity(name: "WIN_Main")
        let candidates = discoverSceneLightPortalCandidates()

        XCTAssertEqual(candidates.map(\.entityId), [entityId])
        XCTAssertEqual(candidates.first?.channels, windowChannel)
    }

    func testDiscoverySkipsHiddenAndInvisibleEntities() {
        let windowChannel = SceneChannel.userCustom(index: 2)
        let hiddenChannel = SceneChannel.userCustom(index: 3)
        setSceneChannel(windowChannel, .lightPortal(.enabled()))
        setSceneChannel(hiddenChannel, .renderMode(.hidden))

        let hiddenEntityId = makeRenderableEntity(channels: [windowChannel, hiddenChannel])
        let invisibleEntityId = makeRenderableEntity(channels: windowChannel, renderVisible: false)
        let candidates = discoverSceneLightPortalCandidates()

        XCTAssertTrue(candidates.isEmpty)
        XCTAssertFalse(candidates.contains { $0.entityId == hiddenEntityId })
        XCTAssertFalse(candidates.contains { $0.entityId == invisibleEntityId })

        XCTAssertEqual(
            getLightPortalDiscoveryDiagnostics(),
            LightPortalDiscoveryDiagnostics(
                scannedRenderableEntityCount: 2,
                candidateCount: 0,
                skippedHiddenCount: 1,
                skippedInvisibleRenderComponentCount: 1,
                skippedDisabledPortalCount: 0,
                skippedInvalidGeometryCount: 0
            )
        )
    }

    func testDiscoverySkipsChannelsWithoutEnabledLightPortalMode() {
        let windowChannel = SceneChannel.userCustom(index: 4)
        setSceneChannel(windowChannel, .lightPortal(.enabled()))
        _ = makeRenderableEntity(channels: .contextGeometry)

        let candidates = discoverSceneLightPortalCandidates()

        XCTAssertTrue(candidates.isEmpty)
        XCTAssertEqual(
            getLightPortalDiscoveryDiagnostics(),
            LightPortalDiscoveryDiagnostics(
                scannedRenderableEntityCount: 1,
                candidateCount: 0,
                skippedHiddenCount: 0,
                skippedInvisibleRenderComponentCount: 0,
                skippedDisabledPortalCount: 1,
                skippedInvalidGeometryCount: 0
            )
        )
    }

    func testDiscoveryFastPathSkipsRenderableScanWhenNoPortalChannelsAreEnabled() {
        _ = makeRenderableEntity(channels: .contextGeometry)

        let candidates = discoverSceneLightPortalCandidates()
        let areaLights = getAreaLights()

        XCTAssertTrue(candidates.isEmpty)
        XCTAssertTrue(areaLights.isEmpty)
        XCTAssertEqual(getLightPortalDiscoveryDiagnostics(), .empty)
        XCTAssertEqual(getLightPortalResolutionDiagnostics(), .empty)
        XCTAssertEqual(getLightPortalPerformanceDiagnostics(), .empty)
    }

    func testPerformanceDiagnosticsRecordDiscoveryAndResolutionCost() {
        let windowChannel = SceneChannel.userCustom(index: 23)
        setSceneChannel(windowChannel, .lightPortal(.enabled(maxActivePortals: 2, activationDistance: 20.0)))
        _ = makePortalEntity(channels: windowChannel, position: simd_float3(1.0, 0.0, 0.0))
        _ = makePortalEntity(channels: windowChannel, position: simd_float3(3.0, 0.0, 0.0))

        _ = resolveSceneLightPortalProxyLights(cameraPosition: .zero)

        let diagnostics = getLightPortalPerformanceDiagnostics()
        XCTAssertNotNil(diagnostics.lastDiscoveryDurationMs)
        XCTAssertNotNil(diagnostics.lastResolutionDurationMs)
        XCTAssertGreaterThanOrEqual(diagnostics.lastDiscoveryDurationMs ?? -1.0, 0.0)
        XCTAssertGreaterThanOrEqual(diagnostics.lastResolutionDurationMs ?? -1.0, 0.0)
        XCTAssertEqual(diagnostics.lastScannedRenderableEntityCount, 2)
        XCTAssertEqual(diagnostics.lastDiscoveredCandidateCount, 2)
        XCTAssertEqual(diagnostics.lastResolvedProxyLightCount, 2)
    }

    func testDiagnosticsLoggingRequiresLightPortalCategory() {
        Logger.resetCategoryToggles()
        XCTAssertFalse(Logger.isEnabled(category: .lightPortal))

        LightPortalSystem.shared.logDiagnosticsNow()

        Logger.enable(category: .lightPortal)
        XCTAssertTrue(Logger.isEnabled(category: .lightPortal))
        LightPortalSystem.shared.logDiagnosticsNow()
    }

    func testResolveProxyLightsDerivesShapeFromPortalTransform() {
        let windowChannel = SceneChannel.userCustom(index: 4)
        setSceneChannel(windowChannel, .lightPortal(.enabled(intensity: 3.0, range: 9.0, useRealWorldTint: false, maxActivePortals: 2, activationDistance: 20.0)))

        let entityId = makeRenderableEntity(channels: windowChannel)
        scene.get(component: LocalTransformComponent.self, for: entityId)?.boundingBox = (
            min: simd_float3(-1.0, -0.5, -0.1),
            max: simd_float3(1.0, 0.5, 0.1)
        )
        scene.get(component: WorldTransformComponent.self, for: entityId)?.space = matrix4x4Translation(2.0, 3.0, 4.0) * matrix4x4Scale(2.0, 3.0, 1.0)

        let proxyLights = resolveSceneLightPortalProxyLights(cameraPosition: simd_float3(2.0, 3.0, 0.0))

        XCTAssertEqual(proxyLights.count, 1)
        let proxyLight = tryUnwrap(proxyLights.first)
        XCTAssertEqual(proxyLight.sourceEntityId, entityId)
        XCTAssertEqual(proxyLight.channels, windowChannel)
        XCTAssertEqual(proxyLight.position, simd_float3(2.0, 3.0, 4.0))
        XCTAssertEqual(proxyLight.forward, simd_float3(0.0, 0.0, 1.0))
        XCTAssertEqual(proxyLight.right, simd_float3(1.0, 0.0, 0.0))
        XCTAssertEqual(proxyLight.up, simd_float3(0.0, 1.0, 0.0))
        XCTAssertEqual(proxyLight.bounds, simd_float2(4.0, 3.0))
        XCTAssertEqual(proxyLight.color, simd_float3(1.0, 1.0, 1.0))
        XCTAssertEqual(proxyLight.intensity, 3.0)
        XCTAssertEqual(proxyLight.range, 9.0)
        XCTAssertEqual(proxyLight.distanceToCamera, 4.0)
        XCTAssertFalse(proxyLight.useRealWorldTint)
    }

    func testResolveProxyLightsDerivesPlaneFromLargestBoundsAxes() {
        let windowChannel = SceneChannel.userCustom(index: 10)
        setSceneChannel(windowChannel, .lightPortal(.enabled(maxActivePortals: 3, activationDistance: 20.0)))

        let xyWindow = makePortalEntity(channels: windowChannel, position: simd_float3(0.0, 0.0, 1.0))
        scene.get(component: LocalTransformComponent.self, for: xyWindow)?.boundingBox = (
            min: simd_float3(-2.0, -1.0, -0.05),
            max: simd_float3(2.0, 1.0, 0.05)
        )

        let xzWindow = makePortalEntity(channels: windowChannel, position: simd_float3(0.0, 0.0, 2.0))
        scene.get(component: LocalTransformComponent.self, for: xzWindow)?.boundingBox = (
            min: simd_float3(-2.0, -0.05, -1.0),
            max: simd_float3(2.0, 0.05, 1.0)
        )

        let yzWindow = makePortalEntity(channels: windowChannel, position: simd_float3(0.0, 0.0, 3.0))
        scene.get(component: LocalTransformComponent.self, for: yzWindow)?.boundingBox = (
            min: simd_float3(-0.05, -2.0, -1.0),
            max: simd_float3(0.05, 2.0, 1.0)
        )

        let proxyLights = resolveSceneLightPortalProxyLights(cameraPosition: .zero)

        let xyProxy = tryUnwrap(proxyLights.first { $0.sourceEntityId == xyWindow })
        XCTAssertEqual(xyProxy.bounds, simd_float2(4.0, 2.0))
        XCTAssertEqual(xyProxy.right, simd_float3(1.0, 0.0, 0.0))
        XCTAssertEqual(xyProxy.up, simd_float3(0.0, 1.0, 0.0))
        XCTAssertEqual(xyProxy.forward, simd_float3(0.0, 0.0, 1.0))

        let xzProxy = tryUnwrap(proxyLights.first { $0.sourceEntityId == xzWindow })
        XCTAssertEqual(xzProxy.bounds, simd_float2(4.0, 2.0))
        XCTAssertEqual(xzProxy.right, simd_float3(1.0, 0.0, 0.0))
        XCTAssertEqual(xzProxy.up, simd_float3(0.0, 0.0, 1.0))
        XCTAssertEqual(xzProxy.forward, simd_float3(0.0, 1.0, 0.0))

        let yzProxy = tryUnwrap(proxyLights.first { $0.sourceEntityId == yzWindow })
        XCTAssertEqual(yzProxy.bounds, simd_float2(4.0, 2.0))
        XCTAssertEqual(yzProxy.right, simd_float3(0.0, 1.0, 0.0))
        XCTAssertEqual(yzProxy.up, simd_float3(0.0, 0.0, 1.0))
        XCTAssertEqual(yzProxy.forward, simd_float3(1.0, 0.0, 0.0))
    }

    func testResolveProxyLightsSelectsNearestActivePortalsWithinCap() {
        let windowChannel = SceneChannel.userCustom(index: 5)
        setSceneChannel(windowChannel, .lightPortal(.enabled(maxActivePortals: 2, activationDistance: 100.0)))

        let far = makePortalEntity(channels: windowChannel, position: simd_float3(20.0, 0.0, 0.0))
        let near = makePortalEntity(channels: windowChannel, position: simd_float3(2.0, 0.0, 0.0))
        let middle = makePortalEntity(channels: windowChannel, position: simd_float3(8.0, 0.0, 0.0))

        let proxyLights = resolveSceneLightPortalProxyLights(cameraPosition: .zero)

        XCTAssertEqual(proxyLights.map(\.sourceEntityId), [near, middle])
        XCTAssertFalse(proxyLights.contains { $0.sourceEntityId == far })
        XCTAssertEqual(
            getLightPortalResolutionDiagnostics(),
            LightPortalResolutionDiagnostics(
                discoveredCandidateCount: 3,
                activePortalCount: 2,
                skippedByActivationDistanceCount: 0,
                maxActivePortals: 2
            )
        )
    }

    func testResolveProxyLightsSkipsPortalsBeyondActivationDistance() {
        let windowChannel = SceneChannel.userCustom(index: 6)
        setSceneChannel(windowChannel, .lightPortal(.enabled(maxActivePortals: 4, activationDistance: 5.0)))

        let active = makePortalEntity(channels: windowChannel, position: simd_float3(3.0, 0.0, 0.0))
        let skipped = makePortalEntity(channels: windowChannel, position: simd_float3(10.0, 0.0, 0.0))

        let proxyLights = resolveSceneLightPortalProxyLights(cameraPosition: .zero)

        XCTAssertEqual(proxyLights.map(\.sourceEntityId), [active])
        XCTAssertFalse(proxyLights.contains { $0.sourceEntityId == skipped })
        XCTAssertEqual(
            getLightPortalResolutionDiagnostics(),
            LightPortalResolutionDiagnostics(
                discoveredCandidateCount: 2,
                activePortalCount: 1,
                skippedByActivationDistanceCount: 1,
                maxActivePortals: 4
            )
        )
    }

    func testResolveProxyLightsUsesDistanceToPortalSurfaceForActivation() {
        let windowChannel = SceneChannel.userCustom(index: 14)
        setSceneChannel(windowChannel, .lightPortal(.enabled(maxActivePortals: 1, activationDistance: 2.0)))

        let entityId = makePortalEntity(channels: windowChannel, position: .zero)
        scene.get(component: LocalTransformComponent.self, for: entityId)?.boundingBox = (
            min: simd_float3(-10.0, -1.0, -0.05),
            max: simd_float3(10.0, 1.0, 0.05)
        )

        let proxyLights = resolveSceneLightPortalProxyLights(cameraPosition: simd_float3(9.5, 0.0, 1.0))

        XCTAssertEqual(proxyLights.map(\.sourceEntityId), [entityId])
        XCTAssertEqual(proxyLights.first?.distanceToCamera ?? -1.0, 1.0, accuracy: 0.0001)
    }

    func testResolveProxyLightsAppliesCapsPerPortalChannel() {
        let westWindows = SceneChannel.userCustom(index: 15)
        let eastWindows = SceneChannel.userCustom(index: 16)
        setSceneChannel(westWindows, .lightPortal(.enabled(maxActivePortals: 1, activationDistance: 100.0)))
        setSceneChannel(eastWindows, .lightPortal(.enabled(maxActivePortals: 1, activationDistance: 100.0)))

        let westNear = makePortalEntity(channels: westWindows, position: simd_float3(1.0, 0.0, 0.0))
        let westFar = makePortalEntity(channels: westWindows, position: simd_float3(2.0, 0.0, 0.0))
        let eastNear = makePortalEntity(channels: eastWindows, position: simd_float3(3.0, 0.0, 0.0))
        let eastFar = makePortalEntity(channels: eastWindows, position: simd_float3(4.0, 0.0, 0.0))

        let proxyLights = resolveSceneLightPortalProxyLights(cameraPosition: .zero)

        XCTAssertEqual(proxyLights.map(\.sourceEntityId), [westNear, eastNear])
        XCTAssertFalse(proxyLights.contains { $0.sourceEntityId == westFar })
        XCTAssertFalse(proxyLights.contains { $0.sourceEntityId == eastFar })
    }

    func testResolveProxyLightsConsumesCapacityForEachPortalChannelMembership() {
        let broadWindows = SceneChannel.userCustom(index: 20)
        let specificWindows = SceneChannel.userCustom(index: 21)
        setSceneChannel(broadWindows, .lightPortal(.enabled(maxActivePortals: 1, activationDistance: 100.0)))
        setSceneChannel(specificWindows, .lightPortal(.enabled(maxActivePortals: 2, activationDistance: 100.0)))

        let shared = makePortalEntity(channels: [broadWindows, specificWindows], position: simd_float3(1.0, 0.0, 0.0))
        let specificOnly = makePortalEntity(channels: specificWindows, position: simd_float3(2.0, 0.0, 0.0))
        let broadOnly = makePortalEntity(channels: broadWindows, position: simd_float3(3.0, 0.0, 0.0))

        let proxyLights = resolveSceneLightPortalProxyLights(cameraPosition: .zero)

        XCTAssertEqual(proxyLights.map(\.sourceEntityId), [shared, specificOnly])
        XCTAssertFalse(proxyLights.contains { $0.sourceEntityId == broadOnly })
    }

    func testDiscoverySkipsPortalChannelsWithNonThinGeometry() {
        let windowChannel = SceneChannel.userCustom(index: 17)
        setSceneChannel(windowChannel, .lightPortal(.enabled()))

        _ = makeRenderableEntity(channels: windowChannel, portalBounds: (
            min: simd_float3(-1.0, -1.0, -1.0),
            max: simd_float3(1.0, 1.0, 1.0)
        ))

        XCTAssertTrue(discoverSceneLightPortalCandidates().isEmpty)
        XCTAssertEqual(getLightPortalDiscoveryDiagnostics().skippedInvalidGeometryCount, 1)
    }

    func testAreaLightsIncludeResolvedLightPortalProxies() {
        let windowChannel = SceneChannel.userCustom(index: 7)
        setSceneChannel(windowChannel, .lightPortal(.enabled(intensity: 2.0, range: 6.0, useRealWorldTint: false, maxActivePortals: 2, activationDistance: 20.0)))
        _ = makePortalEntity(channels: windowChannel, position: simd_float3(1.0, 2.0, 3.0))

        let areaLights = getAreaLights()

        XCTAssertEqual(areaLights.count, 1)
        XCTAssertEqual(areaLights[0].position, simd_float3(1.0, 2.0, 3.0))
        XCTAssertEqual(areaLights[0].intensity, 2.0)
        XCTAssertEqual(areaLights[0].range, 6.0)
        XCTAssertEqual(areaLights[0].nearSourceSuppressionRadius, 0.4, accuracy: 0.0001)
        XCTAssertEqual(areaLights[0].bounds, simd_float2(2.0, 2.0))
        XCTAssertTrue(areaLights[0].twoSided)
    }

    func testAreaLightsReuseLightPortalCacheWithinFrame() {
        let windowChannel = SceneChannel.userCustom(index: 12)
        setSceneChannel(windowChannel, .lightPortal(.enabled(maxActivePortals: 1, activationDistance: 20.0)))
        let entityId = makePortalEntity(channels: windowChannel, position: simd_float3(1.0, 0.0, 0.0))

        let firstFrameLights = getAreaLights()
        scene.get(component: RenderComponent.self, for: entityId)?.isVisible = false
        let cachedSameFrameLights = getAreaLights()

        XCTAssertEqual(firstFrameLights.count, 1)
        XCTAssertEqual(cachedSameFrameLights.count, 1)
        XCTAssertEqual(cachedSameFrameLights[0].position, simd_float3(1.0, 0.0, 0.0))
        XCTAssertEqual(getLightPortalRenderDiagnostics().portalAreaLightCount, 1)

        cullFrameIndex &+= 1
        let nextFrameLights = getAreaLights()

        XCTAssertTrue(nextFrameLights.isEmpty)
        XCTAssertEqual(getLightPortalRenderDiagnostics().portalAreaLightCount, 0)
        XCTAssertEqual(getLightPortalRenderDiagnostics().fallbackReason, "No active portal proxy lights")
    }

    func testSceneChannelLightPortalChangesInvalidateAreaLightCacheWithinFrame() {
        let windowChannel = SceneChannel.userCustom(index: 13)
        setSceneChannel(windowChannel, .lightPortal(.enabled(intensity: 1.0, useRealWorldTint: false, maxActivePortals: 1, activationDistance: 20.0)))
        _ = makePortalEntity(channels: windowChannel, position: simd_float3(1.0, 0.0, 0.0))

        let initialLights = getAreaLights()
        setSceneChannel(windowChannel, .lightPortal(.enabled(intensity: 2.5, useRealWorldTint: false, maxActivePortals: 1, activationDistance: 20.0)))
        let updatedLights = getAreaLights()

        XCTAssertEqual(initialLights.count, 1)
        XCTAssertEqual(initialLights[0].intensity, 1.0, accuracy: 0.0001)
        XCTAssertEqual(updatedLights.count, 1)
        XCTAssertEqual(updatedLights[0].intensity, 2.5, accuracy: 0.0001)
        XCTAssertEqual(getLightPortalRenderDiagnostics().maxEffectivePortalIntensity, 2.5)
    }

    func testTransformChangesInvalidateAreaLightCacheWithinFrame() {
        let windowChannel = SceneChannel.userCustom(index: 18)
        setSceneChannel(windowChannel, .lightPortal(.enabled(maxActivePortals: 1, activationDistance: 20.0)))
        let entityId = makePortalEntity(channels: windowChannel, position: simd_float3(1.0, 0.0, 0.0))

        let initialLights = getAreaLights()
        translateTo(entityId: entityId, position: simd_float3(4.0, 0.0, 0.0))
        let updatedLights = getAreaLights()

        XCTAssertEqual(initialLights.first?.position, simd_float3(1.0, 0.0, 0.0))
        XCTAssertEqual(updatedLights.first?.position, simd_float3(4.0, 0.0, 0.0))
    }

    func testActiveCameraMovementInvalidatesAreaLightCacheWithinFrame() {
        let windowChannel = SceneChannel.userCustom(index: 22)
        setSceneChannel(windowChannel, .lightPortal(.enabled(maxActivePortals: 1, activationDistance: 5.0)))
        _ = makePortalEntity(channels: windowChannel, position: .zero)

        let camera = createEntity()
        createGameCamera(entityId: camera)
        translateTo(entityId: camera, position: simd_float3(100.0, 0.0, 0.0))

        let inactiveLights = getAreaLights()
        translateTo(entityId: camera, position: simd_float3(0.0, 0.0, 1.0))
        let activeLights = getAreaLights()

        XCTAssertTrue(inactiveLights.isEmpty)
        XCTAssertEqual(activeLights.count, 1)
        XCTAssertEqual(getLightPortalRenderDiagnostics().portalAreaLightCount, 1)
    }

    func testAreaLightPortalProxyUsesXRContributionScaleWhenRequested() {
        let windowChannel = SceneChannel.userCustom(index: 8)
        setSceneChannel(windowChannel, .lightPortal(.enabled(intensity: 2.0, useRealWorldTint: true, maxActivePortals: 1, activationDistance: 20.0)))
        _ = makePortalEntity(channels: windowChannel, position: simd_float3(1.0, 0.0, 0.0))
        RuntimeEnvironmentLightingStore.shared.mode = .realWorldEstimate
        RuntimeEnvironmentLightingStore.shared.realWorldLightingContribution = 0.5
        RuntimeEnvironmentLightingStore.shared.publishXRLighting(
            RuntimeEnvironmentLighting(
                irradianceMap: nil,
                specularMap: nil,
                brdfMap: nil,
                intensityScale: 3.0,
                tintColor: simd_float3(1.2, 0.9, 0.6),
                isValid: true
            )
        )

        let areaLights = getAreaLights()

        XCTAssertEqual(areaLights.count, 1)
        XCTAssertEqual(areaLights[0].intensity, 3.0, accuracy: 0.0001)
        XCTAssertEqual(areaLights[0].color, simd_float3(1.2, 0.9, 0.6))

        let diagnostics = getLightPortalRenderDiagnostics()
        XCTAssertEqual(diagnostics.portalAreaLightCount, 1)
        XCTAssertEqual(diagnostics.environmentIntensityScale, 1.5, accuracy: 0.0001)
        XCTAssertEqual(diagnostics.xrIntensityScale, 3.0)
        XCTAssertEqual(diagnostics.environmentTintColor, simd_float3(1.2, 0.9, 0.6))
        XCTAssertEqual(diagnostics.realWorldLightingContribution, 0.5)
        XCTAssertEqual(diagnostics.maxEffectivePortalIntensity, 3.0)
        XCTAssertNil(diagnostics.fallbackReason)
    }

    func testXRLightingChangesInvalidateAreaLightCacheWithinFrame() {
        let windowChannel = SceneChannel.userCustom(index: 19)
        setSceneChannel(windowChannel, .lightPortal(.enabled(intensity: 2.0, useRealWorldTint: true, maxActivePortals: 1, activationDistance: 20.0)))
        _ = makePortalEntity(channels: windowChannel, position: simd_float3(1.0, 0.0, 0.0))
        RuntimeEnvironmentLightingStore.shared.mode = .realWorldEstimate
        RuntimeEnvironmentLightingStore.shared.realWorldLightingContribution = 1.0
        RuntimeEnvironmentLightingStore.shared.publishXRLighting(
            RuntimeEnvironmentLighting(
                irradianceMap: nil,
                specularMap: nil,
                brdfMap: nil,
                intensityScale: 1.0,
                tintColor: simd_float3(1.0, 1.0, 1.0),
                isValid: true
            )
        )

        let initialLights = getAreaLights()
        RuntimeEnvironmentLightingStore.shared.publishXRLighting(
            RuntimeEnvironmentLighting(
                irradianceMap: nil,
                specularMap: nil,
                brdfMap: nil,
                intensityScale: 3.0,
                tintColor: simd_float3(1.3, 0.8, 0.6),
                isValid: true
            )
        )
        let updatedLights = getAreaLights()

        XCTAssertEqual(initialLights.first?.intensity ?? -1.0, 2.0, accuracy: 0.0001)
        XCTAssertEqual(updatedLights.first?.intensity ?? -1.0, 6.0, accuracy: 0.0001)
        XCTAssertEqual(updatedLights.first?.color, simd_float3(1.3, 0.8, 0.6))
    }

    func testAreaLightPortalProxyUsesZeroIntensityWhenXRContributionIsUnavailable() {
        let windowChannel = SceneChannel.userCustom(index: 11)
        setSceneChannel(windowChannel, .lightPortal(.enabled(intensity: 2.0, useRealWorldTint: true, maxActivePortals: 1, activationDistance: 20.0)))
        _ = makePortalEntity(channels: windowChannel, position: simd_float3(1.0, 0.0, 0.0))
        RuntimeEnvironmentLightingStore.shared.mode = .realWorldEstimate
        RuntimeEnvironmentLightingStore.shared.publishXRLighting(nil)

        let areaLights = getAreaLights()

        XCTAssertEqual(areaLights.count, 1)
        XCTAssertEqual(areaLights[0].intensity, 0.0, accuracy: 0.0001)

        let diagnostics = getLightPortalRenderDiagnostics()
        XCTAssertEqual(diagnostics.portalAreaLightCount, 1)
        XCTAssertEqual(diagnostics.environmentIntensityScale, 0.0, accuracy: 0.0001)
        XCTAssertFalse(diagnostics.xrLightingValid)
        XCTAssertEqual(diagnostics.maxEffectivePortalIntensity, 0.0)
        XCTAssertEqual(diagnostics.fallbackReason, "XR lighting unavailable for real-world portal tint")
    }

    func testAuthoredAreaLightsTakeCapacityBeforePortalProxyLights() {
        for _ in 0 ..< maxAreaLights {
            makeAuthoredAreaLight()
        }

        let windowChannel = SceneChannel.userCustom(index: 9)
        setSceneChannel(windowChannel, .lightPortal(.enabled(maxActivePortals: 1, activationDistance: 20.0)))
        _ = makePortalEntity(channels: windowChannel, position: simd_float3(1.0, 0.0, 0.0))

        let areaLights = getAreaLights()

        XCTAssertEqual(areaLights.count, maxAreaLights)
        XCTAssertFalse(areaLights.contains { $0.position == simd_float3(1.0, 0.0, 0.0) })
    }

    private func makeRenderableEntity(
        name: String? = nil,
        channels: SceneChannel? = nil,
        renderVisible: Bool = true,
        portalBounds: (min: simd_float3, max: simd_float3) = (
            min: simd_float3(-1.0, -1.0, -0.05),
            max: simd_float3(1.0, 1.0, 0.05)
        )
    ) -> EntityID {
        let entityId = createEntity()
        if let name {
            setEntityName(entityId: entityId, name: name)
        }
        registerComponent(entityId: entityId, componentType: RenderComponent.self)
        scene.get(component: LocalTransformComponent.self, for: entityId)?.boundingBox = portalBounds
        if let channels {
            setEntitySceneChannels(entityId: entityId, channels: channels)
        }
        scene.get(component: RenderComponent.self, for: entityId)?.isVisible = renderVisible
        return entityId
    }

    private func makePortalEntity(channels: SceneChannel, position: simd_float3) -> EntityID {
        let entityId = makeRenderableEntity(channels: channels)
        scene.get(component: WorldTransformComponent.self, for: entityId)?.space = matrix4x4Translation(position.x, position.y, position.z)
        return entityId
    }

    private func makeAuthoredAreaLight() {
        let entityId = createEntity()
        registerComponent(entityId: entityId, componentType: LightComponent.self)
        registerComponent(entityId: entityId, componentType: AreaLightComponent.self)
    }

    private func tryUnwrap<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) -> T {
        guard let value else {
            XCTFail("Expected non-nil value", file: file, line: line)
            fatalError("Expected non-nil value")
        }
        return value
    }
}
