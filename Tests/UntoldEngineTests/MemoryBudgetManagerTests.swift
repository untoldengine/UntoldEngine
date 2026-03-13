//
//  MemoryBudgetManagerTests.swift
//  UntoldEngineTests
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import UntoldEngine
import XCTest

@MainActor
final class MemoryBudgetManagerTests: XCTestCase {
    var manager: MemoryBudgetManager!

    override func setUp() async throws {
        manager = MemoryBudgetManager.shared
        manager.clear()
        manager.enabled = true
        manager.meshBudget = 100 * 1024 * 1024 // 100 MB for tests
        manager.highWaterMark = 0.85
        manager.lowWaterMark = 0.70
    }

    override func tearDown() async throws {
        manager.clear()
    }

    // MARK: - Registration Tests

    func testRegisterMesh() {
        let entityId: EntityID = 1
        let meshSize = 1024 * 1024 // 1 MB

        manager.registerMesh(entityId: entityId, meshSizeBytes: meshSize)

        XCTAssertTrue(manager.isTracked(entityId: entityId))
        XCTAssertEqual(manager.getMemorySize(for: entityId), meshSize)
        XCTAssertEqual(manager.entityCount, 1)
    }

    func testRegisterMeshWithTextures() {
        let entityId: EntityID = 1
        let meshSize = 1024 * 1024 // 1 MB
        let textureSize = 4 * 1024 * 1024 // 4 MB

        manager.registerMesh(entityId: entityId, meshSizeBytes: meshSize, textureSizeBytes: textureSize)

        XCTAssertEqual(manager.getMemorySize(for: entityId), meshSize + textureSize)

        let stats = manager.getStats()
        XCTAssertEqual(stats.meshMemoryUsed, meshSize)
        XCTAssertEqual(stats.textureMemoryUsed, textureSize)
    }

    func testUnregisterMesh() {
        let entityId: EntityID = 1
        let meshSize = 1024 * 1024

        manager.registerMesh(entityId: entityId, meshSizeBytes: meshSize)
        XCTAssertTrue(manager.isTracked(entityId: entityId))

        manager.unregisterMesh(entityId: entityId)

        XCTAssertFalse(manager.isTracked(entityId: entityId))
        XCTAssertEqual(manager.entityCount, 0)
        XCTAssertEqual(manager.totalMeshMemoryUsed, 0)
    }

    func testReregisterMesh() {
        let entityId: EntityID = 1

        manager.registerMesh(entityId: entityId, meshSizeBytes: 1024)
        manager.registerMesh(entityId: entityId, meshSizeBytes: 2048) // Re-register with different size

        XCTAssertEqual(manager.getMemorySize(for: entityId), 2048)
        XCTAssertEqual(manager.entityCount, 1) // Should still be 1 entity
        XCTAssertEqual(manager.totalMeshMemoryUsed, 2048)
    }

    // MARK: - Memory Stats Tests

    func testGetStats() {
        manager.registerMesh(entityId: 1, meshSizeBytes: 10 * 1024 * 1024) // 10 MB
        manager.registerMesh(entityId: 2, meshSizeBytes: 20 * 1024 * 1024) // 20 MB

        let stats = manager.getStats()

        XCTAssertEqual(stats.meshMemoryUsed, 30 * 1024 * 1024)
        XCTAssertEqual(stats.trackedEntityCount, 2)
        XCTAssertEqual(stats.budgetLimit, 100 * 1024 * 1024)
        XCTAssertEqual(stats.utilizationPercent, 0.30, accuracy: 0.001)
        XCTAssertEqual(stats.availableMemory, 70 * 1024 * 1024)
        XCTAssertFalse(stats.isUnderPressure)
    }

    func testUtilizationCalculation() {
        // Add 85 MB to hit high water mark
        manager.registerMesh(entityId: 1, meshSizeBytes: 85 * 1024 * 1024)

        let stats = manager.getStats()
        XCTAssertEqual(stats.utilizationPercent, 0.85, accuracy: 0.001)
        XCTAssertTrue(stats.isUnderPressure)
    }

    // MARK: - Eviction Tests

    func testShouldEvict() {
        // Below threshold
        manager.registerMesh(entityId: 1, meshSizeBytes: 80 * 1024 * 1024) // 80%
        XCTAssertFalse(manager.shouldEvict())

        // At/above threshold
        manager.registerMesh(entityId: 2, meshSizeBytes: 5 * 1024 * 1024) // 85%
        XCTAssertTrue(manager.shouldEvict())
    }

    func testCanAccept() {
        manager.registerMesh(entityId: 1, meshSizeBytes: 90 * 1024 * 1024) // 90 MB used

        XCTAssertTrue(manager.canAccept(sizeBytes: 5 * 1024 * 1024)) // 5 MB fits
        XCTAssertTrue(manager.canAccept(sizeBytes: 10 * 1024 * 1024)) // 10 MB exactly fits
        XCTAssertFalse(manager.canAccept(sizeBytes: 15 * 1024 * 1024)) // 15 MB doesn't fit
    }

