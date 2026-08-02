//
//  EntityLifecycleEvents.swift
//  UntoldEngine
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public struct EntityCreatedEvent: Sendable {
    public let entityId: EntityID

    public init(entityId: EntityID) {
        self.entityId = entityId
    }
}

public struct EntityDestroyedEvent: Sendable {
    public let entityId: EntityID

    public init(entityId: EntityID) {
        self.entityId = entityId
    }
}

public final class EntityLifecycleEvents: @unchecked Sendable {
    public static let shared = EntityLifecycleEvents()

    private let lock = NSLock()
    private var createdHandlers: [UUID: (EntityCreatedEvent) -> Void] = [:]
    private var destroyedHandlers: [UUID: (EntityDestroyedEvent) -> Void] = [:]

    private init() {}

    public func onEntityCreated(
        _ handler: @escaping (EntityCreatedEvent) -> Void
    ) -> EventSubscription {
        let id = UUID()
        lock.lock()
        createdHandlers[id] = handler
        lock.unlock()
        return EventSubscription { [weak self] in
            self?.unsubscribeCreated(id)
        }
    }

    public func onEntityDestroyed(
        _ handler: @escaping (EntityDestroyedEvent) -> Void
    ) -> EventSubscription {
        let id = UUID()
        lock.lock()
        destroyedHandlers[id] = handler
        lock.unlock()
        return EventSubscription { [weak self] in
            self?.unsubscribeDestroyed(id)
        }
    }

    func dispatchEntityCreated(_ entityId: EntityID) {
        let event = EntityCreatedEvent(entityId: entityId)
        lock.lock()
        let handlers = Array(createdHandlers.values)
        lock.unlock()
        for handler in handlers {
            handler(event)
        }
    }

    func dispatchEntityDestroyed(_ entityId: EntityID) {
        let event = EntityDestroyedEvent(entityId: entityId)
        lock.lock()
        let handlers = Array(destroyedHandlers.values)
        lock.unlock()
        for handler in handlers {
            handler(event)
        }
    }

    func reset() {
        lock.lock()
        createdHandlers.removeAll()
        destroyedHandlers.removeAll()
        lock.unlock()
    }

    private func unsubscribeCreated(_ id: UUID) {
        lock.lock()
        createdHandlers.removeValue(forKey: id)
        lock.unlock()
    }

    private func unsubscribeDestroyed(_ id: UUID) {
        lock.lock()
        destroyedHandlers.removeValue(forKey: id)
        lock.unlock()
    }
}
