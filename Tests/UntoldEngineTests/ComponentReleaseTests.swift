//
//  ComponentReleaseTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import UntoldEngine
import XCTest

/// How many probes were released: one release of a probe is one deinit.
private final class ReleaseCount: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func add() {
        lock.withLock { count += 1 }
    }

    func reset() {
        lock.withLock { count = 0 }
    }

    var value: Int {
        lock.withLock { count }
    }
}

private let probeReleases = ReleaseCount()

private final class ProbeComponent: Component {
    static let intact = 0x00C0_FFEE

    /// Cleared when the probe is released, so that a reader holding a released probe
    /// can tell.
    var canary = ProbeComponent.intact

    required init() {}

    deinit {
        canary = 0
        probeReleases.add()
    }
}

/// A component whose release reads the scene, as a component of a game may.
private final class SceneReadingComponent: Component {
    required init() {}

    deinit {
        _ = scene.getAllEntities().count
        probeReleases.add()
    }
}

private final class ValuePayload {
    var value = 0

    deinit {
        probeReleases.add()
    }
}

/// A component that is a value: nothing in `Component` says it has to be a class.
private struct ValueComponent: Component {
    var payload = ValuePayload()

    init() {}
}

/// An object watched without keeping it alive.
private struct Watched<Object: AnyObject> {
    weak var object: Object?

    init(_ object: Object?) {
        self.object = object
    }

    var isAlive: Bool {
        object != nil
    }
}

/// The entities of a round, handed from the thread that makes them to the one that reads.
private final class RoundEntities: @unchecked Sendable {
    private let lock = NSLock()
    private var current: [EntityID]

    init(_ entities: [EntityID]) {
        current = entities
    }

    var entities: [EntityID] {
        get { lock.withLock { current } }
        set { lock.withLock { current = newValue } }
    }
}

/// Whether a reader on another thread should stop, and what it found.
private final class ReaderState: @unchecked Sendable {
    private let lock = NSLock()
    private var stopped = false
    private var reads = 0
    private var releasedReads = 0

    func stop() {
        lock.withLock { stopped = true }
    }

    var isStopped: Bool {
        lock.withLock { stopped }
    }

    func record(reads newReads: Int, released: Int) {
        lock.withLock {
            reads += newReads
            releasedReads += released
        }
    }

    var totals: (reads: Int, released: Int) {
        lock.withLock { (reads, releasedReads) }
    }
}

/// Component objects used to be kept for ever: removing a component, destroying its
/// entity or giving the entity the component again only cleared the entity's mask,
/// and the object stayed in its slot until the slot was written again, without being
/// released even then. They are released now, once no copy of the scene taken before
/// they left can still read them.
@MainActor
final class ComponentReleaseTests: XCTestCase {
    override func setUp() async throws {
        resetEngineTestState()
        probeReleases.reset()
    }

    override func tearDown() async throws {
        resetEngineTestState()
    }

    private func makeProbe(on entity: EntityID) -> Watched<ProbeComponent> {
        Watched(scene.assign(to: entity, component: ProbeComponent.self))
    }

    // MARK: - Leaving the scene

    func testARemovedComponentIsReleasedByTheNextRelease() {
        let entity = createEntity()
        let probe = makeProbe(on: entity)
        XCTAssertTrue(probe.isAlive)

        scene.remove(component: ProbeComponent.self, from: entity)

        XCTAssertNil(scene.get(component: ProbeComponent.self, for: entity))
        XCTAssertTrue(probe.isAlive, "a removed component waits in quarantine")
        XCTAssertEqual(probeReleases.value, 0)

        releaseQuarantinedComponents()

        XCTAssertFalse(probe.isAlive)
        XCTAssertEqual(probeReleases.value, 1)
    }

    func testAnEntityGivenTheComponentAgainReleasesTheOneItHad() {
        let entity = createEntity()
        let first = makeProbe(on: entity)
        let second = makeProbe(on: entity)

        releaseQuarantinedComponents()

        XCTAssertFalse(first.isAlive)
        XCTAssertTrue(second.isAlive)
        XCTAssertTrue(scene.get(component: ProbeComponent.self, for: entity) === second.object)
        XCTAssertEqual(probeReleases.value, 1)
    }