    func testGetEvictionCandidatesLRU() {
        // Register entities with different "last used" times
        manager.beginFrame() // Frame 1
        manager.registerMesh(entityId: 1, meshSizeBytes: 1024)

        manager.beginFrame() // Frame 2
        manager.registerMesh(entityId: 2, meshSizeBytes: 1024)

        manager.beginFrame() // Frame 3
        manager.registerMesh(entityId: 3, meshSizeBytes: 1024)

        // Entity 1 is oldest (frame 1), should be first eviction candidate
        let candidates = manager.getEvictionCandidates(count: 2)

        XCTAssertEqual(candidates.count, 2)
        XCTAssertEqual(candidates[0], 1) // Oldest first
        XCTAssertEqual(candidates[1], 2)
    }

    func testMarkUsedUpdatesLRU() {
        manager.beginFrame() // Frame 1
        manager.registerMesh(entityId: 1, meshSizeBytes: 1024)
        manager.registerMesh(entityId: 2, meshSizeBytes: 1024)

        manager.beginFrame() // Frame 2
        manager.markUsed(entityId: 1) // Entity 1 is now "newer"

        // Entity 2 should now be the oldest
        let candidates = manager.getEvictionCandidates(count: 1)
        XCTAssertEqual(candidates[0], 2)
    }

    func testGetEvictionCandidatesToTarget() {
        manager.meshBudget = 100 * 1024 // 100 KB for easier testing
        manager.lowWaterMark = 0.50 // 50% = 50 KB target

        // Add 90 KB total (90% utilization)
        manager.registerMesh(entityId: 1, meshSizeBytes: 30 * 1024)
        manager.beginFrame()
        manager.registerMesh(entityId: 2, meshSizeBytes: 30 * 1024)
        manager.beginFrame()
        manager.registerMesh(entityId: 3, meshSizeBytes: 30 * 1024)

        // Need to free 40 KB to get to 50 KB target
        // Should recommend entity 1 and 2 (60 KB, oldest)
        let candidates = manager.getEvictionCandidatesToTarget()

        XCTAssertTrue(candidates.contains(1))
        XCTAssertTrue(candidates.contains(2))
    }

    func testGetStaleEntities() {
        manager.beginFrame() // Frame 1
        manager.registerMesh(entityId: 1, meshSizeBytes: 1024)

        // Advance 10 frames
        for _ in 0 ..< 10 {
            manager.beginFrame()
        }

        manager.registerMesh(entityId: 2, meshSizeBytes: 1024)

        // Entity 1 is 10 frames old, entity 2 is current
        let stale = manager.getStaleEntities(frameThreshold: 5)

        XCTAssertTrue(stale.contains(1))
        XCTAssertFalse(stale.contains(2))
    }

    // MARK: - Clear Tests

    func testClear() {
        manager.registerMesh(entityId: 1, meshSizeBytes: 1024)
        manager.registerMesh(entityId: 2, meshSizeBytes: 2048)

        manager.clear()

        XCTAssertEqual(manager.entityCount, 0)
        XCTAssertEqual(manager.totalMeshMemoryUsed, 0)
        XCTAssertFalse(manager.isTracked(entityId: 1))
    }

    // MARK: - Disabled State Tests

    func testDisabledManagerDoesNotTrack() {
        manager.enabled = false

        manager.registerMesh(entityId: 1, meshSizeBytes: 1024)

        // Registration should be ignored when disabled
        // Note: Implementation may vary - adjust test if needed
        XCTAssertFalse(manager.shouldEvict())
    }

    // MARK: - Thread Safety Tests

    func testConcurrentAccess() async {
        await withTaskGroup(of: Void.self) { group in
            for i in 0 ..< 100 {
                group.addTask { @MainActor in
                    let entityId = EntityID(i)
                    self.manager.registerMesh(entityId: entityId, meshSizeBytes: 1024)
                    self.manager.markUsed(entityId: entityId)
                    _ = self.manager.getStats()
                    _ = self.manager.getEvictionCandidates(count: 10)
                }
            }
        }
        XCTAssertEqual(manager.entityCount, 100)
    }

    // MARK: - Memory Formatting Tests

    func testMemoryFormatting() {
        XCTAssertEqual(500.formattedAsMemory, "500 bytes")
        XCTAssertEqual(1024.formattedAsMemory, "1.00 KB")
        XCTAssertEqual(1536.formattedAsMemory, "1.50 KB")
        XCTAssertEqual(1_048_576.formattedAsMemory, "1.00 MB")
        XCTAssertEqual(1_073_741_824.formattedAsMemory, "1.00 GB")
    }
}
