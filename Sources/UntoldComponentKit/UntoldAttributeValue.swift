//
//  UntoldAttributeValue.swift
//  UntoldComponentKit
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

/// A loosely typed, JSON-shaped value.
///
/// Attribute payloads are kept in this form so a scene can be loaded, held and saved again
/// before (or without) the component type that owns the payload being available. The typed
/// value is only produced when the payload is applied to a property of a known kind.
public enum UntoldAttributeValue: Equatable, Sendable {
    case number(Double)
    case bool(Bool)
    case string(String)
    case array([Double])
    case object([String: String])
}

extension UntoldAttributeValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Bool first: JSONDecoder never decodes a JSON number as Bool nor `true` as a number,
        // so the order only matters for decoders that are looser than JSON.
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([Double].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: String].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unsupported attribute value")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .number(value): try container.encode(value)
        case let .bool(value): try container.encode(value)
        case let .string(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case let .object(value): try container.encode(value)
        }
    }
}

/// What an attribute holds, which decides the control the editor draws for it.
public enum UntoldAttributeKind: Equatable, Sendable {
    case float
    case int
    case bool
    /// Single-line text.
    case string
    /// Multi-line text.
    case text
    case vector3
    case vector4
    /// A `SIMD4<Float>` edited as linear RGBA.
    case color
    /// A reference to another entity, stored by entity name.
    case entity
    /// A project-relative asset path; `category` is the asset browser folder it is picked from.
    case asset(category: String?)
    /// A `String`-backed enum; `cases` are the raw values in declaration order.
    case enumeration(cases: [String])
}

/// Presentation hints for kinds that can be drawn more than one way.
public enum UntoldAttributeStyle: Sendable {
    /// Draw a `SIMD4<Float>` as a color well.
    case color
    /// Draw a `String` as a multi-line text box.
    case multiline
}

/// A type `@UntoldAttribute` can wrap directly.
///
/// `String`-backed `CaseIterable` enums are supported without conforming to this protocol.
public protocol UntoldAttributeValueType {
    var attributeKind: UntoldAttributeKind { get }
    var attributeValue: UntoldAttributeValue { get }
    /// Returns a copy of `self` that holds `value`, or `nil` when `value` has the wrong shape.
    /// Instance-level so declaration metadata (an `AssetRef`'s category) carries over.
    func applying(_ value: UntoldAttributeValue) -> Self?
}

private func finiteOrZero(_ value: Double) -> Double {
    value.isFinite ? value : 0
}

extension Float: UntoldAttributeValueType {
    public var attributeKind: UntoldAttributeKind {
        .float
    }

    public var attributeValue: UntoldAttributeValue {
        .number(finiteOrZero(Double(self)))
    }

    public func applying(_ value: UntoldAttributeValue) -> Float? {
        guard case let .number(number) = value, number.isFinite else { return nil }
        return Float(number)
    }
}

extension Int: UntoldAttributeValueType {
    public var attributeKind: UntoldAttributeKind {
        .int
    }

    public var attributeValue: UntoldAttributeValue {
        .number(Double(self))
    }

    public func applying(_ value: UntoldAttributeValue) -> Int? {
        guard case let .number(number) = value, number.isFinite else { return nil }
        return Int(exactly: number.rounded())
    }
}

extension Bool: UntoldAttributeValueType {
    public var attributeKind: UntoldAttributeKind {
        .bool
    }

    public var attributeValue: UntoldAttributeValue {
        .bool(self)
    }

    public func applying(_ value: UntoldAttributeValue) -> Bool? {
        guard case let .bool(flag) = value else { return nil }
        return flag
    }
}

extension String: UntoldAttributeValueType {
    public var attributeKind: UntoldAttributeKind {
        .string
    }

    public var attributeValue: UntoldAttributeValue {
        .string(self)
    }

    public func applying(_ value: UntoldAttributeValue) -> String? {
        guard case let .string(text) = value else { return nil }
        return text
    }
}

extension SIMD3: UntoldAttributeValueType where Scalar == Float {
    public var attributeKind: UntoldAttributeKind {
        .vector3
    }

    public var attributeValue: UntoldAttributeValue {
        .array([x, y, z].map { finiteOrZero(Double($0)) })
    }

    public func applying(_ value: UntoldAttributeValue) -> SIMD3<Float>? {
        guard case let .array(numbers) = value, numbers.count == 3, numbers.allSatisfy(\.isFinite) else { return nil }
        return SIMD3<Float>(Float(numbers[0]), Float(numbers[1]), Float(numbers[2]))
    }
}

extension SIMD4: UntoldAttributeValueType where Scalar == Float {
    public var attributeKind: UntoldAttributeKind {
        .vector4
    }

    public var attributeValue: UntoldAttributeValue {
        .array([x, y, z, w].map { finiteOrZero(Double($0)) })
    }

    public func applying(_ value: UntoldAttributeValue) -> SIMD4<Float>? {
        guard case let .array(numbers) = value, numbers.count == 4, numbers.allSatisfy(\.isFinite) else { return nil }
        return SIMD4<Float>(Float(numbers[0]), Float(numbers[1]), Float(numbers[2]), Float(numbers[3]))
    }
}
