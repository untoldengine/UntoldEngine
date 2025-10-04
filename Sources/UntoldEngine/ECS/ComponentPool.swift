
//
//  ComponentPool.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import Foundation

struct TypeInfo {
    var id: Int
    let type: Any.Type
}

// Global dictionary to store component IDs for each type
var componentIDs = [ObjectIdentifier: TypeInfo]()

// Function to get or create a component ID for a specific type
public func getComponentId(for type: (some Any).Type) -> Int {
    let typeId = ObjectIdentifier(type)

    if let typeInfo = componentIDs[typeId] {
        return typeInfo.id
    } else {
        let id = componentCounter
        componentCounter += 1

        componentIDs[typeId] = TypeInfo(id: id, type: type)
        return id
    }
}

public protocol Component {
    init() // Requires a default initializer
}

public struct ComponentPool {
    private var data: UnsafeMutableRawPointer?
    private let elementSize: Int

    init(_ elementSize: Int) {
        self.elementSize = elementSize
        // allocate memory
        data = UnsafeMutableRawPointer.allocate(
            byteCount: elementSize * MAX_ENTITIES, alignment: MemoryLayout<UInt8>.alignment
        )
    }

    public mutating func deallocate() {
        data?.deallocate()
        data = nil
    }

    public func get(_ index: Int) -> UnsafeMutableRawPointer? {
        guard let data else { return nil }
        // get component at desired index
        return data.advanced(by: index * elementSize)
    }

    // Add a new component to the pool at a specified index
    public mutating func add<T: Component>(component: T, at index: Int) {
        guard let data else { fatalError("Data in ComponentPool is nil.") }
        let componentPointer = data.advanced(by: index * elementSize).assumingMemoryBound(to: T.self)
        componentPointer.initialize(to: component)
    }
}

public struct ComponentMask: Equatable, Hashable {
    @usableFromInline var bits: UInt64 = 0

    @inlinable init() {}

    @inlinable public mutating func set(_ index: Int) {
        precondition(index >= 0 && index < 64)
        bits |= (1 &<< index)
    }

    @inlinable public mutating func reset(_ index: Int) {
        precondition(index >= 0 && index < 64)
        bits &= ~(1 &<< index)
    }

    @inlinable public mutating func resetAll() { bits = 0 }

    @inlinable public func test(_ index: Int) -> Bool {
        precondition(index >= 0 && index < 64)
        return (bits & (1 &<< index)) != 0
    }

    /// self includes all bits in `other`
    @inlinable func contains(_ other: ComponentMask) -> Bool {
        (bits & other.bits) == other.bits
    }

    @inlinable func intersects(_ other: ComponentMask) -> Bool { (bits & other.bits) != 0 }
    @inlinable func isDisjoint(with other: ComponentMask) -> Bool { (bits & other.bits) == 0 }
}

@inlinable
func makeMask(from componentTypes: some Sequence<Int>) -> ComponentMask {
    var m = ComponentMask()
    for c in componentTypes {
        if c >= 0, c < 64 { m.set(c) }
    }
    return m
}
