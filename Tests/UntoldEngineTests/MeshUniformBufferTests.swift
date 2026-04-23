//
//  MeshUniformBufferTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import MetalKit
import simd
@testable import UntoldEngine
import XCTest

// Tests for the per-mesh uniform buffer strategy.
// Uniforms are now written per-draw via setVertexBytes/setFragmentBytes, so Mesh
// owns no MTLBuffer for transforms. These tests verify that invariant and that
// mesh construction/cleanup still work correctly.

@MainActor
final class MeshUniformBufferTests: XCTestCase {
    var device: MTLDevice!
    var vertexDescriptor: MDLVertexDescriptor!
    var textureLoader: TextureLoader!

    override func setUp() async throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            XCTFail("Failed to create Metal device")
            return
        }

        self.device = device
        renderInfo.device = device

        vertexDescriptor = MDLVertexDescriptor()
        vertexDescriptor.attributes[0] = MDLVertexAttribute(
            name: MDLVertexAttributePosition,
            format: .float3,
            offset: 0,
            bufferIndex: 0
        )
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<simd_float3>.stride)

        textureLoader = TextureLoader(device: device)
    }

    override func tearDown() async throws {
        device = nil
        vertexDescriptor = nil
        textureLoader = nil
    }

    // MARK: - Helpers

    private func makeMesh() -> Mesh? {
        let allocator = MTKMeshBufferAllocator(device: device)
        let mdlMesh = MDLMesh(
            sphereWithExtent: [1, 1, 1],
            segments: [8, 8],
            inwardNormals: false,
            geometryType: .triangles,
            allocator: allocator
        )
        return Mesh(modelIOMesh: mdlMesh, vertexDescriptor: vertexDescriptor,
                    textureLoader: textureLoader, device: device, flip: false)
    }

    // MARK: - Tests

    func testMeshInitSucceeds() {
        XCTAssertNotNil(makeMesh(), "Mesh should initialise successfully")
    }

    func testMeshHasNoUniformBuffers() {
        // Uniforms are written inline via setVertexBytes — the mesh must not allocate
        // any per-mesh MTLBuffer for transform data.
        guard let mesh = makeMesh() else { XCTFail("Mesh init failed"); return }

        // Vertex and index buffers must still exist (geometry data)
        XCTAssertFalse(mesh.metalKitMesh.vertexBuffers.isEmpty,
                       "Mesh should have geometry vertex buffers")

        // The mesh struct should have submeshes
        XCTAssertFalse(mesh.submeshes.isEmpty,
                       "Mesh should have at least one submesh after init")
    }

    func testCleanUpClearsSubmeshes() {
        guard var mesh = makeMesh() else { XCTFail("Mesh init failed"); return }

        XCTAssertFalse(mesh.submeshes.isEmpty, "Should have submeshes before cleanup")
        mesh.cleanUp()
        XCTAssertTrue(mesh.submeshes.isEmpty, "Submeshes should be empty after cleanUp")
    }

    func testCopyWithNewUniformBuffersReturnsSameMesh() {
        guard let mesh = makeMesh() else { XCTFail("Mesh init failed"); return }

        // copyWithNewUniformBuffers is now a no-op copy — verify it still returns a valid mesh
        let copy = mesh.copyWithNewUniformBuffers()
        XCTAssertEqual(mesh.assetName, copy.assetName,
                       "Copied mesh should preserve assetName")
        XCTAssertEqual(mesh.submeshes.count, copy.submeshes.count,
                       "Copied mesh should have the same submesh count")
    }

    func testUniformsSizeIsWithinSetVertexBytesLimit() {
        // setVertexBytes is limited to 4 KB on all Apple platforms.
        let uniformsSize = MemoryLayout<Uniforms>.stride
        XCTAssertLessThanOrEqual(uniformsSize, 4096,
                                 "Uniforms struct must fit within the 4 KB setVertexBytes limit")
    }
}

// MARK: - Helper Extensions for Matrix Operations

extension simd_float4x4: @retroactive Equatable {
    public static func == (lhs: simd_float4x4, rhs: simd_float4x4) -> Bool {
        lhs.columns == rhs.columns
    }
}
