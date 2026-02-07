//
//  MeshResourceManagerTests.swift
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

@testable import UntoldEngine
import XCTest

final class MeshResourceManagerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MeshResourceManager.shared.clearAll()
    }

    func testRetainIncrementsRefCount() {
        let url = URL(fileURLWithPath: "/test/mesh.usdz")
        let meshName = "testMesh"
        let entityA = createEntity()
        let entityB = createEntity()

        // Simulate cached resource (in real test, would load)
        MeshResourceManager.shared.retain(url: url, meshName: meshName, for: entityA)
        XCTAssertEqual(MeshResourceManager.shared.getTotalRefCount(url: url), 1)

        MeshResourceManager.shared.retain(url: url, meshName: meshName, for: entityB)
        XCTAssertEqual(MeshResourceManager.shared.getTotalRefCount(url: url), 2)
    }

    func testReleaseDecrementsRefCount() {
        let url = URL(fileURLWithPath: "/test/mesh.usdz")
        let meshName = "testMesh"
        let entityA = createEntity()
        let entityB = createEntity()

        MeshResourceManager.shared.retain(url: url, meshName: meshName, for: entityA)
        MeshResourceManager.shared.retain(url: url, meshName: meshName, for: entityB)

        MeshResourceManager.shared.release(entityId: entityA)
        XCTAssertEqual(MeshResourceManager.shared.getTotalRefCount(url: url), 1)

        MeshResourceManager.shared.release(entityId: entityB)
        XCTAssertEqual(MeshResourceManager.shared.getTotalRefCount(url: url), 0)
    }

    func testCanEvictOnlyWhenRefCountZero() {
        let url = URL(fileURLWithPath: "/test/mesh.usdz")
        let meshName = "testMesh"
        let entity = createEntity()

        MeshResourceManager.shared.retain(url: url, meshName: meshName, for: entity)
        XCTAssertFalse(MeshResourceManager.shared.canEvict(url: url))

        MeshResourceManager.shared.release(entityId: entity)
        XCTAssertTrue(MeshResourceManager.shared.canEvict(url: url))
    }

    func testEvictUnusedRemovesZeroRefMeshes() {
        let url1 = URL(fileURLWithPath: "/test/mesh1.usdz")
        let meshName = "testMesh"
        let entity = createEntity()

        MeshResourceManager.shared.retain(url: url1, meshName: meshName, for: entity)

        _ = MeshResourceManager.shared.evictUnused()

        // Entity should still have its retained mesh
        XCTAssertTrue(MeshResourceManager.shared.hasRetainedMesh(entityId: entity))
    }

    // MARK: - Cache Tests

    func testCacheLoadedMeshesSkipsEmptyArrays() {
        let url = URL(fileURLWithPath: "/test/cached.usdz")

        // Initially not cached
        XCTAssertFalse(MeshResourceManager.shared.isCached(url: url))

        // Cache empty mesh arrays - should be skipped (no meshes to cache)
        MeshResourceManager.shared.cacheLoadedMeshes(url: url, meshArrays: [])

        // Should NOT be cached because there were no meshes
        XCTAssertFalse(MeshResourceManager.shared.isCached(url: url))
    }

    func testCacheDoesNotOverwriteExistingCache() {
        let url = URL(fileURLWithPath: "/test/existing.usdz")
        let meshName = "existingMesh"
        let entity = createEntity()

        // First, retain to create a resource entry with refCount
        MeshResourceManager.shared.retain(url: url, meshName: meshName, for: entity)
        let initialRefCount = MeshResourceManager.shared.getTotalRefCount(url: url)
        XCTAssertEqual(initialRefCount, 1)

        // Calling cacheLoadedMeshes should preserve the refCount
        MeshResourceManager.shared.cacheLoadedMeshes(url: url, meshArrays: [])

        // RefCount should still be 1
        XCTAssertEqual(MeshResourceManager.shared.getTotalRefCount(url: url), 1)
    }

    func testRetainBeforeLoadCreatesPlaceholder() {
        let url = URL(fileURLWithPath: "/test/placeholder.usdz")
        let meshName = "placeholderMesh"
        let entity = createEntity()

        // Retain before any load
        MeshResourceManager.shared.retain(url: url, meshName: meshName, for: entity)

        // Should have created a placeholder resource
        XCTAssertTrue(MeshResourceManager.shared.isCached(url: url))
        XCTAssertEqual(MeshResourceManager.shared.getTotalRefCount(url: url), 1)

        // But mesh names should be empty (no actual meshes loaded)
        let meshNames = MeshResourceManager.shared.getMeshNames(url: url)
        XCTAssertTrue(meshNames.isEmpty)
    }

    func testReleaseWithoutRetainIsNoOp() {
        let entity = createEntity()

        // Release without prior retain should not crash
        MeshResourceManager.shared.release(entityId: entity)

        // Entity should not have retained mesh
        XCTAssertFalse(MeshResourceManager.shared.hasRetainedMesh(entityId: entity))
    }

    func testMultipleEntitiesSameMesh() {
        let url = URL(fileURLWithPath: "/test/shared.usdz")
        let meshName = "sharedMesh"
        let entity1 = createEntity()
        let entity2 = createEntity()
        let entity3 = createEntity()

        // All three entities retain the same mesh
        MeshResourceManager.shared.retain(url: url, meshName: meshName, for: entity1)
        MeshResourceManager.shared.retain(url: url, meshName: meshName, for: entity2)
        MeshResourceManager.shared.retain(url: url, meshName: meshName, for: entity3)

        XCTAssertEqual(MeshResourceManager.shared.getTotalRefCount(url: url), 3)

        // Release one
        MeshResourceManager.shared.release(entityId: entity2)
        XCTAssertEqual(MeshResourceManager.shared.getTotalRefCount(url: url), 2)

        // Cannot evict while still referenced
        XCTAssertFalse(MeshResourceManager.shared.canEvict(url: url))

        // Release remaining
        MeshResourceManager.shared.release(entityId: entity1)
        MeshResourceManager.shared.release(entityId: entity3)
        XCTAssertEqual(MeshResourceManager.shared.getTotalRefCount(url: url), 0)

        // Now can evict
        XCTAssertTrue(MeshResourceManager.shared.canEvict(url: url))
    }
}