    func testAComponentRemovedAndGivenAgainIsReleasedOnce() {
        let entity = createEntity()
        let first = makeProbe(on: entity)
        scene.remove(component: ProbeComponent.self, from: entity)
        let second = makeProbe(on: entity)

        releaseQuarantinedComponents()

        XCTAssertFalse(first.isAlive)
        XCTAssertTrue(second.isAlive)
        XCTAssertEqual(probeReleases.value, 1)
    }

    func testADestroyedEntityReleasesItsComponents() {
        let entity = createEntity()
        let probe = makeProbe(on: entity)
        let local = Watched(scene.get(component: LocalTransformComponent.self, for: entity))
        let world = Watched(scene.get(component: WorldTransformComponent.self, for: entity))
        let scenegraph = Watched(scene.get(component: ScenegraphComponent.self, for: entity))
        XCTAssertTrue(local.isAlive && world.isAlive && scenegraph.isAlive)

        destroyEntity(entityId: entity)
        XCTAssertTrue(probe.isAlive, "an entity waiting to be destroyed keeps its components")

        finalizePendingDestroys()

        XCTAssertFalse(probe.isAlive)
        XCTAssertFalse(local.isAlive)
        XCTAssertFalse(world.isAlive)
        XCTAssertFalse(scenegraph.isAlive)
        XCTAssertEqual(probeReleases.value, 1)
    }

    func testAComponentOnAReusedEntityIndexIsReleasedOnce() {
        let entity = createEntity()
        let first = makeProbe(on: entity)
        let index = getEntityIndex(entity)
        destroyEntity(entityId: entity)
        finalizePendingDestroys()
        XCTAssertFalse(first.isAlive)

        let reused = createEntity()
        XCTAssertEqual(getEntityIndex(reused), index)
        let second = makeProbe(on: reused)
        releaseQuarantinedComponents()

        XCTAssertTrue(second.isAlive, "the slot was empty: nothing leaves it when it is filled again")
        XCTAssertEqual(probeReleases.value, 1)

        destroyEntity(entityId: reused)
        finalizePendingDestroys()

        XCTAssertFalse(second.isAlive)
        XCTAssertEqual(probeReleases.value, 2)
    }

    func testEveryWayOfLosingTheSameComponentReleasesItOnce() {
        // registerComponent gives the type a cleanup handler that removes it, so that
        // the handler, the removal of all components that follows it and the entity's
        // destruction all come across the same component.
        let entity = createEntity()
        registerComponent(entityId: entity, componentType: ProbeComponent.self)
        let probe = Watched(scene.get(component: ProbeComponent.self, for: entity))

        destroyEntity(entityId: entity)
        finalizePendingDestroys()

        XCTAssertFalse(probe.isAlive)
        XCTAssertEqual(probeReleases.value, 1)

        // The same by hand, on an entity that stays.
        let other = createEntity()
        let otherProbe = makeProbe(on: other)
        scene.remove(component: ProbeComponent.self, from: other)
        scene.remove(component: ProbeComponent.self, from: other)
        scene.removeAllComponents(from: other)
        scene.removeAllComponents(from: other)
        releaseQuarantinedComponents()
        releaseQuarantinedComponents()

        XCTAssertFalse(otherProbe.isAlive)
        XCTAssertEqual(probeReleases.value, 2)
    }

    func testRemovingAComponentTheEntityDoesNotHaveReleasesNothing() {
        // Two entities share nothing but the component type: removing it from the one
        // that never had it must not reach into the pool.
        let owner = createEntity()
        let bystander = createEntity()
        let probe = makeProbe(on: owner)

        scene.remove(component: ProbeComponent.self, from: bystander)
        releaseQuarantinedComponents()

        XCTAssertTrue(probe.isAlive)
        XCTAssertTrue(scene.get(component: ProbeComponent.self, for: owner) === probe.object)
        XCTAssertEqual(probeReleases.value, 0)
    }

    func testAComponentThatIsNotAClassIsReleasedToo() {
        let entity = createEntity()
        let payload = Watched(scene.assign(to: entity, component: ValueComponent.self)?.payload)
        XCTAssertTrue(payload.isAlive)

        scene.remove(component: ValueComponent.self, from: entity)
        XCTAssertTrue(payload.isAlive)
        releaseQuarantinedComponents()

        XCTAssertFalse(payload.isAlive)
        XCTAssertEqual(probeReleases.value, 1)
    }

