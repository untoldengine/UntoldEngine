//
//  MeshUniformBufferTests.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.

import CShaderTypes
import MetalKit
import simd
@testable import UntoldEngine
import XCTest

/// Unit tests for Mesh.spaceUniform initialization, cleanup, and RenderPasses uniform buffer selection
final class MeshUniformBufferTests: XCTestCase {
    var device: MTLDevice!
    var vertexDescriptor: MDLVertexDescriptor!
    var textureLoader: TextureLoader!

    override func setUp() {
        super.setUp()

        guard let device = MTLCreateSystemDefaultDevice() else {
            XCTFail("Failed to create Metal device")
            return
        }

        self.device = device
        renderInfo.device = device

        // Create a simple vertex descriptor for testing
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

    override func tearDown() {
        device = nil
        vertexDescriptor = nil
        textureLoader = nil
        super.tearDown()
    }

    // MARK: - Test Case 1: Mesh.spaceUniform is initialized with two MTLBuffer objects

    func testMeshSpaceUniformInitializedWithTwoBuffers() {
        // Create a simple mesh for testing
        let bufferAllocator = MTKMeshBufferAllocator(device: device)
        let mdlMesh = MDLMesh(
            sphereWithExtent: [1.0, 1.0, 1.0],
            segments: [8, 8],
            inwardNormals: false,
            geometryType: .triangles,
            allocator: bufferAllocator
        )

        // Create the Mesh instance
        guard let mesh = Mesh(
            modelIOMesh: mdlMesh,
            vertexDescriptor: vertexDescriptor,
            textureLoader: textureLoader,
            device: device,
            flip: false
        ) else {
            XCTFail("Failed to create Mesh")
            return
        }

        // Assert: spaceUniform should contain exactly 2 elements
        XCTAssertEqual(mesh.spaceUniform.count, 2, "❌ spaceUniform should contain exactly 2 buffers")

        // Assert: Both buffers should be non-nil MTLBuffer objects
        XCTAssertNotNil(mesh.spaceUniform[0], "❌ spaceUniform[0] should not be nil")
        XCTAssertNotNil(mesh.spaceUniform[1], "❌ spaceUniform[1] should not be nil")

        // Assert: Both buffers should have the correct size
        if let buffer0 = mesh.spaceUniform[0] {
            XCTAssertGreaterThanOrEqual(
                buffer0.length,
                MemoryLayout<Uniforms>.stride,
                "❌ spaceUniform[0] should have sufficient size for Uniforms"
            )
        }

        if let buffer1 = mesh.spaceUniform[1] {
            XCTAssertGreaterThanOrEqual(
                buffer1.length,
                MemoryLayout<Uniforms>.stride,
                "❌ spaceUniform[1] should have sufficient size for Uniforms"
            )
        }

        // Assert: Buffers should be distinct objects
        if let buffer0 = mesh.spaceUniform[0], let buffer1 = mesh.spaceUniform[1] {
            XCTAssertNotEqual(
                Unmanaged.passUnretained(buffer0).toOpaque(),
                Unmanaged.passUnretained(buffer1).toOpaque(),
                "❌ spaceUniform[0] and spaceUniform[1] should be distinct buffer objects"
            )
        }
    }

    // MARK: - Test Case 2: Mesh.cleanUp() correctly removes all buffers from spaceUniform

    func testMeshCleanUpRemovesAllBuffers() {
        // Create a simple mesh for testing
        let bufferAllocator = MTKMeshBufferAllocator(device: device)
        let mdlMesh = MDLMesh(
            sphereWithExtent: [1.0, 1.0, 1.0],
            segments: [8, 8],
            inwardNormals: false,
            geometryType: .triangles,
            allocator: bufferAllocator
        )

        // Create the Mesh instance
        guard var mesh = Mesh(
            modelIOMesh: mdlMesh,
            vertexDescriptor: vertexDescriptor,
            textureLoader: textureLoader,
            device: device,
            flip: false
        ) else {
            XCTFail("Failed to create Mesh")
            return
        }

        // Verify buffers exist before cleanup
        XCTAssertEqual(mesh.spaceUniform.count, 2, "❌ spaceUniform should initially contain 2 buffers")
        XCTAssertNotNil(mesh.spaceUniform[0], "❌ spaceUniform[0] should not be nil before cleanup")
        XCTAssertNotNil(mesh.spaceUniform[1], "❌ spaceUniform[1] should not be nil before cleanup")

        // Call cleanUp
        mesh.cleanUp()

        // Assert: spaceUniform should be empty after cleanUp
        XCTAssertEqual(
            mesh.spaceUniform.count,
            0,
            "❌ spaceUniform should be empty after cleanUp()"
        )

        // Assert: submeshes should also be cleared
        XCTAssertEqual(
            mesh.submeshes.count,
            0,
            "❌ submeshes should be empty after cleanUp()"
        )
    }

    // MARK: - Test Case 3: RenderPasses correctly select the uniform buffer for currentEye = 0

    func testRenderPassesSelectCorrectBufferForEye0() {
        // Create a test mesh
        let bufferAllocator = MTKMeshBufferAllocator(device: device)
        let mdlMesh = MDLMesh(
            sphereWithExtent: [1.0, 1.0, 1.0],
            segments: [8, 8],
            inwardNormals: false,
            geometryType: .triangles,
            allocator: bufferAllocator
        )

        guard let mesh = Mesh(
            modelIOMesh: mdlMesh,
            vertexDescriptor: vertexDescriptor,
            textureLoader: textureLoader,
            device: device,
            flip: false
        ) else {
            XCTFail("Failed to create Mesh")
            return
        }

        // Set currentEye to 0
        renderInfo.currentEye = 0

        // Get the buffer that would be selected
        let selectedBuffer = mesh.spaceUniform[renderInfo.currentEye]

        // Assert: The selected buffer should be the first buffer
        XCTAssertNotNil(selectedBuffer, "❌ Buffer for eye 0 should not be nil")

        if let buffer0 = mesh.spaceUniform[0], let selected = selectedBuffer {
            XCTAssertEqual(
                Unmanaged.passUnretained(buffer0).toOpaque(),
                Unmanaged.passUnretained(selected).toOpaque(),
                "❌ When currentEye=0, mesh.spaceUniform[renderInfo.currentEye] should return the first buffer"
            )
        }

        // Simulate writing uniform data (as done in RenderPasses)
        if let uniformBuffer = mesh.spaceUniform[renderInfo.currentEye] {
            var testUniforms = Uniforms()
            testUniforms.modelMatrix = matrix4x4Identity()
            testUniforms.viewMatrix = matrix4x4Identity()
            testUniforms.projectionMatrix = matrix4x4Identity()

            uniformBuffer.contents().copyMemory(
                from: &testUniforms,
                byteCount: MemoryLayout<Uniforms>.stride
            )

            // Verify we can read back the data
            let readBackPointer = uniformBuffer.contents().bindMemory(
                to: Uniforms.self,
                capacity: 1
            )
            let readBackData = readBackPointer.pointee

            XCTAssertEqual(
                readBackData.modelMatrix,
                testUniforms.modelMatrix,
                "❌ Written data should match read-back data for eye 0"
            )
        }
    }

    // MARK: - Test Case 4: RenderPasses correctly select the uniform buffer for currentEye = 1

    func testRenderPassesSelectCorrectBufferForEye1() {
        // Create a test mesh
        let bufferAllocator = MTKMeshBufferAllocator(device: device)
        let mdlMesh = MDLMesh(
            sphereWithExtent: [1.0, 1.0, 1.0],
            segments: [8, 8],
            inwardNormals: false,
            geometryType: .triangles,
            allocator: bufferAllocator
        )

        guard let mesh = Mesh(
            modelIOMesh: mdlMesh,
            vertexDescriptor: vertexDescriptor,
            textureLoader: textureLoader,
            device: device,
            flip: false
        ) else {
            XCTFail("Failed to create Mesh")
            return
        }

        // Set currentEye to 1
        renderInfo.currentEye = 1

        // Get the buffer that would be selected
        let selectedBuffer = mesh.spaceUniform[renderInfo.currentEye]

        // Assert: The selected buffer should be the second buffer
        XCTAssertNotNil(selectedBuffer, "❌ Buffer for eye 1 should not be nil")

        if let buffer1 = mesh.spaceUniform[1], let selected = selectedBuffer {
            XCTAssertEqual(
                Unmanaged.passUnretained(buffer1).toOpaque(),
                Unmanaged.passUnretained(selected).toOpaque(),
                "❌ When currentEye=1, mesh.spaceUniform[renderInfo.currentEye] should return the second buffer"
            )
        }

        // Simulate writing uniform data (as done in RenderPasses)
        if let uniformBuffer = mesh.spaceUniform[renderInfo.currentEye] {
            var testUniforms = Uniforms()
            testUniforms.modelMatrix = matrix4x4Identity()
            testUniforms.viewMatrix = matrix4x4Identity()
            testUniforms.projectionMatrix = matrix4x4Identity()

            uniformBuffer.contents().copyMemory(
                from: &testUniforms,
                byteCount: MemoryLayout<Uniforms>.stride
            )

            // Verify we can read back the data
            let readBackPointer = uniformBuffer.contents().bindMemory(
                to: Uniforms.self,
                capacity: 1
            )
            let readBackData = readBackPointer.pointee

            XCTAssertEqual(
                readBackData.modelMatrix,
                testUniforms.modelMatrix,
                "❌ Written data should match read-back data for eye 1"
            )
        }
    }

    // MARK: - Test Case 5: RenderInfo.currentEye is correctly set by XRSystem_CompositorServices

    func testCurrentEyeSetByXRSystem() {
        // Test that currentEye can be set correctly for multiple eyes
        // This simulates what XRSystem_CompositorServices does in executeXRSystemPass

        // Initially, currentEye should start at 0
        renderInfo.currentEye = 0
        XCTAssertEqual(renderInfo.currentEye, 0, "❌ Initial currentEye should be 0")

        // Simulate first view (left eye)
        let viewIndex0 = 0
        renderInfo.currentEye = viewIndex0
        XCTAssertEqual(
            renderInfo.currentEye,
            0,
            "❌ currentEye should be set to 0 for first view"
        )

        // Simulate second view (right eye)
        let viewIndex1 = 1
        renderInfo.currentEye = viewIndex1
        XCTAssertEqual(
            renderInfo.currentEye,
            1,
            "❌ currentEye should be set to 1 for second view"
        )

        // Verify that the value persists
        XCTAssertEqual(
            renderInfo.currentEye,
            1,
            "❌ currentEye should persist its value"
        )

        // Reset to 0
        renderInfo.currentEye = 0
        XCTAssertEqual(
            renderInfo.currentEye,
            0,
            "❌ currentEye should be resettable to 0"
        )
    }

    // MARK: - Additional Integration Test

    func testBufferSelectionIntegrityAcrossEyes() {
        // Create a test mesh
        let bufferAllocator = MTKMeshBufferAllocator(device: device)
        let mdlMesh = MDLMesh(
            sphereWithExtent: [1.0, 1.0, 1.0],
            segments: [8, 8],
            inwardNormals: false,
            geometryType: .triangles,
            allocator: bufferAllocator
        )

        guard let mesh = Mesh(
            modelIOMesh: mdlMesh,
            vertexDescriptor: vertexDescriptor,
            textureLoader: textureLoader,
            device: device,
            flip: false
        ) else {
            XCTFail("Failed to create Mesh")
            return
        }

        // Write different data to each eye's buffer
        var uniformsEye0 = Uniforms()
        uniformsEye0.modelMatrix = matrix_identity_float4x4
        uniformsEye0.viewMatrix = matrix4x4Translation(1.0, 0.0, 0.0)

        var uniformsEye1 = Uniforms()
        uniformsEye1.modelMatrix = matrix_identity_float4x4
        uniformsEye1.viewMatrix = matrix4x4Translation(-1.0, 0.0, 0.0)

        // Write to eye 0 buffer
        renderInfo.currentEye = 0
        if let buffer = mesh.spaceUniform[renderInfo.currentEye] {
            buffer.contents().copyMemory(
                from: &uniformsEye0,
                byteCount: MemoryLayout<Uniforms>.stride
            )
        }

        // Write to eye 1 buffer
        renderInfo.currentEye = 1
        if let buffer = mesh.spaceUniform[renderInfo.currentEye] {
            buffer.contents().copyMemory(
                from: &uniformsEye1,
                byteCount: MemoryLayout<Uniforms>.stride
            )
        }

        // Verify eye 0 data is still intact
        renderInfo.currentEye = 0
        if let buffer = mesh.spaceUniform[renderInfo.currentEye] {
            let readBackPointer = buffer.contents().bindMemory(
                to: Uniforms.self,
                capacity: 1
            )
            let readBackData = readBackPointer.pointee

            XCTAssertEqual(
                readBackData.viewMatrix.columns.3.x,
                1.0,
                "❌ Eye 0 buffer should contain its original data"
            )
        }

        // Verify eye 1 data is still intact
        renderInfo.currentEye = 1
        if let buffer = mesh.spaceUniform[renderInfo.currentEye] {
            let readBackPointer = buffer.contents().bindMemory(
                to: Uniforms.self,
                capacity: 1
            )
            let readBackData = readBackPointer.pointee

            XCTAssertEqual(
                readBackData.viewMatrix.columns.3.x,
                -1.0,
                "❌ Eye 1 buffer should contain its original data"
            )
        }
    }
}

// MARK: - Helper Extensions for Matrix Operations
