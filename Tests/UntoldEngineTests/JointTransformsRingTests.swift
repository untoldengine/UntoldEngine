//
//  JointTransformsRingTests.swift
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import MetalKit
import simd
@testable import UntoldEngine
import XCTest

// Tests for the joint transforms buffer ring. The CPU animation update runs
// before the renderer waits on the command-buffer semaphore, so a single
// shared buffer can be rewritten while up to maxInFlightCommandBuffers frames
// still read it on the GPU. The ring guarantees every write lands in a buffer
// no in-flight frame can be reading.

@MainActor
final class JointTransformsRingTests: XCTestCase {
    override func setUp() async throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            XCTFail("Failed to create Metal device")
            return
        }
        renderInfo.device = device
    }

    private func matrix(filledWith value: Float) -> simd_float4x4 {
        simd_float4x4(
            SIMD4<Float>(repeating: value),
            SIMD4<Float>(repeating: value),
            SIMD4<Float>(repeating: value),
            SIMD4<Float>(repeating: value)
        )
    }

    private func readMatrix(_ buffer: MTLBuffer, jointIndex: Int, jointCount: Int) -> simd_float4x4 {
        buffer.contents().bindMemory(to: simd_float4x4.self, capacity: jointCount)[jointIndex]
    }

    // MARK: - Ring construction

    func testRingHoldsOneMoreSlotThanInFlightFrames() throws {
        let ring = try XCTUnwrap(JointTransformsRing(jointCount: 4))
        XCTAssertEqual(ring.buffers.count, maxInFlightCommandBuffers + 1)

        let uniqueBuffers = Set(ring.buffers.map { ObjectIdentifier($0) })
        XCTAssertEqual(uniqueBuffers.count, ring.buffers.count, "Ring slots must be distinct buffers")
    }

    func testAllSlotsPrefilledWithIdentity() throws {
        let jointCount = 3
        let ring = try XCTUnwrap(JointTransformsRing(jointCount: jointCount))

        for (slot, buffer) in ring.buffers.enumerated() {
            for jointIndex in 0 ..< jointCount {
                let matrix = readMatrix(buffer, jointIndex: jointIndex, jointCount: jointCount)
                XCTAssertEqual(
                    matrix, matrix_identity_float4x4,
                    "Slot \(slot), joint \(jointIndex) must start as identity so the bind pose renders before any animation write"
                )
            }
        }
    }

    // MARK: - Write rotation

    func testWriteRotatesAwayFromPreviouslyBoundBuffer() throws {
        let ring = try XCTUnwrap(JointTransformsRing(jointCount: 1))

        let boundBefore = ring.currentBuffer
        ring.write { pointer in pointer[0] = self.matrix(filledWith: 7) }

        XCTAssertNotIdentical(
            ring.currentBuffer, boundBefore,
            "A write must land in a different buffer than the one previous frames bound"
        )
        XCTAssertEqual(readMatrix(ring.currentBuffer, jointIndex: 0, jointCount: 1), matrix(filledWith: 7))
        XCTAssertEqual(
            readMatrix(boundBefore, jointIndex: 0, jointCount: 1), matrix_identity_float4x4,
            "The previously bound buffer must be untouched by the write"
        )
    }

    func testConsecutiveWritesNeverReuseAnInFlightSlot() throws {
        let ring = try XCTUnwrap(JointTransformsRing(jointCount: 1))
        let slotCount = ring.buffers.count

        // Track which buffer each simulated frame bound. A write during
        // frame N must not touch buffers bound by frames N-1 ... N-maxInFlight.
        var boundHistory: [ObjectIdentifier] = []
        for frame in 0 ..< (slotCount * 3) {
            ring.write { pointer in pointer[0] = self.matrix(filledWith: Float(frame)) }
            let bound = ObjectIdentifier(ring.currentBuffer)

            let stillInFlight = boundHistory.suffix(maxInFlightCommandBuffers)
            XCTAssertFalse(
                stillInFlight.contains(bound),
                "Frame \(frame) wrote a buffer that could still be read by an in-flight frame"
            )
            boundHistory.append(bound)
        }
    }

    func testCurrentBufferAlwaysHoldsLatestWrite() throws {
        let ring = try XCTUnwrap(JointTransformsRing(jointCount: 2))

        for frame in 0 ..< 10 {
            let value = Float(frame + 1)
            ring.write { pointer in
                pointer[0] = self.matrix(filledWith: value)
                pointer[1] = self.matrix(filledWith: value * 100)
            }
            XCTAssertEqual(readMatrix(ring.currentBuffer, jointIndex: 0, jointCount: 2), matrix(filledWith: value))
            XCTAssertEqual(readMatrix(ring.currentBuffer, jointIndex: 1, jointCount: 2), matrix(filledWith: value * 100))
        }
    }

    // MARK: - Skin integration

    func testSkinUpdateJointMatricesWritesMappedPose() throws {
        let restRoot = simd_float4x4.identity
        let restChild = simd_float4x4(translation: simd_float3(0, 1, 0))
        let runtimeSkeleton = RuntimeSkeleton(
            jointPaths: ["root", "root/child"],
            parentIndices: [nil, 0],
            bindTransforms: [restRoot, restChild],
            restTransforms: [restRoot, restChild]
        )
        let skeleton = try XCTUnwrap(Skeleton(runtimeSkeleton: runtimeSkeleton))

        // Skin maps its two slots to the skeleton joints in reverse order to
        // verify skinToSkeletonMap is honored.
        let runtimeSkin = RuntimeSkinBinding(skinToSkeletonMap: [1, 0], jointIndexData: Data(), jointWeightData: Data())
        let skin = try XCTUnwrap(Skin(runtimeSkin: runtimeSkin))

        skeleton.currentPose = [matrix(filledWith: 1), matrix(filledWith: 2)]
        skin.updateJointMatrices(skeleton: skeleton)

        let buffer = try XCTUnwrap(skin.jointTransformsBuffer)
        XCTAssertEqual(readMatrix(buffer, jointIndex: 0, jointCount: 2), matrix(filledWith: 2))
        XCTAssertEqual(readMatrix(buffer, jointIndex: 1, jointCount: 2), matrix(filledWith: 1))
    }

    func testSkinCopiesShareTheRingCursor() throws {
        let runtimeSkin = RuntimeSkinBinding(skinToSkeletonMap: [0], jointIndexData: Data(), jointWeightData: Data())
        let skin = try XCTUnwrap(Skin(runtimeSkin: runtimeSkin))
        let skinCopy = skin

        let runtimeSkeleton = RuntimeSkeleton(
            jointPaths: ["root"],
            parentIndices: [nil],
            bindTransforms: [.identity],
            restTransforms: [.identity]
        )
        let skeleton = try XCTUnwrap(Skeleton(runtimeSkeleton: runtimeSkeleton))
        skeleton.currentPose = [matrix(filledWith: 5)]

        skin.updateJointMatrices(skeleton: skeleton)

        // The copy stored in entity mesh maps must bind the same freshly
        // written buffer as the original.
        XCTAssertIdentical(
            try XCTUnwrap(skinCopy.jointTransformsBuffer),
            try XCTUnwrap(skin.jointTransformsBuffer),
            "Skin copies must share the ring cursor so all bind sites see the latest write"
        )
        XCTAssertEqual(readMatrix(skinCopy.jointTransformsBuffer, jointIndex: 0, jointCount: 1), matrix(filledWith: 5))
    }

    func testGPUMemoryAccountsForAllRingSlots() throws {
        let runtimeSkin = RuntimeSkinBinding(skinToSkeletonMap: [0, 1, 2], jointIndexData: Data(), jointWeightData: Data())
        let skin = try XCTUnwrap(Skin(runtimeSkin: runtimeSkin))

        let perBuffer = 3 * MemoryLayout<simd_float4x4>.stride
        XCTAssertEqual(skin.gpuMemorySize, perBuffer * (maxInFlightCommandBuffers + 1))
    }
}
