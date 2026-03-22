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
import MetalKit
import ModelIO
@testable import UntoldEngine
import XCTest

// MARK: - ProgressiveAssetLoader CPU Registry Tests

/// Tests for ProgressiveAssetLoader's CPU mesh registry.
///
/// ProgressiveAssetLoader is now a pure CPU registry: it stores MDLMesh data
/// keyed by entity ID so GeometryStreamingSystem can upload each mesh on demand
/// without re-reading disk. The old per-frame job scheduler (ProgressiveLoadJob,
/// PendingObjectItem, tick() budget, round-robin) was removed; tick() is a
/// retained no-op for call-site compatibility.
@MainActor
final class ProgressiveAssetLoaderRegistryTests: XCTestCase {
    var loader: ProgressiveAssetLoader!
    var device: MTLDevice!
    var textureLoader: TextureLoader!

    override func setUp() async throws {
        loader = ProgressiveAssetLoader.shared
        loader.cancelAll()

        guard let mtlDevice = MTLCreateSystemDefaultDevice() else {
            XCTFail("No Metal device available — skipping ProgressiveAssetLoader tests")
            return
        }
        device = mtlDevice
        renderInfo.device = mtlDevice
        textureLoader = TextureLoader(device: mtlDevice)
    }

    override func tearDown() async throws {
        loader.cancelAll()
        device = nil
        textureLoader = nil
    }

    // MARK: - Helpers

    /// Builds a CPUMeshEntry with a plain MDLObject (no mesh data) and a known
    /// estimatedGPUBytes value so registry round-trips can be verified.
    private func makeEntry(estimatedGPUBytes: Int = 0) -> ProgressiveAssetLoader.CPUMeshEntry {
        ProgressiveAssetLoader.CPUMeshEntry(
            object: MDLObject(),
            vertexDescriptor: MDLVertexDescriptor(),
            textureLoader: textureLoader,
            device: device,
            url: URL(fileURLWithPath: "/dev/null"),
            filename: "test",
            withExtension: "usdz",
            uniqueAssetName: "TestMesh#0",
            estimatedGPUBytes: estimatedGPUBytes,
            residencyPolicy: .fullLoad
        )
    }

    // MARK: - tick() no-op

    func testTickIsNoOp() {
        // tick() is retained only for call-site compatibility; it must not crash
        // and must leave the registry untouched.
        let entityId: EntityID = 1
        loader.storeCPUMesh(makeEntry(), for: entityId)

        loader.tick()
        loader.tick()
        loader.tick()

        XCTAssertNotNil(loader.retrieveCPUMesh(for: entityId),
                        "tick() must not clear CPU registry entries")
    }

    // MARK: - storeCPUMesh / retrieveCPUMesh

    func testStoreThenRetrieve_returnsStoredEntry() {
        let entityId: EntityID = 10
        let entry = makeEntry(estimatedGPUBytes: 512_000)
        loader.storeCPUMesh(entry, for: entityId)

        let retrieved = loader.retrieveCPUMesh(for: entityId)
        XCTAssertNotNil(retrieved, "Entry should be present after store")
    }

    func testRetrieve_returnsNilForUnknownEntity() {
        XCTAssertNil(loader.retrieveCPUMesh(for: 99999),
                     "Retrieving an unknown entity ID should return nil")
    }

    func testStore_overwritesPreviousEntry() {
        let entityId: EntityID = 20
        loader.storeCPUMesh(makeEntry(estimatedGPUBytes: 100), for: entityId)
        loader.storeCPUMesh(makeEntry(estimatedGPUBytes: 200), for: entityId)

        let retrieved = loader.retrieveCPUMesh(for: entityId)
        XCTAssertEqual(retrieved?.estimatedGPUBytes, 200,
                       "Second store should overwrite the first")
    }

    // MARK: - estimatedGPUBytes round-trip

    func testEstimatedGPUBytes_survivesStoreRetrieveRoundTrip() {
        let entityId: EntityID = 30
        let expectedBytes = 1_234_567
        loader.storeCPUMesh(makeEntry(estimatedGPUBytes: expectedBytes), for: entityId)

        let retrieved = loader.retrieveCPUMesh(for: entityId)
        XCTAssertEqual(retrieved?.estimatedGPUBytes, expectedBytes,
                       "estimatedGPUBytes must survive the store / retrieve round-trip")
    }

