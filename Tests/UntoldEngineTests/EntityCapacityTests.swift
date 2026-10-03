//
//  EntityCapacityTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import UntoldEngine
import XCTest

private final class CapacityTestComponent: Component {
    var value: Int = -1

    required init() {}
}

/// Scenes with more entities than INITIAL_ENTITY_CAPACITY: component pools used to be a
/// fixed block of 20,000 entries with no bounds check, so a larger scene (a BIM site
/// cooked to a .untoldpack needs over 21,000) wrote past the end of the storage.
@MainActor
final class EntityCapacityTests: XCTestCase {
    override func setUp() async throws {
        resetEngineTestState()
    }

    override func tearDown() async throws {
        resetEngineTestState()
    }

    func testAPoolHasNoStorageUntilItIsReservedAndThenGrowsByChunks() {
        var pool = ComponentPool(for: CapacityTestComponent.self)
        XCTAssertNil(pool.get(0))

        pool.reserve(upTo: ComponentPool.chunkCapacity + 1)

        XCTAssertEqual(pool.capacity, 2 * ComponentPool.chunkCapacity)
        XCTAssertNotNil(pool.get(ComponentPool.chunkCapacity + 1))
        XCTAssertNil(pool.get(pool.capacity), "an index past the reserved chunks reads as no component")
        pool.deallocate()
    }

    func testMoreEntitiesThanTheInitialCapacityKeepTheirComponents() {
        let total = INITIAL_ENTITY_CAPACITY + ComponentPool.chunkCapacity + 7
        var entities: [EntityID] = []
        entities.reserveCapacity(total)
        for index in 0 ..< total {
            let entityId = createEntity()
            scene.assign(to: entityId, component: CapacityTestComponent.self)?.value = index
            entities.append(entityId)
        }

        for (index, entityId) in entities.enumerated() {
            XCTAssertEqual(scene.get(component: CapacityTestComponent.self, for: entityId)?.value, index)
        }
    }

    func testACopyOfTheSceneStillReadsWhileTheSceneGrows() {
        let first = createEntity()
        scene.assign(to: first, component: CapacityTestComponent.self)?.value = 42
        let snapshot = scene

        for _ in 0 ..< ComponentPool.chunkCapacity * 2 {
            let entityId = createEntity()
            scene.assign(to: entityId, component: CapacityTestComponent.self)
        }

        XCTAssertEqual(snapshot.get(component: CapacityTestComponent.self, for: first)?.value, 42)
        XCTAssertEqual(scene.get(component: CapacityTestComponent.self, for: first)?.value, 42)
    }
}
