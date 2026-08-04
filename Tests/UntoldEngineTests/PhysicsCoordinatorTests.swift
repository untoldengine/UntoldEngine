//
//  PhysicsCoordinatorTests.swift
//  UntoldEngineTests
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldEngine
import XCTest

private final class RecordingPhysicsBackend: PhysicsBackend, @unchecked Sendable {
    let id: String
    let capabilities: PhysicsCapabilities = []

    private(set) var configurations: [PhysicsWorldConfiguration] = []
    private(set) var addedBodies: [(entity: EntityID, descriptor: PhysicsBodyDescriptor)] = []
    private(set) var removedBodies: [EntityID] = []
    private(set) var stepDeltas: [Float] = []
    private(set) var kinematicWrites: [[(entity: EntityID, transform: PhysicsBodyTransform)]] = []
    private(set) var drainCount = 0
    private(set) var callOrder: [String] = []

    /// Transforms handed back on the next `readActiveTransforms`.
    var pendingReadback: [(entity: EntityID, transform: PhysicsBodyTransform)] = []
    var droppedEventsToReport = 0

    init(id: String = "com.example.recordingphysics") {
        self.id = id
    }

    func configure(_ config: PhysicsWorldConfiguration) {
        configurations.append(config)
        callOrder.append("configure")
    }

    func didAddBody(entity: EntityID, descriptor: PhysicsBodyDescriptor) {
        addedBodies.append((entity, descriptor))
        callOrder.append("addBody")
    }

    func didRemoveBody(entity: EntityID) {
        removedBodies.append(entity)
        callOrder.append("removeBody")
    }

    func step(deltaTime: Float) {
        stepDeltas.append(deltaTime)
        callOrder.append("step")
    }

    func drainEvents(into sink: any PhysicsEventSink) {
        drainCount += 1
        callOrder.append("drain")
        if droppedEventsToReport > 0 {
            sink.reportDroppedEvents(count: droppedEventsToReport)
        }
    }

    func writeKinematicTargets(_ batch: PhysicsBodyWriteBatch) {
        var entries: [(EntityID, PhysicsBodyTransform)] = []
        for index in 0 ..< batch.entities.count {
            entries.append((batch.entities[index], batch.transforms[index]))
        }
        kinematicWrites.append(entries)
        callOrder.append("writeKinematic")
    }

    func readActiveTransforms(into batch: PhysicsTransformReadBatch) -> Int {
        callOrder.append("read")
        let count = min(pendingReadback.count, batch.capacity)
        for index in 0 ..< count {
            batch.entities[index] = pendingReadback[index].entity
            batch.transforms[index] = pendingReadback[index].transform
        }
        return count
    }
}

private struct RecordingBackendPlugin: PhysicsBackendPlugin {
    let manifest: PhysicsBackendPluginManifest
    let backend: RecordingPhysicsBackend

    init(pluginID: String = "com.example.recordingphysics") {
        manifest = PhysicsBackendPluginManifest(
            id: pluginID,
            displayName: "Recording Physics",
            version: PhysicsBackendVersion(major: 1, minor: 0, patch: 0),
            requiredAPIVersion: .current
        )
        backend = RecordingPhysicsBackend(id: pluginID)
    }

    func makeBackend() -> any PhysicsBackend {
        backend
    }
}

@MainActor
final class PhysicsCoordinatorTests: XCTestCase {
    override func setUp() async throws {
        resetEngineTestState()
    }

    override func tearDown() {
        PhysicsBackendRegistry.shared.resetForTesting()
        super.tearDown()
    }

    private func makeContext() -> EngineExtensionUpdateContext {
        EngineExtensionUpdateContext(
            viewport: SIMD2<Int>(640, 480),
            immersionStyle: .none,
            frameIndex: 0,
            currentEye: 0,
            isPrimaryEye: true
        )
    }

    private func tick(_ deltaTime: Float = 1.0 / 60.0) {
        PhysicsCoordinator.shared.fixedUpdate(deltaTime: deltaTime, context: makeContext())
    }

    @discardableResult
    private func installRecordingPlugin() -> RecordingPhysicsBackend {
        let plugin = RecordingBackendPlugin()
        XCTAssertEqual(PhysicsBackendRegistry.shared.install(plugin), .installed)
        return plugin.backend
    }

    private func makeBodyEntity(
        motionType: PhysicsMotionType = .dynamic,
        position: simd_float3 = .zero
    ) -> EntityID {
        let entityId = createEntity()
        registerComponent(entityId: entityId, componentType: RigidBodyComponent.self)
        registerComponent(entityId: entityId, componentType: ColliderComponent.self)
        scene.get(component: RigidBodyComponent.self, for: entityId)?.motionType = motionType
        scene.get(component: LocalTransformComponent.self, for: entityId)?.position = position
        return entityId
    }

    // MARK: - Scheduling