    func testEstimatedGPUBytes_zeroIsValid() {
        let entityId: EntityID = 31
        loader.storeCPUMesh(makeEntry(estimatedGPUBytes: 0), for: entityId)
        XCTAssertEqual(loader.retrieveCPUMesh(for: entityId)?.estimatedGPUBytes, 0)
    }

    // MARK: - removeCPUMesh

    func testRemoveCPUMesh_entryIsAbsentAfterRemoval() {
        let entityId: EntityID = 40
        loader.storeCPUMesh(makeEntry(), for: entityId)
        XCTAssertNotNil(loader.retrieveCPUMesh(for: entityId))

        loader.removeCPUMesh(for: entityId)
        XCTAssertNil(loader.retrieveCPUMesh(for: entityId),
                     "Entry should be absent after removeCPUMesh")
    }

    func testRemoveCPUMesh_unknownEntityIsNoOp() {
        // Must not crash when removing an entity that was never stored.
        loader.removeCPUMesh(for: 88888)
    }

    func testRemoveCPUMesh_doesNotAffectOtherEntries() {
        let keepId: EntityID = 50
        let removeId: EntityID = 51
        loader.storeCPUMesh(makeEntry(), for: keepId)
        loader.storeCPUMesh(makeEntry(), for: removeId)

        loader.removeCPUMesh(for: removeId)

        XCTAssertNotNil(loader.retrieveCPUMesh(for: keepId),
                        "Removing one entity must not affect other registry entries")
        XCTAssertNil(loader.retrieveCPUMesh(for: removeId))
    }

    // MARK: - cancelAll

    func testCancelAll_clearsCPURegistry() {
        loader.storeCPUMesh(makeEntry(), for: 60)
        loader.storeCPUMesh(makeEntry(), for: 61)
        loader.storeCPUMesh(makeEntry(), for: 62)

        loader.cancelAll()

        XCTAssertNil(loader.retrieveCPUMesh(for: 60))
        XCTAssertNil(loader.retrieveCPUMesh(for: 61))
        XCTAssertNil(loader.retrieveCPUMesh(for: 62))
    }

    func testCancelAll_onEmptyRegistryIsNoOp() {
        // Must not crash when called on an already-empty registry.
        loader.cancelAll()
        loader.cancelAll()
    }

    // MARK: - registerChildren / removeOutOfCoreAsset

    func testRemoveOutOfCoreAsset_removesRegisteredChildren() {
        let rootId: EntityID = 70
        let childIds: [EntityID] = [71, 72, 73]

        for id in childIds {
            loader.storeCPUMesh(makeEntry(), for: id)
        }
        loader.registerChildren(childIds, for: rootId)

        loader.removeOutOfCoreAsset(rootEntityId: rootId)

        for id in childIds {
            XCTAssertNil(loader.retrieveCPUMesh(for: id),
                         "Child \(id) should be cleared after removeOutOfCoreAsset")
        }
    }

    func testRemoveOutOfCoreAsset_doesNotAffectUnrelatedEntries() {
        let rootId: EntityID = 80
        let childId: EntityID = 81
        let otherId: EntityID = 82

        loader.storeCPUMesh(makeEntry(), for: childId)
        loader.storeCPUMesh(makeEntry(), for: otherId)
        loader.registerChildren([childId], for: rootId)

        loader.removeOutOfCoreAsset(rootEntityId: rootId)

        XCTAssertNil(loader.retrieveCPUMesh(for: childId),
                     "Registered child should be removed")
        XCTAssertNotNil(loader.retrieveCPUMesh(for: otherId),
                        "Unrelated entry must not be removed")
    }

    func testRemoveOutOfCoreAsset_unknownRootIsNoOp() {
        // Must not crash when called for a root that was never registered.
        loader.removeOutOfCoreAsset(rootEntityId: 99000)
    }

