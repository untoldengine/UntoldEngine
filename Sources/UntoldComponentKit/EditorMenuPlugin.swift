//
//  EditorMenuPlugin.swift
//  UntoldComponentKit
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// One reflected `@UntoldMenu`: the property's name plus the wrapper that holds it.
public struct UntoldMenuEntry {
    public let name: String
    public let menu: AnyUntoldMenu
}

/// A problem with a menu plugin's declarations, found before anything is built.
public enum UntoldMenuIssue: Equatable, Sendable {
    /// The path has no title segment.
    case emptyPath(property: String)
    /// Two items resolve to the same domain and path.
    case duplicate(identifier: String)
}

/// Base class for what a loaded library adds to the editor's menus, and to the editor itself.
///
/// Declare menu items with `@UntoldMenu` properties. The editor discovers subclasses the same
/// way it discovers the other plugins, creates one instance when the library loads, puts the
/// items under its own root menus, and drives the callbacks below. A game never instantiates
/// one, so a menu plugin may sit next to components in the same folder; wrap it in
/// `#if UNTOLD_EDITOR` to keep it out of the game binary altogether.
open class EditorMenuPlugin {
    public required init() {}

    public static var typeName: String {
        String(describing: self)
    }

    open class var displayName: String {
        humanizedIdentifier(typeName)
    }

    // MARK: Lifecycle

    /// The library was loaded and persisted menu values were restored.
    open func onLoad() {}
    /// The library is being replaced or its project closed. Undo what `onLoad` did.
    open func onUnload() {}
    /// A scene was loaded or cleared, or the project switched: entity IDs are no longer valid.
    open func onSceneReset() {}
    open func onPlayModeChanged(_: Bool) {}
    /// Once per frame while not playing.
    open func onEditorUpdate(deltaTime _: Float) {}

    // MARK: Menus

    /// A menu holding this plugin's items is about to open. Refresh wrapped values from
    /// outside state here so checkmarks stay truthful.
    open func menuWillOpen() {}
    /// The user changed a toggle or a choice, or a persisted value was restored at load.
    open func menuDidChange(_: UntoldMenuDomain, _: String) {}

    /// Every `@UntoldMenu` property, superclass first, in declaration order.
    public final func untoldMenuItems() -> [UntoldMenuEntry] {
        var chain: [Mirror] = []
        var mirror: Mirror? = Mirror(reflecting: self)
        while let current = mirror {
            chain.append(current)
            mirror = current.superclassMirror
        }

        var entries: [UntoldMenuEntry] = []
        for level in chain.reversed() {
            for child in level.children {
                guard let rawLabel = child.label, let menu = child.value as? AnyUntoldMenu else { continue }
                let name = rawLabel.hasPrefix("_") ? String(rawLabel.dropFirst()) : rawLabel
                entries.append(UntoldMenuEntry(name: name, menu: menu))
            }
        }
        return entries
    }

    /// Checks a set of entries, from one menu plugin or several, for declarations the menu host
    /// must refuse.
    public static func validate(_ entries: [UntoldMenuEntry]) -> [UntoldMenuIssue] {
        var issues: [UntoldMenuIssue] = []
        var seen: Set<String> = []
        for entry in entries {
            if entry.menu.pathComponents.isEmpty {
                issues.append(.emptyPath(property: entry.name))
                continue
            }
            if seen.insert(entry.menu.identifier).inserted == false {
                issues.append(.duplicate(identifier: entry.menu.identifier))
            }
        }
        return issues
    }
}
