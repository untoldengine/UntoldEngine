
//
//  ComponentPool.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

struct TypeInfo {
    var id: Int
    let type: Any.Type
}

public struct ComponentTypeRegistration: Equatable, Sendable {
    public let id: Int
    public let typeName: String

    public init(id: Int, typeName: String) {
        self.id = id
        self.typeName = typeName
    }
}

private final class ComponentIDState: @unchecked Sendable {
    let lock = NSLock()
    var componentIDs: [ObjectIdentifier: TypeInfo] = [:]
}

private let componentIDState = ComponentIDState()

@inline(__always)
func componentTypeInfosSnapshot() -> [ObjectIdentifier: TypeInfo] {
    componentIDState.lock.lock()
    let snapshot = componentIDState.componentIDs
    componentIDState.lock.unlock()
    return snapshot
}

@inline(__always)
func componentTypeInfo(for typeId: ObjectIdentifier) -> TypeInfo? {
    componentIDState.lock.lock()
    let typeInfo = componentIDState.componentIDs[typeId]
    componentIDState.lock.unlock()
    return typeInfo
}

public func registeredComponentTypes() -> [ComponentTypeRegistration] {
    componentTypeInfosSnapshot().values.map { typeInfo in
        ComponentTypeRegistration(
            id: typeInfo.id,
            typeName: String(describing: typeInfo.type)
        )
    }.sorted { lhs, rhs in
        if lhs.id != rhs.id {
            return lhs.id < rhs.id
        }
        return lhs.typeName < rhs.typeName
    }
}

@inline(__always)
private func enforceECSMainActor() {
    // ECS synchronization is lock-based (scene/global stores + component locks),
    // so access is valid from main and XR render threads.
}

/// Function to get or create a component ID for a specific type
public func getComponentId(for type: (some Any).Type) -> Int {
    enforceECSMainActor()
    let typeId = ObjectIdentifier(type)

    if let typeInfo = componentTypeInfo(for: typeId) {
        return typeInfo.id
    } else {
        precondition(
            componentCounter < MAX_COMPONENTS,
            "Exceeded maximum ECS component types (\(MAX_COMPONENTS))."
        )
        let id = componentCounter
        componentCounter += 1

        componentIDState.lock.lock()
        componentIDState.componentIDs[typeId] = TypeInfo(id: id, type: type)
        componentIDState.lock.unlock()
        return id
    }
}

public protocol Component {
    init() // Requires a default initializer
}

/// Storage for one component type, indexed by entity index.
///
/// Memory comes in fixed-size chunks added as the scene grows (see reserve), so the
/// number of entities is not capped. A chunk is never moved or freed before
/// deallocate(): the scene is handed out by value under a lock, and a copy taken on
/// another thread keeps reading through its own chunk list while this one grows.
/// An index past the chunks reserved so far reads as no component.
public struct ComponentPool {
    /// Entities per chunk.
    static let chunkCapacity = 4096

    private var chunks: [UnsafeMutableRawPointer] = []
    private let elementSize: Int

    init(_ elementSize: Int) {
        self.elementSize = elementSize
    }

    /// The number of entity indices the pool can hold without adding a chunk.
    var capacity: Int {
        chunks.count * Self.chunkCapacity
    }

    public mutating func deallocate() {
        for chunk in chunks {
            chunk.deallocate()
        }
        chunks = []
    }

    /// Adds chunks until `index` has storage.
    mutating func reserve(upTo index: Int) {
        precondition(index >= 0, "Negative entity index \(index).")
        while capacity <= index {
            chunks.append(
                UnsafeMutableRawPointer.allocate(
                    byteCount: elementSize * Self.chunkCapacity, alignment: MemoryLayout<UInt8>.alignment
                )
            )
        }
    }

    public func get(_ index: Int) -> UnsafeMutableRawPointer? {
        guard index >= 0, index < capacity else { return nil }
        return chunks[index / Self.chunkCapacity].advanced(by: (index % Self.chunkCapacity) * elementSize)
    }

    /// Add a new component to the pool at a specified index
    public mutating func add<T: Component>(component: T, at index: Int) {
        reserve(upTo: index)
        guard let pointer = get(index) else { fatalError("No storage for entity index \(index) in ComponentPool.") }
        pointer.assumingMemoryBound(to: T.self).initialize(to: component)
    }
}

public struct ComponentMask: Equatable, Hashable {
    @usableFromInline var lowerBits: UInt64 = 0
    @usableFromInline var upperBits: UInt64 = 0

    @inlinable init() {}

    @inlinable public mutating func set(_ index: Int) {
        precondition(index >= 0 && index < 128)
        if index < 64 {
            lowerBits |= (1 &<< index)
        } else {
            upperBits |= (1 &<< (index - 64))
        }
    }

    @inlinable public mutating func reset(_ index: Int) {
        precondition(index >= 0 && index < 128)
        if index < 64 {
            lowerBits &= ~(1 &<< index)
        } else {
            upperBits &= ~(1 &<< (index - 64))
        }
    }

    @inlinable public mutating func resetAll() {
        lowerBits = 0
        upperBits = 0
    }

    @inlinable public func test(_ index: Int) -> Bool {
        precondition(index >= 0 && index < 128)
        if index < 64 {
            return (lowerBits & (1 &<< index)) != 0
        }
        return (upperBits & (1 &<< (index - 64))) != 0
    }

    /// self includes all bits in `other`
    @inlinable func contains(_ other: ComponentMask) -> Bool {
        (lowerBits & other.lowerBits) == other.lowerBits
            && (upperBits & other.upperBits) == other.upperBits
    }

    @inlinable func intersects(_ other: ComponentMask) -> Bool {
        (lowerBits & other.lowerBits) != 0
            || (upperBits & other.upperBits) != 0
    }

    @inlinable func isDisjoint(with other: ComponentMask) -> Bool {
        (lowerBits & other.lowerBits) == 0
            && (upperBits & other.upperBits) == 0
    }

    @inlinable func activeComponentIds() -> [Int] {
        var result: [Int] = []
        var lower = lowerBits
        while lower != 0 {
            result.append(lower.trailingZeroBitCount)
            lower &= lower &- 1
        }
        var upper = upperBits
        while upper != 0 {
            result.append(64 + upper.trailingZeroBitCount)
            upper &= upper &- 1
        }
        return result
    }
}

@inlinable
func makeMask(from componentTypes: some Sequence<Int>) -> ComponentMask {
    var m = ComponentMask()
    for c in componentTypes {
        if c >= 0, c < 128 { m.set(c) }
    }
    return m
}
