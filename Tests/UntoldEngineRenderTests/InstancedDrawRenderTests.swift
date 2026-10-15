//
//  InstancedDrawRenderTests.swift
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

/// Entities that draw the same meshes with the same materials are encoded as one
/// instanced draw. These tests pin what makes a group, and that a frame looks the same,
/// pixel for pixel, whether its entities are drawn instanced or one by one.
@MainActor
final class InstancedDrawRenderTests: BaseRenderSetup {
    private var savedImmersionStyle: UntoldImmersionMode = .none
    private var savedRenderPath: RenderPath = .deferred

    override func setUp() async throws {
        try await super.setUp()
        savedImmersionStyle = renderInfo.immersionStyle
        savedRenderPath = getRenderPath()
        setRendering(.instancedDraws(.enabled))
        // Every entity of these scenes is meant to be drawn, however small on screen.
        setRendering(.smallObjectCulling(pixels: 0))
    }

    override func tearDown() async throws {
        setRendering(.instancedDraws(.enabled))
        setRendering(.smallObjectCulling(pixels: 1))
        setSceneChannel(.ghostGeometry, .renderMode(.normal))
        renderInfo.immersionStyle = savedImmersionStyle
        setRendering(.renderPath(savedRenderPath))
        SpatialDebugVisualization.shared.colorRenderablesByLOD = false
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {
        let camera = createEntity()
        createGameCamera(entityId: camera)
        CameraSystem.shared.activeCamera = camera
        cameraLookAt(entityId: camera, eye: simd_float3(0, 6, 16), target: simd_float3(0, 0, 0), up: simd_float3(0, 1, 0))
    }

    // MARK: - Helpers

    private func material(
        baseColor: simd_float4 = simd_float4(0.8, 0.8, 0.8, 1),
        emissive: simd_float3 = .zero,
        metallic: Float = 0,
        roughness: Float = 0.6
    ) -> Material {
        Material(
            runtimeMaterial: RuntimeMaterialSource(
                baseColorFactor: baseColor,
                emissiveFactor: emissive,
                metallicFactor: metallic,
                roughnessFactor: roughness
            ),
            device: renderInfo.device
        )
    }

    /// A copy of `meshes` whose submeshes all have `material`.
    private func meshes(_ meshes: [Mesh], with material: Material?) -> [Mesh] {
        var copy = meshes
        for meshIndex in copy.indices {
            for submeshIndex in copy[meshIndex].submeshes.indices {
                copy[meshIndex].submeshes[submeshIndex].material = material
            }
        }
        return copy
    }

    @discardableResult
    private func place(
        _ meshes: [Mesh],
        at position: simd_float3,
        scale: simd_float3 = simd_float3(repeating: 1),
        turnedBy degrees: Float = 0
    ) -> EntityID {
        let entity = createEntity()
        setEntityMeshDirect(entityId: entity, meshes: meshes, assetName: "Shape")
        scaleTo(entityId: entity, scale: scale)
        if degrees != 0 {
            rotateTo(entityId: entity, angle: degrees, axis: simd_float3(0.3, 1, 0.2))
        }
        translateTo(entityId: entity, position: position)
        return entity
    }

    /// A 8x8 texture of two colours in squares of two texels.
    private func checkerTexture(_ first: SIMD4<UInt8>, _ second: SIMD4<UInt8>) throws -> MTLTexture {
        let size = 8
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm_srgb, width: size, height: size, mipmapped: false)
        descriptor.usage = .shaderRead
        let texture = try XCTUnwrap(renderInfo.device.makeTexture(descriptor: descriptor))
        var texels = [UInt8]()
        for y in 0 ..< size {
            for x in 0 ..< size {
                let colour = ((x / 2) + (y / 2)).isMultiple(of: 2) ? first : second
                texels.append(contentsOf: [colour.x, colour.y, colour.z, colour.w])
            }
        }
        texture.replace(region: MTLRegionMake2D(0, 0, size, size), mipmapLevel: 0, withBytes: texels, bytesPerRow: size * 4)
        return texture
    }

