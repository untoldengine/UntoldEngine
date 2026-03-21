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
            estimatedGPUBytes: estimatedGPUBytes
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
