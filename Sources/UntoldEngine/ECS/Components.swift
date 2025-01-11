
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

    var boundingBox: (min: simd_float3, max: simd_float3)!

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
}

public class PhysicsComponents: Component {
    var mass: Float
    var velocity: simd_float3
    var acceleration: simd_float3
    var pause: Bool = false

    public required init() {
        mass = 1.0
        velocity = simd_float3(0.0, 0.0, 0.0)
        acceleration = simd_float3(0.0, 0.0, 0.0)
    }
}

public class KineticComponent: Component {
    var forces: [simd_float3] = []

    var gravityScale: Float = 0.0

    public required init() {}

    public func addForce(_ force: simd_float3) {
        forces.append(force)
    }

    public func clearForces() {
        forces.removeAll()
    }
}

public class SkeletonComponent: Component {
    var skeleton: Skeleton!

    public required init() {}
}

public class AnimationComponent: Component {
    var animationClips: [String: AnimationClip] = [:]
    var currentAnimation: AnimationClip?
    var pause: Bool = false
    var currentTime: Float = 0.0
    public required init() {}
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
