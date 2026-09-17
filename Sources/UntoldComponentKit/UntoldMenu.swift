//
//  UntoldMenu.swift
//  UntoldComponentKit
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// The editor's root menus. The set is closed on purpose: loaded code picks one of these and
/// can never create a root menu of its own.
public enum UntoldMenuDomain: String, CaseIterable, Sendable {
    case file
    case view
    /// Shown by the editor only while it holds at least one item.
    case debug
    /// Shown by the editor only while it holds at least one item.
    case tools

    public var rootTitle: String {
        switch self {
        case .file: "File"
        case .view: "View"
        case .debug: "Debug"
        case .tools: "Tools"
        }
    }
}

/// One entry of a choice menu.
public struct UntoldMenuChoice: Equatable, Sendable {
    public let rawValue: String
    public let title: String
}

public enum UntoldMenuKind: Equatable, Sendable {
    /// A checkmark item.
    case toggle
    /// A submenu with one radio item per choice.
    case choice([UntoldMenuChoice])
    /// A command.
    case action
}

/// The state of a toggle or a choice, as the editor reads, writes and persists it.
public enum UntoldMenuValue: Equatable, Sendable {
    case bool(Bool)
    case choice(String)
}

/// Gives the cases of a choice enum titles other than their raw values.
public protocol UntoldMenuTitled {
    var menuTitle: String { get }
}

/// A command menu item.
///
///     @UntoldMenu(.debug, "Splat Twin/Reset Link Adoption")
///     var resetAdoption = UntoldMenuAction { GaussianTwinSystem.shared.resetSceneLinkAdoption() }
public struct UntoldMenuAction {
    private let body: (EditorExtension) -> Void

    public init(_ body: @escaping () -> Void) {
        self.body = { _ in body() }
    }

    /// For commands that need the extension that declared them.
    public init(_ body: @escaping (EditorExtension) -> Void) {
        self.body = body
    }

    public func perform(owner: EditorExtension) {
        body(owner)
    }
}

/// The type-erased face of an `@UntoldMenu`, which is what reflection hands out.
public protocol AnyUntoldMenu: AnyObject {
    var domain: UntoldMenuDomain { get }
    /// As written in the declaration.
    var path: String { get }
    var keyEquivalent: String { get }
    var tooltip: String? { get }
    /// Whether the editor saves the value per project and restores it on load.
    var persists: Bool { get }
    var kind: UntoldMenuKind { get }
    /// `nil` for actions.
    var menuValue: UntoldMenuValue? { get }
    @discardableResult func setMenuValue(_ value: UntoldMenuValue) -> Bool
    /// Evaluated when the menu opens.
    var isEnabled: Bool { get }
    /// Runs an action item; a no-op for toggles and choices.
    func perform(owner: EditorExtension)
}

public extension AnyUntoldMenu {
    /// Submenu names followed by the item title. Empty segments are ignored.
    var pathComponents: [String] {
        path.split(separator: "/")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.isEmpty == false }
    }

    var title: String {
        pathComponents.last ?? ""
    }

    var submenuPath: [String] {
        Array(pathComponents.dropLast())
    }

    /// Unique per item: the domain plus the normalized path. Also the persistence key suffix.
    var identifier: String {
        ([domain.rawValue] + pathComponents).joined(separator: "/")
    }
}

/// Declares an editor menu item on an `EditorExtension`.
///
/// The first argument is the root menu, from a closed set. The second is the item title,
/// optionally preceded by submenu names separated by `/`. It never names a root.
///
///     @UntoldMenu(.view, "Preview Splat Twins") var previewTwins = true              // toggle
///     @UntoldMenu(.debug, "Splat Twin/Blend Cap") var blendCap: BlendCap = .c64        // radio submenu
///     @UntoldMenu(.debug, "Splat Twin/Reset") var reset = UntoldMenuAction { ... }     // command
@propertyWrapper
public final class UntoldMenu<Value>: AnyUntoldMenu {
    public var wrappedValue: Value
    public var projectedValue: UntoldMenu<Value> {
        self
    }

