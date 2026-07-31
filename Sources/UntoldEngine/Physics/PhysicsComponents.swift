//
//  PhysicsComponents.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

// ECS-facing components for the pluggable physics backend. Like
// CameraComponent/LightComponent for render extensions, these are the shared,
// engine-owned vocabulary every PhysicsBackend consumes; backends never define
// their own component types.

public class ColliderComponent: Component {
    public var shape: PhysicsColliderShape = .sphere(radius: 0.5)
    public var localOffset: simd_float3 = .zero
    public var friction: Float = 0.5
    public var restitution: Float = 0.0
    public var isTrigger: Bool = false

    public required init() {}
}

public class RigidBodyComponent: Component {
    public var motionType: PhysicsMotionType = .dynamic
    public var mass: Float = 1.0
    public var layer: UInt32 = 0
    public var collisionMask: UInt32 = .max
    public var gravityScale: Float = 1.0
    public var initialLinearVelocity: simd_float3 = .zero
    public var initialAngularVelocity: simd_float3 = .zero

    public required init() {}
}

/// Called from registerComponentCleanupHandlers() so physics component
/// wiring stays in Physics/ instead of the shared registration list.
func registerPhysicsComponentCleanupHandlers() {
    ComponentRegistry.register(componentType: ColliderComponent.self, handlerId: "physicsBody", priority: 30) { entityId in
        removeEntityPhysicsBody(entityId: entityId)
    }
    ComponentRegistry.register(componentType: RigidBodyComponent.self, handlerId: "physicsBody", priority: 30) { entityId in
        removeEntityPhysicsBody(entityId: entityId)
    }
}

func removeEntityPhysicsBody(entityId: EntityID) {
    if scene.get(component: ColliderComponent.self, for: entityId) != nil {
        scene.remove(component: ColliderComponent.self, from: entityId)
    }

    if scene.get(component: RigidBodyComponent.self, for: entityId) != nil {
        scene.remove(component: RigidBodyComponent.self, from: entityId)
    }
}
