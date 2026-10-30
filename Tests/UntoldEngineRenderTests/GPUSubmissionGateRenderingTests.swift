//
//  GPUSubmissionGateRenderingTests.swift
//  UntoldEngineRenderTests
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

/// With the GPU gate closed the renderer draws nothing, and the first frame after it opens
/// again lets no time pass, as a first frame: no simulation step spans the pause.
@MainActor
final class GPUSubmissionGateRenderingTests: BaseRenderSetup {
    override func tearDown() async throws {
        GPUSubmissionGate.shared.open(reason: "test teardown")
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
    }

    func testAClosedGateDrawsNoFrameAndTheFrameAfterLetsNoTimePass() {
        renderer.draw(in: renderer.metalView)
        renderer.draw(in: renderer.metalView)
        guard let lastBuffer = renderInfo.lastCommandBuffer else {
            XCTFail("the frames drawn left no command buffer")
            return
        }
        XCTAssertGreaterThan(timeSinceLastUpdate ?? 0, 0)

        GPUSubmissionGate.shared.close(reason: "test")
        renderer.draw(in: renderer.metalView)
        XCTAssertTrue(renderInfo.lastCommandBuffer === lastBuffer, "a frame was drawn with the gate closed")

        Thread.sleep(forTimeInterval: 0.05)
        GPUSubmissionGate.shared.open(reason: "test")
        renderer.draw(in: renderer.metalView)
        XCTAssertFalse(renderInfo.lastCommandBuffer === lastBuffer, "no frame was drawn once the gate opened")
        XCTAssertEqual(timeSinceLastUpdate, 0, "the first frame after the pause let the pause's time pass")

        renderer.draw(in: renderer.metalView)
        XCTAssertGreaterThan(timeSinceLastUpdate ?? 0, 0, "the frame after the first stands still")
    }
}
