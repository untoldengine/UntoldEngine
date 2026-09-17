//
//  EditorMenuPluginRegistry.swift
//  UntoldComponentKit
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import UntoldEngine

/// The menu plugin types known to the process, keyed by unqualified type name.
/// Only the editor instantiates them; a game never does.
public final class EditorMenuPluginRegistry: @unchecked Sendable {
    public static let shared = EditorMenuPluginRegistry()

    public struct Entry {
        public let name: String
        public let type: EditorMenuPlugin.Type
        public let revision: Int
    }

    private let lock = NSLock()
    private var entriesByName: [String: Entry] = [:]

    private init() {}

    /// Registers `type`. With `replaceExisting`, a different type under the same name takes
    /// over, which is what loading a new library revision wants; otherwise it is refused.
    @discardableResult
    public func register(_ type: EditorMenuPlugin.Type, revision: Int = 0, replaceExisting: Bool = false) -> Bool {
        let name = type.typeName
        lock.lock()
        defer { lock.unlock() }
        if let existing = entriesByName[name], existing.type != type, replaceExisting == false {
            Logger.logError(
                message: "[ComponentKit] A different menu plugin named '\(name)' is already registered; the new one was ignored.",
                category: LogCategory.general.rawValue
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

    public func type(named name: String) -> EditorMenuPlugin.Type? {
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

    /// Registers every `EditorMenuPlugin` subclass defined in the image at `imagePath` and
    /// returns the names it registered.
    @discardableResult
    public func discover(imagePath: String, revision: Int = 0, replaceExisting: Bool = false) -> [String] {
        let classes = ImageDiscovery.classes(inImageAt: imagePath, inheritingFrom: EditorMenuPlugin.self)
        let types = classes.compactMap { $0 as? EditorMenuPlugin.Type }.sorted { $0.typeName < $1.typeName }
        return types.filter { register($0, revision: revision, replaceExisting: replaceExisting) }.map(\.typeName)
    }
}