    func testRemoveOutOfCoreAsset_calledTwiceIsIdempotent() {
        let rootId: EntityID = 90
        let childId: EntityID = 91
        loader.storeCPUMesh(makeEntry(), for: childId)
        loader.registerChildren([childId], for: rootId)

        loader.removeOutOfCoreAsset(rootEntityId: rootId)
        loader.removeOutOfCoreAsset(rootEntityId: rootId) // second call must not crash
    }

    // MARK: - Configuration

    func testFileSizeThresholdBytesDefaultIs50MB() {
        XCTAssertEqual(loader.fileSizeThresholdBytes, 50 * 1024 * 1024)
    }

    func testOutOfCoreObjectCountThresholdDefaultIs50() {
        XCTAssertEqual(loader.outOfCoreObjectCountThreshold, 50)
    }

    func testConfigurationPropertiesAreWritable() {
        let originalSize = loader.fileSizeThresholdBytes
        let originalCount = loader.outOfCoreObjectCountThreshold

        loader.fileSizeThresholdBytes = 100 * 1024 * 1024
        loader.outOfCoreObjectCountThreshold = 200

        XCTAssertEqual(loader.fileSizeThresholdBytes, 100 * 1024 * 1024)
        XCTAssertEqual(loader.outOfCoreObjectCountThreshold, 200)

        // Restore defaults so other tests are not affected.
        loader.fileSizeThresholdBytes = originalSize
        loader.outOfCoreObjectCountThreshold = originalCount
    }

    // MARK: - textureLoadingEnabled flag

    func testTextureLoadingEnabledDefaultIsTrue() {
        XCTAssertTrue(loader.textureLoadingEnabled, "Texture loading should be enabled by default")
    }

    func testTextureLoadingEnabledIsWritable() {
        loader.textureLoadingEnabled = false
        XCTAssertFalse(loader.textureLoadingEnabled)
        loader.textureLoadingEnabled = true
        XCTAssertTrue(loader.textureLoadingEnabled)
    }

    func testEnsureTexturesLoaded_skipsLoadWhenDisabled() {
        // Register a fake asset reference so ensureTexturesLoaded would normally call loadTextures()
        // (with textureLoadingEnabled = false it must not crash, and assetTexturesLoaded
        // must remain empty so a future re-enable actually calls loadTextures()).
        let rootId: EntityID = 9999

        loader.textureLoadingEnabled = false
        // Should not crash; no textures loaded.
        loader.acquireAssetTextureLock(for: rootId)
        loader.ensureTexturesLoaded(for: rootId)
        loader.releaseAssetTextureLock(for: rootId)

        // After re-enabling, a second call should be allowed (entity not in assetTexturesLoaded).
        loader.textureLoadingEnabled = true
        // Just validate no crash and flag is restored.
        XCTAssertTrue(loader.textureLoadingEnabled)

        loader.textureLoadingEnabled = true // restore
    }
}

// MARK: - V2 Warm/Cold Residency Lifecycle Tests

/// Tests for the warm/cold residency lifecycle introduced in V2.
///
/// CPU-warm: MDLAsset + CPUMeshEntry objects are alive in the registry.
/// CPU-cold: MDLAsset released; rehydration context (URL + policy) retained for re-parse.
///
/// These tests are purely CPU-side — no GPU, no disk I/O.
@MainActor
final class ProgressiveAssetLoaderWarmColdTests: XCTestCase {
    var loader: ProgressiveAssetLoader!
    var device: MTLDevice!
    var textureLoader: TextureLoader!

    override func setUp() async throws {
        loader = ProgressiveAssetLoader.shared
        loader.cancelAll()

        guard let mtlDevice = MTLCreateSystemDefaultDevice() else {
            XCTFail("No Metal device available")
            return
        }
        device = mtlDevice
        renderInfo.device = mtlDevice
        textureLoader = TextureLoader(device: mtlDevice)
    }

    override func tearDown() async throws {
        loader.cancelAll()
        device = nil
        textureLoader = nil
    }

    // MARK: - Helpers

