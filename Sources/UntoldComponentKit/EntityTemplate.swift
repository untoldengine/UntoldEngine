//
//  EntityTemplate.swift
//  UntoldComponentKit
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import UntoldEngine

/// Where the editor lists an entity template. The set is closed on purpose, like the menu
/// roots: loaded code picks a shelf and can never add one.
public enum UntoldEntityShelf: String, CaseIterable, Sendable {
    /// Next to Cube, Sphere and Plane: things with a shape of their own.
    case primitives
    /// Next to the built-in light types.
    case lights
    /// Everything else: markers, volumes, logic. Shown only while it holds something.
    case entities

    public var title: String {
        switch self {
        case .primitives: "Primitives"
        case .lights: "Lights"
        case .entities: "Entities"
        }
    }
}

/// A kind of entity that loaded code adds to the editor's creation shelves: a torus, a spawn
/// point, a rules object.
///
/// A template is only the recipe that runs once, when the entity is created. What the entity
/// *is* afterwards has to live in its components, because those are what the scene saves. So
/// the three sorts of entity come out like this:
///
/// - **No representation.** `build` adds code components and nothing else.
/// - **Editor-only representation.** One of those components overrides
///   `CodeComponent.editorRepresentation`; the editor draws it and the game never sees it.
/// - **A shape in the game.** A component builds the mesh in `onAttach`, with
///   `setGeneratedMesh`, so it comes back whenever the scene is loaded.
///
/// Subclasses are discovered like components. A game can use them too, through
/// `EntityTemplateRegistry.shared.instantiate(_:at:)`.
open class EntityTemplate {
    public required init() {}

    public static var typeName: String {
        String(describing: self)
    }

    /// The name on the shelf. Defaults to the type name spelled out, without a trailing
    /// "Entity" or "Template".
    open class var displayName: String {
        var name = typeName
        for suffix in ["EntityTemplate", "Template", "Entity"] where name.hasSuffix(suffix) && name.count > suffix.count {
            name = String(name.dropLast(suffix.count))
            break
        }
        return humanizedIdentifier(name)
    }

    open class var shelf: UntoldEntityShelf {
        .entities
    }

    /// An SF Symbol name for the shelf row.
    open class var systemImage: String {
        "cube.transparent"
    }

    /// Sets up the new entity. It exists, has a name and a transform, and is otherwise empty.
    open func build(_: EntityID) {}

    /// Adds a code component to the entity being built and returns it, ready to be given its
    /// starting values.
    @discardableResult
    public final func add<T: CodeComponent>(_ type: T.Type, to entity: EntityID) -> T? {
        CodeComponentSystem.shared.add(type, to: entity)
    }
}

/// The entity templates known to the process, keyed by unqualified type name.
public final class EntityTemplateRegistry: @unchecked Sendable {
    public static let shared = EntityTemplateRegistry()

    public struct Entry {
        public let name: String
        public let type: EntityTemplate.Type
        public let revision: Int
    }

    private let lock = NSLock()
    private var entriesByName: [String: Entry] = [:]

    private init() {}

    /// Registers `type`. With `replaceExisting`, a different type under the same name takes
    /// over, which is what loading a new library revision wants; otherwise it is refused.
    @discardableResult
    public func register(_ type: EntityTemplate.Type, revision: Int = 0, replaceExisting: Bool = false) -> Bool {
        let name = type.typeName
        lock.lock()
        defer { lock.unlock() }
        if let existing = entriesByName[name], existing.type != type, replaceExisting == false {
            Logger.logError(
                message: "[ComponentKit] A different entity template named '\(name)' is already registered; the new one was ignored.",
                category: LogCategory.ecs.rawValue
            )
            return false
        }
        entriesByName[name] = Entry(name: name, type: type, revision: revision)
        return true
    }

    public func unregister(name: String) {
        lock.lock()
        entriesByName.removeValue(forKey: name)
        lock.unlock()
    }

    public func removeAll() {
        lock.lock()
        entriesByName.removeAll()
        lock.unlock()
    }

    public func type(named name: String) -> EntityTemplate.Type? {
        lock.lock()
        defer { lock.unlock() }
        return entriesByName[name]?.type
    }

    /// Every registered template, sorted by display name.
    public var entries: [Entry] {
        lock.lock()
        defer { lock.unlock() }
        return entriesByName.values.sorted { $0.type.displayName < $1.type.displayName }
    }

    public func entries(on shelf: UntoldEntityShelf) -> [Entry] {
        entries.filter { $0.type.shelf == shelf }
    }

    /// Registers every `EntityTemplate` subclass defined in the image at `imagePath` and
    /// returns the names it registered.
    @discardableResult
    public func discover(imagePath: String, revision: Int = 0, replaceExisting: Bool = false) -> [String] {
        let classes = ImageDiscovery.classes(inImageAt: imagePath, inheritingFrom: EntityTemplate.self)
        let types = classes.compactMap { $0 as? EntityTemplate.Type }.sorted { $0.typeName < $1.typeName }
        return types.filter { register($0, revision: revision, replaceExisting: replaceExisting) }.map(\.typeName)
    }

    /// Creates an entity from the named template: a new entity, named, built, then moved to
    /// `position`. Returns `nil` when no such template is registered.
    @discardableResult
    public func instantiate(_ name: String, at position: SIMD3<Float>? = nil, entityName: String? = nil) -> EntityID? {
        guard let type = type(named: name) else { return nil }
        CodeComponentSystem.install()
        let entity = createEntity()
        setEntityName(entityId: entity, name: entityName ?? type.displayName)
        type.init().build(entity)
        if let position {
            translateTo(entityId: entity, position: position)
        }
        return entity
    }
}
