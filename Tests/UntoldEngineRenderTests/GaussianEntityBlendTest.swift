//
//  GaussianEntityBlendTest.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Metal
import simd
@testable import UntoldEngine
import XCTest

/// Per-entity opacity weight and linear colour gain, applied by the preprocess when it compacts
/// an entity's splats into the shared working set: what a mesh-to-splat cross-fade drives and what
/// calibrates a capture's exposure to the scene.
final class GaussianEntityBlendTest: BaseRenderSetup {
    override func tearDown() async throws {
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {
        let gaussian = createEntity()
        setEntityGaussian(entityId: gaussian, filename: "test_gaussians", withExtension: "ply")
    }

    private func gaussianComponent() -> GaussianComponent? {
        let transformId = getComponentId(for: WorldTransformComponent.self)
        let gaussianId = getComponentId(for: GaussianComponent.self)
        guard let entity = queryEntitiesWithComponentIds([transformId, gaussianId], in: scene).first else {
            XCTFail("Expected the Gaussian test asset to be loaded")
            return nil
        }
        return scene.get(component: GaussianComponent.self, for: entity)
    }

    private func lookAtAsset() {
        let cameraEntity = createEntity()
        if let cameraComponent = scene.assign(to: cameraEntity, component: CameraComponent.self) {
            CameraSystem.shared.activeCamera = cameraEntity
            cameraComponent.viewSpace = matrix_identity_float4x4
            cameraComponent.localPosition = .zero
        }
        cameraLookAt(entityId: cameraEntity, eye: simd_float3(0, 3, 7), target: .zero, up: simd_float3(0, 1, 0))
    }

    /// Runs cull + preprocess and returns the shared records of this frame.
    private func compactedRecords() throws -> [GaussianWorkingSetSplat] {
        let commandBuffer = try XCTUnwrap(renderInfo.commandQueue.makeCommandBuffer())
        executeGaussianFrustumCulling(commandBuffer)
        executeGaussianPreprocess(commandBuffer)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        let slot = min(renderInfo.currentInFlightFrameSlot, maxInFlightCommandBuffers - 1)
        let set = try XCTUnwrap(GaussianSharedWorkingSet.shared.visibleSet(slot: slot)).contents().load(as: GaussianVisibleSet.self)
        let count = Int(set.visibleCount)
        let buffer = try XCTUnwrap(GaussianSharedWorkingSet.shared.records(slot: slot))
        return Array(UnsafeBufferPointer(start: buffer.contents().bindMemory(to: GaussianWorkingSetSplat.self, capacity: count), count: count))
    }

    func testOpacityScaleWeightsEverySplatAndZeroHidesTheEntity() throws {
        lookAtAsset()
        guard let component = gaussianComponent() else { return }

        let full = try compactedRecords()
        XCTAssertGreaterThan(full.count, 0, "Sanity check: the asset is in view")

        component.opacityScale = 0.25
        let quarter = try compactedRecords()
        XCTAssertEqual(quarter.count, full.count, "A partial weight keeps every splat")
        // Records land in nondeterministic slot order, so compare the multiset of opacities.
        let fullOpacities = full.map { ($0.conicAndOpacity.w * 1000).rounded() / 1000 }.sorted()
        let quarterOpacities = quarter.map { ($0.conicAndOpacity.w * 4 * 1000).rounded() / 1000 }.sorted()
        XCTAssertEqual(fullOpacities, quarterOpacities, "Each splat's opacity is scaled by the entity weight")

        component.opacityScale = 0
        let hidden = try compactedRecords()
        XCTAssertEqual(hidden.count, 0, "A zero weight compacts nothing: the entity is hidden without unloading")

        component.opacityScale = 1
    }

    private func sortedChannel(_ records: [GaussianWorkingSetSplat], _ channel: Int, scale: Float) -> [Float] {
        records.map { (($0.color[channel] / scale) * 1000).rounded() / 1000 }.sorted()
    }

    func testColorGainMultipliesTheRecordColour() throws {
        lookAtAsset()
        guard let component = gaussianComponent() else { return }
        XCTAssertEqual(component.captureExposureEV, 0, "A .ply carries no capture exposure")
        XCTAssertEqual(component.captureWhiteBalance, SIMD3<Float>(repeating: 1))
        XCTAssertEqual(component.colorGain, SIMD3<Float>(repeating: 1))

        let neutral = try compactedRecords()
        XCTAssertGreaterThan(neutral.count, 0)

        // +1 EV over a capture at 0 EV doubles; the capture white balance scales per channel.
        component.exposureOffsetEV = 1
        component.captureWhiteBalance = SIMD3<Float>(1, 0.5, 0.25)
        XCTAssertEqual(component.colorGain, SIMD3<Float>(2, 1, 0.5))
        let gained = try compactedRecords()
        XCTAssertEqual(gained.count, neutral.count)

        XCTAssertEqual(sortedChannel(neutral, 0, scale: 1), sortedChannel(gained, 0, scale: 2), "red doubled")
        XCTAssertEqual(sortedChannel(neutral, 1, scale: 1), sortedChannel(gained, 1, scale: 1), "green unchanged")
        XCTAssertEqual(sortedChannel(neutral, 2, scale: 1), sortedChannel(gained, 2, scale: 0.5), "blue halved")

        // A capture recorded at +1 EV is brought back to neutral: the same offset now cancels.
        component.captureExposureEV = 1
        component.captureWhiteBalance = SIMD3<Float>(repeating: 1)
        XCTAssertEqual(component.colorGain, SIMD3<Float>(repeating: 1))

        component.exposureOffsetEV = 0
        component.captureExposureEV = 0
    }

    func testRealWorldTintAppliesOnlyWhenOptedInAndEstimating() throws {
        lookAtAsset()
        guard let component = gaussianComponent() else { return }
        let store = RuntimeEnvironmentLightingStore.shared
        defer { store.reset() }

        let neutral = try compactedRecords()
        XCTAssertGreaterThan(neutral.count, 0)

        store.publishXRLighting(RuntimeEnvironmentLighting(
            irradianceMap: nil, specularMap: nil, brdfMap: nil,
            intensityScale: 1, tintColor: simd_float3(1, 0.5, 0.25), isValid: true
        ))
        store.setMode(.realWorldEstimate)
        XCTAssertNotNil(gaussianRealWorldTint(), "The estimate is available while the mode is realWorldEstimate")
        XCTAssertFalse(component.useRealWorldTint, "Off by default")
        let notOptedIn = try compactedRecords()
        XCTAssertEqual(sortedChannel(neutral, 2, scale: 1), sortedChannel(notOptedIn, 2, scale: 1), "blue unchanged without the opt-in")

        component.useRealWorldTint = true
        let tinted = try compactedRecords()
        XCTAssertEqual(sortedChannel(neutral, 0, scale: 1), sortedChannel(tinted, 0, scale: 1), "red unchanged")
        XCTAssertEqual(sortedChannel(neutral, 1, scale: 1), sortedChannel(tinted, 1, scale: 0.5), "green halved by the estimate")
        XCTAssertEqual(sortedChannel(neutral, 2, scale: 1), sortedChannel(tinted, 2, scale: 0.25), "blue quartered by the estimate")

        store.setMode(.staticIBL)
        XCTAssertNil(gaussianRealWorldTint(), "Static IBL: no estimate to apply")
        let staticIBL = try compactedRecords()
        XCTAssertEqual(sortedChannel(neutral, 2, scale: 1), sortedChannel(staticIBL, 2, scale: 1), "blue unchanged outside the estimate mode")

        component.useRealWorldTint = false
    }
}
