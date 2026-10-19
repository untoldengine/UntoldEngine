//
//  CullingSlotTests.swift
//  UntoldEngine
//
//  The culling's rings: a frame's GPU work reads the list and the frustum the frame wrote,
//  not the frame before's.
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldEngine
import XCTest

final class CullingSlotTests: BaseRenderSetup {
    private var camera: EntityID = 0
    private var savedStep: Float = 0.5
    private var savedPixels: Float = 1

    override func setUp() async throws {
        try await super.setUp()
        savedStep = HZBOcclusionCulling.maxCameraStep
        savedPixels = SmallObjectCulling.minimumPixels
        // The frustum alone decides: no occlusion test, no small-object threshold.
        HZBOcclusionCulling.maxCameraStep = 0
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
        look(towards: simd_float3(0, 0, -1))
    }

    private func look(towards direction: simd_float3) {
        let eye = simd_float3(0, 1, 0)
        cameraLookAt(entityId: camera, eye: eye, target: eye + direction, up: simd_float3(0, 1, 0))
    }

    private func makeBox(at position: simd_float3) -> EntityID {
        let entity = createEntity()
        setEntityMeshDirect(entityId: entity, meshes: BasicPrimitives.createCube(extent: 1.0), assetName: "Box")
        translateTo(entityId: entity, position: position)
        return entity
    }

    /// One frame, through to its command buffer's completion: the frame's cull has published
    /// its list by then.
    private func drawFrame() {
        renderer.draw(in: renderer.metalView)
        renderInfo.lastCommandBuffer?.waitUntilCompleted()
    }

    /// The list the last frame's cull published.
    private var published: [EntityID] {
        tripleVisibleEntities.snapshotForRead(frame: cullFrameIndex)
    }

    func testTheEntitiesAfterOneThatLeftTheListAreStillTested() {
        // Two boxes in view, the first ahead of the second in the list.
        let first = makeBox(at: simd_float3(-1.5, 1, -5))
        let second = makeBox(at: simd_float3(1.5, 1, -5))
        for _ in 0 ..< 4 {
            drawFrame()
        }
        XCTAssertTrue(published.contains(first))
        XCTAssertTrue(published.contains(second))

        // The first leaves the list, and the second takes its place in it. The frame's cull
        // must test the list as it is: the frame before's list under this frame's count tested
        // the first again and never reached the second.
        scene.get(component: RenderComponent.self, for: first)?.isVisible = false
        drawFrame()
        XCTAssertFalse(published.contains(first), "hidden")
        XCTAssertTrue(published.contains(second), "tested in the frame its place in the list changed")
    }

    func testTheFrameTheCameraTurnsInSeesWhatItTurnedTo() {
        let box = makeBox(at: simd_float3(0, 1, -5))
        look(towards: simd_float3(0, 0, 1))
        for _ in 0 ..< 4 {
            drawFrame()
        }
        XCTAssertFalse(published.contains(box), "behind the camera")

        look(towards: simd_float3(0, 0, -1))
        drawFrame()
        XCTAssertTrue(published.contains(box), "in the frustum of the frame that turned, not the frame before's")
    }
}
