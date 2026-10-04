//
//  SmallObjectCullingRenderTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldEngine
import XCTest

final class SmallObjectCullingRenderTests: BaseRenderSetup {
    private var savedPixels: Float = 1

    override func setUp() async throws {
        try await super.setUp()
        savedPixels = SmallObjectCulling.minimumPixels
    }

    override func tearDown() async throws {
        SmallObjectCulling.minimumPixels = savedPixels
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {
        let camera = createEntity()
        createGameCamera(entityId: camera)
        CameraSystem.shared.activeCamera = camera
        cameraLookAt(entityId: camera, eye: .zero, target: simd_float3(0, 0, -1), up: simd_float3(0, 1, 0))
    }

    private func makeCube(size: Float, at position: simd_float3) -> EntityID {
        let entity = createEntity()
        setEntityMeshDirect(entityId: entity, meshes: BasicPrimitives.createCube(extent: 1.0), assetName: "Cube")
        scaleTo(entityId: entity, scale: simd_float3(repeating: size))
        translateTo(entityId: entity, position: position)
        return entity
    }

    /// Draws enough frames for a culling result to come back and be picked up.
    private func drawFrames() {
        for _ in 0 ..< 6 {
            renderer.draw(in: renderer.metalView)
            renderInfo.lastCommandBuffer?.waitUntilCompleted()
        }
    }

    func testAnObjectUnderAPixelIsNotInTheVisibleSet() {
        // The view is 1,080 pixels high with a 65° field of view: at 400 units a pixel
        // is about 0.47 units. The near cube is off to the side, so that it hides neither
        // of the far ones.
        let near = makeCube(size: 1, at: simd_float3(-3, 0, -5))
        let farLarge = makeCube(size: 20, at: simd_float3(30, 0, -400))
        let farSmall = makeCube(size: 0.1, at: simd_float3(-10, 0, -400))

        setRendering(.smallObjectCulling(pixels: 1))
        drawFrames()

        XCTAssertTrue(visibleEntityIds.contains(near))
        XCTAssertTrue(visibleEntityIds.contains(farLarge))
        XCTAssertFalse(visibleEntityIds.contains(farSmall), "0.37 pixels tall")

        setRendering(.smallObjectCulling(pixels: 0))
        drawFrames()

        XCTAssertTrue(visibleEntityIds.contains(farSmall), "everything in the frustum is drawn when the limit is zero")
    }

    func testTheLimitDecidesWhatCountsAsSmall() {
        // 4 units wide at 400: the sphere around it is about 14.7 pixels tall.
        let cube = makeCube(size: 4, at: simd_float3(0, 0, -400))

        setRendering(.smallObjectCulling(pixels: 8))
        drawFrames()
        XCTAssertTrue(visibleEntityIds.contains(cube))

        setRendering(.smallObjectCulling(pixels: 20))
        drawFrames()
        XCTAssertFalse(visibleEntityIds.contains(cube))
        XCTAssertTrue(visibleEntityIds.isEmpty, "with nothing left to test, the frame stops drawing the set of the frame before")
    }

    func testAnObjectTooSmallToDrawCastsNoShadow() {
        let sun = createEntity()
        createDirLight(entityId: sun)
        let ground = makeCube(size: 1, at: simd_float3(0, -2, -20))
        scaleTo(entityId: ground, scale: simd_float3(60, 0.2, 60))
        // 5 mm across, 20 units away: a third of a pixel.
        let speck = makeCube(size: 0.005, at: simd_float3(0, 1, -20))
        RenderPasses.invalidateShadowEntityCache()

        setRendering(.smallObjectCulling(pixels: 0))
        drawFrames()
        let castersWithEverything = RenderPasses.lastShadowCasterCount

        setRendering(.smallObjectCulling(pixels: 1))
        drawFrames()
        let castersWithoutTheSpeck = RenderPasses.lastShadowCasterCount

        XCTAssertGreaterThan(castersWithEverything, 0, "the ground casts into the cascade")
        XCTAssertEqual(castersWithoutTheSpeck, castersWithEverything - 1)
        XCTAssertTrue(scene.exists(speck))
    }
}
