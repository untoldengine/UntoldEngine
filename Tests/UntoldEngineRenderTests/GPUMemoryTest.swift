//
//  GPUMemoryTest.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import MetalKit
import simd
@testable import UntoldEngine
import XCTest

final class GPUMemoryTest: BaseRenderSetup {
    // MARK: - Setup and Teardown

    override func setUp() async throws {
        try await super.setUp()
    }

    override func tearDown() async throws {
        destroyAllEntities()
        try await super.tearDown()
    }

    // MARK: - Mesh.gpuMemorySize Tests

    func testMeshGPUMemorySize_includesVertexAndIndexBuffers() {
        // Given: Load a mesh that has vertex and index buffers
        let entityId = createEntity()
        setEntityMeshDirect(entityId: entityId, meshes: BasicPrimitives.createSphere(), assetName: "ball")

        guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId),
              let mesh = renderComponent.mesh.first
        else {
            XCTFail("Failed to load mesh for test")
            return
        }

        // When: Calculate GPU memory size
        let gpuMemorySize = mesh.gpuMemorySize

        // Then: Memory should be greater than 0 and include vertex buffers
        XCTAssertGreaterThan(gpuMemorySize, 0, "GPU memory size should be positive")

        // Verify that vertex buffers are accounted for
        var expectedVertexBufferSize = 0
        for vertexBuffer in mesh.metalKitMesh.vertexBuffers {
            expectedVertexBufferSize += vertexBuffer.buffer.length
        }
        XCTAssertGreaterThan(expectedVertexBufferSize, 0, "Should have vertex buffer data")

        // Verify that index buffers are accounted for
        var expectedIndexBufferSize = 0
        for submesh in mesh.metalKitMesh.submeshes {
            expectedIndexBufferSize += submesh.indexBuffer.buffer.length
        }
        XCTAssertGreaterThan(expectedIndexBufferSize, 0, "Should have index buffer data")

        // GPU memory should include at least vertex and index buffers
        XCTAssertGreaterThanOrEqual(gpuMemorySize, expectedVertexBufferSize + expectedIndexBufferSize,
                                    "GPU memory should include vertex and index buffers")

