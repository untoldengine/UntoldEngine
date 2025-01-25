
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
    var space: simd_float4x4 = .identity

    var boundingBox: (min: simd_float3, max: simd_float3) = (min: simd_float3(-1.0, -1.0, -1.0), max: simd_float3(1.0, 1.0, 1.0))

    var flipCoord: Bool = false

    public required init() {}
}

public class WorldTransformComponent: Component {
    var space: simd_float4x4 = .identity

    public required init() {}
}

public class RenderComponent: Component {
    var mesh: [Mesh]

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
    var pause: Bool = false
    var currentTime: Float = 0.0
    public required init() {}

    func cleanUp() {
        animationClips.removeAll()
        currentAnimation?.cleanUp()
        currentAnimation = nil
    }
}

public class LightComponent: Component {
    enum LightType {
        case point(PointLight)
        case directional(DirectionalLight)
        case area(AreaLight)
    }

    var lightType: LightType?

    public required init() {}
}

public class ScenegraphComponent: Component {
    var parent: EntityID = .invalid
    var level: Int = 0 // level 0 means no parent
    var children: [EntityID] = []

    public required init() {}
}
