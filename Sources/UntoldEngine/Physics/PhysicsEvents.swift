//
//  PhysicsEvents.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// Subscription hub for physics simulation events, in the `FrameEvents` style.
///
/// Events originate in the active `PhysicsBackend`, which buffers them internally
/// during `step` and hands them over on the frame thread when the coordinator calls
/// `drainEvents(into:)` after each fixed substep. Handlers therefore run on the
/// frame thread, once per event, in backend delivery order. Subscriptions can be
/// created or cancelled from any thread.
///
/// With no external backend installed nothing is ever dispatched — the built-in
/// integrator has no collision detection, so this hub is dormant, exactly as before.
public final class PhysicsEvents: @unchecked Sendable {
    public static let shared = PhysicsEvents()

    private let lock = NSLock()
    private var contactHandlers: [UUID: (PhysicsContactEvent) -> Void] = [:]
    private var triggerHandlers: [UUID: (PhysicsTriggerEvent) -> Void] = [:]
    private var activationHandlers: [UUID: (PhysicsBodyActivationEvent) -> Void] = [:]
    private var totalDroppedEvents = 0

    private init() {}

    // MARK: - Subscriptions

    public func onContact(_ handler: @escaping (PhysicsContactEvent) -> Void) -> EventSubscription {
        subscribe(handler, into: \.contactHandlers)
    }

    public func onTrigger(_ handler: @escaping (PhysicsTriggerEvent) -> Void) -> EventSubscription {
        subscribe(handler, into: \.triggerHandlers)
    }

    public func onActivation(_ handler: @escaping (PhysicsBodyActivationEvent) -> Void) -> EventSubscription {
        subscribe(handler, into: \.activationHandlers)
    }

    /// Running total of events a backend discarded because its fixed-capacity
    /// buffers overflowed. A growing number means handlers are missing events;
    /// it never causes an allocation or error mid-step.
    public var droppedEventCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return totalDroppedEvents
    }

    private func subscribe<Event>(
        _ handler: @escaping (Event) -> Void,
        into keyPath: ReferenceWritableKeyPath<PhysicsEvents, [UUID: (Event) -> Void]>
    ) -> EventSubscription {
        let id = UUID()
        lock.lock()
        self[keyPath: keyPath][id] = handler
        lock.unlock()
        return EventSubscription { [weak self] in
            guard let self else { return }
            lock.lock()
            self[keyPath: keyPath].removeValue(forKey: id)
            lock.unlock()
        }
    }

    // MARK: - Dispatch (frame thread, called by the coordinator's sink)

    func dispatchContact(_ event: PhysicsContactEvent) {
        // Snapshot under the lock, invoke outside it, matching FrameEventDispatcher:
        // handlers may subscribe or cancel reentrantly without deadlocking.
        lock.lock()
        let snapshot = Array(contactHandlers.values)
        lock.unlock()
        for handler in snapshot {
            handler(event)
        }
    }

    func dispatchTrigger(_ event: PhysicsTriggerEvent) {
        lock.lock()
        let snapshot = Array(triggerHandlers.values)
        lock.unlock()
        for handler in snapshot {
            handler(event)
        }
    }

    func dispatchActivation(_ event: PhysicsBodyActivationEvent) {
        lock.lock()
        let snapshot = Array(activationHandlers.values)
        lock.unlock()
        for handler in snapshot {
            handler(event)
        }
    }

    func recordDroppedEvents(count: Int) {
        lock.lock()
        totalDroppedEvents += count
        lock.unlock()
    }

    /// Restores defaults. Test support only.
    func reset() {
        lock.lock()
        contactHandlers.removeAll()
        triggerHandlers.removeAll()
        activationHandlers.removeAll()
        totalDroppedEvents = 0
        lock.unlock()
    }
}

/// The coordinator's event sink: fans backend events out to `PhysicsEvents`
/// subscribers and fires the corresponding USC script events.
///
/// USC wiring (runs once per event, on both involved entities):
/// - `contactBegan` → `OnCollision`, plus `OnCollision:<name>` when the *other*
///   entity has an explicit name (the builder's `onCollision(tag:)` form).
/// - `triggerEntered`/`triggerExited` → `OnTriggerEnter`/`OnTriggerExit` on the
///   trigger and the other entity, with the same named-tag variants.
final class PhysicsEventDispatchSink: PhysicsEventSink {
    func receiveContact(_ event: PhysicsContactEvent) {
        PhysicsEvents.shared.dispatchContact(event)

        if event.phase == .began {
            fireScriptEvent("OnCollision", on: event.entityA, other: event.entityB)
            fireScriptEvent("OnCollision", on: event.entityB, other: event.entityA)
        }
    }

    func receiveTrigger(_ event: PhysicsTriggerEvent) {
        PhysicsEvents.shared.dispatchTrigger(event)

        let name = event.phase == .entered ? "OnTriggerEnter" : "OnTriggerExit"
        fireScriptEvent(name, on: event.triggerEntity, other: event.otherEntity)
        fireScriptEvent(name, on: event.otherEntity, other: event.triggerEntity)
    }

    func receiveActivation(_ event: PhysicsBodyActivationEvent) {
        PhysicsEvents.shared.dispatchActivation(event)
    }

    func reportDroppedEvents(count: Int) {
        PhysicsEvents.shared.recordDroppedEvents(count: count)
    }

    private func fireScriptEvent(_ eventName: String, on entityId: EntityID, other: EntityID) {
        USCSystem.shared.triggerEvent(eventName, for: entityId)
        if let otherName = entityNameMap[other], !otherName.isEmpty {
            USCSystem.shared.triggerEvent("\(eventName):\(otherName)", for: entityId)
        }
    }
}
