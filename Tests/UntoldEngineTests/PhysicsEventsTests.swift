//
//  PhysicsEventsTests.swift
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

private final class EventEmittingPhysicsBackend: PhysicsBackend, @unchecked Sendable {
    let id: String
    let capabilities: PhysicsCapabilities = [.collisions, .triggers]

    var pendingContacts: [PhysicsContactEvent] = []
    var pendingTriggers: [PhysicsTriggerEvent] = []
    var pendingActivations: [PhysicsBodyActivationEvent] = []
    var droppedEventsToReport = 0

    init(id: String = "com.example.eventphysics") {
        self.id = id
    }

    func configure(_: PhysicsWorldConfiguration) {}

    func step(deltaTime _: Float) {}

    func drainEvents(into sink: any PhysicsEventSink) {
        for event in pendingContacts {
            sink.receiveContact(event)
        }
        for event in pendingTriggers {
            sink.receiveTrigger(event)
        }
        for event in pendingActivations {
            sink.receiveActivation(event)
        }
        pendingContacts.removeAll()
        pendingTriggers.removeAll()
        pendingActivations.removeAll()

        if droppedEventsToReport > 0 {
            sink.reportDroppedEvents(count: droppedEventsToReport)
            droppedEventsToReport = 0
        }
    }
}

private struct EventBackendPlugin: PhysicsBackendPlugin {
    let manifest: PhysicsBackendPluginManifest
    let backend: EventEmittingPhysicsBackend

    init(pluginID: String = "com.example.eventphysics") {
        manifest = PhysicsBackendPluginManifest(
            id: pluginID,
            displayName: "Event Physics",
            version: PhysicsBackendVersion(major: 1, minor: 0, patch: 0),
            requiredAPIVersion: .current
        )
        backend = EventEmittingPhysicsBackend(id: pluginID)
    }

    func makeBackend() -> any PhysicsBackend {
        backend
    }
}

@MainActor
final class PhysicsEventsTests: XCTestCase {
    private var subscriptions: [EventSubscription] = []

    override func setUp() async throws {
        resetEngineTestState()
        initScriptingSystem()
        USCSystem.shared.initialize()
    }

    override func tearDown() {
        for subscription in subscriptions {
            subscription.cancel()
        }
        subscriptions.removeAll()
        gameMode = false
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

    private func tick() {
        PhysicsCoordinator.shared.fixedUpdate(deltaTime: 1.0 / 60.0, context: makeContext())
    }

    @discardableResult
    private func installEventPlugin() -> EventEmittingPhysicsBackend {
        let plugin = EventBackendPlugin()
        XCTAssertEqual(PhysicsBackendRegistry.shared.install(plugin), .installed)
        return plugin.backend
    }

    private func makeContact(
        phase: PhysicsContactPhase,
        entityA: EntityID,
        entityB: EntityID
    ) -> PhysicsContactEvent {
        PhysicsContactEvent(
            phase: phase,
            entityA: entityA,
            entityB: entityB,
            position: simd_float3(0.0, 1.0, 0.0),
            normal: simd_float3(0.0, 1.0, 0.0),
            impulse: 2.5
        )
    }

    // MARK: - Subscriptions

    func testContactSubscriptionReceivesDrainedEvents() {
        let backend = installEventPlugin()
        let entityA = createEntity()
        let entityB = createEntity()

        var received: [PhysicsContactEvent] = []
        subscriptions.append(PhysicsEvents.shared.onContact { received.append($0) })

        backend.pendingContacts = [makeContact(phase: .began, entityA: entityA, entityB: entityB)]
        tick()

        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received.first?.phase, .began)
        XCTAssertEqual(received.first?.entityA, entityA)
        XCTAssertEqual(received.first?.entityB, entityB)
        XCTAssertEqual(received.first?.impulse, 2.5)

        // Nothing queued → nothing dispatched on later substeps.
        tick()
        XCTAssertEqual(received.count, 1)
    }

    func testCancelledSubscriptionStopsReceiving() {
        let backend = installEventPlugin()

        var received = 0
        let subscription = PhysicsEvents.shared.onContact { _ in received += 1 }

        backend.pendingContacts = [makeContact(phase: .began, entityA: 1, entityB: 2)]
        tick()
        XCTAssertEqual(received, 1)

        subscription.cancel()
        backend.pendingContacts = [makeContact(phase: .persisted, entityA: 1, entityB: 2)]
        tick()
        XCTAssertEqual(received, 1)
    }

    func testTriggerAndActivationSubscriptions() {
        let backend = installEventPlugin()

        var triggers: [PhysicsTriggerEvent] = []
        var activations: [PhysicsBodyActivationEvent] = []
        subscriptions.append(PhysicsEvents.shared.onTrigger { triggers.append($0) })
        subscriptions.append(PhysicsEvents.shared.onActivation { activations.append($0) })

        backend.pendingTriggers = [
            PhysicsTriggerEvent(phase: .entered, triggerEntity: 7, otherEntity: 9),
        ]
        backend.pendingActivations = [
            PhysicsBodyActivationEvent(entity: 9, isActive: false),
        ]
        tick()

        XCTAssertEqual(triggers.count, 1)
        XCTAssertEqual(triggers.first?.phase, .entered)
        XCTAssertEqual(activations.count, 1)
        XCTAssertEqual(activations.first?.isActive, false)
    }