    public let domain: UntoldMenuDomain
    public let path: String
    public let keyEquivalent: String
    public let tooltip: String?
    public let persists: Bool
    public let kind: UntoldMenuKind

    private let enabled: (() -> Bool)?
    private let read: (Value) -> UntoldMenuValue?
    private let write: (UntoldMenuValue) -> Value?
    private let run: (Value, EditorExtension) -> Void

    private init(
        value: Value,
        domain: UntoldMenuDomain,
        path: String,
        key: String,
        tooltip: String?,
        persist: Bool,
        enabled: (() -> Bool)?,
        kind: UntoldMenuKind,
        read: @escaping (Value) -> UntoldMenuValue?,
        write: @escaping (UntoldMenuValue) -> Value?,
        run: @escaping (Value, EditorExtension) -> Void
    ) {
        wrappedValue = value
        self.domain = domain
        self.path = path
        keyEquivalent = key
        self.tooltip = tooltip
        persists = persist
        self.enabled = enabled
        self.kind = kind
        self.read = read
        self.write = write
        self.run = run
    }

    public var menuValue: UntoldMenuValue? {
        read(wrappedValue)
    }

    @discardableResult
    public func setMenuValue(_ value: UntoldMenuValue) -> Bool {
        guard let decoded = write(value) else { return false }
        wrappedValue = decoded
        return true
    }

    public var isEnabled: Bool {
        enabled?() ?? true
    }

    public func perform(owner: EditorExtension) {
        run(wrappedValue, owner)
    }
}

public extension UntoldMenu {
    /// A toggle with a checkmark.
    convenience init(
        wrappedValue: Value,
        _ domain: UntoldMenuDomain,
        _ path: String,
        key: String = "",
        tooltip: String? = nil,
        persist: Bool = true,
        enabled: (() -> Bool)? = nil
    ) where Value == Bool {
        self.init(
            value: wrappedValue, domain: domain, path: path, key: key, tooltip: tooltip,
            persist: persist, enabled: enabled, kind: .toggle,
            read: { .bool($0) },
            write: { value in
                guard case let .bool(flag) = value else { return nil }
                return flag
            },
            run: { _, _ in }
        )
    }

    /// A submenu with one radio item per case of a `String`-backed `CaseIterable` enum.
    convenience init(
        wrappedValue: Value,
        _ domain: UntoldMenuDomain,
        _ path: String,
        tooltip: String? = nil,
        persist: Bool = true,
        enabled: (() -> Bool)? = nil
    ) where Value: RawRepresentable & CaseIterable, Value.RawValue == String {
        let choices = Value.allCases.map { option in
            UntoldMenuChoice(rawValue: option.rawValue, title: (option as? UntoldMenuTitled)?.menuTitle ?? option.rawValue)
        }
        self.init(
            value: wrappedValue, domain: domain, path: path, key: "", tooltip: tooltip,
            persist: persist, enabled: enabled, kind: .choice(choices),
            read: { .choice($0.rawValue) },
            write: { value in
                guard case let .choice(rawValue) = value else { return nil }
                return Value(rawValue: rawValue)
            },
            run: { _, _ in }
        )
    }

    /// A command.
    convenience init(
        wrappedValue: Value,
        _ domain: UntoldMenuDomain,
        _ path: String,
        key: String = "",
        tooltip: String? = nil,
        enabled: (() -> Bool)? = nil
    ) where Value == UntoldMenuAction {
        self.init(
            value: wrappedValue, domain: domain, path: path, key: key, tooltip: tooltip,
            persist: false, enabled: enabled, kind: .action,
            read: { _ in nil },
            write: { _ in nil },
            run: { action, owner in action.perform(owner: owner) }
        )
    }
}
