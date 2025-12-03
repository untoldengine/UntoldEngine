//
//  BasicPrimitives.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import Foundation
import MetalKit
import simd

/// Generates basic primitive meshes using ModelIO
public enum BasicPrimitives {
    /// Creates a cube mesh with the specified size
    /// - Parameters:
    ///   - extent: The size of the cube in each dimension (default: 1.0)
    ///   - segments: Number of segments per dimension (default: 1)
    /// - Returns: Array of Mesh objects representing the cube
    public static func createCube(extent: Float = 0.5, segments: UInt32 = 1) -> [Mesh] {
        let bufferAllocator = MTKMeshBufferAllocator(device: renderInfo.device)
        let textureLoader = TextureLoader(device: renderInfo.device)

        let mdlMesh = MDLMesh(
            boxWithExtent: [extent, extent, extent],
            segments: [segments, segments, segments],
            inwardNormals: false,
            geometryType: .triangles,
            allocator: bufferAllocator
        )

        mdlMesh.name = "Cube"

        return Mesh.makeMeshes(
            object: mdlMesh,
            vertexDescriptor: vertexDescriptor.model,
            textureLoader: textureLoader,
            device: renderInfo.device,
            flip: true
        )
    }

    /// Creates a sphere mesh with the specified radius
    /// - Parameters:
    ///   - extent: The diameter of the sphere in each dimension (default: 1.0)
    ///   - segments: Horizontal and vertical segments [horizontal, vertical] (default: [32, 16])
    /// - Returns: Array of Mesh objects representing the sphere
    public static func createSphere(extent: Float = 0.25, segments: [UInt32] = [32, 16]) -> [Mesh] {
        let bufferAllocator = MTKMeshBufferAllocator(device: renderInfo.device)
        let textureLoader = TextureLoader(device: renderInfo.device)

        let mdlMesh = MDLMesh(
            sphereWithExtent: [extent, extent, extent],
            segments: [segments[0], segments[1]],
            inwardNormals: false,
            geometryType: .triangles,
            allocator: bufferAllocator
        )

        mdlMesh.name = "Sphere"

        return Mesh.makeMeshes(
            object: mdlMesh,
            vertexDescriptor: vertexDescriptor.model,
            textureLoader: textureLoader,
            device: renderInfo.device,
            flip: true
        )
    }

    /// Creates a plane mesh with the specified dimensions (laying flat in XZ plane)
    /// - Parameters:
    ///   - width: Width of the plane (default: 1.0)
    ///   - depth: Depth of the plane (default: 1.0)
    ///   - segments: Number of segments [width, depth] (default: [1, 1])
    /// - Returns: Array of Mesh objects representing the plane
    public static func createPlane(width: Float = 1.0, depth: Float = 1.0, segments: [UInt32] = [1, 1]) -> [Mesh] {
        let bufferAllocator = MTKMeshBufferAllocator(device: renderInfo.device)
        let textureLoader = TextureLoader(device: renderInfo.device)

        // MDLMesh.planeWithExtent creates plane in XY, so we swap Y and Z to get XZ (horizontal)
        let mdlMesh = MDLMesh(
            planeWithExtent: [width, 0, depth],
            segments: [segments[0], segments[1]],
            geometryType: .triangles,
            allocator: bufferAllocator
        )

        mdlMesh.name = "Plane"

        return Mesh.makeMeshes(
            object: mdlMesh,
            vertexDescriptor: vertexDescriptor.model,
            textureLoader: textureLoader,
            device: renderInfo.device,
            flip: true
        )
    }

    /// Creates a cylinder mesh with the specified dimensions
    /// - Parameters:
    ///   - height: Height of the cylinder (default: 1.0)
    ///   - radius: Radius of the cylinder (default: 0.5)
    ///   - segments: Radial and vertical segments [radial, vertical] (default: [32, 1])
    /// - Returns: Array of Mesh objects representing the cylinder
    public static func createCylinder(height: Float = 0.5, radius: Float = 0.125, segments: [UInt32] = [32, 1]) -> [Mesh] {
        let bufferAllocator = MTKMeshBufferAllocator(device: renderInfo.device)
        let textureLoader = TextureLoader(device: renderInfo.device)

        let mdlMesh = MDLMesh(
            cylinderWithExtent: [radius * 2, height, radius * 2],
            segments: [segments[0], segments[1]],
            inwardNormals: false,
            topCap: true,
            bottomCap: true,
            geometryType: .triangles,
            allocator: bufferAllocator
        )

        mdlMesh.name = "Cylinder"

        return Mesh.makeMeshes(
            object: mdlMesh,
            vertexDescriptor: vertexDescriptor.model,
            textureLoader: textureLoader,
            device: renderInfo.device,
            flip: true
        )
    }

    /// Creates a cone mesh with the specified dimensions
    /// - Parameters:
    ///   - height: Height of the cone (default: 1.0)
    ///   - radius: Base radius of the cone (default: 0.5)
    ///   - segments: Radial and vertical segments [radial, vertical] (default: [32, 1])
    /// - Returns: Array of Mesh objects representing the cone
    public static func createCone(height: Float = 0.5, radius: Float = 0.25, segments: [UInt32] = [32, 1]) -> [Mesh] {
        let bufferAllocator = MTKMeshBufferAllocator(device: renderInfo.device)
        let textureLoader = TextureLoader(device: renderInfo.device)

        let mdlMesh = MDLMesh(
            coneWithExtent: [radius * 2, height, radius * 2],
            segments: [segments[0], segments[1]],
            inwardNormals: false,
            cap: true,
            geometryType: .triangles,
            allocator: bufferAllocator
        )

        mdlMesh.name = "Cone"

        return Mesh.makeMeshes(
            object: mdlMesh,
            vertexDescriptor: vertexDescriptor.model,
            textureLoader: textureLoader,
            device: renderInfo.device,
            flip: true
        )
    }
}