    /// Draws enough frames for the culling result of the scene to come back and be used.
    private func drawFrames() {
        for _ in 0 ..< 6 {
            renderer.draw(in: renderer.metalView)
            renderInfo.lastCommandBuffer?.waitUntilCompleted()
        }
    }

    /// The lit frame, four half floats per pixel.
    private func litPixels() throws -> [Float16] {
        let texture = try XCTUnwrap(textureResources.deferredColorMap)
        XCTAssertEqual(texture.pixelFormat, .rgba16Float)
        var pixels = [Float16](repeating: 0, count: texture.width * texture.height * 4)
        pixels.withUnsafeMutableBytes { bytes in
            texture.getBytes(
                bytes.baseAddress!,
                bytesPerRow: texture.width * 8,
                from: MTLRegionMake2D(0, 0, texture.width, texture.height),
                mipmapLevel: 0
            )
        }
        return pixels
    }

    private struct Frame {
        let pixels: [Float16]
        let opaque: RenderPasses.InstancedDrawCounts
        let shadow: RenderPasses.InstancedDrawCounts
    }

    private func frame(instanced: Bool) throws -> Frame {
        setRendering(.instancedDraws(instanced ? .enabled : .disabled))
        drawFrames()
        return try Frame(
            pixels: litPixels(),
            opaque: RenderPasses.lastOpaqueInstancedDrawCounts,
            shadow: RenderPasses.lastShadowInstancedDrawCounts
        )
    }

    /// A channel difference beyond this is more than the last bits of a half float.
    private static let lastBits: Float = 0.004

    /// Pixels that differ in any channel at all, those that differ beyond the last bits,
    /// and how many have something drawn on them.
    private func compare(_ first: [Float16], _ second: [Float16]) -> (different: Int, beyondLastBits: Int, covered: Int) {
        XCTAssertEqual(first.count, second.count)
        var different = 0
        var beyondLastBits = 0
        var covered = 0
        let background = Array(first[0 ..< 4])
        for offset in stride(from: 0, to: min(first.count, second.count), by: 4) {
            var differs = false
            var beyond = false
            for channel in 0 ..< 4 where first[offset + channel] != second[offset + channel] {
                differs = true
                if abs(Float(first[offset + channel]) - Float(second[offset + channel])) > Self.lastBits {
                    beyond = true
                }
            }
            if differs { different += 1 }
            if beyond { beyondLastBits += 1 }
            if first[offset] != background[0] || first[offset + 1] != background[1] || first[offset + 2] != background[2] {
                covered += 1
            }
        }
        return (different, beyondLastBits, covered)
    }

