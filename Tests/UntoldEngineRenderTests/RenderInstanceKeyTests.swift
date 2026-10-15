//
//  RenderInstanceKeyTests.swift
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

/// Entities share an instanced draw when their render components have the same key. A
/// key must be shared by components that send the same things to the GPU, and by no
/// others: these tests pin both directions, and what clears a key.
@MainActor
final class RenderInstanceKeyTests: BaseRenderSetup {
    private var table: RenderInstanceKeyTable!

    override func setUp() async throws {
        try await super.setUp()
        table = RenderInstanceKeyTable()
    }

    override func tearDown() async throws {
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {}

    // MARK: - Helpers

    private func material() -> Material {
        Material(
            runtimeMaterial: RuntimeMaterialSource(
                baseColorFactor: simd_float4(0.8, 0.7, 0.6, 1),
                emissiveFactor: .zero,
                metallicFactor: 0.2,
                roughnessFactor: 0.6
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

    private func texture() throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 2, height: 2, mipmapped: false)
        return try XCTUnwrap(renderInfo.device.makeTexture(descriptor: descriptor))
    }

    private func sampler() throws -> MTLSamplerState {
        let descriptor = MTLSamplerDescriptor()
        descriptor.minFilter = .nearest
        // The device gives equal descriptors one sampler: make this one like no other.
        descriptor.lodMaxClamp = Float(samplerCount) + 3.5
        samplerCount += 1
        return try XCTUnwrap(renderInfo.device.makeSamplerState(descriptor: descriptor))
    }

    private var samplerCount = 0

    private func component(_ meshes: [Mesh]) -> RenderComponent {
        let component = RenderComponent()
        component.mesh = meshes
        return component
    }

    // MARK: - The same key

    func testComponentsThatDrawTheSameThingsShareAKey() {
        let cube = meshes(BasicPrimitives.createCube(extent: 1), with: material())
        let first = component(cube)
        let second = component(cube)
        // The same values, set on a copy by hand.
        var rebuilt = cube
        rebuilt[0].submeshes[0].material = cube[0].submeshes[0].material
        let third = component(rebuilt)

        let id = table.resolve(first)

        XCTAssertGreaterThanOrEqual(id, 0)
        XCTAssertEqual(table.resolve(second), id)
        XCTAssertEqual(table.resolve(third), id)
        XCTAssertEqual(table.count, 1)
    }

    func testWhatADrawDoesNotBindLeavesTheKeyAlone() throws {
        let base = material()
        let cube = BasicPrimitives.createCube(extent: 1)
        let id = table.id(for: meshes(cube, with: base))

        // Where a texture came from, how far its streaming got, the samplers of the
        // textures that are read through another one's: none of it reaches the encoder.
        let changes: [(String, (inout Material) -> Void)] = try [
            ("baseColorURL", { $0.baseColorURL = URL(fileURLWithPath: "/tmp/other.png") }),
            ("baseColorTextureName", { $0.baseColorTextureName = "other" }),
            ("baseColorStreamingLevel", { $0.baseColorStreamingLevel = .capped }),
            ("baseColorSourceDimensions", { $0.baseColorSourceDimensions = simd_int2(64, 64) }),
            ("metallic sampler", { [sampler = sampler()] in $0.metallic.sampler = sampler }),
            ("emissive sampler", { [sampler = sampler()] in $0.emissive.sampler = sampler }),
            ("wrap mode", { $0.baseColor.wrapMode = .clampToEdge }),
            // A height setting without a height texture switches nothing on.
            ("heightEnabled", { $0.heightEnabled.toggle() }),
        ]
        for (name, change) in changes {
            var changed = base
            change(&changed)
            XCTAssertEqual(table.id(for: meshes(cube, with: changed)), id, name)
        }
    }

    // MARK: - Another key

    func testEveryValueADrawBindsGivesAnotherKey() throws {
        var base = material()
        base.height.texture = try texture()
        let cube = BasicPrimitives.createCube(extent: 1)
        let id = table.id(for: meshes(cube, with: base))
        XCTAssertGreaterThanOrEqual(id, 0)

        let changes: [(String, (inout Material) -> Void)] = try [
            ("base colour texture", { [texture = texture()] in $0.baseColor.texture = texture }),
            ("roughness texture", { [texture = texture()] in $0.roughness.texture = texture }),
            ("metallic texture", { [texture = texture()] in $0.metallic.texture = texture }),
            ("normal texture", { [texture = texture()] in $0.normal.texture = texture }),
            ("height texture", { [texture = texture()] in $0.height.texture = texture }),
            ("emissive texture", { [texture = texture()] in $0.emissive.texture = texture }),
            ("base colour sampler", { [sampler = sampler()] in $0.baseColor.sampler = sampler }),
            ("roughness sampler", { [sampler = sampler()] in $0.roughness.sampler = sampler }),
            ("normal sampler", { [sampler = sampler()] in $0.normal.sampler = sampler }),
            ("height sampler", { [sampler = sampler()] in $0.height.sampler = sampler }),
            ("stScale", { $0.stScale = 2 }),
            ("normalIsPackedXY", { $0.normalIsPackedXY.toggle() }),
            ("baseColorValue", { $0.baseColorValue.z = 0.1 }),
            ("base colour alpha", { $0.baseColorValue.w = 0.5 }),
            ("edgeTint", { $0.edgeTint.y = 0.4 }),
            ("emissiveValue", { $0.emissiveValue.z = 2 }),
            ("roughnessValue", { $0.roughnessValue = 0.1 }),
            ("metallicValue", { $0.metallicValue = 0.9 }),
            ("roughnessChannel", { $0.roughnessChannel = .g }),
            ("metallicChannel", { $0.metallicChannel = .b }),
            ("normalScale", { $0.normalScale = 0.5 }),
            ("specular", { $0.specular = 0.3 }),
            ("specularTint", { $0.specularTint = 0.3 }),
            ("subsurface", { $0.subsurface = 0.3 }),
            ("anisotropic", { $0.anisotropic = 0.3 }),
            ("sheen", { $0.sheen = 0.3 }),
            ("sheenTint", { $0.sheenTint = 0.3 }),
            ("clearCoat", { $0.clearCoat = 0.3 }),
            ("clearCoatGloss", { $0.clearCoatGloss = 0.3 }),
            ("ior", { $0.ior = 1.33 }),
            ("interactWithLight", { $0.interactWithLight.toggle() }),
            ("alphaMode", { $0.alphaMode = .mask }),
            ("alphaCutoff", { $0.alphaCutoff = 0.25 }),
            ("heightScale", { $0.heightScale = 0.11 }),
            ("heightMidlevel", { $0.heightMidlevel = 0.4 }),
            ("heightRemapMin", { $0.heightRemapMin = 0.2 }),
            ("heightRemapMax", { $0.heightRemapMax = 0.8 }),
            ("heightEnabled", { $0.heightEnabled.toggle() }),
        ]

        var ids: [Int32: String] = [id: "the unchanged material"]
        for (name, change) in changes {
            var changed = base
            change(&changed)
            let changedID = table.id(for: meshes(cube, with: changed))
            XCTAssertGreaterThanOrEqual(changedID, 0, name)
            XCTAssertNil(ids[changedID], "\(name) draws like \(ids[changedID] ?? "")")
            ids[changedID] = name
        }
    }

    func testAnotherMeshOrLocalTransformGivesAnotherKey() {
        let shared = material()
        let cube = meshes(BasicPrimitives.createCube(extent: 1), with: shared)
        let id = table.id(for: cube)

        // The same shape built again is another set of vertex buffers.
        XCTAssertNotEqual(table.id(for: meshes(BasicPrimitives.createCube(extent: 1), with: shared)), id)

        var moved = cube
        moved[0].localSpace.columns.3.x = 2
        XCTAssertNotEqual(table.id(for: moved), id)

        // A mesh more, or the same meshes in another order.
        let sphere = meshes(BasicPrimitives.createSphere(extent: 1), with: shared)
        let both = table.id(for: cube + sphere)
        XCTAssertNotEqual(both, id)
        XCTAssertNotEqual(table.id(for: sphere + cube), both)
    }

    // MARK: - No key

    func testAMeshListTheOpaquePassDoesNotDrawHasNoKey() {
        let cube = BasicPrimitives.createCube(extent: 1)
        var glass = material()
        glass.alphaMode = .blend

        XCTAssertEqual(table.id(for: []), RenderInstanceKey.notInstanced)
        XCTAssertEqual(table.id(for: meshes(cube, with: nil)), RenderInstanceKey.notInstanced)
        XCTAssertEqual(table.id(for: meshes(cube, with: glass)), RenderInstanceKey.notInstanced)
        XCTAssertEqual(table.count, 0)

        // One solid submesh among them is enough.
        let mixed = meshes(cube, with: glass) + meshes(BasicPrimitives.createSphere(extent: 1), with: material())
        XCTAssertGreaterThanOrEqual(table.id(for: mixed), 0)
    }

    // MARK: - What clears a key

    func testAChangeToTheMeshesClearsTheKeyAndThePreparedDraws() {
        let renderComponent = component(meshes(BasicPrimitives.createCube(extent: 1), with: material()))
        let id = table.resolve(renderComponent)
        renderComponent.instancedSubmeshDraws = InstancedSubmeshDraw.draws(of: renderComponent.mesh)
        XCTAssertEqual(renderComponent.instanceKey, RenderInstanceKey(generation: table.currentGeneration, id: id))

        // One value of one material, changed where it is.
        renderComponent.mesh[0].submeshes[0].material?.roughnessValue = 0.05

        XCTAssertEqual(renderComponent.instanceKey, .unresolved)
        XCTAssertNil(renderComponent.instancedSubmeshDraws)
        let changedID = table.resolve(renderComponent)
        XCTAssertNotEqual(changedID, id)

        // And changed back: the first key again.
        renderComponent.mesh[0].submeshes[0].material?.roughnessValue = 0.6
        XCTAssertEqual(renderComponent.instanceKey, .unresolved)
        XCTAssertEqual(table.resolve(renderComponent), id)
    }

    func testAResolvedKeyIsNotLookedUpAgain() {
        let renderComponent = component(meshes(BasicPrimitives.createCube(extent: 1), with: material()))
        let generation = table.beginPass()
        let id = table.resolve(renderComponent)

        // The component answers for itself while its key is of the pass's generation.
        XCTAssertEqual(renderComponent.instanceKey.generation, generation)
        XCTAssertEqual(renderComponent.instanceKey.id, id)

        table.removeAll()
        XCTAssertNotEqual(table.currentGeneration, generation, "a key of the old generation is stale")
        XCTAssertEqual(table.count, 0)
        XCTAssertEqual(table.resolve(renderComponent), 0, "the table numbers from zero again")
        XCTAssertEqual(renderComponent.instanceKey.generation, table.currentGeneration)
    }

    func testTheTableStartsOverOnceItHasOutgrownItsLimit() {
        var moving = meshes(BasicPrimitives.createCube(extent: 1), with: material())
        let generation = table.beginPass()

        // A material edited over and over leaves a description behind each time.
        for step in 0 ... RenderInstanceKeyTable.maximumDescriptions {
            moving[0].localSpace.columns.3.x = Float(step)
            XCTAssertEqual(table.id(for: moving), Int32(step))
        }
        XCTAssertEqual(table.count, RenderInstanceKeyTable.maximumDescriptions + 1)
        XCTAssertEqual(table.currentGeneration, generation, "never in the middle of a pass")

        XCTAssertNotEqual(table.beginPass(), generation)
        XCTAssertEqual(table.count, 0)
    }

    // MARK: - The parameter block

    /// `MeshListDescription` lists the fields of the material's parameter block one by
    /// one. A field added to the block and not to the list would let two materials that
    /// differ in it share a draw: this fails until the list (and this test) know it.
    func testTheDescriptionKnowsEveryFieldOfTheParameterBlock() {
        let described = [
            "baseColor", "hasTexture", "textureChannels", "edgeTint", "emmissive", "roughness", "specular",
            "subsurface", "metallic", "specularTint", "anisotropic", "sheen", "sheenTint", "clearCoat",
            "clearCoatGloss", "ior", "alphaCutoff", "alphaMode", "interactWithLight", "heightScale",
            "heightMidlevel", "heightRemapMin", "heightRemapMax", "normalScale", "hasEmissiveTexture",
            "transmission",
        ]
        // The instance's own: its record carries the opacity, and it has no dither.
        let ofTheInstance = ["passthroughAlpha", "lodDither"]

        let fields = Mirror(reflecting: MaterialParametersUniform()).children.compactMap(\.label)

        XCTAssertFalse(fields.isEmpty, "the block's fields can be listed")
        XCTAssertEqual(
            Set(fields), Set(described + ofTheInstance),
            "MaterialParametersUniform changed: add the new field to MeshListDescription.addMaterial(of:) and to this list"
        )
    }
}
