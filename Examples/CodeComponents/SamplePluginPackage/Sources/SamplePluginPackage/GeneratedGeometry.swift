import Foundation
import ModelIO
import simd

/// One vertex of a shape built in code: what ModelIO needs to make an engine mesh.
public struct GeneratedVertex {
    public var position: SIMD3<Float>
    public var normal: SIMD3<Float>
    public var uv: SIMD2<Float>

    public init(position: SIMD3<Float>, normal: SIMD3<Float>, uv: SIMD2<Float>) {
        self.position = position
        self.normal = normal
        self.uv = uv
    }
}

/// Shared by the package's shapes: packs vertices and indices into an `MDLMesh` that
/// `BasicPrimitives.createMesh(from:)` turns into engine meshes.
public enum GeneratedGeometry {
    public static func makeMesh(
        named name: String,
        vertices: [GeneratedVertex],
        indices: [UInt32],
        allocator: MDLMeshBufferAllocator
    ) -> MDLMesh {
        // Packed by hand: position, normal, texture coordinate, 32 bytes a vertex. A SIMD3 is
        // padded to 16 bytes in memory, so the struct above is not this layout.
        var packed: [Float] = []
        packed.reserveCapacity(vertices.count * 8)
        for vertex in vertices {
            packed += [vertex.position.x, vertex.position.y, vertex.position.z]
            packed += [vertex.normal.x, vertex.normal.y, vertex.normal.z]
            packed += [vertex.uv.x, vertex.uv.y]
        }

        let vertexBuffer = packed.withUnsafeBytes { allocator.newBuffer(with: Data($0), type: .vertex) }
        let indexBuffer = indices.withUnsafeBytes { allocator.newBuffer(with: Data($0), type: .index) }

        let material = MDLMaterial(name: name, scatteringFunction: MDLPhysicallyPlausibleScatteringFunction())
        let submesh = MDLSubmesh(
            indexBuffer: indexBuffer,
            indexCount: indices.count,
            indexType: .uInt32,
            geometryType: .triangles,
            material: material
        )

        let descriptor = MDLVertexDescriptor()
        descriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition, format: .float3, offset: 0, bufferIndex: 0)
        descriptor.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal, format: .float3, offset: 12, bufferIndex: 0)
        descriptor.attributes[2] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate, format: .float2, offset: 24, bufferIndex: 0)
        descriptor.layouts[0] = MDLVertexBufferLayout(stride: 32)

        let mesh = MDLMesh(vertexBuffer: vertexBuffer, vertexCount: vertices.count, descriptor: descriptor, submeshes: [submesh])
        mesh.name = name
        return mesh
    }
}
