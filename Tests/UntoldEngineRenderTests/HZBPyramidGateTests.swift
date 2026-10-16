//
//  HZBPyramidGateTests.swift
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

/// The depth pyramid, and the depth copy that feeds it, are built only for a frame whose depth
/// could hide something next frame: the occlusion test on, and enough mesh entities (or any
/// splats) in the scene. The GPU's own pass timing says which passes ran.
@MainActor
final class HZBPyramidGateTests: BaseRenderSetup {
    private var savedMinimum = 2
    private var savedStep: Float = 0.5

    override func setUp() async throws {
        try await super.setUp()
        savedMinimum = getOcclusionCullingMinimumEntities()
        savedStep = getOcclusionCullingMaxCameraStep()
        setRendering(.gpuPassTiming(.enabled))
    }

    override func tearDown() async throws {
        setRendering(.gpuPassTiming(.disabled))
        setRendering(.occlusionCullingMinimumEntities(savedMinimum))
        setRendering(.occlusionCullingMaxCameraStep(savedStep))
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {
        let camera = createEntity()
        createGameCamera(entityId: camera)
        CameraSystem.shared.activeCamera = camera
        cameraLookAt(entityId: camera, eye: simd_float3(0, 1, 4), target: .zero, up: simd_float3(0, 1, 0))
        addBox(at: simd_float3(0, 0.5, 0))
        let sun = createEntity()
        createDirLight(entityId: sun)
        rotateTo(entityId: sun, pitch: -40, yaw: 30, roll: 0)
    }

    private func addBox(at position: simd_float3) {
        let box = createEntity()
        setEntityMeshDirect(entityId: box, meshes: BasicPrimitives.createCube(extent: 0.6), assetName: "Box")
        translateTo(entityId: box, position: position)
    }

    /// The labels of the passes the last frame ran, after a few frames.
    private func passesRun() -> Set<String> {
        for _ in 0 ..< 4 {
            renderer.draw(in: renderer.metalView)
            renderInfo.lastCommandBuffer?.waitUntilCompleted()
        }
        return Set(GPUPassTiming.shared.lastFrame().passes.map(\.label))
    }

    func testOneEntityGetsNoPyramid() throws {
        try XCTSkipUnless(renderInfo.device.supportsCounterSampling(.atStageBoundary), "no pass timing here")
        setRendering(.occlusionCullingMinimumEntities(2))
        setRendering(.occlusionCullingMaxCameraStep(0.5))
        let passes = passesRun()
        XCTAssertEqual(renderInfo.hzbCandidateCount, 1)
        XCTAssertFalse(passes.contains("HZB"), "no pyramid for one entity: \(passes.sorted())")
        XCTAssertFalse(passes.contains("DepthCopy"), "no depth copy without a pyramid")
        XCTAssertFalse(renderInfo.hzbIsValid)
    }

    func testTwoEntitiesGetThePyramidUnlessTheTestIsOff() throws {
        try XCTSkipUnless(renderInfo.device.supportsCounterSampling(.atStageBoundary), "no pass timing here")
        addBox(at: simd_float3(1.2, 0.5, -1))
        setVisibleEntities()
        setRendering(.occlusionCullingMinimumEntities(2))
        setRendering(.occlusionCullingMaxCameraStep(0.5))
        var passes = passesRun()
        XCTAssertEqual(renderInfo.hzbCandidateCount, 2)
        XCTAssertTrue(passes.contains("HZB"), "two entities: the pyramid is built: \(passes.sorted())")
        XCTAssertTrue(passes.contains("DepthCopy"))
        XCTAssertTrue(renderInfo.hzbIsValid)

        setRendering(.occlusionCullingMinimumEntities(5))
        passes = passesRun()
        XCTAssertFalse(passes.contains("HZB"), "below the minimum: no pyramid")
        XCTAssertFalse(renderInfo.hzbIsValid)

        setRendering(.occlusionCullingMinimumEntities(2))
        setRendering(.occlusionCullingMaxCameraStep(0))
        passes = passesRun()
        XCTAssertFalse(passes.contains("HZB"), "the test off: no pyramid")
        XCTAssertFalse(passes.contains("DepthCopy"))
    }
}
