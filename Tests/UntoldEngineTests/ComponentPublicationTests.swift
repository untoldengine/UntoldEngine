//
//  ComponentPublicationTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import UntoldEngine
import XCTest

private final class PublishedComponent: Component {
    static let initial = 0x00C0_FFEE

    var value = PublishedComponent.initial

    required init() {}
}

/// A component that is a value: nothing in `Component` says it has to be a class.
private struct ValueComponent: Component {
    var first = 1
    var second = 2
    var third = 3

    init() {}
}

/// Whether the reader on the other thread should stop, and what it found.
private final class ReaderState: @unchecked Sendable {
    private let lock = NSLock()
    private var stopped = false
    private var reads = 0
    private var unexpected = 0

    func stop() {
        lock.withLock { stopped = true }
    }

    var isStopped: Bool {
        lock.withLock { stopped }
    }

    func record(reads newReads: Int, unexpected newUnexpected: Int) {
        lock.withLock {
            reads += newReads
            unexpected += newUnexpected
        }
    }

    var totals: (reads: Int, unexpected: Int) {
        lock.withLock { (reads, unexpected) }
    }
}

/// A copy of the scene is read after the scene's lock is released, and a slot the copy
/// says is in use may get a new component meanwhile. A component used to be written
/// into its slot with a plain store and read with a plain load, so nothing ordered the
/// read after the new object's initialization: a data race.
///
/// The threaded tests hold one copy on a reader thread while this thread puts new
/// components in the slots the copy reads. They say the most under Thread Sanitizer:
///
///     swift test --sanitize=thread --filter ComponentPublicationTests
@MainActor
final class ComponentPublicationTests: XCTestCase {
    override func setUp() async throws {
        resetEngineTestState()
    }

    override func tearDown() async throws {
        resetEngineTestState()
    }

    // MARK: - A slot

    func testASlotOwnsItsObjectOnceAndReadsLeaveItSo() {
        let slot = UnsafeMutableRawPointer.allocate(
            byteCount: MemoryLayout<PublishedComponent>.stride, alignment: MemoryLayout<PublishedComponent>.alignment
        )
        defer { slot.deallocate() }
        weak var watched: PublishedComponent?
        do {
            let component = PublishedComponent()
            watched = component
            ComponentSlot.store(component, in: slot, asReference: true)
        }
        XCTAssertNotNil(watched, "the slot keeps the component")

        for _ in 0 ..< 3 {
            let read = ComponentSlot.load(from: slot, as: PublishedComponent.self, asReference: true)
            XCTAssertTrue(read === watched)
        }

        // The slot's reference is the only one left: without it the component goes.
        Unmanaged<AnyObject>.fromOpaque(slot.load(as: UnsafeRawPointer.self)).release()
        XCTAssertNil(watched)
    }

    func testASlotOfObjectsThatNeverHeldOneReadsAsNone() throws {
        // Leave a block of a chunk's size full of ones for the allocator to hand back:
        // a chunk that is not cleared would then show them.
        let chunkSize = MemoryLayout<UnsafeRawPointer?>.stride * ComponentPool.chunkCapacity
        let used = UnsafeMutableRawPointer.allocate(byteCount: chunkSize, alignment: MemoryLayout<UnsafeRawPointer?>.alignment)
        used.initializeMemory(as: UInt8.self, repeating: 0xFF, count: chunkSize)
        used.deallocate()

        var pool = ComponentPool(for: PublishedComponent.self)
        pool.reserve(upTo: 0)
        defer { pool.deallocate() }

        var holdingSomething = 0
        for index in 0 ..< ComponentPool.chunkCapacity {
            let slot = try XCTUnwrap(pool.slot(at: index))
            if slot.address.load(as: UnsafeRawPointer?.self) != nil {
                holdingSomething += 1
            }
        }
        XCTAssertEqual(holdingSomething, 0, "slots of a new chunk that do not read as none")

        let first = try XCTUnwrap(pool.slot(at: 0))
        XCTAssertTrue(first.holdsReference)
        XCTAssertNil(ComponentSlot.load(from: first.address, as: PublishedComponent.self, asReference: first.holdsReference))
    }

    func testOnlyAComponentThatIsAnObjectIsKeptAsOneReference() {
        XCTAssertTrue(ComponentSlot.holdsReference(PublishedComponent.self))
        XCTAssertFalse(ComponentSlot.holdsReference(ValueComponent.self))
    }

    func testAComponentThatIsAValueIsKeptInPlace() {
        let entity = createEntity()
        XCTAssertEqual(scene.assign(to: entity, component: ValueComponent.self)?.second, 2)

        let read = scene.get(component: ValueComponent.self, for: entity)

        XCTAssertEqual(read?.first, 1)
        XCTAssertEqual(read?.second, 2)
        XCTAssertEqual(read?.third, 3)
    }

