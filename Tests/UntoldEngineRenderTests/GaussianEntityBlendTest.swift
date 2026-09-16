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

    /// The gained records' `channel` against the neutral records' channel decoded to linear,
    /// scaled by `gain` and re-encoded: the gain is a gain in linear light on a colour the
    /// record keeps display-referred. Both sides are sorted; the transform is monotone, so ranks
    /// pair the same splats. The GPU and CPU transfer curves agree to well under 1/1000.
    private func assertChannel(_ gained: [GaussianWorkingSetSplat], _ channel: Int, matches neutral: [GaussianWorkingSetSplat], gain: Float, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        let expected = neutral.map { UntoldGSColor.display(fromLinear: UntoldGSColor.linear(fromDisplay: $0.color[channel]) * gain) }.sorted()
        let actual = gained.map { $0.color[channel] }.sorted()
        XCTAssertEqual(expected.count, actual.count, message, file: file, line: line)
        let worst = zip(expected, actual).map { abs($0 - $1) }.max() ?? 0
        XCTAssertLessThan(worst, 2e-3, "\(message): largest channel difference \(worst)", file: file, line: line)
        if gain != 1 {
            // A gain applied to the encoded colour would give neutral × gain instead.
            let encodedDomain = neutral.map { $0.color[channel] * gain }.sorted()
            let encodedWorst = zip(encodedDomain, actual).map { abs($0 - $1) }.max() ?? 0
            XCTAssertGreaterThan(encodedWorst, 1e-2, "\(message): the gain is not applied to the encoded colour", file: file, line: line)
        }
    }

    func testColorGainMultipliesTheRecordColour() throws {
        lookAtAsset()
        guard let component = gaussianComponent() else { return }
        XCTAssertEqual(component.captureExposureEV, 0, "A .ply carries no capture exposure")
        XCTAssertEqual(component.captureWhiteBalance, SIMD3<Float>(repeating: 1))
        XCTAssertEqual(component.colorGain, SIMD3<Float>(repeating: 1))

        let neutral = try compactedRecords()
        XCTAssertGreaterThan(neutral.count, 0)

        // +1 EV over a capture at 0 EV doubles; the capture white balance scales per channel. The
        // gain is a gain in linear light: a record's colour stays display-referred (the splats
        // blend in the capture's own space), so the preprocess decodes, scales and re-encodes it.
        component.exposureOffsetEV = 1
        component.captureWhiteBalance = SIMD3<Float>(1, 0.5, 0.25)
        XCTAssertEqual(component.colorGain, SIMD3<Float>(2, 1, 0.5))
        let gained = try compactedRecords()
        XCTAssertEqual(gained.count, neutral.count)

        assertChannel(gained, 0, matches: neutral, gain: 2, "red doubled in linear light")
        assertChannel(gained, 1, matches: neutral, gain: 1, "green unchanged")
        assertChannel(gained, 2, matches: neutral, gain: 0.5, "blue halved in linear light")

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
        // Red keeps a gain of 1 but still passes through the decode and re-encode with the other
        // channels, so it is compared with the same tolerance rather than exactly.
        assertChannel(tinted, 0, matches: neutral, gain: 1, "red unchanged")
        assertChannel(tinted, 1, matches: neutral, gain: 0.5, "green halved by the estimate, in linear light")
        assertChannel(tinted, 2, matches: neutral, gain: 0.25, "blue quartered by the estimate, in linear light")

        store.setMode(.staticIBL)
        XCTAssertNil(gaussianRealWorldTint(), "Static IBL: no estimate to apply")
        let staticIBL = try compactedRecords()
        XCTAssertEqual(sortedChannel(neutral, 2, scale: 1), sortedChannel(staticIBL, 2, scale: 1), "blue unchanged outside the estimate mode")

        component.useRealWorldTint = false
    }
}