    func testInstallSchedulesCoordinatorAndUninstallRemovesIt() {
        XCTAssertFalse(
            EngineExtensionRegistry.shared.registeredIDs().contains(PhysicsCoordinator.shared.id)
        )

        installRecordingPlugin()
        XCTAssertTrue(
            EngineExtensionRegistry.shared.registeredIDs().contains(PhysicsCoordinator.shared.id)
        )

        XCTAssertTrue(PhysicsBackendRegistry.shared.uninstall(id: "com.example.recordingphysics"))
        XCTAssertFalse(
            EngineExtensionRegistry.shared.registeredIDs().contains(PhysicsCoordinator.shared.id)
        )
    }

    func testInstallConfiguresBackendWithCurrentWorldConfiguration() {
        var config = PhysicsWorldConfiguration()
        config.gravity = simd_float3(0.0, -3.7, 0.0)
        PhysicsCoordinator.shared.setWorldConfiguration(config)

        let backend = installRecordingPlugin()
        XCTAssertEqual(backend.configurations.count, 1)
        XCTAssertEqual(backend.configurations.first?.gravity, simd_float3(0.0, -3.7, 0.0))
    }

    func testSetWorldConfigurationReconfiguresActiveBackend() {
        let backend = installRecordingPlugin()
        XCTAssertEqual(backend.configurations.count, 1)

        var config = PhysicsWorldConfiguration()
        config.gravity = simd_float3(0.0, -1.6, 0.0)
        PhysicsCoordinator.shared.setWorldConfiguration(config)

        XCTAssertEqual(backend.configurations.count, 2)
        XCTAssertEqual(backend.configurations.last?.gravity, simd_float3(0.0, -1.6, 0.0))
    }

    func testFixedUpdateWithoutBackendIsInert() {
        _ = makeBodyEntity()
        tick()
        // Nothing to assert beyond "no trap": no backend, no coordinator work.
        XCTAssertFalse(PhysicsBackendRegistry.shared.isLockedForRuntime)
    }

    // MARK: - Runtime lock

    func testFirstSimulatedSubstepLocksRegistry() {
        installRecordingPlugin()
        XCTAssertFalse(PhysicsBackendRegistry.shared.isLockedForRuntime)

        tick()
        XCTAssertTrue(PhysicsBackendRegistry.shared.isLockedForRuntime)

        XCTAssertFalse(PhysicsBackendRegistry.shared.uninstall(id: "com.example.recordingphysics"))
        if case .rejected = PhysicsBackendRegistry.shared.install(RecordingBackendPlugin()) {
        } else {
            XCTFail("Install after the first simulated substep should be rejected")
        }
    }

    // MARK: - Body lifecycle

    func testBodyEntityIsAddedWithDescriptorSnapshot() throws {
        let backend = installRecordingPlugin()
        let entityId = makeBodyEntity(position: simd_float3(1.0, 2.0, 3.0))

        let rigidBody = scene.get(component: RigidBodyComponent.self, for: entityId)
        rigidBody?.mass = 4.0
        rigidBody?.layer = 2
        rigidBody?.initialLinearVelocity = simd_float3(0.0, 0.0, 5.0)
        let collider = scene.get(component: ColliderComponent.self, for: entityId)
        collider?.shape = .box(halfExtents: simd_float3(0.5, 0.5, 0.5))
        collider?.isTrigger = true

        tick()

        XCTAssertEqual(backend.addedBodies.count, 1)
        let added = try XCTUnwrap(backend.addedBodies.first)
        XCTAssertEqual(added.entity, entityId)
        XCTAssertEqual(added.descriptor.motionType, .dynamic)
        XCTAssertEqual(added.descriptor.mass, 4.0)
        XCTAssertEqual(added.descriptor.layer, 2)
        XCTAssertEqual(added.descriptor.position, simd_float3(1.0, 2.0, 3.0))
        XCTAssertEqual(added.descriptor.linearVelocity, simd_float3(0.0, 0.0, 5.0))
        XCTAssertEqual(added.descriptor.collider.shape, .box(halfExtents: simd_float3(0.5, 0.5, 0.5)))
        XCTAssertTrue(added.descriptor.collider.isTrigger)

        // Known bodies are not re-added on later substeps.
        tick()
        XCTAssertEqual(backend.addedBodies.count, 1)
    }

    func testEntityWithoutColliderIsNotABody() {
        let backend = installRecordingPlugin()
        let entityId = createEntity()
        registerComponent(entityId: entityId, componentType: RigidBodyComponent.self)

        tick()
        XCTAssertTrue(backend.addedBodies.isEmpty)
    }

    func testDestroyedEntityIsRemovedFromBackend() {
        let backend = installRecordingPlugin()
        let entityId = makeBodyEntity()

        tick()
        XCTAssertEqual(backend.addedBodies.count, 1)

        destroyEntity(entityId: entityId)
        scene.finalizePendingDestroys()

        tick()
        XCTAssertEqual(backend.removedBodies, [entityId])
    }