    func testComponentsThatComeAndGoDoNotPileUp() {
        // What a fade does: the component is added, removed a few frames later, and
        // the frame releases what left since the one before.
        let entity = createEntity()
        let cycles = 1000
        for cycle in 0 ..< cycles {
            _ = scene.assign(to: entity, component: ProbeComponent.self)
            scene.remove(component: ProbeComponent.self, from: entity)
            if cycle % 10 == 9 {
                releaseQuarantinedComponents()
                XCTAssertEqual(probeReleases.value, cycle + 1)
            }
        }
        XCTAssertEqual(probeReleases.value, cycles)
    }

    // MARK: - Readers

    func testACopyOfTheSceneKeepsTheComponentsItCanStillRead() {
        let entity = createEntity()
        let probe = makeProbe(on: entity)
        var copy: Scene? = scene

        scene.remove(component: ProbeComponent.self, from: entity)
        releaseQuarantinedComponents()

        XCTAssertNil(scene.get(component: ProbeComponent.self, for: entity))
        XCTAssertTrue(probe.isAlive, "the copy was taken before the component left")
        XCTAssertEqual(copy?.get(component: ProbeComponent.self, for: entity)?.canary, ProbeComponent.intact)
        XCTAssertEqual(probeReleases.value, 0)

        copy = nil
        releaseQuarantinedComponents()

        XCTAssertFalse(probe.isAlive)
        XCTAssertEqual(probeReleases.value, 1)
    }

    func testACopyOfTheSceneKeepsTheComponentsOfADestroyedEntity() {
        let entity = createEntity()
        let probe = makeProbe(on: entity)
        var copy: Scene? = scene

        destroyEntity(entityId: entity)
        finalizePendingDestroys()

        XCTAssertFalse(scene.exists(entity))
        XCTAssertTrue(probe.isAlive)
        XCTAssertTrue(copy?.get(component: ProbeComponent.self, for: entity) === probe.object)
        XCTAssertNotNil(copy?.get(component: LocalTransformComponent.self, for: entity))

        copy = nil
        releaseQuarantinedComponents()

        XCTAssertFalse(probe.isAlive)
        XCTAssertEqual(probeReleases.value, 1)
    }

    func testACopyOfThePoolKeepsTheComponentsItCanStillRead() {
        // A render pass keeps the pools it reads, not the scene.
        let entity = createEntity()
        let probe = makeProbe(on: entity)
        let index = Int(getEntityIndex(entity))
        var pool = scene.componentPool[getComponentId(for: ProbeComponent.self)]
        XCTAssertNotNil(pool)

        scene.remove(component: ProbeComponent.self, from: entity)
        releaseQuarantinedComponents()

        XCTAssertTrue(probe.isAlive)
        XCTAssertTrue(pool?.component(at: index, as: ProbeComponent.self) === probe.object)

        pool = nil
        releaseQuarantinedComponents()

        XCTAssertFalse(probe.isAlive)
    }

    func testACopyTakenBeforeThePoolGrewStillKeepsItsComponents() {
        let entity = createEntity()
        let probe = makeProbe(on: entity)
        var copy: Scene? = scene

        // The pool gets a new chunk list; the copy keeps the old one.
        for _ in 0 ..< ComponentPool.chunkCapacity {
            _ = scene.assign(to: createEntity(), component: ProbeComponent.self)
        }
        scene.remove(component: ProbeComponent.self, from: entity)
        releaseQuarantinedComponents()

        XCTAssertTrue(probe.isAlive)
        XCTAssertTrue(copy?.get(component: ProbeComponent.self, for: entity) === probe.object)

        copy = nil
        releaseQuarantinedComponents()

        XCTAssertFalse(probe.isAlive)
        XCTAssertEqual(probeReleases.value, 1)
    }

