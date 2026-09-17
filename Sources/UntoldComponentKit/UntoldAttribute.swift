//
//  UntoldAttribute.swift
//  UntoldComponentKit
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// The type-erased face of an `@UntoldAttribute`, which is what reflection hands out.
public protocol AnyUntoldAttribute: AnyObject {
    /// The label given in the declaration; empty means "derive it from the property name".
    var label: String { get }
    var kind: UntoldAttributeKind { get }
    /// A UI hint for numeric kinds. Values are not clamped when loaded from a scene.
    var range: ClosedRange<Double>? { get }
    var step: Double? { get }
    var attributeValue: UntoldAttributeValue { get }
    /// Writes `value` into the wrapped property. Returns `false`, leaving the property
    /// untouched, when `value` does not fit the attribute's kind.
    @discardableResult func setAttributeValue(_ value: UntoldAttributeValue) -> Bool
}

/// Marks a stored property of a `CodeComponent` as visible to the editor and saved with the
/// scene.
///
///     @UntoldAttribute("Speed", range: 0...20) var speed: Float = 5
///     @UntoldAttribute(.color) var tint: SIMD4<Float> = [1, 1, 1, 1]
///     @UntoldAttribute var stance: Stance = .idle      // String-backed, CaseIterable enum
///
/// It is a class on purpose: reflection returns the very object the component holds, so the
/// editor writes through it without key paths or generated code.
@propertyWrapper
public final class UntoldAttribute<Value>: AnyUntoldAttribute {
    public var wrappedValue: Value
    public var projectedValue: UntoldAttribute<Value> {
        self
    }

    public let label: String
    public let kind: UntoldAttributeKind
    public let range: ClosedRange<Double>?
    public let step: Double?

    private let encode: (Value) -> UntoldAttributeValue
    private let decode: (Value, UntoldAttributeValue) -> Value?

    private init(
        value: Value,
        label: String,
        kind: UntoldAttributeKind,
        range: ClosedRange<Double>?,
        step: Double?,
        encode: @escaping (Value) -> UntoldAttributeValue,
        decode: @escaping (Value, UntoldAttributeValue) -> Value?
    ) {
        wrappedValue = value
        self.label = label
        self.kind = kind
        self.range = range
        self.step = step
        self.encode = encode
        self.decode = decode
    }

    public var attributeValue: UntoldAttributeValue {
        encode(wrappedValue)
    }

    @discardableResult
    public func setAttributeValue(_ value: UntoldAttributeValue) -> Bool {
        guard let decoded = decode(wrappedValue, value) else { return false }
        wrappedValue = decoded
        return true
    }
}

public extension UntoldAttribute {
    /// Numbers, booleans, text, vectors, `EntityRef` and `AssetRef`.
    convenience init(
        wrappedValue: Value,
        _ label: String = "",
        range: ClosedRange<Double>? = nil,
        step: Double? = nil
    ) where Value: UntoldAttributeValueType {
        self.init(
            value: wrappedValue,
            label: label,
            kind: wrappedValue.attributeKind,
            range: range,
            step: step,
            encode: { $0.attributeValue },
            decode: { current, value in current.applying(value) }
        )
    }

    /// The same types, with a presentation hint: `.color` on a `SIMD4<Float>`, `.multiline` on
    /// a `String`. A hint that does not fit the type is ignored.
    convenience init(
        wrappedValue: Value,
        _ style: UntoldAttributeStyle,
        _ label: String = ""
    ) where Value: UntoldAttributeValueType {
        let baseKind = wrappedValue.attributeKind
        let kind: UntoldAttributeKind
        switch (style, baseKind) {
        case (.color, .vector4): kind = .color
        case (.multiline, .string): kind = .text
        default: kind = baseKind
        }
        self.init(
            value: wrappedValue,
            label: label,
            kind: kind,
            range: nil,
            step: nil,
            encode: { $0.attributeValue },
            decode: { current, value in current.applying(value) }
        )
    }

    /// `String`-backed `CaseIterable` enums, drawn as a popup and saved as the raw value.
    convenience init(
        wrappedValue: Value,
        _ label: String = ""
    ) where Value: RawRepresentable & CaseIterable, Value.RawValue == String {
        self.init(
            value: wrappedValue,
            label: label,
            kind: .enumeration(cases: Value.allCases.map(\.rawValue)),
            range: nil,
            step: nil,
            encode: { .string($0.rawValue) },
            decode: { _, value in
                guard case let .string(rawValue) = value else { return nil }
                return Value(rawValue: rawValue)
            }
        )
    }
}