    /// Draws the scene one by one and instanced, and checks that both frames are the same
    /// picture and that the picture is not empty. Returns the instanced frame.
    ///
    /// The same picture, to the last bits of a few pixels: the instanced vertex stage is
    /// compiled apart from the single-entity one, and the two differ in the last bits of
    /// what they hand the fragment stage (the G-buffer attachments at their own precision
    /// are identical), which the derivatives the fragment stage takes (the texture
    /// footprint, the specular anti-aliasing) turn into a visible difference at a quad or
    /// two along the silhouettes. A wrong transform, material, opacity or missing instance
    /// changes hundreds of pixels by much more.
    @discardableResult
    private func assertSamePictureBothWays(
        coveringAtLeast coveredPixels: Int = 2000,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> Frame {
        let single = try frame(instanced: false)
        let instanced = try frame(instanced: true)
        let result = compare(single.pixels, instanced.pixels)
        XCTAssertGreaterThan(result.covered, coveredPixels, "the scene is on screen", file: file, line: line)
        XCTAssertLessThanOrEqual(
            result.different, max(50, result.covered / 1000),
            "pixels that differ at all between the two ways of drawing, of \(result.covered) covered", file: file, line: line
        )
        XCTAssertLessThanOrEqual(
            result.beyondLastBits, max(4, result.covered / 10000),
            "pixels that differ beyond the last bits between the two ways of drawing, of \(result.covered) covered", file: file, line: line
        )
        XCTAssertEqual(single.opaque, RenderPasses.InstancedDrawCounts(), "nothing is instanced when the setting is off", file: file, line: line)
        return instanced
    }

    // MARK: - What makes a group

    func testEntitiesThatShareMeshesAndMaterialsAreOneDraw() throws {
        let cube = meshes(BasicPrimitives.createCube(extent: 1), with: material(baseColor: simd_float4(0.9, 0.2, 0.2, 1)))
        let sphere = meshes(BasicPrimitives.createSphere(extent: 1), with: material(baseColor: simd_float4(0.2, 0.3, 0.9, 1)))
        for index in 0 ..< 12 {
            place(cube, at: simd_float3(Float(index % 6) * 2.4 - 6, 0, Float(index / 6) * -3))
        }
        for index in 0 ..< 5 {
            place(sphere, at: simd_float3(Float(index) * 2.4 - 4.8, 2.5, -1))
        }

        let instanced = try frame(instanced: true)

        XCTAssertEqual(instanced.opaque, RenderPasses.InstancedDrawCounts(groups: 2, instances: 17, draws: 2))
    }

    func testAnEntityWithItsOwnMaterialIsAGroupOfItsOwn() throws {
        let shape = BasicPrimitives.createCube(extent: 1)
        // Black and glowing: what is seen is the material's own colour, whatever the light.
        let red = material(baseColor: simd_float4(0, 0, 0, 1), emissive: simd_float3(1, 0, 0))
        var entities: [EntityID] = []
        for index in 0 ..< 5 {
            entities.append(place(meshes(shape, with: red), at: simd_float3(Float(index) * 3 - 6, 0, 0)))
        }
        XCTAssertEqual(try frame(instanced: true).opaque, RenderPasses.InstancedDrawCounts(groups: 1, instances: 5, draws: 1))

        // The middle one turns green: the change reaches the renderer by itself.
        XCTAssertTrue(updateMaterial(entityId: entities[2]) { $0.emissiveValue = simd_float3(0, 1, 0) })
        let edited = try frame(instanced: true)
        XCTAssertEqual(edited.opaque, RenderPasses.InstancedDrawCounts(groups: 2, instances: 5, draws: 2))

        let texture = try XCTUnwrap(textureResources.deferredColorMap)
        let camera = try XCTUnwrap(CameraSystem.shared.activeCamera)
        let view = try XCTUnwrap(scene.get(component: CameraComponent.self, for: camera)).viewSpace
        func colour(atEntity index: Int) -> simd_float3 {
            let clip = renderInfo.perspectiveSpace * view * simd_float4(Float(index) * 3 - 6, 0, 0, 1)
            let x = Int((clip.x / clip.w * 0.5 + 0.5) * Float(texture.width))
            let y = Int((0.5 - clip.y / clip.w * 0.5) * Float(texture.height))
            let offset = (y * texture.width + x) * 4
            return simd_float3(Float(edited.pixels[offset]), Float(edited.pixels[offset + 1]), Float(edited.pixels[offset + 2]))
        }
        for index in 0 ..< 5 {
            let seen = colour(atEntity: index)
            if index == 2 {
                XCTAssertGreaterThan(seen.y, 0.5, "the edited entity shows its own material, got \(seen)")
                XCTAssertLessThan(seen.x, 0.2, "the edited entity does not show the group's material, got \(seen)")
            } else {
                XCTAssertGreaterThan(seen.x, 0.5, "entity \(index) shows the group's material, got \(seen)")
                XCTAssertLessThan(seen.y, 0.2, "entity \(index) does not show the edited material, got \(seen)")
            }
        }

        // Given the group's material back, it is one of the group again.
        XCTAssertTrue(updateMaterial(entityId: entities[2]) { $0.emissiveValue = simd_float3(1, 0, 0) })
        XCTAssertEqual(try frame(instanced: true).opaque, RenderPasses.InstancedDrawCounts(groups: 1, instances: 5, draws: 1))
    }

    func testSubmeshesTheOpaquePassDoesNotDrawAreNotDrawnInstancedEither() throws {
        let shape = BasicPrimitives.createCube(extent: 1)
        var glass = material(baseColor: simd_float4(0.2, 0.5, 0.9, 0.4))
        glass.alphaMode = .blend
        for index in 0 ..< 4 {
            place(meshes(shape, with: glass), at: simd_float3(Float(index) * 3 - 4.5, 0, 0))
            place(meshes(shape, with: nil), at: simd_float3(Float(index) * 3 - 4.5, 3, 0))
        }
        place(meshes(shape, with: material()), at: simd_float3(0, -3, 0))

        let instanced = try assertSamePictureBothWays()

        XCTAssertEqual(instanced.opaque, RenderPasses.InstancedDrawCounts(groups: 1, instances: 1, draws: 1), "only the solid cube")
    }

    // MARK: - The same picture

    /// Six materials (plain, metallic, emissive, textured, cut out, tiled) on two shapes,
    /// four placements each: 12 groups of 2.
    private func placeManyMaterials() throws {
        let cube = BasicPrimitives.createCube(extent: 1)
        let sphere = BasicPrimitives.createSphere(extent: 1)

        var textured = material()
        textured.baseColor.texture = try checkerTexture(SIMD4(230, 60, 40, 255), SIMD4(250, 240, 200, 255))
        var cutOut = material(baseColor: simd_float4(1, 1, 1, 1))
        cutOut.baseColor.texture = try checkerTexture(SIMD4(40, 200, 90, 255), SIMD4(40, 200, 90, 0))
        cutOut.alphaMode = .mask
        cutOut.alphaCutoff = 0.5
        var tiled = textured
        tiled.stScale = 3

        let materials: [Material] = [
            material(baseColor: simd_float4(0.85, 0.15, 0.1, 1), roughness: 0.3),
            material(baseColor: simd_float4(0.9, 0.9, 0.95, 1), metallic: 1, roughness: 0.15),
            material(baseColor: simd_float4(0.05, 0.05, 0.05, 1), emissive: simd_float3(0.2, 0.9, 1.4)),
            textured,
            cutOut,
            tiled,
        ]
        var index = 0
        for (materialIndex, material) in materials.enumerated() {
            for copy in 0 ..< 4 {
                let shape = (materialIndex + copy).isMultiple(of: 2) ? cube : sphere
                place(
                    meshes(shape, with: material),
                    at: simd_float3(Float(index % 8) * 2.6 - 9.1, Float(index / 8) * 2.6 - 2.6, Float(copy) * -1.5),
                    scale: simd_float3(1 + Float(copy) * 0.25, 1, 0.6 + Float(materialIndex) * 0.15),
                    turnedBy: Float(index) * 17
                )
                index += 1
            }
        }
    }

    func testAFrameOfManyMaterialsLooksTheSameDrawnBothWays() throws {
        try placeManyMaterials()

        let instanced = try assertSamePictureBothWays()

        // Six materials on two shapes each.
        XCTAssertEqual(instanced.opaque, RenderPasses.InstancedDrawCounts(groups: 12, instances: 24, draws: 12))
    }

    func testMeshesWithTheirOwnLocalTransformsLookTheSameDrawnBothWays() throws {
        // One entity draws a cube to its left and a sphere to its right: each mesh has a
        // local transform, the same as its world one so that the registration keeps it.
        var pair = meshes(BasicPrimitives.createCube(extent: 1), with: material(baseColor: simd_float4(0.9, 0.6, 0.1, 1)))
            + meshes(BasicPrimitives.createSphere(extent: 1), with: material(baseColor: simd_float4(0.2, 0.7, 0.4, 1)))
        pair[0].localSpace = matrix4x4Translation(-0.9, 0, 0)
        pair[0].worldSpace = pair[0].localSpace
        pair[1].localSpace = matrix4x4Translation(0.9, 0.4, 0)
        pair[1].worldSpace = pair[1].localSpace
        for index in 0 ..< 6 {
            place(pair, at: simd_float3(Float(index % 3) * 5 - 5, Float(index / 3) * 3 - 1, 0), turnedBy: Float(index) * 31)
        }

        let instanced = try assertSamePictureBothWays()

        XCTAssertEqual(instanced.opaque, RenderPasses.InstancedDrawCounts(groups: 1, instances: 6, draws: 2))
    }

    func testAnEntityThatFadesAmongInstancesLooksTheSameDrawnBothWays() throws {
        let shape = meshes(BasicPrimitives.createCube(extent: 1.5), with: material(baseColor: simd_float4(0.3, 0.6, 0.9, 1)))
        var entities: [EntityID] = []
        for index in 0 ..< 6 {
            entities.append(place(shape, at: simd_float3(Float(index) * 3 - 7.5, 0, 0), turnedBy: 20))
        }
        // Half way through a fade, an entity is drawn with a dither of its own.
        registerComponent(entityId: entities[3], componentType: MeshFadeComponent.self)
        let fade = try XCTUnwrap(scene.get(component: MeshFadeComponent.self, for: entities[3]))
        fade.progress = 0.5

        let instanced = try assertSamePictureBothWays()

        XCTAssertEqual(instanced.opaque, RenderPasses.InstancedDrawCounts(groups: 1, instances: 5, draws: 1))
    }

    func testAGhostChannelKeepsItsOpacityDrawnBothWays() throws {
        // In mixed immersion an entity on a ghost channel is drawn see-through: the
        // opacity belongs to the entity, not to the material it shares, and the ghosts
        // are a group of their own.
        renderInfo.immersionStyle = .mixed
        let shape = meshes(BasicPrimitives.createCube(extent: 1.5), with: material(emissive: simd_float3(1, 0.5, 0.1)))
        var entities: [EntityID] = []
        for index in 0 ..< 6 {
            entities.append(place(shape, at: simd_float3(Float(index) * 3 - 7.5, 0, 0)))
        }
        setEntitySceneChannels(entityId: entities[1], channels: .ghostGeometry)
        setEntitySceneChannels(entityId: entities[4], channels: .ghostGeometry)
        setSceneChannel(.ghostGeometry, .renderMode(.passthroughGhost(opacity: 0.35)))

        let instanced = try assertSamePictureBothWays()

        XCTAssertEqual(instanced.opaque, RenderPasses.InstancedDrawCounts(groups: 2, instances: 6, draws: 2), "the four opaque cubes, and the two ghosts")
    }

    // MARK: - The render paths

    /// The hybrid path: the geometry evaluates the indirect light and the sun's shadow per
    /// fragment, through the instanced pipelines built with the same function constants.
    func testAFrameOfManyMaterialsLooksTheSameDrawnBothWaysOnTheHybridPath() throws {
        setRendering(.renderPath(.hybrid))
        try placeManyMaterials()

        let instanced = try assertSamePictureBothWays()

        XCTAssertTrue(renderInfo.perFragmentIndirectLightingBuilt, "the pipelines are the hybrid path's")
        XCTAssertFalse(renderInfo.perFragmentLightingBuilt)
        XCTAssertEqual(instanced.opaque, RenderPasses.InstancedDrawCounts(groups: 12, instances: 24, draws: 12))
    }

    /// The forward path, the headset's: the geometry lights itself whole per fragment and
    /// writes the lit colour and its velocity; the light quad stands down.
    func testAFrameOfManyMaterialsLooksTheSameDrawnBothWaysOnTheForwardPath() throws {
        setRendering(.renderPath(.forward))
        try placeManyMaterials()

        let instanced = try assertSamePictureBothWays()

        XCTAssertTrue(renderInfo.perFragmentLightingBuilt, "the pipelines are the forward path's")
        XCTAssertEqual(instanced.opaque, RenderPasses.InstancedDrawCounts(groups: 12, instances: 24, draws: 12))
    }

    /// The velocity texture of the last frame, two half floats per pixel (the surface's
    /// motion in NDC), copied out of the private texture the forward pass writes.
    private func velocityPixels() throws -> [Float16] {
        let velocity = try XCTUnwrap(textureResources.velocityMap)
        XCTAssertEqual(velocity.pixelFormat, .rg16Float)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rg16Float, width: velocity.width, height: velocity.height, mipmapped: false
        )
        descriptor.storageMode = .shared
        descriptor.usage = .shaderRead
        let copy = try XCTUnwrap(renderInfo.device.makeTexture(descriptor: descriptor))
        let commandBuffer = try XCTUnwrap(renderInfo.commandQueue.makeCommandBuffer())
        let blit = try XCTUnwrap(commandBuffer.makeBlitCommandEncoder())
        blit.copy(from: velocity, to: copy)
        blit.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        var pixels = [Float16](repeating: 0, count: copy.width * copy.height * 2)
        pixels.withUnsafeMutableBytes { bytes in
            copy.getBytes(
                bytes.baseAddress!,
                bytesPerRow: copy.width * 4,
                from: MTLRegionMake2D(0, 0, copy.width, copy.height),
                mipmapLevel: 0
            )
        }
        return pixels
    }