    func testAReaderOnAnotherThreadNeverGetsAReleasedComponent() {
        // The render thread of an XR app reads the scene while the main thread changes
        // it. Here one thread reads through `scene`, and this one removes, replaces and
        // destroys what it reads and releases what left.
        var entities = (0 ..< 64).map { _ in createEntity() }
        for entity in entities {
            _ = scene.assign(to: entity, component: ProbeComponent.self)
        }
        let readerEntities = entities
        let state = ReaderState()
        let finished = expectation(description: "the reader stopped")

        Thread.detachNewThread {
            var reads = 0
            var released = 0
            while !state.isStopped {
                for entity in readerEntities {
                    guard let probe = scene.get(component: ProbeComponent.self, for: entity) else { continue }
                    reads += 1
                    if probe.canary != ProbeComponent.intact {
                        released += 1
                    }
                }
            }
            state.record(reads: reads, released: released)
            finished.fulfill()
        }

        let rounds = 2000
        for round in 0 ..< rounds {
            for slot in entities.indices {
                let entity = entities[slot]
                switch (round + slot) % 3 {
                case 0:
                    scene.remove(component: ProbeComponent.self, from: entity)
                    _ = scene.assign(to: entity, component: ProbeComponent.self)
                case 1:
                    _ = scene.assign(to: entity, component: ProbeComponent.self)
                default:
                    destroyEntity(entityId: entity)
                    finalizePendingDestroys()
                    entities[slot] = createEntity()
                    _ = scene.assign(to: entities[slot], component: ProbeComponent.self)
                }
            }
            releaseQuarantinedComponents()
        }
        let releasedWhileRead = probeReleases.value
        state.stop()
        wait(for: [finished], timeout: 30)

        let totals = state.totals
        XCTAssertGreaterThan(totals.reads, 0)
        XCTAssertEqual(totals.released, 0)
        XCTAssertGreaterThan(releasedWhileRead, 0, "components were released while the reader ran")

        // With the reader gone, everything that left is released: each step above
        // made one probe and lost one.
        for entity in entities {
            destroyEntity(entityId: entity)
        }
        finalizePendingDestroys()
        XCTAssertEqual(probeReleases.value, entities.count + rounds * entities.count)
    }

    func testACopyHeldOnAnotherThreadKeepsItsComponents() {
        // A render pass on another thread holds a copy of the scene for as long as it
        // runs. Round by round: the reader takes a copy, this thread removes and
        // destroys what the copy reads and asks for the release, the reader reads it
        // all through its copy and lets the copy go, and only then is it released.
        let entityCount = 32
        let rounds = 50
        let copyTaken = DispatchSemaphore(value: 0)
        let sceneChanged = DispatchSemaphore(value: 0)
        let copyDropped = DispatchSemaphore(value: 0)
        let nextRound = DispatchSemaphore(value: 0)
        let state = ReaderState()
        let finished = expectation(description: "the reader stopped")

        var entities = (0 ..< entityCount).map { _ in createEntity() }
        for entity in entities {
            _ = scene.assign(to: entity, component: ProbeComponent.self)
        }
        let watched = RoundEntities(entities)

        Thread.detachNewThread {
            var reads = 0
            var released = 0
            for _ in 0 ..< rounds {
                nextRound.wait()
                do {
                    let copy = scene
                    let readerEntities = watched.entities
                    copyTaken.signal()
                    sceneChanged.wait()
                    for entity in readerEntities {
                        guard let probe = copy.get(component: ProbeComponent.self, for: entity) else { continue }
                        reads += 1
                        if probe.canary != ProbeComponent.intact {
                            released += 1
                        }
                    }
                }
                copyDropped.signal()
            }
            state.record(reads: reads, released: released)
            finished.fulfill()
        }

        for round in 0 ..< rounds {
            nextRound.signal()
            copyTaken.wait()
            let releasedBefore = probeReleases.value

            // Half are removed, half destroyed; none may be released yet.
            for (slot, entity) in entities.enumerated() {
                if slot.isMultiple(of: 2) {
                    scene.remove(component: ProbeComponent.self, from: entity)
                } else {
                    destroyEntity(entityId: entity)
                }
            }
            finalizePendingDestroys()
            releaseQuarantinedComponents()
            XCTAssertEqual(probeReleases.value, releasedBefore, "round \(round): the reader's copy still reads them")

            sceneChanged.signal()
            copyDropped.wait()
            releaseQuarantinedComponents()
            XCTAssertEqual(probeReleases.value, releasedBefore + entityCount, "round \(round)")

            // The next round's probes, made while no copy is held.
            for slot in entities.indices {
                if !slot.isMultiple(of: 2) {
                    entities[slot] = createEntity()
                }
                _ = scene.assign(to: entities[slot], component: ProbeComponent.self)
            }
            watched.entities = entities
        }
        wait(for: [finished], timeout: 30)

        let totals = state.totals
        XCTAssertEqual(totals.reads, rounds * entityCount, "the copy read every component that had left the scene")
        XCTAssertEqual(totals.released, 0)
    }

