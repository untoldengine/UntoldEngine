//
//  CodeComponentRegistry.swift
//  UntoldComponentKit
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import UntoldEngine

/// The component types known to the process, keyed by unqualified type name.
///
/// The name, not the Swift type, is the identity: a reloaded library registers new types
/// under the same names and takes over the saved data of the old ones.
public final class CodeComponentRegistry: @unchecked Sendable {
    public static let shared = CodeComponentRegistry()

    public struct Entry {
        public let name: String
        public let type: CodeComponent.Type
        /// The library revision that provided the type; 0 for statically linked types.
        public let revision: Int
    }

    public enum RegistrationPolicy: Sendable {
        /// A different type under an existing name is refused. Use for static registration.
        case rejectDuplicates
        /// A different type under an existing name replaces it. Use when loading a new revision.
        case replace
    }

    public enum RegistrationResult: Equatable, Sendable {
        case registered
        case replaced
        /// The very same type was already registered.
        case unchanged
        /// A different type already owns the name and the policy forbids replacing it.
        case rejectedDuplicate
    }

    public struct DiscoveryReport: Equatable, Sendable {
        public var registered: [String] = []
        public var replaced: [String] = []
        public var rejected: [String] = []

        public init() {}
    }

    private let lock = NSLock()
    private var entriesByName: [String: Entry] = [:]

    private init() {}

    // MARK: Registration

    @discardableResult
    public func register(
        _ type: CodeComponent.Type,
        revision: Int = 0,
        policy: RegistrationPolicy = .rejectDuplicates
    ) -> RegistrationResult {
        let name = type.typeName

        lock.lock()
        let existing = entriesByName[name]
        if let existing, existing.type == type {
            lock.unlock()
            return .unchanged
        }
        if existing != nil, policy == .rejectDuplicates {
            lock.unlock()
            Logger.logError(
                message: "[ComponentKit] A different component type named '\(name)' is already registered; the new one was ignored.",
                category: LogCategory.ecs.rawValue
            )
            return .rejectedDuplicate
        }
        entriesByName[name] = Entry(name: name, type: type, revision: revision)
        lock.unlock()

        if let existing {
            USCBridge.unregisterActions(for: existing.type)
        }
        USCBridge.registerActions(for: type)
        CodeComponentSystem.shared.setNeedsBind()
        return existing == nil ? .registered : .replaced
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

    // MARK: Lookup

    public func type(named name: String) -> CodeComponent.Type? {
        lock.lock()
        defer { lock.unlock() }
        return entriesByName[name]?.type
    }

    /// Every registered type, sorted by name.
    public var entries: [Entry] {
        lock.lock()
        defer { lock.unlock() }
        return entriesByName.values.sorted { $0.name < $1.name }
    }

    /// The types an editor may offer for any entity: every registered type except the ones
    /// that are part of a kind of entity (`ComponentAttachment.entityKindOnly`).
    public var attachableEntries: [Entry] {
        entries.filter { $0.type.attachment == .anyEntity }
    }

    // MARK: Discovery

    /// Registers every `CodeComponent` subclass defined in the image at `imagePath`.
    @discardableResult
    public func discover(
        imagePath: String,
        revision: Int = 0,
        policy: RegistrationPolicy = .rejectDuplicates
    ) -> DiscoveryReport {
        var report = DiscoveryReport()
        let classes = ImageDiscovery.classes(inImageAt: imagePath, inheritingFrom: CodeComponent.self)
        let types = classes.compactMap { $0 as? CodeComponent.Type }.sorted { $0.typeName < $1.typeName }
        for type in types {
            switch register(type, revision: revision, policy: policy) {
            case .registered: report.registered.append(type.typeName)
            case .replaced: report.replaced.append(type.typeName)
            case .rejectedDuplicate: report.rejected.append(type.typeName)
            case .unchanged: break
            }
        }
        return report
    }

    /// Registers the component types, and the entity templates, that are part of the app: those in its main executable,
    /// in the debug dylib Xcode splits an app's code into, and in frameworks embedded in its
    /// bundle. Call once at startup, before loading scenes.
    @discardableResult
    public func discoverInApp() -> DiscoveryReport {
        var report = DiscoveryReport()
        for path in ImageDiscovery.appImagePaths() {
            let found = discover(imagePath: path)
            report.registered += found.registered
            report.replaced += found.replaced
            report.rejected += found.rejected
        }
        var templates: [String] = []
        for path in ImageDiscovery.appImagePaths() {
            templates += EntityTemplateRegistry.shared.discover(imagePath: path)
        }
        let names = report.registered + report.replaced
        Logger.log(
            message: names.isEmpty
                ? "[ComponentKit] No code component types found in the app."
                : "[ComponentKit] Code component types in the app: \(names.joined(separator: ", "))",
            category: LogCategory.ecs.rawValue
        )
        if templates.isEmpty == false {
            Logger.log(
                message: "[ComponentKit] Entity templates in the app: \(templates.joined(separator: ", "))",
                category: LogCategory.ecs.rawValue
            )
        }
        return report
    }

    /// Registers the component types defined in the same image as `cls`.
    @discardableResult
    public func discover(
        imageContaining cls: AnyClass,
        revision: Int = 0,
        policy: RegistrationPolicy = .rejectDuplicates
    ) -> DiscoveryReport {
        guard let path = ImageDiscovery.imagePath(containing: cls) else { return DiscoveryReport() }
        return discover(imagePath: path, revision: revision, policy: policy)
    }

    // MARK: Queries

    /// Entities that currently carry a live `type`, sorted by entity ID.
    public static func entities<T: CodeComponent>(with _: T.Type) -> [EntityID] {
        CodeComponentSystem.shared.entities(withComponentNamed: T.typeName)
    }

    /// The live `type` on `entityId`, if any.
    public static func component<T: CodeComponent>(_: T.Type, on entityId: EntityID) -> T? {
        CodeComponentSystem.shared.component(named: T.typeName, on: entityId) as? T
    }
}
