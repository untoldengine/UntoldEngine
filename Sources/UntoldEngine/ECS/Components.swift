
//
//  Components.swift
//  ECSinSwift
//
//  Created by Harold Serrano on 1/14/24.
//

import Foundation
import Metal
import MetalKit
import simd

public class LocalTransformComponent: Component {
    var position: simd_float3 = .zero
    var rotation: simd_quatf = .init()
    var scale: simd_float3 = .one

    var space: simd_float4x4 = .identity

    var boundingBox: (min: simd_float3, max: simd_float3) = (min: simd_float3(-1.0, -1.0, -1.0), max: simd_float3(1.0, 1.0, 1.0))

    var flipCoord: Bool = false

    var rotationX: Float = 0
    var rotationY: Float = 0
    var rotationZ: Float = 0

    public required init() {}
}

public class WorldTransformComponent: Component {
    var space: simd_float4x4 = .identity

    public required init() {}
}

public class RenderComponent: Component {
    var mesh: [Mesh]
    var assetURL: URL = .init(fileURLWithPath: "")
    var assetName: String = ""

    public required init() {
        mesh = []
    }

    func cleanUp() {
        for index in 0 ..< mesh.count {
            mesh[index].cleanUp()
        }

        mesh.removeAll()
    }

    deinit {
        cleanUp()
    }
}

public class PhysicsComponents: Component {
    var mass: Float = 1.0
    var centerOfMass: simd_float3 = .zero
    var velocity: simd_float3 = .zero
    var angularVelocity: simd_float3 = .zero
    var acceleration: simd_float3 = .zero
    var angularAcceleration: simd_float3 = .zero
    var inertiaTensorType: InertiaTensorType = .spherical
    var momentOfInertiaTensor: simd_float3x3 = .init(diagonal: simd_float3(1.0, 1.0, 1.0))
    var inverseMomentOfInertiaTensor: simd_float3x3 = .init(diagonal: simd_float3(1.0, 1.0, 1.0))
    var linearDragCoefficients: simd_float2 = .zero
    var angularDragCoefficients: simd_float2 = .zero
    var pause: Bool = false
    var inertiaTensorComputed: Bool = false

    public required init() {}
}

public class KineticComponent: Component {
    var forces: [simd_float3] = []
    var moments: [simd_float3] = []

    var gravityScale: Float = 0.0

    public required init() {}

    public func addForce(_ force: simd_float3) {
        forces.append(force)
    }

    public func clearForces() {
        forces.removeAll()
    }

    public func addMoment(_ moment: simd_float3) {
        moments.append(moment)
    }

    public func clearMoments() {
        moments.removeAll()
    }
}

public class SkeletonComponent: Component {
    var skeleton: Skeleton!

    public required init() {}

    func cleanUp() {
        skeleton = nil
    }
}

public class AnimationComponent: Component {
    var animationClips: [String: AnimationClip] = [:]
    var currentAnimation: AnimationClip?
    var animationsFilenames: [URL] = []
    var pause: Bool = false
    var currentTime: Float = 0.0
    public required init() {}

    func cleanUp() {
        animationClips.removeAll()
        currentAnimation?.cleanUp()
        currentAnimation = nil
    }

    func getAllAnimationClips() -> [String] {
        Array(animationClips.keys)
    }

    func removeAnimationClip(animationClip: String) {
        animationClips.removeValue(forKey: animationClip)
    }
}

public enum LightType: String, CaseIterable {
    case directional
    case point
    case area
    case spotlight
}

public class LightTexture {
    var directional: MTLTexture?
    var point: MTLTexture?
    var spot: MTLTexture?
    var area: MTLTexture?
}

public class LightComponent: Component {
    var texture: LightTexture = .init()
    var lightType: LightType?

    var color: simd_float3 = .one
    var intensity: Float = 1.0

    public required init() {}
}

public class DirectionalLightComponent: Component {
    public required init() {}
}

public class PointLightComponent: Component {
    var attenuation: simd_float4 = .init(1.0, 0.7, 1.8, 0.0) // (constant, linear, quadratic)->x,y,z
    var radius: Float = 1.0
    var falloff: Float = 0.5

    public required init() {}
}

public class SpotLightComponent: Component {
    var attenuation: simd_float4 = .init(1.0, 0.7, 1.8, 0.0)
    var radius: Float = 1.0
    var innerCone: Float = 5.0
    var outerCone: Float = 10.0
    var direction: simd_float3 = .init(0, -1, 0)
    var falloff: Float = 0.5
    var coneAngle: Float = 30.0

    public required init() {}
}

public class AreaLightComponent: Component {
    var bounds: simd_float2 = .init(1.0, 1.0)
    var forward: simd_float3 = .zero
    var right: simd_float3 = .zero
    var up: simd_float3 = .zero
    var twoSided: Bool = false

    public required init() {}
}

public class ScenegraphComponent: Component {
    var parent: EntityID = .invalid
    var level: Int = 0 // level 0 means no parent
    var children: [EntityID] = []

    public required init() {}
}

public class CameraComponent: Component {
    var fov: Float = 65.0
    var nearClip: Float = 0.1
    var farClip: Float = 1000.0

    public var viewSpace = simd_float4x4.init(1.0)
    public var xAxis: simd_float3 = .init(0.0, 0.0, 0.0)
    public var yAxis: simd_float3 = .init(0.0, 0.0, 0.0)
    public var zAxis: simd_float3 = .init(0.0, 0.0, 0.0)

    // quaternion
    var rotation: simd_quatf = .init()
    var localOrientation: simd_float3 = .init(0.0, 0.0, 0.0)
    public var localPosition: simd_float3 = .init(0.0, 0.0, 0.0)
    var orbitTarget: simd_float3 = .init(0.0, 0.0, 0.0)

    var eye: simd_float3 = .zero
    var up: simd_float3 = .zero
    var target: simd_float3 = .zero

    public required init() {}
}

public class SceneCameraComponent: Component {
    public required init() {}
}

public class GizmoComponent: Component {
    public required init() {}
}
