import Foundation
import MetalKit
import ModelIO
import simd
import UntoldComponentKit
import UntoldEngine

// A kind of entity with geometry AND an editor representation.
//
// A spline path is a cubic Bézier curve. In the game it is a thin tube, and things can travel
// along it. In the editor it is the same tube plus what you need to shape it: the four control
// points and the lines between them. Those are drawn only while editing, are never saved, and
// do not exist in the game. Both come from the same four properties, so moving a control
// point in the Inspector moves the dot and reshapes the tube together.
//
// PathFollower, below, is the other half of the picture: a component. It has nothing to do
// with splines in particular (any entity can follow a path), so it is attachable to any
// entity, and it reaches the spline through the entity plugin API.

/// The "Spline Path" row on the editor's Entities shelf, and every path made from it.
public final class SplinePathEntity: EntityPlugin {
    @UntoldAttribute("Start") public var start: SIMD3<Float> = [-1.5, 0, 0]
    @UntoldAttribute("Start Handle") public var startHandle: SIMD3<Float> = [-0.5, 1, 1]
    @UntoldAttribute("End Handle") public var endHandle: SIMD3<Float> = [0.5, 1, -1]
    @UntoldAttribute("End") public var end: SIMD3<Float> = [1.5, 0, 0]
    @UntoldAttribute("Thickness", range: 0.005 ... 0.5, step: 0.005) public var thickness: Float = 0.03
    @UntoldAttribute("Segments", range: 4 ... 128) public var segments: Int = 48

    override public class var systemImage: String {
        "point.topleft.down.to.point.bottomright.curvepath"
    }

    // MARK: Geometry: in the editor and in the game

    override public func onAttach() {
        rebuild()
    }

    override public func onEditorChanged(property _: String) {
        rebuild()
    }

    public func rebuild() {
        guard let device = renderInfo.device else { return }
        let mesh = SplineGeometry.makeTube(
            along: { self.position(at: $0) },
            tangent: { self.tangent(at: $0) },
            radius: thickness,
            segments: segments,
            allocator: MTKMeshBufferAllocator(device: device)
        )
        setGeneratedMesh(BasicPrimitives.createMesh(from: mesh), name: "SplinePath")
    }

    // MARK: Editor representation: in the editor only

    /// The control polygon, the two ends in one color and the two handles in another. The
    /// editor asks every frame while editing, so it always matches the properties above.
    override public var editorRepresentation: EditorRepresentation {
        EditorRepresentation([
            .polyline([start, startHandle, endHandle, end], closed: false),
            .points([start, end], tint: SIMD3<Float>(1.0, 0.75, 0.2)),
            .points([startHandle, endHandle], tint: SIMD3<Float>(0.35, 0.8, 1.0)),
        ])
    }

    // MARK: The curve: what a game asks for

    /// A point of the curve in the entity's local space, `t` from 0 to 1.
    public func position(at t: Float) -> SIMD3<Float> {
        let u = 1 - t
        return u * u * u * start + 3 * u * u * t * startHandle + 3 * u * t * t * endHandle + t * t * t * end
    }

    /// The direction of travel at `t`, in local space.
    public func tangent(at t: Float) -> SIMD3<Float> {
        let u = 1 - t
        let derivative = 3 * u * u * (startHandle - start) + 6 * u * t * (endHandle - startHandle) + 3 * t * t * (end - endHandle)
        let length = simd_length(derivative)
        return length > 1e-6 ? derivative / length : simd_normalize(end - start + SIMD3<Float>(1e-6, 0, 0))
    }

    /// A point of the curve in world space, wherever the path entity has been moved to.
    public func worldPosition(at t: Float) -> SIMD3<Float> {
        let local = position(at: t)
        var space = transform?.space ?? matrix_identity_float4x4
        if hasComponent(entityId: entity, componentType: WorldTransformComponent.self),
           let world = scene.get(component: WorldTransformComponent.self, for: entity)
        {
            space = world.space
        }
        let result = space * SIMD4<Float>(local.x, local.y, local.z, 1)
        return SIMD3<Float>(result.x, result.y, result.z)
    }
}