    /// The velocity the frame writes after `mover` goes from `from` to `to`, drawn `instanced`.
    private func velocityOfAMove(_ mover: EntityID, from: simd_float3, to: simd_float3, instanced: Bool) throws -> [Float16] {
        setRendering(.instancedDraws(instanced ? .enabled : .disabled))
        translateTo(entityId: mover, position: from)
        drawFrames()
        translateTo(entityId: mover, position: to)
        renderer.draw(in: renderer.metalView)
        renderInfo.lastCommandBuffer?.waitUntilCompleted()
        return try velocityPixels()
    }

    /// An instance's record carries where it was the previous frame, so an entity that
    /// moves on its own has its motion written for the temporal resolve as it has when it
    /// is drawn alone.
    func testAnEntityThatMovesAmongInstancesWritesTheSameVelocityDrawnBothWays() throws {
        setRendering(.renderPath(.forward))
        let shape = meshes(BasicPrimitives.createCube(extent: 1.5), with: material(baseColor: simd_float4(0.2, 0.6, 0.9, 1)))
        var entities: [EntityID] = []
        for index in 0 ..< 6 {
            entities.append(place(shape, at: simd_float3(Float(index) * 3 - 7.5, 0, 0)))
        }
        let mover = entities[2]
        let from = simd_float3(-1.5, 0, 0)
        let to = simd_float3(-1.5, 1.2, 0.8)

        let single = try velocityOfAMove(mover, from: from, to: to, instanced: false)
        let instanced = try velocityOfAMove(mover, from: from, to: to, instanced: true)

        XCTAssertTrue(renderInfo.perFragmentLightingBuilt, "the velocity is written on the forward path")
        XCTAssertEqual(RenderPasses.lastOpaqueInstancedDrawCounts, RenderPasses.InstancedDrawCounts(groups: 1, instances: 6, draws: 1))
        XCTAssertEqual(single.count, instanced.count)
        var moving = 0
        var different = 0
        for offset in stride(from: 0, to: min(single.count, instanced.count), by: 2) {
            if single[offset] != 0 || single[offset + 1] != 0 { moving += 1 }
            // To the last bits, as the pictures (see assertSamePictureBothWays).
            if abs(Float(single[offset]) - Float(instanced[offset])) > Self.lastBits
                || abs(Float(single[offset + 1]) - Float(instanced[offset + 1])) > Self.lastBits
            {
                different += 1
            }
        }
        XCTAssertGreaterThan(moving, 500, "the moved cube's pixels carry its motion; the camera stood still")
        XCTAssertLessThanOrEqual(different, max(4, moving / 10000), "pixels whose velocity differs between the two ways of drawing, of \(moving) moving")
    }

