//
//  PhysicsBackend.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

/// Simulation features a physics backend provides beyond basic integration.
public struct PhysicsCapabilities: OptionSet, Hashable, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let collisions = PhysicsCapabilities(rawValue: 1 << 0)
    public static let triggers = PhysicsCapabilities(rawValue: 1 << 1)
    public static let raycast = PhysicsCapabilities(rawValue: 1 << 2)
    public static let shapecast = PhysicsCapabilities(rawValue: 1 << 3)
    public static let overlap = PhysicsCapabilities(rawValue: 1 << 4)
    public static let constraints = PhysicsCapabilities(rawValue: 1 << 5)
    public static let characterController = PhysicsCapabilities(rawValue: 1 << 6)
    public static let meshColliders = PhysicsCapabilities(rawValue: 1 << 7)
}

/// How a body participates in simulation.
public enum PhysicsMotionType: Hashable, Sendable {
    /// Never moves; collides with dynamic bodies.
    case `static`
    /// Moved by game code; pushes dynamic bodies but is not pushed back.
    case kinematic
    /// Fully simulated.
    case dynamic
}

/// Collision shape in body-local space. Dimensions are in metres.
public enum PhysicsColliderShape: Hashable, Sendable {
    case sphere(radius: Float)
    case box(halfExtents: simd_float3)
    /// Capsule aligned to the local Y axis; `height` is the cylindrical section, excluding caps.
    case capsule(radius: Float, height: Float)
    /// Cylinder aligned to the local Y axis.
    case cylinder(radius: Float, height: Float)
    case convexHull(vertices: [simd_float3])
}

/// World-level simulation settings. Units are metres, kilograms and seconds; Y is up.
public struct PhysicsWorldConfiguration: Sendable {
    public var gravity: simd_float3 = .init(0.0, -9.8, 0.0)
    /// Layer pair filter: `collisionLayerMatrix[layer]` is the bit mask of layers that
    /// layer collides with. Empty means every pair collides.
    public var collisionLayerMatrix: [UInt32] = []

    public init() {}
}

/// Collider description snapshot handed to a backend when a body is created.
public struct PhysicsColliderDescriptor: Hashable, Sendable {
    public var shape: PhysicsColliderShape
    public var localOffset: simd_float3
    public var friction: Float
    public var restitution: Float
    public var isTrigger: Bool

    public init(
        shape: PhysicsColliderShape,
        localOffset: simd_float3 = .zero,
        friction: Float = 0.5,
        restitution: Float = 0.0,
        isTrigger: Bool = false
    ) {
        self.shape = shape
        self.localOffset = localOffset
        self.friction = friction
        self.restitution = restitution
        self.isTrigger = isTrigger
    }
}

/// Complete body description snapshot handed to a backend when a body is created.
public struct PhysicsBodyDescriptor: Sendable {
    public var motionType: PhysicsMotionType
    public var collider: PhysicsColliderDescriptor
    public var mass: Float
    public var layer: UInt32
    public var collisionMask: UInt32
    public var gravityScale: Float
    public var position: simd_float3
    public var orientation: simd_quatf
    public var linearVelocity: simd_float3
    public var angularVelocity: simd_float3

    public init(
        motionType: PhysicsMotionType,
        collider: PhysicsColliderDescriptor,
        mass: Float = 1.0,
        layer: UInt32 = 0,
        collisionMask: UInt32 = .max,
        gravityScale: Float = 1.0,
        position: simd_float3 = .zero,
        orientation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
        linearVelocity: simd_float3 = .zero,
        angularVelocity: simd_float3 = .zero
    ) {
        self.motionType = motionType
        self.collider = collider
        self.mass = mass
        self.layer = layer
        self.collisionMask = collisionMask
        self.gravityScale = gravityScale
        self.position = position
        self.orientation = orientation
        self.linearVelocity = linearVelocity
        self.angularVelocity = angularVelocity
    }
}

/// A rigid transform exchanged between the engine and a backend.
public struct PhysicsBodyTransform: Sendable {
    public var position: simd_float3
    public var orientation: simd_quatf

    public init(position: simd_float3, orientation: simd_quatf) {
        self.position = position
        self.orientation = orientation
    }
}

/// Kinematic targets for a set of bodies, written by the engine before a step.
/// `entities` and `transforms` are parallel and equal in length. The buffers are
/// only valid for the duration of the call that receives them.
public struct PhysicsBodyWriteBatch {
    public let entities: UnsafeBufferPointer<EntityID>
    public let transforms: UnsafeBufferPointer<PhysicsBodyTransform>

    public init(
        entities: UnsafeBufferPointer<EntityID>,
        transforms: UnsafeBufferPointer<PhysicsBodyTransform>
    ) {
        self.entities = entities
        self.transforms = transforms
    }
}

/// Caller-supplied storage a backend fills with the transforms of its active bodies.
/// `entities` and `transforms` are parallel; the backend writes at most `capacity`
/// entries and returns the count written. The buffers are only valid for the
/// duration of the call that receives them.
public struct PhysicsTransformReadBatch {
    public let entities: UnsafeMutableBufferPointer<EntityID>
    public let transforms: UnsafeMutableBufferPointer<PhysicsBodyTransform>

    public var capacity: Int {
        min(entities.count, transforms.count)
    }

