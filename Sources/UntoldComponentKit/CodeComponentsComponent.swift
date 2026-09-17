//
//  CodeComponentsComponent.swift
//  UntoldComponentKit
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import UntoldEngine

/// The single engine component behind every code component on an entity.
///
/// Engine component IDs are keyed by the Swift type's identity, and a reloaded library brings
/// new types, so one engine component per user type would consume a mask slot per reload.
/// Instead each entity carries one of these, holding a slot per code component. A slot keeps
/// its saved payload even when its type is not loaded, so a scene opened without the library
/// saves back unchanged.
public final class CodeComponentsComponent: Component, Codable {
    public struct Slot {
        public var typeName: String
        /// The values as last saved or snapshotted. Authoritative only while `instance` is nil.
        public var payload: [String: UntoldAttributeValue]
        /// The live component, once its type is registered.
        public internal(set) var instance: CodeComponent?

        public init(typeName: String, payload: [String: UntoldAttributeValue] = [:]) {
            self.typeName = typeName
            self.payload = payload
            instance = nil
        }
    }

    public var slots: [Slot] = []

    public required init() {}

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case components
    }

    private struct StoredSlot: Codable {
        var type: String
        var properties: [String: UntoldAttributeValue]
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let stored = try container.decodeIfPresent([StoredSlot].self, forKey: .components) ?? []
        slots = stored.map { Slot(typeName: $0.type, payload: $0.properties) }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let stored = slots.map { slot in
            StoredSlot(type: slot.typeName, properties: slot.instance?.attributePayload() ?? slot.payload)
        }
        try container.encode(stored, forKey: .components)
    }
}
