
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

/// The components that left a pool and are not released yet.
///
/// A component leaves its slot when it is removed from its entity, when its entity is
/// destroyed, or when the entity is given the component again. It cannot be released
/// on the spot: the scene is read through copies taken under a lock and used after the
/// lock is released (a render pass may keep one for as long as it runs), and such a
/// copy still says the entity has the component and reads its slot. So the component
/// moves here, and the slot keeps its bits.
///
/// Every copy of a pool reaches this one object, and that is how the readers are known:
/// the components are handed back for release only while no other copy of the pool
/// exists, which is when nothing can read them out of a slot any more.
final class ComponentQuarantine {
    var components: [AnyObject] = []
    /// How many components have left the pool, through any copy of it.
    var departures: UInt64 = 0
    /// Takes a component that is not an object out of its slot, in a box that keeps it
    /// alive. Nil for the usual component, a class, whose slot holds a reference.
    let boxed: ((UnsafeMutableRawPointer) -> AnyObject)?

    init<T>(of _: T.Type) {
        boxed = T.self is AnyObject.Type ? nil : { $0.assumingMemoryBound(to: T.self).move() as AnyObject }
    }

    /// Takes the component out of `slot` and leaves the slot's bits as they are.
    func takeOut(of slot: UnsafeMutableRawPointer) -> AnyObject {
        if let boxed {
            return boxed(slot)
        }
        return Unmanaged<AnyObject>.fromOpaque(slot.load(as: UnsafeRawPointer.self)).takeRetainedValue()
    }
}

/// Storage for one component type, indexed by entity index.
///
/// Memory comes in fixed-size chunks added as the scene grows (see reserve), so the
/// number of entities is not capped. A chunk is never moved or freed before
/// deallocate(): the scene is handed out by value under a lock, and a copy taken on
/// another thread keeps reading through its own chunk list while this one grows.
/// An index past the chunks reserved so far reads as no component.
///
/// A slot owns its component for as long as the entity's mask says the entity has it.
/// When that ends the component moves to the quarantine, which every copy of the pool
/// shares, and is released once no copy of the pool is left to read it.
public struct ComponentPool {
    /// Entities per chunk.
    static let chunkCapacity = 4096

    /// What a chunk list carries besides its chunks.
    private struct Header {
        let chunkCount: Int
        let elementSize: Int
        var quarantine: ComponentQuarantine
    }

    /// The chunk list as a copy of the pool reads it. It is never changed: a pool that
    /// grows gets a new one, and the copies made before keep theirs. Each one holds the
    /// quarantine, so the quarantine can tell whether a copy of the pool is still about.
    private typealias Storage = ManagedBuffer<Header, UnsafeMutableRawPointer>

    private var storage: Storage
    /// The departures this copy of the pool has seen.
    private var departures: UInt64 = 0

    init<T: Component>(for type: T.Type) {
        storage = Self.makeStorage(chunks: [], elementSize: MemoryLayout<T>.stride, quarantine: ComponentQuarantine(of: type))
    }

    private static func makeStorage(
        chunks: [UnsafeMutableRawPointer], elementSize: Int, quarantine: ComponentQuarantine
    ) -> Storage {
        let storage = Storage.create(minimumCapacity: chunks.count) { _ in
            Header(chunkCount: chunks.count, elementSize: elementSize, quarantine: quarantine)
        }
        storage.withUnsafeMutablePointerToElements { $0.initialize(from: chunks, count: chunks.count) }
        return storage
    }

    private var chunks: [UnsafeMutableRawPointer] {
        storage.withUnsafeMutablePointers { header, chunks in
            Array(UnsafeBufferPointer(start: chunks, count: header.pointee.chunkCount))
        }
    }

    private var elementSize: Int {
        storage.withUnsafeMutablePointerToHeader { $0.pointee.elementSize }
    }

    private var quarantine: ComponentQuarantine {
        storage.withUnsafeMutablePointerToHeader { $0.pointee.quarantine }
    }

    /// The number of entity indices the pool can hold without adding a chunk.
    var capacity: Int {
        storage.withUnsafeMutablePointerToHeader { $0.pointee.chunkCount } * Self.chunkCapacity
    }

    public mutating func deallocate() {
        for chunk in chunks {
            chunk.deallocate()
        }
        storage = Self.makeStorage(chunks: [], elementSize: elementSize, quarantine: quarantine)
    }

    /// Adds chunks until `index` has storage.
    mutating func reserve(upTo index: Int) {
        precondition(index >= 0, "Negative entity index \(index).")
        guard capacity <= index else { return }
        var chunks = chunks
        while chunks.count * Self.chunkCapacity <= index {
            chunks.append(
                UnsafeMutableRawPointer.allocate(
                    byteCount: elementSize * Self.chunkCapacity, alignment: MemoryLayout<UInt8>.alignment
                )
            )
        }
        storage = Self.makeStorage(chunks: chunks, elementSize: elementSize, quarantine: quarantine)
    }

    public func get(_ index: Int) -> UnsafeMutableRawPointer? {
        storage.withUnsafeMutablePointers { header, chunks in
            guard index >= 0, index < header.pointee.chunkCount * Self.chunkCapacity else { return nil }
            return chunks[index / Self.chunkCapacity].advanced(by: (index % Self.chunkCapacity) * header.pointee.elementSize)
        }
    }

    /// The component in the slot at `index`, read as a `T`. Only for a slot the entity's
    /// mask says holds one.
    ///
    /// Read a slot through this: the pool is kept until the component is in the caller's
    /// hands, and a pool that is kept holds back the release of what left it.
    @inline(__always)
    func component<T>(at index: Int, as _: T.Type) -> T? {
        guard let slot = get(index) else { return nil }
        return withExtendedLifetime(storage) {
            slot.bindMemory(to: T.self, capacity: 1).pointee
        }
    }

    /// Moves the component in the slot at `index` to the quarantine. Only for a slot
    /// the entity's mask says holds one.
    ///
    /// Copies of a scene share their slots, but each has its own masks. A copy that was
    /// changed on its own, or an old copy put back as the scene, has masks that no longer
    /// say which slots hold a component: it has not seen every component leave. Such a
    /// pool moves nothing to the quarantine and releases nothing from it. Its components
    /// stay for good, as they did before components were released.
    mutating func quarantineComponent(at index: Int) {
        let quarantine = quarantine
        guard departures == quarantine.departures, let slot = get(index) else { return }
        quarantine.components.append(quarantine.takeOut(of: slot))
        quarantine.departures += 1
        departures += 1
    }

    /// Moves the components in quarantine to `released`, for the caller to release, if
    /// no other copy of the pool exists.
    ///
    /// Call it on the pool in place, under the lock the copies are taken under: a copy
    /// made for the call would itself be another copy.
    mutating func takeQuarantinedComponents(into released: inout [AnyObject]) {
        let isWaiting = storage.withUnsafeMutablePointerToHeader { !$0.pointee.quarantine.components.isEmpty }
        // No copy has this chunk list, and none has an older one.
        guard isWaiting, isKnownUniquelyReferenced(&storage) else { return }
        storage.withUnsafeMutablePointerToHeader { header in
            // Asked of the reference alone: the rest of the header is what readers read.
            guard let reference = header.pointer(to: \.quarantine), isKnownUniquelyReferenced(&reference.pointee) else { return }
            let quarantine = reference.pointee
            guard departures == quarantine.departures else { return }
            if released.isEmpty {
                swap(&released, &quarantine.components)
            } else {
                released.append(contentsOf: quarantine.components)
                quarantine.components.removeAll()
            }
        }
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
