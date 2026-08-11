//
//  PhysicsCoordinator.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

/// Drives the installed external physics backend from the engine's
/// fixed-timestep loop as an `EngineExtension` — no engine-core seams.
///
/// `PhysicsBackendRegistry` registers the coordinator with
/// `EngineExtensionRegistry` when a backend plugin installs and unregisters it
/// on uninstall, so with no backend installed nothing is scheduled and the
/// engine behaves exactly as before. The built-in integrator is untouched
/// either way: it keeps running for legacy `PhysicsComponents`/
/// `KineticComponent` entities, while the external backend owns only entities
/// carrying both `RigidBodyComponent` and `ColliderComponent`.
///
/// Each `fixedUpdate` (frame thread, once per fixed substep, right after
/// `updatePhysicsSystem`):
/// 1. locks `PhysicsBackendRegistry` for runtime on the first simulated substep,
///    freezing the backend choice for the rest of the run;
/// 2. diffs the current `RigidBodyComponent`+`ColliderComponent` query result
///    against the backend's known-body set → `didAddBody`/`didRemoveBody`
///    (destruction needs no extra hook: component cleanup removes the entity
///    from the query and the diff picks it up);
/// 3. batch-writes kinematic body targets;
/// 4. steps the backend;
/// 5. batch-reads active transforms back into `LocalTransformComponent` for
///    dynamic bodies, marking them dirty for the scenegraph/octree exactly like
///    the built-in integrator does;
/// 6. drains buffered events.
public final class PhysicsCoordinator: EngineExtension, @unchecked Sendable {
    public static let shared = PhysicsCoordinator()

    public let id = "com.untoldengine.physics.coordinator"

    private let configLock = NSLock()
    private var worldConfig = PhysicsWorldConfiguration()

    // Frame-thread state: touched only from fixedUpdate and the install path,
    // which the registry contract requires to happen before runtime starts.
    private var knownBodies: Set<EntityID> = []
    private var readbackEntities: [EntityID] = []
    private var readbackTransforms: [PhysicsBodyTransform] = []
    private var kinematicEntities: [EntityID] = []
    private var kinematicTransforms: [PhysicsBodyTransform] = []
    let eventSink = PhysicsEventDispatchSink()

    private init() {}

    // MARK: - World configuration

    /// Applies world settings to the active backend immediately and to any
    /// backend installed later. The built-in integrator reads `gravity` from
    /// here as well, so legacy and backend-owned bodies share one gravity.
    public func setWorldConfiguration(_ config: PhysicsWorldConfiguration) {
        configLock.lock()
        worldConfig = config
        configLock.unlock()
        PhysicsBackendRegistry.shared.activeBackend()?.configure(config)
    }

    public func worldConfiguration() -> PhysicsWorldConfiguration {
        configLock.lock()
        defer { configLock.unlock() }
        return worldConfig
    }

    var worldGravity: simd_float3 {
        configLock.lock()
        defer { configLock.unlock() }
        return worldConfig.gravity
    }

    // MARK: - Install hooks (called by PhysicsBackendRegistry, post-transaction)

    func backendDidInstall(_ backend: any PhysicsBackend) {
        backend.configure(worldConfiguration())
        knownBodies.removeAll()
        EngineExtensionRegistry.shared.register(self)
    }

    func backendDidUninstall() {
        EngineExtensionRegistry.shared.unregister(id: id)
    }

    // MARK: - EngineExtension

    public func fixedUpdate(deltaTime: Float, context _: EngineExtensionUpdateContext) {
        guard let backend = PhysicsBackendRegistry.shared.activeBackend() else { return }

        if !PhysicsBackendRegistry.shared.isLockedForRuntime {
            PhysicsBackendRegistry.shared.lockForRuntime()
        }

        syncBodySet(with: backend)
        pushKinematicTargets(to: backend)
        backend.step(deltaTime: deltaTime)
        pullTransforms(from: backend)
        backend.drainEvents(into: eventSink)
    }

    public func willUnregister() {
        knownBodies.removeAll()
    }

    /// Restores defaults. Test support only.
    func resetForTesting() {
        configLock.lock()
        worldConfig = PhysicsWorldConfiguration()
        configLock.unlock()
        knownBodies.removeAll()
        PhysicsEvents.shared.reset()
    }

