//
//  FrameEvents.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// Per-frame update event, delivered once per rendered frame regardless of `gameMode`.
/// Mirrors RealityKit's `SceneEvents.Update`.
public struct UpdateEvent {
    /// Seconds elapsed since the previous frame.
    public let deltaTime: TimeInterval
    /// The renderer that produced this frame.
    public let renderer: UntoldRenderer
}

/// Token returned by update subscriptions. Call `cancel()` to stop receiving events.
/// RealityKit semantics: the subscription stays active if you discard the token;
/// it is NOT auto-cancelled on deinit.
public final class EventSubscription: @unchecked Sendable {
    private let lock = NSLock()
    private var onCancel: (() -> Void)?

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    public func cancel() {
        lock.lock()
        let block = onCancel
        onCancel = nil
        lock.unlock()
        block?()
    }
}

/// Multicast registry for per-frame update handlers. Thread-safe: subscriptions can be
/// created or cancelled from any thread while frames dispatch from the frame thread.
final class FrameEventDispatcher: @unchecked Sendable {
    private let lock = NSLock()
    private var handlers: [UUID: (UpdateEvent) -> Void] = [:]

    func subscribe(_ handler: @escaping (UpdateEvent) -> Void) -> EventSubscription {
        let id = UUID()
        lock.lock()
        handlers[id] = handler
        lock.unlock()
        return EventSubscription { [weak self] in
            self?.unsubscribe(id)
        }
    }

    private func unsubscribe(_ id: UUID) {
        lock.lock()
        handlers.removeValue(forKey: id)
        lock.unlock()
    }

    var hasSubscribers: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !handlers.isEmpty
    }

    func dispatch(_ event: UpdateEvent) {
        // Snapshot under the lock, invoke outside it: handlers may subscribe or
        // cancel reentrantly without deadlocking. A handler cancelled mid-dispatch
        // may still receive the current frame's event.
        lock.lock()
        let snapshot = Array(handlers.values)
        lock.unlock()
        for handler in snapshot {
            handler(event)
        }
    }
}
