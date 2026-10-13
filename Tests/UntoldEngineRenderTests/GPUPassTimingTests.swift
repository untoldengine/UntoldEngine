//
//  GPUPassTimingTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Metal
import simd
@testable import UntoldEngine
import XCTest

/// The GPU times its own passes: with the timing on, a frame's passes come back with their
/// vertex and fragment milliseconds, which add up to no more than the frame; off, nothing.
@MainActor
final class GPUPassTimingTests: BaseRenderSetup {
    override func tearDown() async throws {
        setRendering(.gpuPassTiming(.disabled))
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {
        let camera = createEntity()
        createGameCamera(entityId: camera)
        CameraSystem.shared.activeCamera = camera
        cameraLookAt(entityId: camera, eye: simd_float3(0, 1, 4), target: .zero, up: simd_float3(0, 1, 0))
        let box = createEntity()
        setEntityMeshDirect(entityId: box, meshes: BasicPrimitives.createCube(extent: 1.0), assetName: "Box")
        translateTo(entityId: box, position: simd_float3(0, 0.5, 0))
        let sun = createEntity()
        createDirLight(entityId: sun)
        rotateTo(entityId: sun, pitch: -40, yaw: 30, roll: 0)
        applyIBL = true
    }

    private func drawFrames(_ count: Int) -> Double {
        var span = 0.0
        for _ in 0 ..< count {
            renderer.draw(in: renderer.metalView)
            guard let cb = renderInfo.lastCommandBuffer else { continue }
            cb.waitUntilCompleted()
            span = (cb.gpuEndTime - cb.gpuStartTime) * 1000
        }
        return span
    }

    func testPassesAreTimedWhenOnAndNotWhenOff() throws {
        try XCTSkipUnless(renderInfo.device.supportsCounterSampling(.atStageBoundary), "no stage-boundary sampling here")
        _ = drawFrames(3)
        XCTAssertTrue(GPUPassTiming.shared.averages().isEmpty, "off by default")

        setRendering(.gpuPassTiming(.enabled))
        let frameMs = drawFrames(30)
        let passes = GPUPassTiming.shared.averages()
        XCTAssertFalse(passes.isEmpty, "the frame's passes are timed")
        let gBuffer = try XCTUnwrap(passes.first { $0.label == "G-Buffer" }, "the combined pass is timed: \(passes.map(\.label))")
        XCTAssertGreaterThan(gBuffer.fragmentMs, 0, "the combined pass shades")
        XCTAssertGreaterThanOrEqual(gBuffer.vertexMs, 0)
        let total = passes.reduce(0) { $0 + $1.totalMs }
        XCTAssertGreaterThan(total, 0)
        XCTAssertLessThan(total, frameMs * 1.5 + 0.5, "the passes add up to no more than the frame (\(frameMs) ms): \(passes)")
        print("GPU pass timing (Mac): " + passes.map { String(format: "%@ v%.3f f%.3f", $0.label, $0.vertexMs, $0.fragmentMs) }.joined(separator: ", ") + String(format: " | frame %.3f", frameMs))

        setRendering(.gpuPassTiming(.disabled))
        _ = drawFrames(3)
        XCTAssertTrue(GPUPassTiming.shared.averages().isEmpty, "off again")
    }
}
