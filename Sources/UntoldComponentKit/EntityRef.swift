//
//  EntityRef.swift
//  UntoldComponentKit
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import UntoldEngine

/// A reference to another entity, stored by entity name.
///
/// Entity IDs are not stable across a save and load, and the scene file's per-entity UUIDs are
/// regenerated on every save, so the name is the only identity that survives today.
public struct EntityRef: Equatable, Sendable {
    public var name: String

    public init(_ name: String = "") {
        self.name = name
    }

    public var isEmpty: Bool {
        name.isEmpty
    }

    /// The entity currently carrying `name`, if any.
    public func resolve() -> EntityID? {
        guard name.isEmpty == false else { return nil }
        return findEntity(name: name)
    }
}

extension EntityRef: UntoldAttributeValueType {
    public var attributeKind: UntoldAttributeKind {
        .entity
    }

    public var attributeValue: UntoldAttributeValue {
        .object(["entity": name])
    }

    public func applying(_ value: UntoldAttributeValue) -> EntityRef? {
        guard case let .object(fields) = value, let name = fields["entity"] else { return nil }
        return EntityRef(name)
    }
}
