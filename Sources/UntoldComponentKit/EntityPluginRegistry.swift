//
//  EntityPluginRegistry.swift
//  UntoldComponentKit
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import UntoldEngine

/// The kinds of entity known to the process, keyed by unqualified type name.
public final class EntityPluginRegistry: @unchecked Sendable {
    public static let shared = EntityPluginRegistry()

    public struct Entry {
        public let name: String
        public let type: EntityPlugin.Type
        /// The library revision that provided the type; 0 for statically linked types.
        public let revision: Int
    }

    private let lock = NSLock()
    private var entriesByName: [String: Entry] = [:]

    private init() {}

    /// Registers `type`. With `replaceExisting`, a different type under the same name takes
    /// over, which is what loading a new library revision wants; otherwise it is refused.
    @discardableResult
    public func register(_ type: EntityPlugin.Type, revision: Int = 0, replaceExisting: Bool = false) -> Bool {
        let name = type.typeName
        lock.lock()
        let existing = entriesByName[name]
        if let existing, existing.type != type, replaceExisting == false {
            lock.unlock()
            Logger.logError(
                message: "[ComponentKit] A different entity plugin named '\(name)' is already registered; the new one was ignored.",
                category: LogCategory.ecs.rawValue
            )
            return false
        }
        entriesByName[name] = Entry(name: name, type: type, revision: revision)
        lock.unlock()

        if let existing, existing.type != type {
            USCBridge.unregisterActions(for: existing.type)
        }
        USCBridge.registerActions(for: type)
        ScenePluginSystem.shared.setNeedsBind()
        return true
    }

    public func unregister(name: String) {
        lock.lock()
        let removed = entriesByName.removeValue(forKey: name)
        lock.unlock()
        if let removed {
            USCBridge.unregisterActions(for: removed.type)
        }
    }

    public func removeAll() {
        lock.lock()
        let removed = Array(entriesByName.values)
        entriesByName.removeAll()
        lock.unlock()
        for entry in removed {
            USCBridge.unregisterActions(for: entry.type)
        }
    }

    public func type(named name: String) -> EntityPlugin.Type? {
        lock.lock()
        defer { lock.unlock() }
        return entriesByName[name]?.type
    }

    /// Every registered kind, sorted by display name.
    public var entries: [Entry] {
        lock.lock()
        defer { lock.unlock() }
        return entriesByName.values.sorted { $0.type.displayName < $1.type.displayName }
    }

    public func entries(on shelf: UntoldEntityShelf) -> [Entry] {
        entries.filter { $0.type.shelf == shelf }
    }

    /// Registers every `EntityPlugin` subclass defined in the image at `imagePath` and returns
    /// the names it registered.
    @discardableResult
    public func discover(imagePath: String, revision: Int = 0, replaceExisting: Bool = false) -> [String] {
        let classes = ImageDiscovery.classes(inImageAt: imagePath, inheritingFrom: EntityPlugin.self)
        let types = classes.compactMap { $0 as? EntityPlugin.Type }.sorted { $0.typeName < $1.typeName }
        return types.filter { register($0, revision: revision, replaceExisting: replaceExisting) }.map(\.typeName)
    }

    // MARK: Creating entities

    /// Creates an entity of the named kind: a new entity, named, with the plugin bound
    /// (`onAttach`), told it is new (`onCreate`), then moved to `position`. This is what the
    /// editor's shelves do, and a game can do the same. Returns `nil` for an unknown kind.
    @discardableResult
    public func instantiate(_ name: String, at position: SIMD3<Float>? = nil, entityName: String? = nil) -> EntityID? {
        guard let type = type(named: name) else { return nil }
        ScenePluginSystem.install()
        let entity = createEntity()
        setEntityName(entityId: entity, name: entityName ?? type.displayName)
        ScenePluginSystem.shared.setEntityPlugin(name, on: entity)?.onCreate()
        if let position {
            translateTo(entityId: entity, position: position)
        }
        return entity
    }

    /// Creates an entity of kind `type`, registering the type if needed, and returns its plugin.
    @discardableResult
    public func instantiate<T: EntityPlugin>(_ type: T.Type, at position: SIMD3<Float>? = nil, entityName: String? = nil) -> T? {
        guard register(type) else { return nil }
        guard let entity = instantiate(T.typeName, at: position, entityName: entityName) else { return nil }
        return Self.plugin(type, on: entity)
    }

    // MARK: Queries

    /// The plugin of `entityId`, if the entity is of kind `type`.
    public static func plugin<T: EntityPlugin>(_: T.Type, on entityId: EntityID) -> T? {
        ScenePluginSystem.shared.entityPlugin(on: entityId) as? T
    }

    /// Entities of kind `type`, sorted by entity ID.
    public static func entities<T: EntityPlugin>(of _: T.Type) -> [EntityID] {
        ScenePluginSystem.shared.entities(withEntityPluginNamed: T.typeName)
    }
}