    func testTheSceneReadsTheComponentItWasGivenLast() {
        let entity = createEntity()
        let first = scene.assign(to: entity, component: PublishedComponent.self)
        XCTAssertNotNil(first)
        XCTAssertTrue(scene.get(component: PublishedComponent.self, for: entity) === first)

        let second = scene.assign(to: entity, component: PublishedComponent.self)

        XCTAssertNotNil(second)
        XCTAssertFalse(second === first, "an entity given the component again gets a new one")
        XCTAssertTrue(scene.get(component: PublishedComponent.self, for: entity) === second)
    }

    func testACopyOfTheSceneReadsTheComponentItsEntityWasGivenAgain() {
        // A copy shares the scene's slots: it reads what the slot holds now.
        let entity = createEntity()
        _ = scene.assign(to: entity, component: PublishedComponent.self)
        let copy = scene

        let second = scene.assign(to: entity, component: PublishedComponent.self)

        XCTAssertTrue(copy.get(component: PublishedComponent.self, for: entity) === second)
    }

    // MARK: - A reader on another thread

    /// Runs `change` on this thread, `rounds` times, while a reader thread reads the
    /// component of every entity over and over through one copy of the scene, taken
    /// before the first change. The reader stops after the last change.
    private func readThroughOneCopy(
        of entities: [EntityID], rounds: Int, while change: (Int) -> Void
    ) -> (reads: Int, unexpected: Int) {
        let copyTaken = DispatchSemaphore(value: 0)
        let state = ReaderState()
        let finished = expectation(description: "the reader stopped")

        Thread.detachNewThread {
            let copy = scene
            copyTaken.signal()
            var reads = 0
            var unexpected = 0
            while !state.isStopped {
                for entity in entities {
                    guard let component = copy.get(component: PublishedComponent.self, for: entity) else { continue }
                    reads += 1
                    if component.value != PublishedComponent.initial {
                        unexpected += 1
                    }
                }
            }
            state.record(reads: reads, unexpected: unexpected)
            finished.fulfill()
        }

        copyTaken.wait()
        for round in 0 ..< rounds {
            change(round)
        }
        state.stop()
        wait(for: [finished], timeout: 60)
        return state.totals
    }

    func testAReaderHoldingACopyReadsWhileItsEntitiesAreGivenTheComponentAgain() {
        // What a loader does to the transform components: the entity has the component,
        // and it is registered once more.
        let entities = (0 ..< 16).map { _ in createEntity() }
        for entity in entities {
            registerComponent(entityId: entity, componentType: PublishedComponent.self)
        }
        let rounds = 200

        let totals = readThroughOneCopy(of: entities, rounds: rounds) { _ in
            for entity in entities {
                registerComponent(entityId: entity, componentType: PublishedComponent.self)
            }
        }

        XCTAssertGreaterThan(totals.reads, 0)
        XCTAssertEqual(totals.unexpected, 0)
    }

    func testAReaderHoldingACopyReadsWhileTheComponentIsRemovedAndGivenAgain() {
        // What replacing an entity's mesh does to its render component: the copy still
        // says the entity has the component, and its slot gets a new one.
        let entities = (0 ..< 16).map { _ in createEntity() }
        for entity in entities {
            registerComponent(entityId: entity, componentType: PublishedComponent.self)
        }
        let rounds = 200

        let totals = readThroughOneCopy(of: entities, rounds: rounds) { _ in
            for entity in entities {
                scene.remove(component: PublishedComponent.self, from: entity)
                registerComponent(entityId: entity, componentType: PublishedComponent.self)
            }
        }

        XCTAssertGreaterThan(totals.reads, 0)
        XCTAssertEqual(totals.unexpected, 0)
    }

    func testAReaderHoldingACopyReadsWhileItsEntitiesAreDestroyedAndTheirIndicesReused() {
        // The copy still holds the entities that were destroyed, and new entities take
        // their indices and their slots.
        var entities = (0 ..< 16).map { _ in createEntity() }
        for entity in entities {
            registerComponent(entityId: entity, componentType: PublishedComponent.self)
        }
        let readerEntities = entities
        let rounds = 200

        let totals = readThroughOneCopy(of: readerEntities, rounds: rounds) { _ in
            for entity in entities {
                destroyEntity(entityId: entity)
            }
            finalizePendingDestroys()
            entities = entities.map { _ in createEntity() }
            for entity in entities {
                registerComponent(entityId: entity, componentType: PublishedComponent.self)
            }
        }

        XCTAssertEqual(
            Set(entities.map { getEntityIndex($0) }), Set(readerEntities.map { getEntityIndex($0) }),
            "the new entities took the indices of the destroyed ones"
        )
        XCTAssertGreaterThan(totals.reads, 0)
        XCTAssertEqual(totals.unexpected, 0)
    }
}
