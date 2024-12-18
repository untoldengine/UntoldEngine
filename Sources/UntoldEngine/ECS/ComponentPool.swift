
//
//  ComponentPool.swift
//  ECSinSwift
//
//  Created by Harold Serrano on 1/14/24.
//

import Foundation

// Global dictionary to store component IDs for each type
var componentIDs = [ObjectIdentifier: Int]()

// Function to get or create a component ID for a specific type
public func getComponentId(for type: (some Any).Type) -> Int {
    let typeId = ObjectIdentifier(type)
    if let id = componentIDs[typeId] {
        return id
    } else {
        let id = componentCounter
        componentCounter += 1
        componentIDs[typeId] = id
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

public struct ComponentMask {
    private var bits = [Bool](repeating: false, count: MAX_COMPONENTS)

    // set the bit at a specific index to true
    public mutating func set(_ index: Int) {
        guard index < MAX_COMPONENTS else { return }
        bits[index] = true
    }

    // Resets the bit at a specific index to false
    public mutating func reset(_ index: Int? = nil) {
        if let index, index < MAX_COMPONENTS {
            bits[index] = false
        } else if index == nil {
            bits = [Bool](repeating: false, count: MAX_COMPONENTS)
        }
    }

    // Checks if the bit at a specific index is true
    public func test(_ index: Int) -> Bool {
        guard index < MAX_COMPONENTS else { return false }
        return bits[index]
    }

    // Checks if this ComponentMask contains all the components in the specified `otherMask`.
    func contains(_ otherMask: ComponentMask) -> Bool {
        zip(bits, otherMask.bits).allSatisfy { $0 || !$1 }
    }
}