    private func makeEntry(estimatedGPUBytes: Int = 0) -> ProgressiveAssetLoader.CPUMeshEntry {
        ProgressiveAssetLoader.CPUMeshEntry(
            object: MDLObject(),
            vertexDescriptor: MDLVertexDescriptor(),
            textureLoader: textureLoader,
            device: device,
            url: URL(fileURLWithPath: "/dev/null"),
            filename: "test",
            withExtension: "usdz",
            uniqueAssetName: "TestMesh#0",
            estimatedGPUBytes: estimatedGPUBytes,
            residencyPolicy: .fullLoad
        )
    }

    // MARK: - Test 1: isColdRoot returns false before releaseWarmAsset

    func testIsColdRoot_falseBeforeRelease() {
        let rootId: EntityID = 200
        loader.registerChildren([201, 202], for: rootId)
        XCTAssertFalse(loader.isColdRoot(rootId),
                       "Asset should start warm (isColdRoot must be false before releaseWarmAsset)")
    }

    // MARK: - Test 2: releaseWarmAsset transitions to cold

    func testReleaseWarmAsset_transitionsToCold() {
        let rootId: EntityID = 210
        let childIds: [EntityID] = [211, 212]

        for id in childIds {
            loader.storeCPUMesh(makeEntry(), for: id)
        }
        loader.registerChildren(childIds, for: rootId)

        loader.releaseWarmAsset(rootEntityId: rootId)

        XCTAssertTrue(loader.isColdRoot(rootId),
                      "isColdRoot must be true after releaseWarmAsset")
    }

    // MARK: - Test 3: releaseWarmAsset clears child CPU entries

    func testReleaseWarmAsset_clearsCPUEntriesForChildren() {
        let rootId: EntityID = 220
        let childIds: [EntityID] = [221, 222, 223]

        for id in childIds {
            loader.storeCPUMesh(makeEntry(estimatedGPUBytes: 1024), for: id)
        }
        loader.registerChildren(childIds, for: rootId)

        loader.releaseWarmAsset(rootEntityId: rootId)

        for id in childIds {
            XCTAssertNil(loader.retrieveCPUMesh(for: id),
                         "Child \(id) CPUMeshEntry must be cleared after releaseWarmAsset")
        }
    }

    // MARK: - Test 4: rehydration context survives releaseWarmAsset

    func testRehydrationContext_survivesReleaseWarmAsset() {
        let rootId: EntityID = 230
        let testURL = URL(fileURLWithPath: "/tmp/test.usdz")
        let policy = AssetLoadingPolicy.fullLoad

        loader.registerChildren([231], for: rootId)
        loader.storeRootRehydrationContext(url: testURL, policy: policy, for: rootId)
        loader.releaseWarmAsset(rootEntityId: rootId)

        let context = loader.rehydrationContext(for: rootId)
        XCTAssertNotNil(context, "Rehydration context must survive releaseWarmAsset")
        XCTAssertEqual(context?.url, testURL, "Rehydration context URL must be preserved")
    }

    // MARK: - Test 5: markAsWarm restores warm state

    func testMarkAsWarm_restoringWarmStateAfterCold() {
        let rootId: EntityID = 240
        loader.registerChildren([241], for: rootId)
        loader.releaseWarmAsset(rootEntityId: rootId)

        XCTAssertTrue(loader.isColdRoot(rootId), "Pre-condition: must be cold")

        loader.markAsWarm(rootEntityId: rootId)

        XCTAssertFalse(loader.isColdRoot(rootId),
                       "isColdRoot must be false after markAsWarm")
    }

    // MARK: - Test 6: getOrCreateRehydrationTask returns same task for concurrent calls

    func testGetOrCreateRehydrationTask_factoryCalledOnlyOnceForDuplicateCalls() {
        let rootId: EntityID = 250
        var factoryCallCount = 0

        let task1 = loader.getOrCreateRehydrationTask(for: rootId) {
            factoryCallCount += 1
            return Task { true }
        }
        _ = loader.getOrCreateRehydrationTask(for: rootId) {
            factoryCallCount += 1
            return Task { true }
        }

        XCTAssertEqual(factoryCallCount, 1,
                       "Factory must be called exactly once even when called twice for the same root")

        loader.clearRehydrationTask(for: rootId)
        task1.cancel()
    }

    // MARK: - Test 7: clearRehydrationTask causes next call to create a new task

