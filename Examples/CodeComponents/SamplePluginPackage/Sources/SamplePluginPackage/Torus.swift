import Foundation
import MetalKit
import ModelIO
import simd
import UntoldComponentKit
import UntoldEngine

// A kind of entity whose geometry is all there is to it, in the editor and in the game.
//
// The engine ships no torus, so this plugin package brings one. The ring's numbers are the entity's own
// properties: they show in the Inspector as the Torus block, above whatever components the
// entity carries. There is no "torus shape" component, because a ring's shape can only ever
// belong to a torus. What is part of an entity goes on its EntityPlugin; a ComponentPlugin is
// for what any entity could have.
//
// The scene file stores these properties, not the geometry. When the scene is loaded, in the
// editor or in the game, the entity plugin is bound to the entity again and rebuilds the ring.

/// The "Torus" row on the editor's Primitives shelf, and every torus made from it.
public final class TorusEntity: EntityPlugin {
    @UntoldAttribute("Ring Radius", range: 0.1 ... 5, step: 0.05) public var ringRadius: Float = 0.5
    @UntoldAttribute("Tube Radius", range: 0.02 ... 2, step: 0.01) public var tubeRadius: Float = 0.18
    @UntoldAttribute("Ring Segments", range: 3 ... 128) public var ringSegments: Int = 48
    @UntoldAttribute("Tube Segments", range: 3 ... 64) public var tubeSegments: Int = 20

    override public class var shelf: UntoldEntityShelf {
        .primitives
    }

    override public class var systemImage: String {
        "circle.circle"
    }

    override public func onAttach() {
        rebuild()
    }

    /// The editor calls this after it changes one of the properties above.
    override public func onEditorChanged(property _: String) {
        rebuild()
    }

    public func rebuild() {
        // No renderer, no mesh: a command-line tool or a unit test can still have the entity.
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
        var vertices: [GeneratedVertex] = []
        vertices.reserveCapacity((ring + 1) * (tube + 1))
        for i in 0 ... ring {
            let u = Float(i) / Float(ring)
            let around = u * 2 * .pi
            for j in 0 ... tube {
                let v = Float(j) / Float(tube)
                let across = v * 2 * .pi
                let distance = ringRadius + tubeRadius * cos(across)
                vertices.append(GeneratedVertex(
                    position: SIMD3<Float>(distance * cos(around), tubeRadius * sin(across), distance * sin(around)),
                    normal: SIMD3<Float>(cos(across) * cos(around), sin(across), cos(across) * sin(around)),
                    uv: SIMD2<Float>(u, v)
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
                indices += [a, a + 1, b, b, a + 1, b + 1]
            }
        }
        return GeneratedGeometry.makeMesh(named: "Torus", vertices: vertices, indices: indices, allocator: allocator)
    }
}