    // MARK: - Copies that are changed or put back

    func testASceneChangedThroughACopyAndPutBackStillReleases() {
        let entity = createEntity()
        let probe = makeProbe(on: entity)

        do {
            var changed = scene
            changed.remove(component: ProbeComponent.self, from: entity)
            scene = changed
        }
        releaseQuarantinedComponents()

        XCTAssertFalse(probe.isAlive)
        XCTAssertEqual(probeReleases.value, 1)
    }

    func testAChangedCopyThatIsDroppedTakesNothingFromTheScene() {
        // The copy shares the scene's slots but has its own masks: what it removed, the
        // scene still has. The component stays, and the pool, which no longer knows
        // which of its slots hold one, stops releasing.
        let entity = createEntity()
        let probe = makeProbe(on: entity)

        do {
            var fork = scene
            fork.remove(component: ProbeComponent.self, from: entity)
        }
        releaseQuarantinedComponents()

        XCTAssertTrue(probe.isAlive)
        XCTAssertTrue(scene.get(component: ProbeComponent.self, for: entity) === probe.object)

        scene.remove(component: ProbeComponent.self, from: entity)
        _ = scene.assign(to: entity, component: ProbeComponent.self)
        releaseQuarantinedComponents()

        XCTAssertTrue(probe.isAlive)
        XCTAssertEqual(probeReleases.value, 0)
    }

    func testAnOldCopyPutBackKeepsTheComponentsItSaysItHas() {
        let entity = createEntity()
        let probe = makeProbe(on: entity)

        do {
            let saved = scene
            scene.remove(component: ProbeComponent.self, from: entity)
            scene = saved
        }
        releaseQuarantinedComponents()

        XCTAssertTrue(probe.isAlive)
        XCTAssertTrue(scene.get(component: ProbeComponent.self, for: entity) === probe.object)
        XCTAssertEqual(probeReleases.value, 0)
    }

    func testASceneSetAsideForAnEmptyOneAndPutBackStillReleases() {
        // What a test that wants an empty scene does: nothing left the scene that was
        // set aside, so it is as good as it was.
        let entity = createEntity()
        let probe = makeProbe(on: entity)

        do {
            let saved = scene
            scene = Scene()
            _ = scene.assign(to: createEntity(), component: ProbeComponent.self)
            scene = saved
        }
        scene.remove(component: ProbeComponent.self, from: entity)
        releaseQuarantinedComponents()

        XCTAssertFalse(probe.isAlive)
        XCTAssertEqual(probeReleases.value, 1)
    }

    // MARK: - Where the release happens

    func testAReleasedComponentMayReadTheScene() {
        // The release happens after the scene lock is let go: a deinit that reads the
        // scene must neither deadlock nor overlap the change that released it.
        let entity = createEntity()
        _ = scene.assign(to: entity, component: SceneReadingComponent.self)
        scene.remove(component: SceneReadingComponent.self, from: entity)
        releaseQuarantinedComponents()
        XCTAssertEqual(probeReleases.value, 1)

        let other = createEntity()
        _ = scene.assign(to: other, component: SceneReadingComponent.self)
        destroyEntity(entityId: other)
        finalizePendingDestroys()
        XCTAssertEqual(probeReleases.value, 2)
    }

    func testASceneThatIsReplacedLetsGoOfItsQuarantine() {
        let entity = createEntity()
        let probe = makeProbe(on: entity)
        _ = scene.assign(to: entity, component: SceneReadingComponent.self)
        scene.remove(component: ProbeComponent.self, from: entity)
        scene.remove(component: SceneReadingComponent.self, from: entity)

        scene = Scene()

        XCTAssertFalse(probe.isAlive)
        XCTAssertEqual(probeReleases.value, 2)
    }
}
