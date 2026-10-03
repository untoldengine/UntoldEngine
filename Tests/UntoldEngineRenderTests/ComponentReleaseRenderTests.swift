//
//  ComponentReleaseRenderTests.swift
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

private final class FrameProbeComponent: Component {
    required init() {}
}

/// An object watched without keeping it alive.
private struct Watched<Object: AnyObject> {
    weak var object: Object?

    init(_ object: Object?) {
        self.object = object
    }

    var isAlive: Bool {
        object != nil
    }
}

/// The frame is where components that left the scene are released (see
/// ComponentReleaseTests for the rules).
final class ComponentReleaseRenderTests: BaseRenderSetup {
    /// These tests bring their own entities: no scene is loaded.
    override func initializeAssets() {
        let camera = findGameCamera()
        CameraSystem.shared.activeCamera = camera
        cameraLookAt(entityId: camera, eye: simd_float3(0, 1, 4), target: .zero, up: simd_float3(0, 1, 0))
    }

    override func tearDown() async throws {
        destroyAllEntities()
        try await super.tearDown()
    }

    func testAFrameReleasesAComponentRemovedSinceTheLastOne() {
        let entity = createEntity()
        let probe = Watched(scene.assign(to: entity, component: FrameProbeComponent.self))
        renderer.draw(in: renderer.metalView)
        XCTAssertTrue(probe.isAlive)

        scene.remove(component: FrameProbeComponent.self, from: entity)
        XCTAssertTrue(probe.isAlive)
        renderer.draw(in: renderer.metalView)

        XCTAssertFalse(probe.isAlive)
    }

    func testTheFramesAfterAnEntityIsDestroyedReleaseItsComponents() async throws {
        let entity = createEntity()
        setEntityMeshDirect(entityId: entity, meshes: BasicPrimitives.createCube(extent: 1.0), assetName: "release_cube")
        let render = Watched(scene.get(component: RenderComponent.self, for: entity))
        let world = Watched(scene.get(component: WorldTransformComponent.self, for: entity))
        setVisibleEntities()
        for _ in 0 ..< 3 {
            renderer.draw(in: renderer.metalView)
        }
        XCTAssertTrue(render.isAlive && world.isAlive)

        destroyEntity(entityId: entity)

        // The destroy is finalized by the frame that follows one the GPU has finished.
        for _ in 0 ..< 200 where render.isAlive || world.isAlive {
            renderer.draw(in: renderer.metalView)
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertFalse(scene.exists(entity))
        XCTAssertFalse(render.isAlive)
        XCTAssertFalse(world.isAlive)

        // And the frames after it draw without it.
        for _ in 0 ..< 3 {
            renderer.draw(in: renderer.metalView)
        }
    }
}