    func testClearRehydrationTask_allowsNewTaskOnNextCall() {
        let rootId: EntityID = 260
        var factoryCallCount = 0

        let task1 = loader.getOrCreateRehydrationTask(for: rootId) {
            factoryCallCount += 1
            return Task { false }
        }
        task1.cancel()
        loader.clearRehydrationTask(for: rootId)

        let task2 = loader.getOrCreateRehydrationTask(for: rootId) {
            factoryCallCount += 1
            return Task { true }
        }
        XCTAssertEqual(factoryCallCount, 2,
                       "After clearRehydrationTask, factory must be called again for the same root")

        loader.clearRehydrationTask(for: rootId)
        task2.cancel()
    }

    // MARK: - Test 8: removeOutOfCoreAsset clears cold state

    func testRemoveOutOfCoreAsset_clearsColdState() {
        let rootId: EntityID = 270
        let testURL = URL(fileURLWithPath: "/tmp/remove_test.usdz")

        loader.registerChildren([271], for: rootId)
        loader.storeRootRehydrationContext(url: testURL, policy: .fullLoad, for: rootId)
        loader.releaseWarmAsset(rootEntityId: rootId)

        XCTAssertTrue(loader.isColdRoot(rootId), "Pre-condition: must be cold")

        loader.removeOutOfCoreAsset(rootEntityId: rootId)

        XCTAssertFalse(loader.isColdRoot(rootId),
                       "removeOutOfCoreAsset must clear the cold state")
        XCTAssertNil(loader.rehydrationContext(for: rootId),
                     "removeOutOfCoreAsset must remove the rehydration context")
    }

    // MARK: - Test 9: cancelAll clears all cold state

    func testCancelAll_clearsAllColdState() {
        let rootIds: [EntityID] = [280, 281, 282]
        for rootId in rootIds {
            loader.registerChildren([rootId + 100], for: rootId)
            loader.storeRootRehydrationContext(
                url: URL(fileURLWithPath: "/tmp/asset_\(rootId).usdz"),
                policy: .fullLoad,
                for: rootId
            )
            loader.releaseWarmAsset(rootEntityId: rootId)
        }

        loader.cancelAll()

        for rootId in rootIds {
            XCTAssertFalse(loader.isColdRoot(rootId),
                           "cancelAll must clear cold state for root \(rootId)")
            XCTAssertNil(loader.rehydrationContext(for: rootId),
                         "cancelAll must remove rehydration context for root \(rootId)")
        }
    }

    // MARK: - Test 10: getChildren returns children in registration order

    func testGetChildren_returnsChildrenInRegistrationOrder() {
        let rootId: EntityID = 290
        let childIds: [EntityID] = [291, 292, 293, 294, 295]
        loader.registerChildren(childIds, for: rootId)

        let retrieved = loader.getChildren(for: rootId)
        XCTAssertEqual(retrieved, childIds,
                       "getChildren must return children in the same order they were registered")
    }

    func testGetChildren_returnsEmptyForUnknownRoot() {
        XCTAssertTrue(loader.getChildren(for: 99999).isEmpty,
                      "getChildren must return empty array for an unregistered root")
    }

    // MARK: - Test 11: releaseWarmAsset on already-cold root is a no-op

    func testReleaseWarmAsset_calledTwiceIsNoOp() {
        let rootId: EntityID = 300
        loader.registerChildren([301, 302], for: rootId)
        loader.releaseWarmAsset(rootEntityId: rootId)
        loader.releaseWarmAsset(rootEntityId: rootId) // Must not crash or corrupt state

        XCTAssertTrue(loader.isColdRoot(rootId),
                      "Root should remain cold after a redundant releaseWarmAsset call")
    }
}

// MARK: - LOD CPU Registry Tests

/// Tests for ProgressiveAssetLoader's LOD CPU registry (cpuLODRegistry).
///
/// The LOD+OOC path stores one CPUMeshEntry per LOD level per group entity in
/// cpuLODRegistry, keyed by (EntityID, lodIndex). These tests verify all CRUD
/// operations and lifecycle interactions (releaseWarmAsset, removeOutOfCoreAsset, cancelAll).
@MainActor
final class ProgressiveAssetLoaderLODRegistryTests: XCTestCase {
    var loader: ProgressiveAssetLoader!
    var device: MTLDevice!
    var textureLoader: TextureLoader!

