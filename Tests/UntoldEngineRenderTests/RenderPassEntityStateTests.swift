//
//  RenderPassEntityStateTests.swift
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

/// What the opaque pass decides per entity before it draws: whether the entity is still
/// there, what its scene channels ask for, and the fade its draws carry. The passes read
/// those through `RenderSceneSnapshot`; these tests pin what ends up on screen.
@MainActor
final class RenderPassEntityStateTests: BaseRenderSetup {
    override func tearDown() async throws {
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {}

    // MARK: - Scene helpers

    private let eye = simd_float3(0, 3, 7)
    private let target = simd_float3(0, 0, 0)

    private func createTestCamera() {
        let cameraEntity = createEntity()
        if let cameraComponent = scene.assign(to: cameraEntity, component: CameraComponent.self) {
            CameraSystem.shared.activeCamera = cameraEntity
            cameraComponent.viewSpace = matrix_identity_float4x4
            cameraComponent.localPosition = .zero
        }
        cameraLookAt(entityId: cameraEntity, eye: eye, target: target, up: simd_float3(0, 1, 0))
    }

    /// A cube whose near face covers the whole frame. The material is emissive so the lit
    /// colour does not depend on the lights or on the test IBL bake.
    private func makeFrameFillingCube() -> EntityID {
        let position = eye + 0.657 * (target - eye)
        let entity = createEntity()
        var meshes = BasicPrimitives.createCube(extent: 8.0)
        let emissiveMaterial = Material(
            runtimeMaterial: RuntimeMaterialSource(
                baseColorFactor: simd_float4(0, 0, 0, 1),
                emissiveFactor: simd_float3(0.8, 0.6, 0.4),
                metallicFactor: 0.0,
                roughnessFactor: 1.0
            ),
            device: renderInfo.device
        )
        for meshIndex in meshes.indices {
            for submeshIndex in meshes[meshIndex].submeshes.indices {
                meshes[meshIndex].submeshes[submeshIndex].material = emissiveMaterial
            }
        }
        if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
            renderComponent.mesh = meshes
        }
        if let local = scene.get(component: LocalTransformComponent.self, for: entity) {
            local.position = position
            local.boundingBox = Mesh.computeMeshBoundingBox(for: meshes)
        }
        if let world = scene.get(component: WorldTransformComponent.self, for: entity) {
            var space = matrix_identity_float4x4
            space.columns.3 = simd_float4(position, 1.0)
            world.space = space
        }
        return entity
    }

    // MARK: - Readback

    private var backgroundLit: [Float16] = []

    private func litPixels() throws -> [Float16] {
        let texture = try XCTUnwrap(textureResources.deferredColorMap)
        precondition(texture.pixelFormat == .rgba16Float, "Test assumes an rgba16Float lit target")
        var data = [Float16](repeating: 0, count: texture.width * texture.height * 4)
        data.withUnsafeMutableBytes { bytes in
            texture.getBytes(
                bytes.baseAddress!,
                bytesPerRow: texture.width * 8,
                from: MTLRegionMake2D(0, 0, texture.width, texture.height),
                mipmapLevel: 0
            )
        }
        return data
    }

    /// Draws a frame with `visible` as the visible list (every mesh entity when nil) and
    /// returns how many pixels of the lit colour differ from the empty scene's.
    private func litCoverage(visible: [EntityID]? = nil) throws -> Int {
        if let visible {
            visibleEntityIds = visible
            for frame in 0 ..< 3 {
                tripleVisibleEntities.setWrite(frame: frame, with: visible)
            }
        } else {
            setVisibleEntities()
        }
        renderer.draw(in: renderer.metalView)
        renderInfo.lastCommandBuffer?.waitUntilCompleted()

        let pixels = try litPixels()
        if backgroundLit.isEmpty {
            backgroundLit = pixels
            return 0
        }
        var covered = 0
        var pixel = 0
        while pixel < pixels.count {
            if (0 ..< 3).contains(where: { abs(Float(pixels[pixel + $0]) - Float(backgroundLit[pixel + $0])) > 1e-3 }) {
                covered += 1
            }
            pixel += 4
        }
        return covered
    }

    /// The camera alone, kept as the "nothing drawn" reference; then the cube.
    private func makeSceneWithCube() throws -> (entity: EntityID, plainCoverage: Int) {
        createTestCamera()
        _ = try litCoverage()
        let entity = makeFrameFillingCube()
        let plain = try litCoverage()
        XCTAssertGreaterThan(plain, 1000, "Sanity: the cube fills the frame")
        return (entity, plain)
    }

    // MARK: - Scene channels

    func testAnEntityOnAHiddenChannelIsNotDrawnAndComesBack() throws {
        let (entity, plain) = try makeSceneWithCube()
        let channel = SceneChannel.userCustom(index: 5)
        setEntitySceneChannels(entityId: entity, channels: channel)
        XCTAssertGreaterThan(try litCoverage(), plain * 9 / 10, "A channel in its normal mode changes nothing")

        setSceneChannel(channel, .renderMode(.hidden))
        XCTAssertLessThan(try litCoverage(), plain / 50, "Hidden channel: nothing of the entity is drawn")

        setSceneChannel(channel, .renderMode(.normal))
        XCTAssertGreaterThan(try litCoverage(), plain * 9 / 10, "Back to normal: the entity is drawn again")
    }