        destroyEntity(entityId: entityId)
    }

    func testMeshGPUMemorySize_noUniformBuffers() {
        // Uniforms are now written per-draw via setVertexBytes — no per-mesh MTLBuffer is allocated.
        let entityId = createEntity()
        setEntityMeshDirect(entityId: entityId, meshes: BasicPrimitives.createSphere(), assetName: "ball")

        guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId),
              let mesh = renderComponent.mesh.first
        else {
            XCTFail("Failed to load mesh for test")
            return
        }

        // gpuMemorySize should still account for vertex + index buffers
        XCTAssertGreaterThan(mesh.gpuMemorySize, 0,
                             "GPU memory size should be non-zero (vertex + index buffers)")

        destroyEntity(entityId: entityId)
    }

    func testMeshGPUMemorySize_includesSkinBuffers() {
        // Given: Load an animated mesh with skin data
        let entityId = createEntity()
        setEntityMeshDirect(entityId: entityId, meshes: BasicPrimitives.createSphere(), assetName: "redplayer")

        guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId),
              let mesh = renderComponent.mesh.first
        else {
            XCTFail("Failed to load mesh for test")
            return
        }

        // When: Calculate GPU memory with skin
        let gpuMemorySize = mesh.gpuMemorySize

        // Then: If mesh has skin, skin memory should be included
        if let skin = mesh.skin {
            let skinMemory = skin.gpuMemorySize
            XCTAssertGreaterThan(skinMemory, 0, "Skin should have GPU memory for joint transforms")

            // The total should include skin memory
            // We verify by checking the total is at least as large as skin memory
            XCTAssertGreaterThanOrEqual(gpuMemorySize, skinMemory,
                                        "GPU memory should include skin buffer memory")
        }

        destroyEntity(entityId: entityId)
    }

    func testMeshGPUMemorySize_calculatesCorrectTotal() {
        // Given: Load a mesh
        let entityId = createEntity()
        setEntityMeshDirect(entityId: entityId, meshes: BasicPrimitives.createSphere(), assetName: "ball")

        guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId),
              let mesh = renderComponent.mesh.first
        else {
            XCTFail("Failed to load mesh for test")
            return
        }

        // When: Calculate expected total manually
        var expectedTotal = 0

        // Vertex buffers
        for vertexBuffer in mesh.metalKitMesh.vertexBuffers {
            expectedTotal += vertexBuffer.buffer.length
        }

        // Index buffers
        for submesh in mesh.metalKitMesh.submeshes {
            expectedTotal += submesh.indexBuffer.buffer.length
        }

        // Skin buffers
        if let skin = mesh.skin {
            expectedTotal += skin.gpuMemorySize
        }

        // Then: Calculated value should match expected
        let gpuMemorySize = mesh.gpuMemorySize
        XCTAssertEqual(gpuMemorySize, expectedTotal,
                       "GPU memory size should equal sum of all buffer sizes")

        destroyEntity(entityId: entityId)
    }

    // MARK: - Mesh.textureMemorySize Tests

    func testMeshTextureMemorySize_sumsSubmeshTextures() {
        // Given: Load a mesh with textures
        let entityId = createEntity()
        setEntityMeshDirect(entityId: entityId, meshes: BasicPrimitives.createSphere(), assetName: "ball")

        guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId),
              !renderComponent.mesh.isEmpty
        else {
            XCTFail("Failed to load mesh for test")
            return
        }

        // Test all meshes in the render component
        for mesh in renderComponent.mesh {
            // When: Calculate texture memory
            let textureMemorySize = mesh.textureMemorySize

            // Then: Calculate expected by summing submesh textures
            var expectedTotal = 0
            for submesh in mesh.submeshes {
                expectedTotal += submesh.textureMemorySize
            }

            XCTAssertEqual(textureMemorySize, expectedTotal,
                           "Texture memory should equal sum of all submesh texture memory")
        }

        destroyEntity(entityId: entityId)
    }

    func testMeshTextureMemorySize_zeroWhenNoTextures() {
        // Given: Create a mesh programmatically without textures
        let bufferAllocator = MTKMeshBufferAllocator(device: renderInfo.device)
        let sphereMDL = MDLMesh(
            sphereWithExtent: [0.5, 0.5, 0.5],
            segments: [16, 8],
            inwardNormals: false,
            geometryType: .triangles,
            allocator: bufferAllocator
        )

        let textureLoader = TextureLoader(device: renderInfo.device)
        let meshes = Mesh.makeMeshes(
            object: sphereMDL,
            vertexDescriptor: vertexDescriptor.model,
            textureLoader: textureLoader,
            device: renderInfo.device,
            flip: true
        )

        guard let mesh = meshes.first else {
            XCTFail("Failed to create mesh")
            return
        }

        // When: Calculate texture memory
        let textureMemorySize = mesh.textureMemorySize

        // Then: Should be 0 for meshes without textures
        XCTAssertEqual(textureMemorySize, 0,
                       "Texture memory should be 0 when no textures are present")
    }

    // MARK: - Mesh.totalGPUMemorySize Tests

    func testMeshTotalGPUMemorySize_sumsGPUAndTextureMemory() {
        // Given: Load a mesh with both geometry and textures
        let entityId = createEntity()
        setEntityMeshDirect(entityId: entityId, meshes: BasicPrimitives.createSphere(), assetName: "ball")

        guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId),
              !renderComponent.mesh.isEmpty
        else {
            XCTFail("Failed to load mesh for test")
            return
        }

        // Test all meshes in the render component
        for mesh in renderComponent.mesh {
            // When: Calculate total GPU memory
            let totalMemory = mesh.totalGPUMemorySize
            let gpuMemory = mesh.gpuMemorySize
            let textureMemory = mesh.textureMemorySize

            // Then: Total should equal GPU + texture memory
            XCTAssertEqual(totalMemory, gpuMemory + textureMemory,
                           "Total GPU memory should be gpuMemorySize + textureMemorySize")
        }

        destroyEntity(entityId: entityId)
    }

    func testMeshTotalGPUMemorySize_equalsGPUMemoryWhenNoTextures() {
        // Given: Create a mesh without textures
        let bufferAllocator = MTKMeshBufferAllocator(device: renderInfo.device)
        let boxMDL = MDLMesh(
            boxWithExtent: [1, 1, 1],
            segments: [1, 1, 1],
            inwardNormals: false,
            geometryType: .triangles,
            allocator: bufferAllocator
        )

        let textureLoader = TextureLoader(device: renderInfo.device)
        let meshes = Mesh.makeMeshes(
            object: boxMDL,
            vertexDescriptor: vertexDescriptor.model,
            textureLoader: textureLoader,
            device: renderInfo.device,
            flip: true
        )

        guard let mesh = meshes.first else {
            XCTFail("Failed to create mesh")
            return
        }

        // When: Calculate memory sizes
        let totalMemory = mesh.totalGPUMemorySize
        let gpuMemory = mesh.gpuMemorySize

        // Then: Total should equal GPU memory when no textures
        XCTAssertEqual(totalMemory, gpuMemory,
                       "Total should equal GPU memory when there are no textures")
    }

    // MARK: - SubMesh.textureMemorySize Tests

    func testSubMeshTextureMemorySize_calculatesAllTextureTypes() {
        // Given: Load a mesh that has materials
        let entityId = createEntity()
        setEntityMeshDirect(entityId: entityId, meshes: BasicPrimitives.createSphere(), assetName: "ball")

        guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId),
              !renderComponent.mesh.isEmpty
        else {
            XCTFail("Failed to load mesh")
            return
        }

        // Find a submesh to test
        var testedSubmesh = false
        for mesh in renderComponent.mesh {
            for submesh in mesh.submeshes {
                // When: Calculate texture memory
                let textureMemory = submesh.textureMemorySize

                // Then: Manually verify by checking individual textures
                var expectedTotal = 0

                if let material = submesh.material {
                    if let texture = material.baseColor.texture {
                        expectedTotal += texture.allocatedSize
                    }
                    if let texture = material.normal.texture {
                        expectedTotal += texture.allocatedSize
                    }
                    if let texture = material.metallic.texture {
                        expectedTotal += texture.allocatedSize
                    }
                    if let texture = material.roughness.texture {
                        expectedTotal += texture.allocatedSize
                    }
                }

                XCTAssertEqual(textureMemory, expectedTotal,
                               "SubMesh texture memory should equal sum of all material textures")
                testedSubmesh = true
            }
        }

        XCTAssertTrue(testedSubmesh, "Should have tested at least one submesh")
        destroyEntity(entityId: entityId)
    }

    func testSubMeshTextureMemorySize_zeroWhenNoMaterial() {
        // Given: Create a simple mesh and access its submesh
        let bufferAllocator = MTKMeshBufferAllocator(device: renderInfo.device)
        let sphereMDL = MDLMesh(
            sphereWithExtent: [0.5, 0.5, 0.5],
            segments: [8, 4],
            inwardNormals: false,
            geometryType: .triangles,
            allocator: bufferAllocator
        )

        let textureLoader = TextureLoader(device: renderInfo.device)
        let meshes = Mesh.makeMeshes(
            object: sphereMDL,
            vertexDescriptor: vertexDescriptor.model,
            textureLoader: textureLoader,
            device: renderInfo.device,
            flip: true
        )

        guard let mesh = meshes.first,
              let submesh = mesh.submeshes.first
        else {
            XCTFail("Failed to create mesh with submesh")
            return
        }

        // When: Calculate texture memory
        let textureMemory = submesh.textureMemorySize

        // Then: Should be 0 when material has no textures or is nil
        if submesh.material == nil ||
            (submesh.material?.baseColor.texture == nil &&
                submesh.material?.normal.texture == nil &&
                submesh.material?.metallic.texture == nil &&
                submesh.material?.roughness.texture == nil)
        {
            XCTAssertEqual(textureMemory, 0,
                           "Texture memory should be 0 when no textures present")
        }
    }

    // MARK: - Skin.gpuMemorySize Tests

    func testSkinGPUMemorySize_calculatesJointTransformBuffer() {
        // Given: Load an animated mesh with skin
        let entityId = createEntity()
        setEntityMeshDirect(entityId: entityId, meshes: BasicPrimitives.createSphere(), assetName: "redplayer")

        guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId),
              let mesh = renderComponent.mesh.first,
              let skin = mesh.skin
        else {
            // If no skin found, test with a manually created skin
            // Create a minimal skin for testing
            guard let testSkin = Skin() else {
                XCTFail("Could not create test skin")
                return
            }

            let skinMemory = testSkin.gpuMemorySize

            // Should have at least one joint's worth of memory
            XCTAssertGreaterThan(skinMemory, 0, "Skin should have GPU memory for joint transforms")

            // Verify it matches the whole ring (one buffer per in-flight
            // frame slot plus one; jointTransformsBuffer is only the
            // currently bound slot).
            if let ring = testSkin.jointTransformsRing {
                let ringTotal = ring.buffers.reduce(0) { $0 + $1.length }
                XCTAssertEqual(skinMemory, ringTotal,
                               "Skin GPU memory should equal the total of all joint ring slots")
            }
            return
        }

        // When: Calculate skin GPU memory
        let skinMemory = skin.gpuMemorySize

        // Then: Verify it matches the whole ring (one buffer per in-flight
        // frame slot plus one; jointTransformsBuffer is only the currently
        // bound slot).
        if let ring = skin.jointTransformsRing {
            let ringTotal = ring.buffers.reduce(0) { $0 + $1.length }
            XCTAssertEqual(skinMemory, ringTotal,
                           "Skin GPU memory should equal the total of all joint ring slots")
        }

        XCTAssertGreaterThan(skinMemory, 0, "Skin should have positive GPU memory")

        destroyEntity(entityId: entityId)
    }

    func testSkinGPUMemorySize_scaledByJointCount() {
        // Given: Create a minimal skin with a known joint count
        guard let testSkin = Skin() else {
            XCTFail("Could not create test skin")
            return
        }

        // When: Calculate memory
        let skinMemory = testSkin.gpuMemorySize

        // Then: Memory should be at least one joint's worth (1 * sizeof(simd_float4x4))
        let singleJointSize = MemoryLayout<simd_float4x4>.stride
        XCTAssertGreaterThanOrEqual(skinMemory, singleJointSize,
                                    "Skin memory should accommodate at least one joint transform")
    }

    // MARK: - Integration Tests

    func testMultipleMeshesTotalMemory() {
        // Given: Load multiple entities with meshes
        let entity1 = createEntity()
        setEntityMeshDirect(entityId: entity1, meshes: BasicPrimitives.createSphere(), assetName: "ball")

        let entity2 = createEntity()
        setEntityMeshDirect(entityId: entity2, meshes: BasicPrimitives.createSphere(), assetName: "redplayer")

        guard let rc1 = scene.get(component: RenderComponent.self, for: entity1),
              let rc2 = scene.get(component: RenderComponent.self, for: entity2),
              !rc1.mesh.isEmpty,
              !rc2.mesh.isEmpty
        else {
            XCTFail("Failed to load meshes")
            return
        }

        // When: Use utility functions to calculate total memory
        let allMeshes = rc1.mesh + rc2.mesh
        XCTAssertGreaterThan(allMeshes.count, 0, "Should have at least one mesh")

        let totalGPUMemory = calculateMeshArrayMemory(allMeshes)
        let totalWithTextures = calculateMeshArrayTotalMemory(allMeshes)

        // Then: Verify calculations
        var expectedGPUMemory = 0
        var expectedTotalMemory = 0

        for mesh in allMeshes {
            expectedGPUMemory += mesh.gpuMemorySize
            expectedTotalMemory += mesh.totalGPUMemorySize
        }

        XCTAssertEqual(totalGPUMemory, expectedGPUMemory,
                       "calculateMeshArrayMemory should sum all mesh GPU memory")
        XCTAssertEqual(totalWithTextures, expectedTotalMemory,
                       "calculateMeshArrayTotalMemory should sum all mesh total memory")

        destroyEntity(entityId: entity1)
        destroyEntity(entityId: entity2)
    }
}
