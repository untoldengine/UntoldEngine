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

/// The per-frame Gaussian passes (preprocess, radix sort, draw) must be sized by counts written
/// on the GPU *this* frame — the entity's cull count and the shared working set's append count —
/// never by the CPU's readback of an older frame. That readback lags by the frames in flight, so
/// while the camera moves and the visible set grows, sizing from it cut the tail of the visible
/// list every frame: a hole that followed the camera and closed once it stood still.
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

    // MARK: - Tests

    /// The record a freshly loaded entity starts with counts every splat as visible, and its
    /// indirect arguments agree with that count.
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

    /// After a cull, the entity's indirect dispatch arguments are derived on the GPU from the
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
    /// Every visible splat must be compacted into the shared working set, keyed and sorted:
    /// the passes take their sizes from this frame's GPU counts, so the stale value cannot cut
    /// the list.
    func testStaleCPUCountDoesNotTruncateTheVisibleSet() {
        lookAtAsset()
        guard let component = gaussianComponent() else { return }
        let slot = frameSlot(for: component)
        guard let visibleSetBuffer = component.gaussianVisibleCount[slot],
              let visibleIndicesBuffer = component.gaussianVisibleIndices[slot]
        else {
            XCTFail("Expected the per-frame Gaussian buffers")
            return
        }

        // Stale readback from a frame in which one splat was visible.
        component.visibleSplatCountForRendering = 1

        // The frame's pass order, see RenderingSystem.swift.
        runSynchronously { commandBuffer in
            executeGaussianFrustumCulling(commandBuffer)
            executeGaussianPreprocess(commandBuffer)
            executeRadixSort(commandBuffer)
        }

        let visibleCount = Int(visibleSetBuffer.contents().load(as: UInt32.self))
        XCTAssertGreaterThan(visibleCount, 1, "Sanity check: the whole asset is in view, far more than the stale count")
        let visibleIndices = Array(UnsafeBufferPointer(start: visibleIndicesBuffer.contents().bindMemory(to: UInt32.self, capacity: visibleCount), count: visibleCount))
        XCTAssertEqual(Set(visibleIndices).count, visibleCount, "Each visible splat appears once in the cull output")

        let workingSet = GaussianSharedWorkingSet.shared
        let sharedSlot = min(renderInfo.currentInFlightFrameSlot, maxInFlightCommandBuffers - 1)
        guard let sharedSetBuffer = workingSet.visibleSet(slot: sharedSlot),
              let keysBuffer = workingSet.keys(slot: sharedSlot),
              let recordsBuffer = workingSet.records(slot: sharedSlot)
        else {
            XCTFail("Expected the shared working set")
            return
        }
        let sharedSet = sharedSetBuffer.contents().load(as: GaussianVisibleSet.self)
        XCTAssertEqual(Int(sharedSet.visibleCount), visibleCount, "Every culled-in splat was compacted into the shared set")
        XCTAssertEqual(sharedSet.overflowCount, 0)
        XCTAssertEqual(sharedSet.instanceCount, sharedSet.visibleCount)

        // The sorted keys cover the whole shared list: ascending depth, each slot once, and every
        // record carries the entity's index and a valid footprint.
        let keys = keysBuffer.contents().bindMemory(to: UInt64.self, capacity: visibleCount)
        let records = recordsBuffer.contents().bindMemory(to: GaussianWorkingSetSplat.self, capacity: visibleCount)
        var slots = Set<UInt32>()
        var previousDepth: UInt32 = 0
        var outOfOrder = 0
        var badRecords = 0
        for position in 0 ..< visibleCount {
            let packed = keys[position]
            let depth = UInt32(truncatingIfNeeded: packed >> 32)
            let recordSlot = UInt32(truncatingIfNeeded: packed)
            if depth < previousDepth {
                outOfOrder += 1
            }
            previousDepth = depth
            slots.insert(recordSlot)
            let record = records[Int(recordSlot)]
            if record.entityIndex != 0 || (record.axis1 == .zero && record.axis2 == .zero) {
                badRecords += 1
            }
        }
        XCTAssertEqual(outOfOrder, 0, "Depth keys are not ascending")
        XCTAssertEqual(slots, Set(0 ..< UInt32(visibleCount)), "The sorted list is not a permutation of the shared slots")
        XCTAssertEqual(badRecords, 0, "Records carry the entity index and a footprint")
    }
}