/// Moves its entity along a spline path while the scene plays.
///
/// A component, not part of the spline: any entity can have it, so the editor lists it under
/// Add Component. Point `path` at a Spline Path entity by name.
public final class PathFollower: ComponentPlugin {
    @UntoldAttribute public var path = EntityRef()
    @UntoldAttribute("Seconds Per Trip", range: 0.5 ... 60, step: 0.5) public var secondsPerTrip: Float = 4
    @UntoldAttribute public var backAndForth = true

    private var elapsed: Float = 0

    override public func onStart() {
        elapsed = 0
    }

    override public func onUpdate(deltaTime: Float) {
        guard let pathEntity = path.resolve(),
              let spline = EntityPluginRegistry.plugin(SplinePathEntity.self, on: pathEntity)
        else { return }

        elapsed += deltaTime
        var phase = elapsed / max(secondsPerTrip, 0.01)
        if backAndForth {
            phase = phase.truncatingRemainder(dividingBy: 2)
            phase = phase > 1 ? 2 - phase : phase
        } else {
            phase = phase.truncatingRemainder(dividingBy: 1)
        }
        translateTo(entityId: entity, position: spline.worldPosition(at: phase))
    }
}

public enum SplineGeometry {
    /// A capped tube around a curve. The ring of vertices is carried along the curve without
    /// twisting (each frame is the previous one turned by the change in direction).
    public static func makeTube(
        along position: (Float) -> SIMD3<Float>,
        tangent: (Float) -> SIMD3<Float>,
        radius: Float,
        segments: Int,
        sides: Int = 12,
        allocator: MDLMeshBufferAllocator
    ) -> MDLMesh {
        let steps = max(segments, 2)
        let sides = max(sides, 3)

        var vertices: [GeneratedVertex] = []
        var indices: [UInt32] = []

        var forward = tangent(0)
        let reference: SIMD3<Float> = abs(forward.y) < 0.95 ? [0, 1, 0] : [1, 0, 0]
        var side = simd_normalize(simd_cross(forward, reference))
        var up = simd_cross(side, forward)

        func ring(center: SIMD3<Float>, around axis: SIMD3<Float>, up: SIMD3<Float>, u: Float, normal: SIMD3<Float>?) {
            let binormal = simd_cross(axis, up)
            for j in 0 ... sides {
                let angle = Float(j) / Float(sides) * 2 * .pi
                let outward = cos(angle) * up + sin(angle) * binormal
                vertices.append(GeneratedVertex(position: center + radius * outward, normal: normal ?? outward, uv: SIMD2<Float>(u, Float(j) / Float(sides))))
            }
        }

        for i in 0 ... steps {
            let t = Float(i) / Float(steps)
            let next = tangent(t)
            let axis = simd_cross(forward, next)
            if simd_length(axis) > 1e-6 {
                let angle = acos(min(max(simd_dot(forward, next), -1), 1))
                up = simd_quatf(angle: angle, axis: simd_normalize(axis)).act(up)
            }
            forward = next
            side = simd_cross(forward, up)
            up = simd_normalize(simd_cross(side, forward))
            ring(center: position(t), around: forward, up: up, u: t, normal: nil)
        }

        for i in 0 ..< steps {
            for j in 0 ..< sides {
                let a = UInt32(i * (sides + 1) + j)
                let b = UInt32((i + 1) * (sides + 1) + j)
                indices += [a, a + 1, b, b, a + 1, b + 1]
            }
        }

        // Caps: a flat fan at each end, facing away from the tube.
        for (t, facing, flipped) in [(Float(0), -tangent(0), true), (Float(1), tangent(1), false)] {
            let first = UInt32(vertices.count)
            let sourceRing = t == 0 ? 0 : steps * (sides + 1)
            for j in 0 ... sides {
                var vertex = vertices[sourceRing + j]
                vertex.normal = facing
                vertices.append(vertex)
            }
            let center = UInt32(vertices.count)
            vertices.append(GeneratedVertex(position: position(t), normal: facing, uv: SIMD2<Float>(t, 0.5)))
            for j in 0 ..< sides {
                let a = first + UInt32(j)
                indices += flipped ? [center, a + 1, a] : [center, a, a + 1]
            }
        }

        return GeneratedGeometry.makeMesh(named: "SplinePath", vertices: vertices, indices: indices, allocator: allocator)
    }
}