    override func setUp() async throws {
        loader = ProgressiveAssetLoader.shared
        loader.cancelAll()
        guard let mtlDevice = MTLCreateSystemDefaultDevice() else {
            XCTFail("No Metal device available")
            return
        }
        device = mtlDevice
        renderInfo.device = mtlDevice
        textureLoader = TextureLoader(device: mtlDevice)
    }

    override func tearDown() async throws {
        loader.cancelAll()
        device = nil
        textureLoader = nil
    }

    private func makeEntry(uniqueAssetName: String = "TestMesh_LOD0", estimatedGPUBytes: Int = 0) -> ProgressiveAssetLoader.CPUMeshEntry {
        ProgressiveAssetLoader.CPUMeshEntry(
            object: MDLObject(),
            vertexDescriptor: MDLVertexDescriptor(),
            textureLoader: textureLoader,
            device: device,
            url: URL(fileURLWithPath: "/dev/null"),
            filename: "test",
            withExtension: "usdz",
            uniqueAssetName: uniqueAssetName,
            estimatedGPUBytes: estimatedGPUBytes,
            residencyPolicy: .fullLoad
        )
    }

    // MARK: - storeCPULODMesh / retrieveCPULODMesh

    func testStoreThenRetrieve_returnsStoredLODEntry() {
        let entityId: EntityID = 1000
        let entry = makeEntry(uniqueAssetName: "Tree_LOD0", estimatedGPUBytes: 256_000)
        loader.storeCPULODMesh(entry, for: entityId, lodIndex: 0)

        let retrieved = loader.retrieveCPULODMesh(for: entityId, lodIndex: 0)
        XCTAssertNotNil(retrieved, "LOD entry should be present after store")
        XCTAssertEqual(retrieved?.uniqueAssetName, "Tree_LOD0")
        XCTAssertEqual(retrieved?.estimatedGPUBytes, 256_000)
    }

    func testRetrieve_returnsNilForUnknownEntityOrLOD() {
        XCTAssertNil(loader.retrieveCPULODMesh(for: 99999, lodIndex: 0),
                     "Unknown entity should return nil")

        let entityId: EntityID = 1001
        loader.storeCPULODMesh(makeEntry(), for: entityId, lodIndex: 0)
        XCTAssertNil(loader.retrieveCPULODMesh(for: entityId, lodIndex: 5),
                     "Unknown LOD index should return nil")
    }

    func testStore_multipleLODLevelsForSameEntity() {
        let entityId: EntityID = 1002
        loader.storeCPULODMesh(makeEntry(uniqueAssetName: "Tree_LOD0"), for: entityId, lodIndex: 0)
        loader.storeCPULODMesh(makeEntry(uniqueAssetName: "Tree_LOD1"), for: entityId, lodIndex: 1)
        loader.storeCPULODMesh(makeEntry(uniqueAssetName: "Tree_LOD2"), for: entityId, lodIndex: 2)

        XCTAssertEqual(loader.retrieveCPULODMesh(for: entityId, lodIndex: 0)?.uniqueAssetName, "Tree_LOD0")
        XCTAssertEqual(loader.retrieveCPULODMesh(for: entityId, lodIndex: 1)?.uniqueAssetName, "Tree_LOD1")
        XCTAssertEqual(loader.retrieveCPULODMesh(for: entityId, lodIndex: 2)?.uniqueAssetName, "Tree_LOD2")
    }

    func testStore_overwritesPreviousEntryForSameLODIndex() {
        let entityId: EntityID = 1003
        loader.storeCPULODMesh(makeEntry(estimatedGPUBytes: 100), for: entityId, lodIndex: 0)
        loader.storeCPULODMesh(makeEntry(estimatedGPUBytes: 200), for: entityId, lodIndex: 0)

        XCTAssertEqual(loader.retrieveCPULODMesh(for: entityId, lodIndex: 0)?.estimatedGPUBytes, 200,
                       "Second store should overwrite the first for the same LOD index")
    }

