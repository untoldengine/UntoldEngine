
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

public class TransformComponent: Component {
    var localSpace: simd_float4x4
    var xRot: Float
    var yRot: Float
    var zRot: Float

    var minBox: simd_float3!
    var maxBox: simd_float3!

    var scale: simd_float3!

    public required init() {
        // Initialize default values
        localSpace = matrix4x4Identity()
        xRot = 0.0
        yRot = 0.0
        zRot = 0.0
    }
}

public class RenderComponent: Component {
    var spaceUniform: MTLBuffer!
    var mesh: Mesh!

    public required init() {}
}

public class PhysicsComponents: Component {
    var mass: Float
    var velocity: simd_float3
    var acceleration: simd_float3

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
