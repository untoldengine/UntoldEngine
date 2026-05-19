//
//  ProgressiveAssetLoaderTests.swift
//  UntoldEngineTests
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Metal
import simd
@testable import UntoldEngine
import XCTest

// MARK: - ProgressiveAssetLoader CPURuntimeEntry Registry Tests

/// Tests for ProgressiveAssetLoader's native .untold CPU registry.
///
/// ProgressiveAssetLoader stores CPURuntimeEntry (RuntimeAssetNode + metadata) keyed
/// by child entity ID so GeometryStreamingSystem can upload each node to Metal on demand
/// without re-reading disk. These tests verify all CRUD operations and lifecycle interactions.
@MainActor
final class ProgressiveAssetLoaderRegistryTests: XCTestCase {
    var loader: ProgressiveAssetLoader!

    override func setUp() async throws {
        loader = ProgressiveAssetLoader.shared
        loader.cancelAll()

        guard let mtlDevice = MTLCreateSystemDefaultDevice() else {
            XCTFail("No Metal device available — skipping ProgressiveAssetLoader tests")
            return
        }
        renderInfo.device = mtlDevice
    }

    override func tearDown() async throws {
        loader.cancelAll()
    }

    // MARK: - Helpers

    private func makeEntry(estimatedGPUBytes: Int = 0) -> ProgressiveAssetLoader.CPURuntimeEntry {
        let dummyNode = RuntimeAssetNode(
            id: 0,
            name: "TestNode",
            localBounds: RuntimeAABB(min: .zero, max: simd_float3(1, 1, 1)),
            worldBounds: RuntimeAABB(min: .zero, max: simd_float3(1, 1, 1)),
            primitives: []
        )
        return ProgressiveAssetLoader.CPURuntimeEntry(
            node: dummyNode,
            url: URL(fileURLWithPath: "/dev/null"),
            uniqueAssetName: "TestMesh#0",
            estimatedGPUBytes: estimatedGPUBytes,
            residencyPolicy: .fullLoad
        )
    }

    // MARK: - tick() no-op

    func testTickIsNoOp() {
        let entityId: EntityID = 1
        loader.storeCPURuntimeEntry(makeEntry(), for: entityId)

        loader.tick()
        loader.tick()

        XCTAssertNotNil(loader.retrieveCPURuntimeEntry(for: entityId),
                        "tick() must not clear CPU registry entries")
    }

    // MARK: - storeCPURuntimeEntry / retrieveCPURuntimeEntry

    func testStoreThenRetrieve_returnsStoredEntry() {
        let entityId: EntityID = 10
        loader.storeCPURuntimeEntry(makeEntry(estimatedGPUBytes: 512_000), for: entityId)
        XCTAssertNotNil(loader.retrieveCPURuntimeEntry(for: entityId),
                        "Entry should be present after store")
    }

    func testRetrieve_returnsNilForUnknownEntity() {
        XCTAssertNil(loader.retrieveCPURuntimeEntry(for: 99999),
                     "Retrieving an unknown entity ID should return nil")
    }

    func testStore_overwritesPreviousEntry() {
        let entityId: EntityID = 20
        loader.storeCPURuntimeEntry(makeEntry(estimatedGPUBytes: 100), for: entityId)
        loader.storeCPURuntimeEntry(makeEntry(estimatedGPUBytes: 200), for: entityId)
        XCTAssertEqual(loader.retrieveCPURuntimeEntry(for: entityId)?.estimatedGPUBytes, 200,
                       "Second store should overwrite the first")
    }

    func testEstimatedGPUBytes_survivesRoundTrip() {
        let entityId: EntityID = 30
        let expectedBytes = 1_234_567
        loader.storeCPURuntimeEntry(makeEntry(estimatedGPUBytes: expectedBytes), for: entityId)
        XCTAssertEqual(loader.retrieveCPURuntimeEntry(for: entityId)?.estimatedGPUBytes, expectedBytes)
    }

    func testEstimatedGPUBytes_zeroIsValid() {
        let entityId: EntityID = 31
        loader.storeCPURuntimeEntry(makeEntry(estimatedGPUBytes: 0), for: entityId)
        XCTAssertEqual(loader.retrieveCPURuntimeEntry(for: entityId)?.estimatedGPUBytes, 0)
    }

    // MARK: - hasCPURuntimeData

    func testHasCPURuntimeData_trueAfterStore() {
        let entityId: EntityID = 40
        XCTAssertFalse(loader.hasCPURuntimeData(for: entityId))
        loader.storeCPURuntimeEntry(makeEntry(), for: entityId)
        XCTAssertTrue(loader.hasCPURuntimeData(for: entityId))
    }