    func testRemovingPhysicsComponentsRemovesBody() {
        let backend = installRecordingPlugin()
        let entityId = makeBodyEntity()

        tick()
        XCTAssertEqual(backend.addedBodies.count, 1)

        scene.remove(component: RigidBodyComponent.self, from: entityId)

        tick()
        XCTAssertEqual(backend.removedBodies, [entityId])
    }

    // MARK: - Transform transfer

    func testDynamicTransformReadbackUpdatesLocalTransform() throws {
        let backend = installRecordingPlugin()
        let entityId = makeBodyEntity(position: simd_float3(0.0, 10.0, 0.0))

        let newOrientation = simd_quatf(angle: .pi / 2, axis: simd_float3(0.0, 1.0, 0.0))
        backend.pendingReadback = [(
            entityId,
            PhysicsBodyTransform(position: simd_float3(0.0, 9.5, 0.0), orientation: newOrientation)
        )]

        anyTransformDirty = false
        tick()

        let transform = try XCTUnwrap(scene.get(component: LocalTransformComponent.self, for: entityId))
        XCTAssertEqual(transform.position, simd_float3(0.0, 9.5, 0.0))
        XCTAssertEqual(transform.rotation.vector, newOrientation.vector)
        XCTAssertTrue(transform.transformDirty)
        XCTAssertTrue(anyTransformDirty)
    }

    func testReadbackIgnoresKinematicAndUnknownEntities() throws {
        let backend = installRecordingPlugin()
        let kinematicId = makeBodyEntity(motionType: .kinematic, position: simd_float3(1.0, 0.0, 0.0))
        let strangerId: EntityID = 987_654

        backend.pendingReadback = [
            (kinematicId, PhysicsBodyTransform(
                position: simd_float3(5.0, 5.0, 5.0),
                orientation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
            )),
            (strangerId, PhysicsBodyTransform(
                position: simd_float3(6.0, 6.0, 6.0),
                orientation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
            )),
        ]

        tick()

        let transform = try XCTUnwrap(scene.get(component: LocalTransformComponent.self, for: kinematicId))
        XCTAssertEqual(transform.position, simd_float3(1.0, 0.0, 0.0))
    }

    func testKinematicTargetsAreBatchWritten() throws {
        let backend = installRecordingPlugin()
        let kinematicId = makeBodyEntity(motionType: .kinematic, position: simd_float3(2.0, 0.0, 2.0))
        _ = makeBodyEntity(motionType: .dynamic)

        tick()

        XCTAssertEqual(backend.kinematicWrites.count, 1)
        let write = try XCTUnwrap(backend.kinematicWrites.first)
        XCTAssertEqual(write.count, 1)
        XCTAssertEqual(write.first?.entity, kinematicId)
        XCTAssertEqual(write.first?.transform.position, simd_float3(2.0, 0.0, 2.0))
    }

    // MARK: - Step orchestration

    func testSubstepCallOrderAndEventDrain() {
        let backend = installRecordingPlugin()
        _ = makeBodyEntity(motionType: .kinematic)
        backend.droppedEventsToReport = 3

        tick(1.0 / 60.0)

        XCTAssertEqual(backend.callOrder, ["configure", "addBody", "writeKinematic", "step", "read", "drain"])
        XCTAssertEqual(backend.stepDeltas, [1.0 / 60.0])
        XCTAssertEqual(backend.drainCount, 1)
        XCTAssertEqual(PhysicsCoordinator.shared.eventSink.droppedEventCount, 3)
    }

    // MARK: - Built-in integrator gravity seam

    func testBuiltInIntegratorReadsConfigurableGravity() {
        let entityId = createEntity()
        registerComponent(entityId: entityId, componentType: PhysicsComponents.self)
        registerComponent(entityId: entityId, componentType: KineticComponent.self)
        setMass(entityId: entityId, mass: 1.0)
        setGravityScale(entityId: entityId, gravityScale: 1.0)

        var config = PhysicsWorldConfiguration()
        config.gravity = .zero
        PhysicsCoordinator.shared.setWorldConfiguration(config)

        updatePhysicsSystem(deltaTime: 1.0 / 60.0)
        XCTAssertEqual(getVelocity(entityId: entityId), .zero)

        PhysicsCoordinator.shared.setWorldConfiguration(PhysicsWorldConfiguration())
        updatePhysicsSystem(deltaTime: 1.0 / 60.0)
        XCTAssertLessThan(getVelocity(entityId: entityId).y, 0.0)
    }

    func testDefaultWorldConfigurationMatchesLegacyGravity() {
        XCTAssertEqual(
            PhysicsCoordinator.shared.worldConfiguration().gravity,
            simd_float3(0.0, -9.8, 0.0)
        )
    }
}