    func testDormantWithoutBackend() {
        var received = 0
        subscriptions.append(PhysicsEvents.shared.onContact { _ in received += 1 })

        tick()
        XCTAssertEqual(received, 0)
        XCTAssertEqual(PhysicsEvents.shared.droppedEventCount, 0)
    }

    func testDroppedEventsAccumulateAcrossSubsteps() {
        let backend = installEventPlugin()

        backend.droppedEventsToReport = 3
        tick()
        backend.droppedEventsToReport = 2
        tick()

        XCTAssertEqual(PhysicsEvents.shared.droppedEventCount, 5)
    }

    // MARK: - USC wiring

    private func attachScript(
        _ build: (USCBuilder) -> USCBuilder,
        named name: String,
        to entityId: EntityID,
        recording flagName: String,
        into counter: @escaping () -> Void
    ) {
        USCActionRegistry.shared.register(name: flagName) { _, _ in
            counter()
            return nil
        }
        let builder = USCBuilder()
        _ = build(builder).callAction(flagName)
        let script = builder.build(name: name)
        USCSystem.shared.attachScript(script, to: entityId)
    }

    func testContactBeganFiresUSCOnCollision() {
        gameMode = true
        let backend = installEventPlugin()
        let scripted = createEntity()
        let other = createEntity()

        var hits = 0
        attachScript({ $0.onCollision() }, named: "HitScript", to: scripted,
                     recording: "recordHit", into: { hits += 1 })

        backend.pendingContacts = [makeContact(phase: .began, entityA: scripted, entityB: other)]
        tick()
        XCTAssertEqual(hits, 1, "contactBegan must fire OnCollision on the scripted entity")

        // Later phases of the same contact must not re-fire the collision event.
        backend.pendingContacts = [
            makeContact(phase: .persisted, entityA: scripted, entityB: other),
            makeContact(phase: .ended, entityA: scripted, entityB: other),
        ]
        tick()
        XCTAssertEqual(hits, 1)
    }

    func testContactFiresTaggedOnCollisionForNamedOther() {
        gameMode = true
        let backend = installEventPlugin()
        let scripted = createEntity()
        let ball = createEntity()
        setEntityName(entityId: ball, name: "Ball")

        var taggedHits = 0
        attachScript({ $0.onCollision(tag: "Ball") }, named: "BallScript", to: scripted,
                     recording: "recordBallHit", into: { taggedHits += 1 })

        // Contact with an unnamed entity: the tagged handler must stay silent.
        let stranger = createEntity()
        backend.pendingContacts = [makeContact(phase: .began, entityA: scripted, entityB: stranger)]
        tick()
        XCTAssertEqual(taggedHits, 0)

        // Contact with the named entity fires the tagged event, on either side.
        backend.pendingContacts = [makeContact(phase: .began, entityA: ball, entityB: scripted)]
        tick()
        XCTAssertEqual(taggedHits, 1)
    }

    func testTriggerFiresUSCOnTriggerEnterAndExit() {
        gameMode = true
        let backend = installEventPlugin()
        let scripted = createEntity()
        let volume = createEntity()

        var enters = 0
        var exits = 0
        attachScript({ $0.onEvent("OnTriggerEnter") }, named: "EnterScript", to: scripted,
                     recording: "recordEnter", into: { enters += 1 })
        attachScript({ $0.onEvent("OnTriggerExit") }, named: "ExitScript", to: scripted,
                     recording: "recordExit", into: { exits += 1 })

        backend.pendingTriggers = [
            PhysicsTriggerEvent(phase: .entered, triggerEntity: volume, otherEntity: scripted),
        ]
        tick()
        XCTAssertEqual(enters, 1)
        XCTAssertEqual(exits, 0)

        backend.pendingTriggers = [
            PhysicsTriggerEvent(phase: .exited, triggerEntity: volume, otherEntity: scripted),
        ]
        tick()
        XCTAssertEqual(enters, 1)
        XCTAssertEqual(exits, 1)
    }

    func testUSCEventsRespectGameMode() {
        gameMode = false
        let backend = installEventPlugin()
        let scripted = createEntity()

        var hits = 0
        attachScript({ $0.onCollision() }, named: "PausedScript", to: scripted,
                     recording: "recordPausedHit", into: { hits += 1 })

        backend.pendingContacts = [makeContact(phase: .began, entityA: scripted, entityB: 42)]
        tick()
        XCTAssertEqual(hits, 0, "USC events must not fire outside Play mode")
    }
}