    public init(
        entities: UnsafeMutableBufferPointer<EntityID>,
        transforms: UnsafeMutableBufferPointer<PhysicsBodyTransform>
    ) {
        self.entities = entities
        self.transforms = transforms
    }
}

public enum PhysicsContactPhase: Hashable, Sendable {
    case began
    case persisted
    case ended
}

public struct PhysicsContactEvent: Sendable {
    public let phase: PhysicsContactPhase
    public let entityA: EntityID
    public let entityB: EntityID
    public let position: simd_float3
    public let normal: simd_float3
    public let impulse: Float

    public init(
        phase: PhysicsContactPhase,
        entityA: EntityID,
        entityB: EntityID,
        position: simd_float3,
        normal: simd_float3,
        impulse: Float
    ) {
        self.phase = phase
        self.entityA = entityA
        self.entityB = entityB
        self.position = position
        self.normal = normal
        self.impulse = impulse
    }
}

public enum PhysicsTriggerPhase: Hashable, Sendable {
    case entered
    case exited
}

public struct PhysicsTriggerEvent: Sendable {
    public let phase: PhysicsTriggerPhase
    public let triggerEntity: EntityID
    public let otherEntity: EntityID

    public init(phase: PhysicsTriggerPhase, triggerEntity: EntityID, otherEntity: EntityID) {
        self.phase = phase
        self.triggerEntity = triggerEntity
        self.otherEntity = otherEntity
    }
}

public struct PhysicsBodyActivationEvent: Sendable {
    public let entity: EntityID
    public let isActive: Bool

    public init(entity: EntityID, isActive: Bool) {
        self.entity = entity
        self.isActive = isActive
    }
}

/// Receives simulation events during `PhysicsBackend.drainEvents(into:)`.
public protocol PhysicsEventSink: AnyObject {
    func receiveContact(_ event: PhysicsContactEvent)
    func receiveTrigger(_ event: PhysicsTriggerEvent)
    func receiveActivation(_ event: PhysicsBodyActivationEvent)
    /// Reports events discarded because a backend's fixed-capacity buffers overflowed.
    func reportDroppedEvents(count: Int)
}

public struct PhysicsRay: Sendable {
    public var origin: simd_float3
    public var direction: simd_float3
    public var maxDistance: Float

    public init(origin: simd_float3, direction: simd_float3, maxDistance: Float = .greatestFiniteMagnitude) {
        self.origin = origin
        self.direction = direction
        self.maxDistance = maxDistance
    }
}

public struct PhysicsQueryFilter: Sendable {
    public var layerMask: UInt32
    public var excludedEntities: Set<EntityID>

    public init(layerMask: UInt32 = .max, excludedEntities: Set<EntityID> = []) {
        self.layerMask = layerMask
        self.excludedEntities = excludedEntities
    }
}

public struct PhysicsRayHit: Sendable {
    public let entity: EntityID
    public let position: simd_float3
    public let normal: simd_float3
    public let distance: Float

    public init(entity: EntityID, position: simd_float3, normal: simd_float3, distance: Float) {
        self.entity = entity
        self.position = position
        self.normal = normal
        self.distance = distance
    }
}

/// A physics simulation provider.
///
/// Threading contract: every method is called on the engine's frame thread. A backend
/// may parallelize internally, but callbacks from its worker threads must never reach
/// the engine — events are buffered inside the backend and handed over only through
/// `drainEvents(into:)`, which the engine calls after `step(deltaTime:)` returns.
///
/// Data-transfer contract: transform exchange is batch-only. Backends must never be
/// asked for — nor perform — one call per body per frame.
public protocol PhysicsBackend: AnyObject {
    var id: String { get }
    var capabilities: PhysicsCapabilities { get }

    func configure(_ config: PhysicsWorldConfiguration)

    /// Called when an entity gains the components that make it a physics body.
    func didAddBody(entity: EntityID, descriptor: PhysicsBodyDescriptor)
    /// Called when a body entity is destroyed or loses its physics components.
    func didRemoveBody(entity: EntityID)

    /// Advances the simulation by one fixed substep.
    func step(deltaTime: Float)

    /// Delivers events buffered during the preceding `step`. Called on the frame thread.
    func drainEvents(into sink: any PhysicsEventSink)

    func writeKinematicTargets(_ batch: PhysicsBodyWriteBatch)

    /// Fills `batch` with the transforms of active bodies; returns the count written.
    func readActiveTransforms(into batch: PhysicsTransformReadBatch) -> Int

    /// Requires the `.raycast` capability; backends without it return nil.
    func raycast(_ ray: PhysicsRay, filter: PhysicsQueryFilter) -> PhysicsRayHit?
}

/// Default no-op implementations so minimal backends only implement what they support.
public extension PhysicsBackend {
    func didAddBody(entity _: EntityID, descriptor _: PhysicsBodyDescriptor) {}
    func didRemoveBody(entity _: EntityID) {}
    func drainEvents(into _: any PhysicsEventSink) {}
    func writeKinematicTargets(_: PhysicsBodyWriteBatch) {}
    func readActiveTransforms(into _: PhysicsTransformReadBatch) -> Int {
        0
    }

    func raycast(_: PhysicsRay, filter _: PhysicsQueryFilter) -> PhysicsRayHit? {
        nil
    }
}