    // MARK: - retrieveAllCPULODMeshes

    func testRetrieveAll_returnsAllStoredLevels() {
        let entityId: EntityID = 1010
        loader.storeCPULODMesh(makeEntry(uniqueAssetName: "Rock_LOD0"), for: entityId, lodIndex: 0)
        loader.storeCPULODMesh(makeEntry(uniqueAssetName: "Rock_LOD1"), for: entityId, lodIndex: 1)

        let all = loader.retrieveAllCPULODMeshes(for: entityId)
        XCTAssertNotNil(all, "Should return a dictionary when entries exist")
        XCTAssertEqual(all?.count, 2, "Should have 2 LOD entries")
        XCTAssertEqual(all?[0]?.uniqueAssetName, "Rock_LOD0")
        XCTAssertEqual(all?[1]?.uniqueAssetName, "Rock_LOD1")
    }

    func testRetrieveAll_returnsNilForUnknownEntity() {
        XCTAssertNil(loader.retrieveAllCPULODMeshes(for: 99998),
                     "Unknown entity should return nil")
    }

    // MARK: - hasCPULODData

    func testHasCPULODData_trueAfterStoring() {
        let entityId: EntityID = 1020
        XCTAssertFalse(loader.hasCPULODData(for: entityId), "Should be false before any store")
        loader.storeCPULODMesh(makeEntry(), for: entityId, lodIndex: 0)
        XCTAssertTrue(loader.hasCPULODData(for: entityId), "Should be true after storing a LOD entry")
    }

    func testHasCPULODData_falseForRegularCPUMeshEntry() {
        let entityId: EntityID = 1021
        // Storing in cpuMeshRegistry (not cpuLODRegistry) must not affect hasCPULODData
        loader.storeCPUMesh(makeEntry(), for: entityId)
        XCTAssertFalse(loader.hasCPULODData(for: entityId),
                       "hasCPULODData should remain false for regular OOC entries")
    }

    func testHasCPULODData_falseAfterRemoveCPULODEntry() {
        let entityId: EntityID = 1022
        loader.storeCPULODMesh(makeEntry(), for: entityId, lodIndex: 0)
        XCTAssertTrue(loader.hasCPULODData(for: entityId))

        loader.removeCPULODEntry(for: entityId)
        XCTAssertFalse(loader.hasCPULODData(for: entityId),
                       "hasCPULODData should be false after removeCPULODEntry")
    }

    // MARK: - removeCPULODEntry

    func testRemoveCPULODEntry_removesAllLevels() {
        let entityId: EntityID = 1030
        loader.storeCPULODMesh(makeEntry(), for: entityId, lodIndex: 0)
        loader.storeCPULODMesh(makeEntry(), for: entityId, lodIndex: 1)
        loader.storeCPULODMesh(makeEntry(), for: entityId, lodIndex: 2)

        loader.removeCPULODEntry(for: entityId)

        XCTAssertNil(loader.retrieveCPULODMesh(for: entityId, lodIndex: 0))
        XCTAssertNil(loader.retrieveCPULODMesh(for: entityId, lodIndex: 1))
        XCTAssertNil(loader.retrieveCPULODMesh(for: entityId, lodIndex: 2))
    }

    func testRemoveCPULODEntry_unknownEntityIsNoOp() {
        loader.removeCPULODEntry(for: 99997) // Must not crash
    }

    func testRemoveCPULODEntry_doesNotAffectOtherEntities() {
        let keepId: EntityID = 1040
        let removeId: EntityID = 1041
        loader.storeCPULODMesh(makeEntry(uniqueAssetName: "Tree_LOD0"), for: keepId, lodIndex: 0)
        loader.storeCPULODMesh(makeEntry(uniqueAssetName: "Rock_LOD0"), for: removeId, lodIndex: 0)

        loader.removeCPULODEntry(for: removeId)

        XCTAssertNotNil(loader.retrieveCPULODMesh(for: keepId, lodIndex: 0),
                        "Removing one entity's LOD data must not affect other entities")
    }

    // MARK: - releaseWarmAsset clears LOD entries for children