    // MARK: - Body lifecycle

    private func syncBodySet(with backend: any PhysicsBackend) {
        let bodyEntities = queryEntities(with: [
            RigidBodyComponent.self, ColliderComponent.self, LocalTransformComponent.self,
        ])
        let currentSet = Set(bodyEntities)

        for entity in knownBodies.subtracting(currentSet) {
            backend.didRemoveBody(entity: entity)
            knownBodies.remove(entity)
        }

        for entity in bodyEntities where !knownBodies.contains(entity) {
            guard let descriptor = makeBodyDescriptor(entityId: entity) else { continue }
            backend.didAddBody(entity: entity, descriptor: descriptor)
            knownBodies.insert(entity)
        }
    }

    private func makeBodyDescriptor(entityId: EntityID) -> PhysicsBodyDescriptor? {
        guard let rigidBody = scene.get(component: RigidBodyComponent.self, for: entityId),
              let collider = scene.get(component: ColliderComponent.self, for: entityId),
              let transform = scene.get(component: LocalTransformComponent.self, for: entityId)
        else {
            return nil
        }

        return PhysicsBodyDescriptor(
            motionType: rigidBody.motionType,
            collider: PhysicsColliderDescriptor(
                shape: collider.shape,
                localOffset: collider.localOffset,
                friction: collider.friction,
                restitution: collider.restitution,
                isTrigger: collider.isTrigger
            ),
            mass: rigidBody.mass,
            layer: rigidBody.layer,
            collisionMask: rigidBody.collisionMask,
            gravityScale: rigidBody.gravityScale,
            position: transform.position,
            orientation: transform.rotation,
            linearVelocity: rigidBody.initialLinearVelocity,
            angularVelocity: rigidBody.initialAngularVelocity
        )
    }

    // MARK: - Transform transfer

    private func pushKinematicTargets(to backend: any PhysicsBackend) {
        kinematicEntities.removeAll(keepingCapacity: true)
        kinematicTransforms.removeAll(keepingCapacity: true)

        for entity in knownBodies {
            guard let rigidBody = scene.get(component: RigidBodyComponent.self, for: entity),
                  rigidBody.motionType == .kinematic,
                  let transform = scene.get(component: LocalTransformComponent.self, for: entity)
            else {
                continue
            }
            kinematicEntities.append(entity)
            kinematicTransforms.append(
                PhysicsBodyTransform(position: transform.position, orientation: transform.rotation)
            )
        }

        guard !kinematicEntities.isEmpty else { return }

        kinematicEntities.withUnsafeBufferPointer { entities in
            kinematicTransforms.withUnsafeBufferPointer { transforms in
                backend.writeKinematicTargets(
                    PhysicsBodyWriteBatch(entities: entities, transforms: transforms)
                )
            }
        }
    }

    private func pullTransforms(from backend: any PhysicsBackend) {
        let capacity = knownBodies.count
        guard capacity > 0 else { return }

        if readbackEntities.count < capacity {
            readbackEntities = [EntityID](repeating: 0, count: capacity)
            readbackTransforms = [PhysicsBodyTransform](
                repeating: PhysicsBodyTransform(
                    position: .zero,
                    orientation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
                ),
                count: capacity
            )
        }

        var written = 0
        readbackEntities.withUnsafeMutableBufferPointer { entities in
            readbackTransforms.withUnsafeMutableBufferPointer { transforms in
                written = backend.readActiveTransforms(
                    into: PhysicsTransformReadBatch(entities: entities, transforms: transforms)
                )
            }
        }

        guard written > 0 else { return }

        for index in 0 ..< min(written, capacity) {
            let entity = readbackEntities[index]
            guard knownBodies.contains(entity),
                  let rigidBody = scene.get(component: RigidBodyComponent.self, for: entity),
                  rigidBody.motionType == .dynamic,
                  let transform = scene.get(component: LocalTransformComponent.self, for: entity)
            else {
                continue
            }

            transform.position = readbackTransforms[index].position
            transform.rotation = readbackTransforms[index].orientation
            transform.transformDirty = true
            anyTransformDirty = true
        }
    }
}