    func testShadowsLookTheSameDrawnBothWays() throws {
        let sun = createEntity()
        createDirLight(entityId: sun)
        setSunElevationAzimuth(entityId: sun, elevation: 50, azimuth: 30)

        let ground = meshes(BasicPrimitives.createCube(extent: 1), with: material(baseColor: simd_float4(0.7, 0.7, 0.7, 1)))
        place(ground, at: simd_float3(0, -1.2, 0), scale: simd_float3(40, 0.2, 40))
        let post = meshes(BasicPrimitives.createCube(extent: 1), with: material(baseColor: simd_float4(0.8, 0.3, 0.2, 1)))
        for index in 0 ..< 9 {
            place(post, at: simd_float3(Float(index % 3) * 4 - 4, 0.4, Float(index / 3) * -4 + 2), scale: simd_float3(0.8, 3, 0.8), turnedBy: Float(index) * 11)
        }
        RenderPasses.invalidateShadowEntityCache()

        let instanced = try assertSamePictureBothWays()

        // The ground and the posts share the cube's mesh and differ in material: two
        // groups in the opaque pass, and in every cascade they are cast into.
        XCTAssertEqual(instanced.opaque, RenderPasses.InstancedDrawCounts(groups: 2, instances: 10, draws: 2))
        XCTAssertGreaterThan(instanced.shadow.instances, 0, "the posts cast into a cascade")
        XCTAssertEqual(instanced.shadow.draws, instanced.shadow.groups, "a cube is one draw per group")
        XCTAssertLessThan(instanced.shadow.draws, instanced.shadow.instances, "casters share their draws")
    }