    func testReleaseWarmAsset_clearsCPULODEntriesForChildren() {
        let rootId: EntityID = 1050
        let groupId: EntityID = 1051

        loader.storeCPULODMesh(makeEntry(uniqueAssetName: "Tree_LOD0"), for: groupId, lodIndex: 0)
        loader.storeCPULODMesh(makeEntry(uniqueAssetName: "Tree_LOD1"), for: groupId, lodIndex: 1)
        loader.registerChildren([groupId], for: rootId)

        loader.releaseWarmAsset(rootEntityId: rootId)

        XCTAssertNil(loader.retrieveCPULODMesh(for: groupId, lodIndex: 0),
                     "LOD entry for LOD0 should be cleared after releaseWarmAsset")
        XCTAssertNil(loader.retrieveCPULODMesh(for: groupId, lodIndex: 1),
                     "LOD entry for LOD1 should be cleared after releaseWarmAsset")
        XCTAssertFalse(loader.hasCPULODData(for: groupId),
                       "hasCPULODData should be false after releaseWarmAsset")
    }

    // MARK: - removeOutOfCoreAsset clears LOD entries

    func testRemoveOutOfCoreAsset_clearsCPULODEntriesForChildren() {
        let rootId: EntityID = 1060
        let groupId1: EntityID = 1061
        let groupId2: EntityID = 1062

        loader.storeCPULODMesh(makeEntry(uniqueAssetName: "Tree_LOD0"), for: groupId1, lodIndex: 0)
        loader.storeCPULODMesh(makeEntry(uniqueAssetName: "Rock_LOD0"), for: groupId2, lodIndex: 0)
        loader.registerChildren([groupId1, groupId2], for: rootId)

        loader.removeOutOfCoreAsset(rootEntityId: rootId)

        XCTAssertFalse(loader.hasCPULODData(for: groupId1),
                       "Group 1 LOD data should be cleared after removeOutOfCoreAsset")
        XCTAssertFalse(loader.hasCPULODData(for: groupId2),
                       "Group 2 LOD data should be cleared after removeOutOfCoreAsset")
    }

    // MARK: - cancelAll clears LOD registry

    func testCancelAll_clearsCPULODRegistry() {
        let entityId1: EntityID = 1070
        let entityId2: EntityID = 1071
        loader.storeCPULODMesh(makeEntry(), for: entityId1, lodIndex: 0)
        loader.storeCPULODMesh(makeEntry(), for: entityId2, lodIndex: 0)
        loader.storeCPULODMesh(makeEntry(), for: entityId2, lodIndex: 1)

        loader.cancelAll()

        XCTAssertFalse(loader.hasCPULODData(for: entityId1),
                       "cancelAll must clear all LOD registry entries")
        XCTAssertFalse(loader.hasCPULODData(for: entityId2),
                       "cancelAll must clear all LOD registry entries")
    }

    // MARK: - LOD and regular OOC registries are independent

    func testLODAndRegularRegistriesAreIndependent() {
        let entityId: EntityID = 1080
        loader.storeCPUMesh(makeEntry(uniqueAssetName: "Regular#0"), for: entityId)
        loader.storeCPULODMesh(makeEntry(uniqueAssetName: "LOD_LOD0"), for: entityId, lodIndex: 0)

        // Both should be independently accessible
        XCTAssertNotNil(loader.retrieveCPUMesh(for: entityId),
                        "Regular OOC entry should be accessible independently")
        XCTAssertNotNil(loader.retrieveCPULODMesh(for: entityId, lodIndex: 0),
                        "LOD OOC entry should be accessible independently")

        // Removing from LOD registry must not affect regular registry
        loader.removeCPULODEntry(for: entityId)
        XCTAssertNotNil(loader.retrieveCPUMesh(for: entityId),
                        "Regular OOC entry must survive removeCPULODEntry")

        // Removing from regular registry must not affect LOD registry data
        loader.storeCPULODMesh(makeEntry(uniqueAssetName: "LOD_LOD0"), for: entityId, lodIndex: 0)
        loader.removeCPUMesh(for: entityId)
        XCTAssertTrue(loader.hasCPULODData(for: entityId),
                      "LOD OOC data must survive removeCPUMesh")
    }
}
