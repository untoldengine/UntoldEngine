
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

/// How a component gets into its slot and out of it.
///
/// A slot is read without the scene's lock: the scene is handed out by value under the
/// lock and the copy is read after it, and a render pass may keep a copy for as long as
/// it runs. While a copy says a slot holds a component, another thread may put a new
/// one there: the entity is given the component again, or it lost the component and
/// gets it back, or it was destroyed and a new entity took its index.
///
/// So a component that is an object, as the engine's are, goes into its slot with an
/// atomic store that comes after everything its initializer wrote, and comes out with
/// an atomic load that takes that order. A reader gets the component the slot had or
/// the new one, and either one whole.
///
/// A component that is a value is not one reference and cannot be swapped in one step.
/// It is written and read in place: do not give one again to an entity that another
/// thread may be reading.
enum ComponentSlot {
    /// Whether a slot of `T` holds one reference to an object.
    static func holdsReference<T>(_: T.Type) -> Bool {
        T.self is AnyObject.Type
    }

    /// Puts `component` in `slot`, which owns it from here on. What the slot held is
    /// written over, not released.
    @inline(__always)
    static func store<T>(_ component: T, in slot: UnsafeMutableRawPointer, asReference: Bool) {
        guard asReference else {
            slot.bindMemory(to: T.self, capacity: 1).initialize(to: component)
            return
        }
        let reference = unsafeBitCast(component, to: UnsafeRawPointer.self)
        // The slot's own reference to the object.
        _ = Unmanaged<AnyObject>.fromOpaque(reference).retain()
        // Before macOS 15 and iOS 18 (Synchronization) the standard library has an atomic
        // compare and exchange of a pointer and no plain atomic store. A scene is
        // written under its lock, so the exchange has nobody to lose to.
        var held = slot.load(as: UnsafeRawPointer?.self)
        let word = slot.assumingMemoryBound(to: UnsafeRawPointer?.self)
        while !_stdlib_atomicCompareExchangeStrongPtr(object: word, expected: &held, desired: reference) {}
    }

    /// The component in `slot`, read as a `T`. Only for a slot that holds one.
    @inline(__always)
    static func load<T>(from slot: UnsafeMutableRawPointer, as _: T.Type, asReference: Bool) -> T? {
        guard asReference else {
            return slot.assumingMemoryBound(to: T.self).pointee
        }
        guard let reference = _stdlib_atomicAcquiringLoadARCRef(object: slot.assumingMemoryBound(to: AnyObject?.self)) else {
            return nil
        }
        return unsafeBitCast(reference.toOpaque(), to: T.self)
    }
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
        /// Whether a slot holds one reference to an object (see ComponentSlot).
        let holdsReferences: Bool
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
        storage = Self.makeStorage(
            chunks: [], elementSize: MemoryLayout<T>.stride, holdsReferences: ComponentSlot.holdsReference(T.self),
            quarantine: ComponentQuarantine(of: type)
        )
    }

    private static func makeStorage(
        chunks: [UnsafeMutableRawPointer], elementSize: Int, holdsReferences: Bool, quarantine: ComponentQuarantine
    ) -> Storage {
        let storage = Storage.create(minimumCapacity: chunks.count) { _ in
            Header(chunkCount: chunks.count, elementSize: elementSize, holdsReferences: holdsReferences, quarantine: quarantine)
        }
        storage.withUnsafeMutablePointerToElements { $0.initialize(from: chunks, count: chunks.count) }
        return storage
    }

    private var holdsReferences: Bool {
        storage.withUnsafeMutablePointerToHeader { $0.pointee.holdsReferences }
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
        storage = Self.makeStorage(chunks: [], elementSize: elementSize, holdsReferences: holdsReferences, quarantine: quarantine)
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
        storage = Self.makeStorage(chunks: chunks, elementSize: elementSize, holdsReferences: holdsReferences, quarantine: quarantine)
    }

    public func get(_ index: Int) -> UnsafeMutableRawPointer? {
        storage.withUnsafeMutablePointers { header, chunks in
            guard index >= 0, index < header.pointee.chunkCount * Self.chunkCapacity else { return nil }
            return chunks[index / Self.chunkCapacity].advanced(by: (index % Self.chunkCapacity) * header.pointee.elementSize)
        }
    }

    /// Where the slot at `index` is, and whether it holds one reference to an object:
    /// what ComponentSlot needs to read it or write it. Read and write a component
    /// through ComponentSlot, not through the pointer `get` returns.
    @inline(__always)
    func slot(at index: Int) -> (address: UnsafeMutableRawPointer, holdsReference: Bool)? {
        storage.withUnsafeMutablePointers { header, chunks in
            guard index >= 0, index < header.pointee.chunkCount * Self.chunkCapacity else { return nil }
            let address = chunks[index / Self.chunkCapacity].advanced(by: (index % Self.chunkCapacity) * header.pointee.elementSize)
            return (address, header.pointee.holdsReferences)
        }
    }

    /// The component in the slot at `index`, read as a `T`. Only for a slot the entity's
    /// mask says holds one.
    ///
    /// For a reader that holds a pool on its own: the pool is kept until the component is
    /// in the caller's hands, and a pool that is kept holds back the release of what left
    /// it. A reader that holds the scene (Scene.get) asks for the slot and reads it: the
    /// scene it holds keeps the pool.
    @inline(__always)
    func component<T>(at index: Int, as _: T.Type) -> T? {
        guard let slot = slot(at: index) else { return nil }
        return withExtendedLifetime(storage) {
            ComponentSlot.load(from: slot.address, as: T.self, asReference: slot.holdsReference)
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
    public mutating func add(component: some Component, at index: Int) {
        reserve(upTo: index)
        guard let slot = slot(at: index) else { fatalError("No storage for entity index \(index) in ComponentPool.") }
        ComponentSlot.store(component, in: slot.address, asReference: slot.holdsReference)
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