    func testAnEntityNamedForAHiddenChannelIsNotDrawn() throws {
        // No channel component: the entity takes the channels its name asks for.
        let (entity, plain) = try makeSceneWithCube()
        let channel = SceneChannel.userCustom(index: 6)
        registerSceneChannelPrefix("HIDE_", channels: channel)
        setSceneChannel(channel, .renderMode(.hidden))
        XCTAssertGreaterThan(try litCoverage(), plain * 9 / 10, "The name does not match yet")

        setEntityName(entityId: entity, name: "HIDE_Cube")
        XCTAssertNil(scene.get(component: EntitySceneChannelsComponent.self, for: entity))
        XCTAssertLessThan(try litCoverage(), plain / 50, "Renamed onto the hidden channel: not drawn")
    }

    func testAnEntityOnAWireframeChannelLeavesTheSolidPass() throws {
        let (entity, plain) = try makeSceneWithCube()
        let channel = SceneChannel.userCustom(index: 7)
        setEntitySceneChannels(entityId: entity, channels: channel)

        setSceneChannel(channel, .renderMode(.wireframe))
        let wireframe = try litCoverage()
        XCTAssertLessThan(wireframe, plain / 4, "Wireframe channel: the faces are not filled (\(wireframe) of \(plain))")

        setSceneChannel(channel, .renderMode(.normal))
        XCTAssertGreaterThan(try litCoverage(), plain * 9 / 10, "Back to normal: the faces are filled again")
    }

    // MARK: - Entities that are gone

    func testAnEntityWaitingToBeDestroyedIsSkippedThoughStillListedAsVisible() throws {
        let (entity, plain) = try makeSceneWithCube()
        XCTAssertGreaterThan(try litCoverage(visible: [entity]), plain * 9 / 10)

        destroyEntity(entityId: entity)
        XCTAssertLessThan(try litCoverage(visible: [entity]), plain / 50, "Waiting to be destroyed: not drawn")

        finalizePendingDestroys()
        XCTAssertLessThan(try litCoverage(visible: [entity]), plain / 50, "Destroyed, its id still in the list: not drawn")
    }

    func testAnIdThatWasNeverAnEntityIsSkipped() throws {
        let (entity, plain) = try makeSceneWithCube()
        let unknown = createEntityId(EntityIndex(60000), 3)

        XCTAssertGreaterThan(try litCoverage(visible: [unknown, entity, unknown]), plain * 9 / 10)
    }

    func testAnEntityWithoutARenderComponentIsSkipped() throws {
        let (entity, plain) = try makeSceneWithCube()
        let bare = createEntity()

        XCTAssertGreaterThan(try litCoverage(visible: [bare, entity]), plain * 9 / 10)

        scene.remove(component: RenderComponent.self, from: entity)
        XCTAssertLessThan(try litCoverage(visible: [bare, entity]), plain / 50, "Render component removed: not drawn")
    }

    // MARK: - Fades

    /// A quarter of the way, the outgoing representation of a tile keeps three quarters of
    /// its pixels and the incoming one a quarter: complementary halves of one dither.
    func testTileRepresentationFadeDithersTheEntityInEachDirection() throws {
        let (entity, plain) = try makeSceneWithCube()

        let fade = try XCTUnwrap(scene.assign(to: entity, component: TileRepresentationFadeComponent.self))
        fade.progress = 0.25
        fade.mode = 2
        let outgoing = try Float(litCoverage()) / Float(plain)
        XCTAssertEqual(outgoing, 0.75, accuracy: 0.1, "Outgoing at 0.25 keeps three quarters of the pixels, kept \(outgoing)")

        fade.mode = 1
        let incoming = try Float(litCoverage()) / Float(plain)
        XCTAssertEqual(incoming, 0.25, accuracy: 0.1, "Incoming at 0.25 keeps a quarter of the pixels, kept \(incoming)")
        XCTAssertEqual(outgoing + incoming, 1.0, accuracy: 0.1, "The two directions are complementary")

        scene.remove(component: TileRepresentationFadeComponent.self, from: entity)
        XCTAssertGreaterThan(try litCoverage(), plain * 9 / 10, "Fade removed: the full mesh is back")
    }

    /// The mesh fade is applied after the tile fade, so it decides when an entity has both.
    func testMeshFadeWinsOverATileRepresentationFade() throws {
        let (entity, plain) = try makeSceneWithCube()

        let tileFade = try XCTUnwrap(scene.assign(to: entity, component: TileRepresentationFadeComponent.self))
        tileFade.progress = 0.25
        tileFade.mode = 2
        let meshFade = try XCTUnwrap(scene.assign(to: entity, component: MeshFadeComponent.self))
        meshFade.direction = .fadeIn
        meshFade.progress = 0.25

        let ratio = try Float(litCoverage()) / Float(plain)
        XCTAssertEqual(ratio, 0.25, accuracy: 0.1, "The mesh fade's quarter, not the tile fade's three quarters: kept \(ratio)")
    }

    // MARK: - Lights, cameras and gizmos

    func testAMeshOnALightCameraOrGizmoEntityIsNotDrawn() throws {
        let (entity, plain) = try makeSceneWithCube()

        for componentType in [LightComponent.self, GizmoComponent.self, SceneCameraComponent.self] as [any Component.Type] {
            registerComponent(entityId: entity, componentType: componentType)
            XCTAssertLessThan(try litCoverage(visible: [entity]), plain / 50, "\(componentType): the entity's mesh is not drawn")
            removeEntityComponent(entityId: entity, componentType: componentType)
            XCTAssertGreaterThan(try litCoverage(visible: [entity]), plain * 9 / 10, "\(componentType) removed: drawn again")
        }
    }
}