    func testLoadedModelsWithASkinnedOneAmongThemLookTheSameDrawnBothWays() async throws {
        func load(_ file: String, at position: simd_float3) async -> EntityID {
            let entity = createEntity()
            let loaded = expectation(description: file)
            setEntityMeshAsync(entityId: entity, filename: file, withExtension: "untold") { _ in loaded.fulfill() }
            await fulfillment(of: [loaded], timeout: 60)
            translateTo(entityId: entity, position: position)
            return entity
        }
        _ = await load("stadium", at: .zero)
        for index in 0 ..< 3 {
            _ = await load("ball", at: simd_float3(Float(index) * 1.5 - 1.5, 0.3, 2))
        }
        // The player is posed by its skeleton: its vertices are its own, frame by frame.
        let player = await load("redplayer", at: simd_float3(0, 0, 0))
        setEntityAnimations(entityId: player, filename: "running", withExtension: "untold", name: "running")
        changeAnimation(entityId: player, name: "running")
        setAnimationPlaybackSpeed(entityId: player, speed: 0)
        let camera = try XCTUnwrap(CameraSystem.shared.activeCamera)
        cameraLookAt(entityId: camera, eye: simd_float3(0, 3, 7), target: .zero, up: simd_float3(0, 1, 0))

        let instanced = try assertSamePictureBothWays()

        let skeletonId = getComponentId(for: SkeletonComponent.self)
        let renderId = getComponentId(for: RenderComponent.self)
        let skinned = queryEntitiesWithComponentIds([skeletonId, renderId], in: scene)
        XCTAssertFalse(skinned.isEmpty, "the player is drawn through its skeleton")
        XCTAssertGreaterThan(instanced.opaque.instances, 0, "the stadium and the balls are drawn instanced")
        for entity in skinned {
            let render = try XCTUnwrap(scene.get(component: RenderComponent.self, for: entity))
            XCTAssertNil(render.instancedSubmeshDraws, "a skinned entity never stands for a group")
        }
    }

