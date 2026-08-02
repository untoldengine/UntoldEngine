//
//  EngineExtensions.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// Frame identity data handed to `EngineExtension` lifecycle callbacks.
public struct EngineExtensionUpdateContext: Sendable {
    public let viewport: SIMD2<Int>
    public let immersionStyle: UntoldImmersionMode
    public let frameIndex: UInt64
    public let currentEye: Int
    public let isPrimaryEye: Bool

    public init(
        viewport: SIMD2<Int>,
        immersionStyle: UntoldImmersionMode,
        frameIndex: UInt64,
        currentEye: Int,
        isPrimaryEye: Bool
    ) {
        self.viewport = viewport
        self.immersionStyle = immersionStyle
        self.frameIndex = frameIndex
        self.currentEye = currentEye
        self.isPrimaryEye = isPrimaryEye
    }
}

/// A plugin that needs a per-frame lifecycle callback without owning any render-graph
/// surface. `RenderExtension` refines this protocol, so a plugin that is both a
/// simulation system and a render extension registers once with `RenderExtensionRegistry`
/// and is ticked once — it should never also register with `EngineExtensionRegistry`.
public protocol EngineExtension: AnyObject, Sendable {
    var id: String { get }

    func update(deltaTime: Float, context: EngineExtensionUpdateContext)

    func fixedUpdate(deltaTime: Float, context: EngineExtensionUpdateContext)

    func willUnregister()
}

public extension EngineExtension {
    func update(deltaTime _: Float, context _: EngineExtensionUpdateContext) {}
    func fixedUpdate(deltaTime _: Float, context _: EngineExtensionUpdateContext) {}
    func willUnregister() {}
}

/// Reports whether a registration created a new entry or replaced an existing one.
public enum EngineExtensionRegistrationResult: Equatable, Sendable {
    case registered
    case replaced
}

/// Installs and removes non-rendering plugin lifecycle participants.
///
/// Dispatch order for `update`/`fixedUpdate` is registration order. Registering a new
/// instance under an `id` that is already registered replaces it, calling
/// `willUnregister()` on the previous instance first.
public final class EngineExtensionRegistry: @unchecked Sendable {
    public static let shared = EngineExtensionRegistry()

    private let lock = NSLock()
    private let lifecycleLock = NSRecursiveLock()
    private var extensionsByID: [String: any EngineExtension] = [:]
    private var extensionOrder: [String] = []

    private init() {}

    @discardableResult
    public func register(_ extensionInstance: any EngineExtension) -> EngineExtensionRegistrationResult {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        lock.lock()
        let previousExtension = extensionsByID[extensionInstance.id]
        if previousExtension == nil {
            extensionOrder.append(extensionInstance.id)
        }
        extensionsByID[extensionInstance.id] = extensionInstance
        lock.unlock()

        if let previousExtension, previousExtension !== extensionInstance {
            previousExtension.willUnregister()
        }

        return previousExtension == nil ? .registered : .replaced
    }

    public func unregister(id: String) {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        lock.lock()
        let removedExtension = extensionsByID.removeValue(forKey: id)
        extensionOrder.removeAll { $0 == id }
        lock.unlock()

        removedExtension?.willUnregister()
    }

    public func removeAll() {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        lock.lock()
        let removedExtensions = extensionOrder.compactMap { extensionsByID[$0] }
        extensionsByID.removeAll()
        extensionOrder.removeAll()
        lock.unlock()

        for extensionInstance in removedExtensions {
            extensionInstance.willUnregister()
        }
    }

    public func registeredIDs() -> [String] {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        lock.lock()
        let ids = extensionOrder
        lock.unlock()
        return ids
    }

    public func updateExtensions(deltaTime: Float, context: EngineExtensionUpdateContext) {
        for extensionInstance in orderedExtensionsSnapshot() {
            extensionInstance.update(deltaTime: deltaTime, context: context)
        }
    }

    public func fixedUpdateExtensions(deltaTime: Float, context: EngineExtensionUpdateContext) {
        for extensionInstance in orderedExtensionsSnapshot() {
            extensionInstance.fixedUpdate(deltaTime: deltaTime, context: context)
        }
    }

    private func orderedExtensionsSnapshot() -> [any EngineExtension] {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        lock.lock()
        let orderedExtensions = extensionOrder.compactMap { extensionsByID[$0] }
        lock.unlock()
        return orderedExtensions
    }
}
