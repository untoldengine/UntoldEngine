//
//  GaussianVisibleSetTest.swift
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

/// The per-frame Gaussian passes (preprocess, depth keys, radix sort, draw) must be sized by
/// the count the cull wrote on the GPU *this* frame, never by the CPU's readback of an older
/// frame. That readback lags by the frames in flight, so while the camera moves and the
/// visible set grows, sizing from it cut the tail of the visible list every frame — a hole
/// that followed the camera and closed only once it stood still (contiguous in a `.untoldgs`
/// v3 file, whose Morton order makes the tail a compact region; scattered in a `.ply`).
final class GaussianVisibleSetTest: BaseRenderSetup {
    override func tearDown() async throws {
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {
        let gaussian = createEntity()
        setEntityGaussian(entityId: gaussian, filename: "test_gaussians", withExtension: "ply")
    }

    // MARK: - Helpers

    private func lookAtAsset() {
        let cameraEntity = createEntity()
        if let cameraComponent = scene.assign(to: cameraEntity, component: CameraComponent.self) {
            CameraSystem.shared.activeCamera = cameraEntity
            cameraComponent.viewSpace = matrix_identity_float4x4
            cameraComponent.localPosition = .zero
        }
        cameraLookAt(entityId: cameraEntity, eye: simd_float3(0, 3, 7), target: .zero, up: simd_float3(0, 1, 0))
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

    private func frameSlot(for component: GaussianComponent) -> Int {
        min(renderInfo.currentInFlightFrameSlot, component.gaussianVisibleCount.count - 1)
    }

    private func runSynchronously(_ encode: (MTLCommandBuffer) -> Void) {
        guard let commandBuffer = renderInfo.commandQueue.makeCommandBuffer() else {
            XCTFail("Expected to allocate a command buffer")
            return
        }
        encode(commandBuffer)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        XCTAssertEqual(commandBuffer.status, .completed)
    }

    // MARK: - Tests

    /// The record a freshly loaded entity starts with counts every splat as visible, so a draw
    /// before the first cull is not empty, and its indirect arguments agree with that count.
    func testLoadedEntityStartsWithEverySplatVisible() {
        guard let component = gaussianComponent(),
              let buffer = component.gaussianVisibleCount[frameSlot(for: component)]
        else {
            XCTFail("Expected a visible-set buffer")
            return
        }
        XCTAssertEqual(buffer.length, MemoryLayout<GaussianVisibleSet>.stride)
        let visibleSet = buffer.contents().load(as: GaussianVisibleSet.self)
        XCTAssertEqual(visibleSet.visibleCount, UInt32(component.splatCount))
        XCTAssertEqual(visibleSet.instanceCount, UInt32(component.splatCount))
        XCTAssertEqual(visibleSet.vertexCount, 4)
    }

    /// After a cull, the indirect dispatch and draw arguments are derived on the GPU from the
    /// count the cull appended, in the same command buffer.
    func testCullFinalizesIndirectArgumentsFromGPUCount() {
        lookAtAsset()
        guard let component = gaussianComponent() else { return }

        runSynchronously { executeGaussianFrustumCulling($0) }

        guard let buffer = component.gaussianVisibleCount[frameSlot(for: component)] else {
            XCTFail("Expected a visible-set buffer")
            return
        }
        let visibleSet = buffer.contents().load(as: GaussianVisibleSet.self)
        let block = UInt32(gaussianVisibleBlockSize)
        let expectedThreadgroups = (visibleSet.visibleCount + block - 1) / block

        XCTAssertGreaterThan(visibleSet.visibleCount, 0, "Sanity check: the camera looks at the asset")
        XCTAssertLessThan(visibleSet.visibleCount, UInt32(component.splatCount) + 1)
        XCTAssertEqual(visibleSet.threadgroupCount, expectedThreadgroups)
        XCTAssertEqual(visibleSet.threadgroupsPerGrid.0, expectedThreadgroups)
        XCTAssertEqual(visibleSet.threadgroupsPerGrid.1, 1)
        XCTAssertEqual(visibleSet.threadgroupsPerGrid.2, 1)
        XCTAssertEqual(visibleSet.vertexCount, 4)
        XCTAssertEqual(visibleSet.instanceCount, visibleSet.visibleCount)
        XCTAssertEqual(visibleSet.vertexStart, 0)
        XCTAssertEqual(visibleSet.baseInstance, 0)
    }

    /// The regression itself. The CPU-side count is left at 1, as if the last completed frame
    /// had seen almost nothing, then a full frame of passes runs with the whole asset in view.
    /// Every visible splat must still be preprocessed, keyed and sorted: the passes take their
    /// size from this frame's GPU count, so the stale CPU value cannot cut the list.
    func testStaleCPUCountDoesNotTruncateTheVisibleSet() {
        lookAtAsset()
        guard let component = gaussianComponent() else { return }
        let slot = frameSlot(for: component)
        guard let visibleSetBuffer = component.gaussianVisibleCount[slot],
              let visibleIndicesBuffer = component.gaussianVisibleIndices[slot],
              let sortedBuffer = component.gaussianSortedIndices[slot],
              let precomputedBuffer = component.gaussianPrecomputedData[slot]
        else {
            XCTFail("Expected the per-frame Gaussian buffers")
            return
        }
        let splatCount = Int(component.splatCount)

        // Stale readback from a frame in which one splat was visible.
        component.visibleSplatCountForRendering = 1

        // Sentinels so anything a pass skipped is visible afterwards.
        let sentinelKey: UInt64 = 0xDEAD_BEEF_DEAD_BEEF
        let sortedKeys = sortedBuffer.contents().bindMemory(to: UInt64.self, capacity: splatCount)
        for index in 0 ..< splatCount {
            sortedKeys[index] = sentinelKey
        }
        let sentinelConic = simd_float3(repeating: -12345)
        let precomputed = precomputedBuffer.contents().bindMemory(to: GaussianPrecomputedSplat.self, capacity: splatCount)
        for index in 0 ..< splatCount {
            precomputed[index].conic = sentinelConic
        }

        // The frame's pass order, see RenderingSystem.swift.
        runSynchronously { commandBuffer in
            executeGaussianFrustumCulling(commandBuffer)
            executeGaussianPreprocess(commandBuffer)
            executeGaussianDepth(commandBuffer)
            executeRadixSort(commandBuffer)
        }

        let visibleCount = Int(visibleSetBuffer.contents().load(as: UInt32.self))
        XCTAssertGreaterThan(visibleCount, 1, "Sanity check: the whole asset is in view, far more than the stale count")

        let visibleIndices = Array(UnsafeBufferPointer(start: visibleIndicesBuffer.contents().bindMemory(to: UInt32.self, capacity: visibleCount), count: visibleCount))
        XCTAssertEqual(Set(visibleIndices).count, visibleCount, "Each visible splat appears once in the cull output")

        // Preprocess reached every visible splat.
        let skippedByPreprocess = visibleIndices.filter { precomputed[Int($0)].conic == sentinelConic }.count
        XCTAssertEqual(skippedByPreprocess, 0, "\(skippedByPreprocess) of \(visibleCount) visible splats were never preprocessed")

        // Depth keys and the sort covered the whole visible list: the first `visibleCount`
        // sorted entries are exactly the visible splats, in ascending depth order.
        var sortedSplatIndices: [UInt32] = []
        var previousDepthKey: UInt32 = 0
        var outOfOrder = 0
        for position in 0 ..< visibleCount {
            let packed = sortedKeys[position]
            XCTAssertNotEqual(packed, sentinelKey, "Sorted entry \(position) was never written")
            let depthKey = UInt32(truncatingIfNeeded: packed >> 32)
            let splatIndex = UInt32(truncatingIfNeeded: packed)
            if depthKey < previousDepthKey {
                outOfOrder += 1
            }
            previousDepthKey = depthKey
            sortedSplatIndices.append(splatIndex)
        }
        XCTAssertEqual(outOfOrder, 0, "Depth keys are not ascending")
        XCTAssertEqual(Set(sortedSplatIndices), Set(visibleIndices), "The sorted list is not a permutation of the visible list")
    }
}