    func testEntitiesFollowTheirLevelOfDetailFromGroupToGroup() throws {
        // Six entities with two levels, a cube up close and a sphere from 20 units on.
        let shared = material(baseColor: simd_float4(0.9, 0.7, 0.2, 1))
        let near = meshes(BasicPrimitives.createCube(extent: 1), with: shared)
        let far = meshes(BasicPrimitives.createSphere(extent: 1), with: shared)
        var entities: [EntityID] = []
        for index in 0 ..< 6 {
            // Three within reach of the first level, three beyond it.
            let entity = place(near, at: simd_float3(Float(index % 3) * 3 - 3, 0, index < 3 ? 4 : -14))
            registerComponent(entityId: entity, componentType: LODComponent.self)
            let lod = try XCTUnwrap(scene.get(component: LODComponent.self, for: entity))
            lod.lodLevels = [
                LODLevel(mesh: near, maxDistance: 20),
                LODLevel(mesh: far, maxDistance: .greatestFiniteMagnitude),
            ]
            entities.append(entity)
        }
        LODSystem.shared.reset()
        LODSystem.shared.update(deltaTime: 0.1)

        let instanced = try assertSamePictureBothWays()
        XCTAssertEqual(instanced.opaque, RenderPasses.InstancedDrawCounts(groups: 2, instances: 6, draws: 2), "three cubes, three spheres")

        // The camera backs away: every entity is past its first level now.
        let camera = try XCTUnwrap(CameraSystem.shared.activeCamera)
        cameraLookAt(entityId: camera, eye: simd_float3(0, 12, 40), target: .zero, up: simd_float3(0, 1, 0))
        LODSystem.shared.update(deltaTime: 0.1)

        let fromAfar = try assertSamePictureBothWays(coveringAtLeast: 500)
        XCTAssertEqual(fromAfar.opaque, RenderPasses.InstancedDrawCounts(groups: 1, instances: 6, draws: 1), "six spheres")
    }

