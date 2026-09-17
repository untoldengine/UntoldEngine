//
//  CodeComponent.swift
//  UntoldComponentKit
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import UntoldEngine

/// One reflected `@UntoldAttribute`: the property's name plus the wrapper that holds it.
public struct UntoldAttributeEntry {
    /// The Swift property name, which is also the key the value is saved under.
    public let name: String
    public let attribute: AnyUntoldAttribute

    /// The label to show: the one given in the declaration, or the property name spelled out.
    public var displayLabel: String {
        attribute.label.isEmpty ? humanizedIdentifier(name) : attribute.label
    }
}

/// What happened when a saved payload was applied to a component.
public struct UntoldAttributeApplyReport: Equatable, Sendable {
    /// Properties that took their value from the payload.
    public var applied: [String] = []
    /// Declared properties the payload did not mention; they keep their default.
    public var missing: [String] = []
    /// Payload keys no property claims any more; they are discarded.
    public var dropped: [String] = []
    /// Payload values of the wrong shape for their property; the default is kept.
    public var rejected: [String] = []

    public init() {}
}

/// Base class for components written in code.
///
/// Subclass it (`final` recommended), mark what the editor should see with `@UntoldAttribute`,
/// and override the lifecycle methods you need. The kit constructs every instance with
/// `init()` and then applies the values saved in the scene, so subclasses give every stored
/// property a default and declare no initializer parameters.
open class CodeComponent {
    // Every member below that subclasses cannot override is `final`, and that is load-bearing.
    // A subclass compiled into another image copies this class's dispatch table, entries for
    // internal members and internal setters included, and so needs their symbols. Release
    // builds hide internal symbols, so a library loaded by the editor would fail to resolve
    // them. `final` members have no table entry. create_app_bundle.sh checks this.

    /// The entity this instance is attached to; `.invalid` until `onAttach()`.
    public internal(set) final var entity: EntityID = .invalid
    /// `true` between `onAttach()` and `onDetach()`.
    public internal(set) final var isAttached: Bool = false
    final var hasStarted: Bool = false

    public required init() {}

    /// The unqualified Swift type name. It is the identity saved in scenes and the key types
    /// are re-bound under after a reload, so renaming a component orphans its saved data.
    public static var typeName: String {
        String(describing: self)
    }

    /// The name the editor shows. Defaults to the type name spelled out.
    open class var displayName: String {
        humanizedIdentifier(typeName)
    }

    /// Functions exposed as editor buttons and USC actions.
    open class var actions: [ComponentAction] {
        []
    }

    /// What the editor draws for an entity carrying this component when it has no shape of its
    /// own. Declared here, not on the template that created the entity, because the component
    /// is what is still there after the scene is saved, loaded, or the library reloaded.
    open class var editorRepresentation: EditorRepresentation {
        .none
    }

    // MARK: Lifecycle

    /// The instance was bound to `entity`, in edit mode or in play.
    open func onAttach() {}
    /// Play began, or the instance was attached while playing.
    open func onStart() {}
    /// Once per rendered frame while playing.
    open func onUpdate(deltaTime _: Float) {}
    /// Once per fixed step while playing.
    open func onFixedUpdate(deltaTime _: Float) {}
    /// Play ended, or the instance is being detached while playing.
    open func onStop() {}
    /// The instance is leaving `entity`: removed, entity destroyed, or a reload is replacing it.
    open func onDetach() {}
    /// The editor wrote `property` while not playing.
    open func onEditorChanged(property _: String) {}

    // MARK: Conveniences

    /// The entity's local transform, if it has one.
    public final var transform: LocalTransformComponent? {
        guard scene.mask(for: entity) != nil else { return nil }
        return scene.get(component: LocalTransformComponent.self, for: entity)
    }

    // MARK: Reflection

    /// Every `@UntoldAttribute` property, superclass first, in declaration order.
    public final func untoldAttributes() -> [UntoldAttributeEntry] {
        var chain: [Mirror] = []
        var mirror: Mirror? = Mirror(reflecting: self)
        while let current = mirror {
            chain.append(current)
            mirror = current.superclassMirror
        }

        var entries: [UntoldAttributeEntry] = []
        for level in chain.reversed() {
            for child in level.children {
                guard let rawLabel = child.label, let attribute = child.value as? AnyUntoldAttribute else { continue }
                let name = rawLabel.hasPrefix("_") ? String(rawLabel.dropFirst()) : rawLabel
                entries.append(UntoldAttributeEntry(name: name, attribute: attribute))
            }
        }
        return entries
    }

    /// The current value of every attribute, keyed by property name.
    public final func attributePayload() -> [String: UntoldAttributeValue] {
        var payload: [String: UntoldAttributeValue] = [:]
        for entry in untoldAttributes() {
            payload[entry.name] = entry.attribute.attributeValue
        }
        return payload
    }

    /// Writes a saved payload into the attributes. Tolerant by design: a property the payload
    /// does not mention keeps its default, and a key nothing claims is reported and ignored.
    @discardableResult
    public final func applyAttributePayload(_ payload: [String: UntoldAttributeValue]) -> UntoldAttributeApplyReport {
        var report = UntoldAttributeApplyReport()
        var unclaimed = Set(payload.keys)
        for entry in untoldAttributes() {
            guard let value = payload[entry.name] else {
                report.missing.append(entry.name)
                continue
            }
            unclaimed.remove(entry.name)
            if entry.attribute.setAttributeValue(value) {
                report.applied.append(entry.name)
            } else {
                report.rejected.append(entry.name)
            }
        }
        report.dropped = unclaimed.sorted()
        return report
    }
}

/// `jumpHeight` → `Jump Height`, `HZBCull` → `HZB Cull`, `PlayerController2D` → `Player Controller 2D`.
public func humanizedIdentifier(_ identifier: String) -> String {
    let characters = Array(identifier)
    var result = ""
    for (index, character) in characters.enumerated() {
        if index > 0 {
            let previous = characters[index - 1]
            let next: Character? = index + 1 < characters.count ? characters[index + 1] : nil
            let lowerToUpper = previous.isLowercase && character.isUppercase
            let acronymEnd = previous.isUppercase && character.isUppercase && (next?.isLowercase ?? false)
            let letterToDigit = previous.isLetter && character.isNumber
            if lowerToUpper || acronymEnd || letterToDigit {
                result.append(" ")
            }
        }
        result.append(character)
    }
    return result.prefix(1).uppercased() + result.dropFirst()
}