    func testHasCPURuntimeData_falseForUnknownEntity() {
        XCTAssertFalse(loader.hasCPURuntimeData(for: 88888))
    }

    // MARK: - removeCPURuntimeEntry

    func testRemoveCPURuntimeEntry_entryIsAbsentAfterRemoval() {
        let entityId: EntityID = 50
        loader.storeCPURuntimeEntry(makeEntry(), for: entityId)
        XCTAssertTrue(loader.hasCPURuntimeData(for: entityId))

        loader.removeCPURuntimeEntry(for: entityId)
        XCTAssertFalse(loader.hasCPURuntimeData(for: entityId))
        XCTAssertNil(loader.retrieveCPURuntimeEntry(for: entityId))
    }

    func testRemoveCPURuntimeEntry_unknownEntityIsNoOp() {
        loader.removeCPURuntimeEntry(for: 88888) // Must not crash
    }

    func testRemoveCPURuntimeEntry_doesNotAffectOtherEntries() {
        let keepId: EntityID = 60
        let removeId: EntityID = 61
        loader.storeCPURuntimeEntry(makeEntry(), for: keepId)
        loader.storeCPURuntimeEntry(makeEntry(), for: removeId)

        loader.removeCPURuntimeEntry(for: removeId)

        XCTAssertTrue(loader.hasCPURuntimeData(for: keepId))
        XCTAssertFalse(loader.hasCPURuntimeData(for: removeId))
    }

    // MARK: - cancelAll

    func testCancelAll_clearsCPURuntimeRegistry() {
        loader.storeCPURuntimeEntry(makeEntry(), for: 70)
        loader.storeCPURuntimeEntry(makeEntry(), for: 71)

        loader.cancelAll()

        XCTAssertFalse(loader.hasCPURuntimeData(for: 70))
        XCTAssertFalse(loader.hasCPURuntimeData(for: 71))
    }

    func testCancelAll_onEmptyRegistryIsNoOp() {
        loader.cancelAll()
        loader.cancelAll() // Must not crash
    }

    // MARK: - registerChildren / removeOutOfCoreAsset

    func testRemoveOutOfCoreAsset_removesRegisteredChildren() {
        let rootId: EntityID = 80
        let childIds: [EntityID] = [81, 82, 83]

        for id in childIds {
            loader.storeCPURuntimeEntry(makeEntry(), for: id)
        }
        loader.registerChildren(childIds, for: rootId)
        loader.removeOutOfCoreAsset(rootEntityId: rootId)

        for id in childIds {
            XCTAssertFalse(loader.hasCPURuntimeData(for: id),
                           "Child \(id) should be cleared after removeOutOfCoreAsset")
        }
    }

    func testRemoveOutOfCoreAsset_doesNotAffectUnrelatedEntries() {
        let rootId: EntityID = 90
        let childId: EntityID = 91
        let otherId: EntityID = 92

        loader.storeCPURuntimeEntry(makeEntry(), for: childId)
        loader.storeCPURuntimeEntry(makeEntry(), for: otherId)
        loader.registerChildren([childId], for: rootId)

        loader.removeOutOfCoreAsset(rootEntityId: rootId)

        XCTAssertFalse(loader.hasCPURuntimeData(for: childId), "Registered child should be removed")
        XCTAssertTrue(loader.hasCPURuntimeData(for: otherId), "Unrelated entry must not be removed")
    }

    func testRemoveOutOfCoreAsset_unknownRootIsNoOp() {
        loader.removeOutOfCoreAsset(rootEntityId: 99000) // Must not crash
    }

    func testRemoveOutOfCoreAsset_calledTwiceIsIdempotent() {
        let rootId: EntityID = 100
        let childId: EntityID = 101
        loader.storeCPURuntimeEntry(makeEntry(), for: childId)
        loader.registerChildren([childId], for: rootId)

        loader.removeOutOfCoreAsset(rootEntityId: rootId)
        loader.removeOutOfCoreAsset(rootEntityId: rootId) // Must not crash
    }

    // MARK: - getChildren

    func testGetChildren_returnsChildrenInRegistrationOrder() {
        let rootId: EntityID = 110
        let childIds: [EntityID] = [111, 112, 113]
        loader.registerChildren(childIds, for: rootId)
        XCTAssertEqual(loader.getChildren(for: rootId), childIds)
    }

    func testGetChildren_returnsEmptyForUnknownRoot() {
        XCTAssertTrue(loader.getChildren(for: 99999).isEmpty)
    }
}