    func testGlassAmongInstancesLooksTheSameDrawnBothWays() throws {
        let sun = createEntity()
        createDirLight(entityId: sun)
        setSunElevationAzimuth(entityId: sun, elevation: 50, azimuth: 30)

        let ground = meshes(BasicPrimitives.createCube(extent: 1), with: material(baseColor: simd_float4(0.7, 0.7, 0.7, 1)))
        place(ground, at: simd_float3(0, -1.2, 0), scale: simd_float3(40, 0.2, 40))

        // A post with a glass ball on top, six times: the post is drawn instanced and
        // casts; the ball goes to the transparency pass and casts no shadow.
        var glass = material(baseColor: simd_float4(0.6, 0.9, 1.0, 1), roughness: 0.0)
        glass.transmission = 1
        XCTAssertTrue(glass.transmitsLight)
        var lamp = meshes(BasicPrimitives.createCube(extent: 1), with: material(baseColor: simd_float4(0.8, 0.3, 0.2, 1)))
            + meshes(BasicPrimitives.createSphere(extent: 1), with: glass)
        lamp[0].localSpace = matrix4x4Translation(0, 0, 0)
        lamp[0].worldSpace = lamp[0].localSpace
        lamp[1].localSpace = matrix4x4Translation(0, 1.4, 0)
        lamp[1].worldSpace = lamp[1].localSpace
        for index in 0 ..< 6 {
            place(lamp, at: simd_float3(Float(index % 3) * 4 - 4, 0, Float(index / 3) * -4 + 2))
        }
        RenderPasses.invalidateShadowEntityCache()

        let instanced = try assertSamePictureBothWays()

        // The ground, and the posts of the lamps: the glass is in neither pass's groups.
        XCTAssertEqual(instanced.opaque, RenderPasses.InstancedDrawCounts(groups: 2, instances: 7, draws: 2))
        XCTAssertGreaterThan(instanced.shadow.instances, 0)
        XCTAssertEqual(instanced.shadow.draws, instanced.shadow.groups, "a lamp casts with its post alone")
    }

    // MARK: - When nothing is instanced

    func testADebugColouringDrawsEveryEntityOnItsOwn() throws {
        let shape = meshes(BasicPrimitives.createCube(extent: 1), with: material())
        for index in 0 ..< 4 {
            place(shape, at: simd_float3(Float(index) * 3 - 4.5, 0, 0))
        }
        XCTAssertEqual(try frame(instanced: true).opaque.instances, 4)

        SpatialDebugVisualization.shared.colorRenderablesByLOD = true
        XCTAssertEqual(try frame(instanced: true).opaque, RenderPasses.InstancedDrawCounts())
    }

    // MARK: - Records

    func testTheRecordBuffersOfAFrameComeBack() throws {
        let shape = meshes(BasicPrimitives.createCube(extent: 1), with: material())
        for index in 0 ..< 4 {
            place(shape, at: simd_float3(Float(index) * 3 - 4.5, 0, 0))
        }

        _ = try frame(instanced: true)

        // drawFrames waits for each frame's command buffer; the completion handlers
        // may still be running.
        let deadline = Date().addingTimeInterval(5)
        while InstanceRecordBufferPool.shared.bufferCounts.lent > 0, Date() < deadline {
            usleep(1000)
        }
        let counts = InstanceRecordBufferPool.shared.bufferCounts
        XCTAssertEqual(counts.lent, 0, "every buffer a pass borrowed is back once its frame completed")
        XCTAssertGreaterThan(counts.free, 0)
        XCTAssertLessThanOrEqual(counts.free, InstanceRecordBufferPool.maximumFreeBuffers)
    }
}
