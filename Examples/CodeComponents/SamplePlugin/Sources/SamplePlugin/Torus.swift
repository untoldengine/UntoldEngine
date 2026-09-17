import Foundation
import MetalKit
import ModelIO
import simd
import UntoldComponentKit
import UntoldEngine

// A kind of entity with a shape of its own, in the editor and in the game.
//
// The engine ships no torus, so the plugin brings one. Three pieces, and only the first is
// specific to a torus:
//
//   TorusGeometry  builds the vertices and hands them to ModelIO.
//   TorusShape     is the component. It owns the numbers that define the ring, and turns them
//                  into the entity's mesh whenever it is attached or one of them changes.
//   TorusEntity    is the template: the "Torus" row on the editor's Primitives shelf.
//
// The scene file stores TorusShape's attributes, not the geometry. When the scene is loaded,
// in the editor or in the game, the component is attached again and rebuilds the ring.

/// The "Torus" row on the Primitives shelf. Runs once, when the entity is created.
public final class TorusEntity: EntityTemplate {
    override public class var shelf: UntoldEntityShelf {
        .primitives
    }

    override public class var systemImage: String {
        "circle.circle"
    }

    override public func build(_ entity: EntityID) {
        add(TorusShape.self, to: entity)
    }
}

/// Gives its entity the shape of a ring.
public final class TorusShape: CodeComponent {
    @UntoldAttribute("Ring Radius", range: 0.1 ... 5, step: 0.05) public var ringRadius: Float = 0.5
    @UntoldAttribute("Tube Radius", range: 0.02 ... 2, step: 0.01) public var tubeRadius: Float = 0.18
    @UntoldAttribute("Ring Segments", range: 3 ... 128) public var ringSegments: Int = 48
    @UntoldAttribute("Tube Segments", range: 3 ... 64) public var tubeSegments: Int = 20

    override public func onAttach() {
        rebuild()
    }

    /// The editor calls this after it changes one of the attributes above.
    override public func onEditorChanged(property _: String) {
        rebuild()
    }

    public func rebuild() {
        // No renderer, no mesh: a command-line tool or a unit test can still carry the component.
        guard let device = renderInfo.device else { return }
        let mesh = TorusGeometry.makeMesh(
            ringRadius: ringRadius,
            tubeRadius: tubeRadius,
            ringSegments: ringSegments,
            tubeSegments: tubeSegments,
            allocator: MTKMeshBufferAllocator(device: device)
        )
        setGeneratedMesh(BasicPrimitives.createMesh(from: mesh), name: "Torus")
    }
}

public enum TorusGeometry {
    /// One vertex as ModelIO reads it: position, normal, texture coordinate.
    struct Vertex {
        var position: (Float, Float, Float)
        var normal: (Float, Float, Float)
        var uv: (Float, Float)
    }

    /// A ring in the XZ plane, centred on the origin. `allocator` must come from the renderer's
    /// device, so the engine can use the buffers as they are.
    public static func makeMesh(
        ringRadius: Float,
        tubeRadius: Float,
        ringSegments: Int,
        tubeSegments: Int,
        allocator: MDLMeshBufferAllocator
    ) -> MDLMesh {
        let ring = max(ringSegments, 3)
        let tube = max(tubeSegments, 3)

        // The seam vertices are doubled so the texture coordinates can run from 0 to 1.
        var vertices: [Vertex] = []
        vertices.reserveCapacity((ring + 1) * (tube + 1))
        for i in 0 ... ring {
            let u = Float(i) / Float(ring)
            let around = u * 2 * .pi
            for j in 0 ... tube {
                let v = Float(j) / Float(tube)
                let across = v * 2 * .pi
                let distance = ringRadius + tubeRadius * cos(across)
                vertices.append(Vertex(
                    position: (distance * cos(around), tubeRadius * sin(across), distance * sin(around)),
                    normal: (cos(across) * cos(around), sin(across), cos(across) * sin(around)),
                    uv: (u, v)
                ))
            }
        }

        // Two triangles per patch, counter-clockwise seen from outside.
        var indices: [UInt32] = []
        indices.reserveCapacity(ring * tube * 6)
        for i in 0 ..< ring {
            for j in 0 ..< tube {
                let a = UInt32(i * (tube + 1) + j)
                let b = UInt32((i + 1) * (tube + 1) + j)
                let c = b + 1
                let d = a + 1
                indices += [a, d, b, b, d, c]
            }
        }

        let vertexBuffer = vertices.withUnsafeBytes { allocator.newBuffer(with: Data($0), type: .vertex) }
        let indexBuffer = indices.withUnsafeBytes { allocator.newBuffer(with: Data($0), type: .index) }

        let material = MDLMaterial(name: "Torus", scatteringFunction: MDLPhysicallyPlausibleScatteringFunction())
        let submesh = MDLSubmesh(
            indexBuffer: indexBuffer,
            indexCount: indices.count,
            indexType: .uInt32,
            geometryType: .triangles,
            material: material
        )

        let stride = MemoryLayout<Vertex>.stride
        let descriptor = MDLVertexDescriptor()
        descriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition, format: .float3, offset: 0, bufferIndex: 0)
        descriptor.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal, format: .float3, offset: 12, bufferIndex: 0)
        descriptor.attributes[2] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate, format: .float2, offset: 24, bufferIndex: 0)
        descriptor.layouts[0] = MDLVertexBufferLayout(stride: stride)

        let mesh = MDLMesh(vertexBuffer: vertexBuffer, vertexCount: vertices.count, descriptor: descriptor, submeshes: [submesh])
        mesh.name = "Torus"
        return mesh
    }
}
