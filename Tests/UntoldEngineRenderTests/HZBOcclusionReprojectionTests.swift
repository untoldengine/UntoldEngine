//
//  HZBOcclusionReprojectionTests.swift
//  UntoldEngine
//
//  The occlusion test runs against the depth pyramid of the frame before, and sees the
//  scene from that frame's camera: what the camera's movement does to the test.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldEngine
import XCTest

final class HZBOcclusionReprojectionTests: BaseRenderSetup {
    private var camera: EntityID = 0
    private var savedStep: Float = 0.5
    private var savedPixels: Float = 1

    override func setUp() async throws {
        try await super.setUp()
        savedStep = HZBOcclusionCulling.maxCameraStep
        HZBOcclusionCulling.maxCameraStep = 0.5
        savedPixels = SmallObjectCulling.minimumPixels
        SmallObjectCulling.minimumPixels = 0
    }

    override func tearDown() async throws {
        HZBOcclusionCulling.maxCameraStep = savedStep
        SmallObjectCulling.minimumPixels = savedPixels
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {
        camera = createEntity()
        createGameCamera(entityId: camera)
        CameraSystem.shared.activeCamera = camera
        look(from: simd_float3(0, 1, 0))
    }

    // MARK: - Helpers

    /// Looks along -z from `eye`.
    private func look(from eye: simd_float3) {
        cameraLookAt(entityId: camera, eye: eye, target: eye + simd_float3(0, 0, -1), up: simd_float3(0, 1, 0))
    }

    private func makeBox(size: simd_float3, at position: simd_float3) -> EntityID {
        let entity = createEntity()
        setEntityMeshDirect(entityId: entity, meshes: BasicPrimitives.createCube(extent: 1.0), assetName: "Box")
        scaleTo(entityId: entity, scale: size)
        translateTo(entityId: entity, position: position)
        return entity
    }

    /// One frame. Its cull runs against the pyramid of the frame before and its depth becomes
    /// the next pyramid. The cull's counts are in `HZBDebugMonitor` once the frame's command
    /// buffer has completed; the visible list itself reaches `visibleEntityIds` a frame or two
    /// later, through the triple buffer, so the tests read the monitor.
    private func drawFrame() {
        renderer.draw(in: renderer.metalView)
        renderInfo.lastCommandBuffer?.waitUntilCompleted()
    }

    /// Enough frames for the scene to be drawn and its depth to be the pyramid the last
    /// frame's cull ran against: the first cull's list is drawn two frames later at most.
    private func settle() {
        for _ in 0 ..< 4 {
            drawFrame()
        }
    }

    /// Whether the cull of the last frame ran the occlusion test.
    private var lastCullUsedOcclusion: Bool {
        HZBDebugMonitor.shared.stats.usedHZBThisFrame
    }

    /// How many of the last cull's candidates the occlusion test dropped. In these scenes the
    /// wall stands in front of everything, so only the small box can ever be dropped.
    private var lastCullOccluded: Int {
        HZBDebugMonitor.shared.stats.occludedCount
    }

    /// A wall 3 units ahead of the camera, 1.5 tall and wider than the view: the occluder.
    private func makeWall() -> EntityID {
        makeBox(size: simd_float3(20, 1.5, 0.2), at: simd_float3(0, 0.75, -3))
    }

    // MARK: - The camera's movement

    func testAnObjectSeenFromBothPlacesStaysVisibleWhenTheCameraRises() {
        setRendering(.occlusionCullingMaxCameraStep(5))
        _ = makeWall()
        // A small box 80 units out, high enough to show over the wall's top from 1 unit up.
        _ = makeBox(size: simd_float3(0.5, 0.5, 0.5), at: simd_float3(0, 15.8, -80))
        settle()
        XCTAssertTrue(lastCullUsedOcclusion)
        XCTAssertEqual(lastCullOccluded, 0, "over the wall's top from 1 unit up")

        // Three units higher the box still shows over the wall, lower on screen: where the
        // pyramid of the frame before holds the wall, 3 units from the camera.
        look(from: simd_float3(0, 4, 0))
        drawFrame()
        XCTAssertTrue(lastCullUsedOcclusion)
        XCTAssertEqual(lastCullOccluded, 0, "tested where the old camera saw it: over the wall")
    }

    func testAnObjectBehindTheWallStaysHiddenAcrossASmallStep() {
        _ = makeWall()
        _ = makeBox(size: simd_float3(0.5, 0.5, 0.5), at: simd_float3(0, 0.5, -20))
        settle()
        XCTAssertTrue(lastCullUsedOcclusion)
        XCTAssertEqual(lastCullOccluded, 1, "behind the wall")

        look(from: simd_float3(0.2, 1, 0))
        drawFrame()
        XCTAssertTrue(lastCullUsedOcclusion, "a step of 0.2 is within the default")
        XCTAssertEqual(lastCullOccluded, 1, "still behind the wall")
    }

    func testTheTestIsSkippedForTheFrameAfterAJump() {
        _ = makeWall()
        _ = makeBox(size: simd_float3(0.5, 0.5, 0.5), at: simd_float3(0, 0.5, -20))
        settle()
        XCTAssertEqual(lastCullOccluded, 1)

        // Two units sideways: past the default step. That frame's cull keeps what the frustum keeps.
        look(from: simd_float3(2, 1, 0))
        drawFrame()
        XCTAssertFalse(lastCullUsedOcclusion, "the pyramid was built 2 units away")
        XCTAssertEqual(lastCullOccluded, 0)

        // The frame after has the pyramid of the new place and hides the box again.
        drawFrame()
        XCTAssertTrue(lastCullUsedOcclusion)
        XCTAssertEqual(lastCullOccluded, 1, "behind the wall from here too")
    }

    func testTheCameraOfTheViewMatrixIsWhereItLooksFrom() throws {
        look(from: simd_float3(3, 4, 5))
        let view = try XCTUnwrap(scene.get(component: CameraComponent.self, for: camera)).viewSpace
        let position = eyePosition(ofView: view)
        XCTAssertEqual(position.x, 3, accuracy: 1e-4)
        XCTAssertEqual(position.y, 4, accuracy: 1e-4)
        XCTAssertEqual(position.z, 5, accuracy: 1e-4)
    }

    func testThePyramidRecordsTheCameraItWasBuiltFrom() {
        look(from: simd_float3(1, 2, 3))
        drawFrame()
        let frame = renderInfo.hzbFrame
        XCTAssertNotNil(frame)
        XCTAssertEqual(frame?.cameraPosition.x ?? 0, 1, accuracy: 1e-4)
        XCTAssertEqual(frame?.cameraPosition.y ?? 0, 2, accuracy: 1e-4)
        XCTAssertEqual(frame?.cameraPosition.z ?? 0, 3, accuracy: 1e-4)
    }

    func testTheStepSettingRoundTrips() {
        setRendering(.occlusionCullingMaxCameraStep(2))
        XCTAssertEqual(getOcclusionCullingMaxCameraStep(), 2)
        setRendering(.occlusionCullingMaxCameraStep(-1))
        XCTAssertEqual(getOcclusionCullingMaxCameraStep(), 0, "no negative step")
        setRendering(.occlusionCullingMaxCameraStep(.nan))
        XCTAssertEqual(getOcclusionCullingMaxCameraStep(), 0)
    }
}
