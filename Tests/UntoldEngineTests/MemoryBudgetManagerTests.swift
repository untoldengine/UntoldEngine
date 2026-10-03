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
        // shouldEvict() fires when the geometry pool OR texture pool reaches 85%.
        // With meshBudget = 100 MB: geometryBudget = 60 MB, textureBudget = 40 MB.

        // Geometry at 80% of its pool (48 MB / 60 MB) — both pools below threshold.
        manager.registerMesh(entityId: 1, meshSizeBytes: Int(Double(manager.geometryBudget) * 0.80))
        XCTAssertFalse(manager.shouldEvict())

        // Push geometry past its 85% threshold.
        manager.registerMesh(entityId: 2, meshSizeBytes: Int(Double(manager.geometryBudget) * 0.06))
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

    func testGetEvictionCandidatesCorrectAtScale() {
        // Verify LRU-selection correctness holds with many entries and
        // randomized recency, not just the small hand-ordered fixtures above.
        // Registration order determines recency (each beginFrame() advances
        // lastUsedFrame), so shuffling the order entities are registered in
        // shuffles their staleness ranking independent of entityId.
        var entityIds = (1 ... 400).map { EntityID($0) }
        entityIds.shuffle()

        var registrationRank: [EntityID: Int] = [:]
        for (rank, id) in entityIds.enumerated() {
            manager.beginFrame()
            manager.registerMesh(entityId: id, meshSizeBytes: 1024)
            registrationRank[id] = rank
        }

        // The 5 oldest entities are the first 5 registered.
        let expectedOldest = Set(entityIds.prefix(5))

        let candidates = manager.getEvictionCandidates(count: 5)
        XCTAssertEqual(candidates.count, 5)
        XCTAssertEqual(Set(candidates), expectedOldest)

        // getEvictionCandidatesToTarget should also only ever return the
        // stalest entries first, never something newer while something
        // older remains unselected.
        manager.meshBudget = entityIds.count * 1024 // full utilization at 100%
        manager.lowWaterMark = 0.10 // force freeing ~90% of tracked memory

        let toTargetCandidates = manager.getEvictionCandidatesToTarget()
        let selectedRanks = toTargetCandidates.map { registrationRank[$0]! }
        let unselectedRanks = Set(entityIds).subtracting(toTargetCandidates).map { registrationRank[$0]! }

        if let maxSelectedRank = selectedRanks.max(), let minUnselectedRank = unselectedRanks.min() {
            XCTAssertLessThan(
                maxSelectedRank, minUnselectedRank,
                "every selected entry must be older than every entry left behind"
            )
        }
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

    // MARK: - Gaussian working set

    /// The Gaussian splat frame's shared working set is one ledger entry beside the entities',
    /// replaced on every call, counted with the geometry and cleared with everything else.
    func testGaussianWorkingSetBytesAreOneReplaceableGeometryEntry() {
        manager.registerMesh(entityId: 1, meshSizeBytes: 1000)

        manager.setGaussianWorkingSetBytes(5000)
        XCTAssertEqual(manager.gaussianWorkingSetBytesTracked, 5000)
        XCTAssertEqual(manager.totalMeshMemoryUsed, 6000)
        XCTAssertEqual(manager.getMemorySize(for: 1), 1000, "the set is not any entity's")
        XCTAssertEqual(manager.entityCount, 1)

        manager.setGaussianWorkingSetBytes(2000)
        XCTAssertEqual(manager.gaussianWorkingSetBytesTracked, 2000, "replaced, not accumulated")
        XCTAssertEqual(manager.totalMeshMemoryUsed, 3000)

        manager.setGaussianWorkingSetBytes(-1)
        XCTAssertEqual(manager.gaussianWorkingSetBytesTracked, 0, "clamped at zero")
        XCTAssertEqual(manager.totalMeshMemoryUsed, 1000)

        manager.setGaussianWorkingSetBytes(4000)
        XCTAssertFalse(manager.canAcceptMesh(sizeBytes: manager.geometryBudget - 4000), "it counts against the geometry budget")
        XCTAssertTrue(manager.canAcceptMesh(sizeBytes: manager.geometryBudget - 5000))

        manager.clear()
        XCTAssertEqual(manager.gaussianWorkingSetBytesTracked, 0)
        XCTAssertEqual(manager.totalMeshMemoryUsed, 0)
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

    // MARK: - Combined Mesh + Texture Memory Tests

    // These tests verify the fix that made utilizationPercent, availableMemory,
    // and shouldEvict() use the combined mesh + texture total rather than mesh alone.

    func testUtilizationIncludesTextureMemory() {
        // 20 MB mesh + 40 MB textures = 60 MB / 100 MB budget → 60%.
        manager.registerMesh(entityId: 1, meshSizeBytes: 20 * 1024 * 1024, textureSizeBytes: 40 * 1024 * 1024)

        let stats = manager.getStats()
        XCTAssertEqual(stats.meshMemoryUsed, 20 * 1024 * 1024)
        XCTAssertEqual(stats.textureMemoryUsed, 40 * 1024 * 1024)
        XCTAssertEqual(stats.totalTrackedMemory, 60 * 1024 * 1024)
        XCTAssertEqual(stats.utilizationPercent, 0.60, accuracy: 0.001)
    }

    func testAvailableMemoryAccountsForTextureMemory() {
        // 30 MB mesh + 20 MB textures used → 50 MB available from 100 MB budget.
        manager.registerMesh(entityId: 1, meshSizeBytes: 30 * 1024 * 1024, textureSizeBytes: 20 * 1024 * 1024)

        let stats = manager.getStats()
        XCTAssertEqual(stats.availableMemory, 50 * 1024 * 1024)
    }

    func testShouldEvictTriggeredByTextureMemoryAlone() {
        // Only 5 MB of mesh, but 82 MB of textures → combined 87% > 85% high water mark.
        manager.registerMesh(entityId: 1, meshSizeBytes: 5 * 1024 * 1024, textureSizeBytes: 82 * 1024 * 1024)

        XCTAssertTrue(manager.shouldEvict())
    }

    func testShouldNotEvictWhenCombinedMemoryIsBelowThreshold() {
        // Geometry at 50% of its pool, texture at 70% of its pool — both below 85%.
        // With meshBudget = 100 MB: geometryBudget = 60 MB, textureBudget = 40 MB.
        let meshAmt = Int(Double(manager.geometryBudget) * 0.50)
        let textureAmt = Int(Double(manager.textureBudget) * 0.70)
        manager.registerMesh(entityId: 1, meshSizeBytes: meshAmt, textureSizeBytes: textureAmt)

        XCTAssertFalse(manager.shouldEvict())
    }

    func testTotalTrackedMemoryAcrossMultipleEntities() {
        manager.registerMesh(entityId: 1, meshSizeBytes: 10 * 1024 * 1024, textureSizeBytes: 5 * 1024 * 1024)
        manager.registerMesh(entityId: 2, meshSizeBytes: 15 * 1024 * 1024, textureSizeBytes: 10 * 1024 * 1024)

        let stats = manager.getStats()
        XCTAssertEqual(stats.meshMemoryUsed, 25 * 1024 * 1024)
        XCTAssertEqual(stats.textureMemoryUsed, 15 * 1024 * 1024)
        XCTAssertEqual(stats.totalTrackedMemory, 40 * 1024 * 1024)
    }

    func testClearResetsTextureMemory() {
        manager.registerMesh(entityId: 1, meshSizeBytes: 10 * 1024 * 1024, textureSizeBytes: 20 * 1024 * 1024)
        manager.clear()

        let stats = manager.getStats()
        XCTAssertEqual(stats.textureMemoryUsed, 0)
        XCTAssertEqual(stats.totalTrackedMemory, 0)
    }

    // MARK: - Geometry-only gate (shouldEvictGeometry / canAcceptMesh)

    func testShouldEvictGeometry_notTriggeredByTextureMemoryAlone() {
        // 90 MB of texture memory on a 100 MB budget — combined gate fires, geo gate must not.
        manager.registerMesh(entityId: 1, meshSizeBytes: 1 * 1024 * 1024, textureSizeBytes: 89 * 1024 * 1024)

        XCTAssertTrue(manager.shouldEvict(), "Combined gate should fire when total ≥ 85 %")
        XCTAssertFalse(manager.shouldEvictGeometry(), "Geo-only gate must not fire when mesh memory is low")
    }

    func testShouldEvictGeometry_triggeredWhenMeshMemoryHigh() {
        // 86 MB of mesh memory on a 100 MB budget — geo gate must fire.
        manager.registerMesh(entityId: 1, meshSizeBytes: 86 * 1024 * 1024)

        XCTAssertTrue(manager.shouldEvictGeometry(), "Geo-only gate should fire when mesh memory ≥ 85 %")
    }

    func testShouldEvictGeometry_notTriggeredWhenBelowThreshold() {
        manager.registerMesh(entityId: 1, meshSizeBytes: 50 * 1024 * 1024)

        XCTAssertFalse(manager.shouldEvictGeometry(), "Geo-only gate should not fire below high-water mark")
    }

    func testCanAcceptMesh_trueWhenBelowBudget() {
        manager.registerMesh(entityId: 1, meshSizeBytes: 10 * 1024 * 1024)
        let candidate = 5 * 1024 * 1024 // 5 MB

        XCTAssertTrue(manager.canAcceptMesh(sizeBytes: candidate), "Should accept mesh that fits within budget")
    }

    func testCanAcceptMesh_falseWhenExceedsBudget() {
        manager.registerMesh(entityId: 1, meshSizeBytes: 98 * 1024 * 1024)
        let candidate = 5 * 1024 * 1024 // would push to 103 MB > 100 MB budget

        XCTAssertFalse(manager.canAcceptMesh(sizeBytes: candidate), "Should reject mesh that exceeds budget")
    }

    func testCanAcceptMesh_ignoresTextureMemory() {
        // 80 MB texture + 5 MB mesh = 85 MB combined, but mesh alone is only 5 MB.
        // canAcceptMesh must look only at mesh memory.
        manager.registerMesh(entityId: 1, meshSizeBytes: 5 * 1024 * 1024, textureSizeBytes: 80 * 1024 * 1024)
        let candidate = 10 * 1024 * 1024 // 5 + 10 = 15 MB mesh, well within 100 MB budget

        XCTAssertTrue(manager.canAcceptMesh(sizeBytes: candidate),
                      "canAcceptMesh should ignore texture memory and pass when mesh-only budget is fine")
    }

    // MARK: - Texture Reservation Tests (V1.4 — TOCTOU fix)

    // These tests verify the atomic reserveTexture / releaseTextureReservation pair
    // that eliminates the check-then-act race in TextureStreamingSystem.

    func testReserveTexture_succeedsWhenBudgetAvailable() {
        // 10 MB used, 90 MB free — a 20 MB reservation should succeed.
        manager.registerMesh(entityId: 1, meshSizeBytes: 10 * 1024 * 1024)

        XCTAssertTrue(manager.reserveTexture(sizeBytes: 20 * 1024 * 1024),
                      "reserveTexture should succeed when budget has headroom")
        manager.releaseTextureReservation(sizeBytes: 20 * 1024 * 1024) // cleanup
    }

    func testReserveTexture_failsWhenBudgetFull() {
        // Texture pool (40 MB with meshBudget = 100 MB) is nearly full —
        // a reservation that would overshoot it must be rejected.
        // Geometry memory does not affect the texture pool.
        let nearFull = Int(Double(manager.textureBudget) * 0.96)
        manager.registerMesh(entityId: 1, meshSizeBytes: 1 * 1024 * 1024, textureSizeBytes: nearFull)

        XCTAssertFalse(manager.reserveTexture(sizeBytes: Int(Double(manager.textureBudget) * 0.10)),
                       "reserveTexture should fail when the texture budget would be exceeded")
    }

    func testReserveTexture_secondCallSeesReducedHeadroom() {
        // Texture budget (40 MB). Reserve 60% → success. Reserve another 60% → must fail.
        let sixtyPct = Int(Double(manager.textureBudget) * 0.60)
        XCTAssertTrue(manager.reserveTexture(sizeBytes: sixtyPct),
                      "First 60% texture reservation should succeed on an empty budget")
        XCTAssertFalse(manager.reserveTexture(sizeBytes: sixtyPct),
                       "Second 60% reservation must fail — first reservation reduces apparent headroom")

        manager.releaseTextureReservation(sizeBytes: sixtyPct) // cleanup
    }

    func testReleaseTextureReservation_restoresHeadroom() {
        // Reserve 60% of texture budget, verify a second 60% fails, release, verify it succeeds.
        let sixtyPct = Int(Double(manager.textureBudget) * 0.60)
        XCTAssertTrue(manager.reserveTexture(sizeBytes: sixtyPct))
        XCTAssertFalse(manager.reserveTexture(sizeBytes: sixtyPct),
                       "Second reservation should fail before release")

        manager.releaseTextureReservation(sizeBytes: sixtyPct)

        XCTAssertTrue(manager.reserveTexture(sizeBytes: sixtyPct),
                      "After releasing the first reservation the second attempt should succeed")
        manager.releaseTextureReservation(sizeBytes: sixtyPct) // cleanup
    }

    func testReleaseTextureReservation_doesNotGoBelowZero() {
        // Releasing more than was reserved must clamp at 0, not underflow.
        // If inFlightTextureReservation went negative, canAcceptTexture would over-report headroom.
        manager.releaseTextureReservation(sizeBytes: 100 * 1024 * 1024)
        // Fill the texture pool to near-capacity and verify the reservation is correctly rejected.
        let nearFull = Int(Double(manager.textureBudget) * 0.97)
        manager.registerMesh(entityId: 1, meshSizeBytes: 1 * 1024 * 1024, textureSizeBytes: nearFull)
        XCTAssertFalse(manager.reserveTexture(sizeBytes: Int(Double(manager.textureBudget) * 0.10)),
                       "Over-releasing must not create phantom headroom — texture budget should still be nearly full")
    }

    func testCanAcceptTexture_includesInFlightReservation() {
        // 50 MB used. Reserve 40 MB in-flight (total committed = 90 MB).
        // canAcceptTexture for 15 MB would push to 105 MB > 100 MB budget → must return false.
        manager.registerMesh(entityId: 1, meshSizeBytes: 50 * 1024 * 1024)
        _ = manager.reserveTexture(sizeBytes: 40 * 1024 * 1024)

        XCTAssertFalse(manager.canAcceptTexture(sizeBytes: 15 * 1024 * 1024),
                       "canAcceptTexture must account for in-flight reservations")

        manager.releaseTextureReservation(sizeBytes: 40 * 1024 * 1024) // cleanup
    }

    func testCanAcceptTexture_trueWhenReservationFitsWithinBudget() {
        // Texture budget = 40 MB (with meshBudget = 100 MB). 20 MB reserved in-flight.
        // 20 MB query: (0 used + 20 in-flight + 20 query) = 40 MB ≤ 40 MB budget → fits.
        // Geometry memory (50 MB mesh) does not affect the texture pool.
        manager.registerMesh(entityId: 1, meshSizeBytes: 50 * 1024 * 1024)
        _ = manager.reserveTexture(sizeBytes: 20 * 1024 * 1024)

        XCTAssertTrue(manager.canAcceptTexture(sizeBytes: 20 * 1024 * 1024),
                      "canAcceptTexture should return true when reserved + query still fits in texture budget")

        manager.releaseTextureReservation(sizeBytes: 20 * 1024 * 1024) // cleanup
    }

    func testClearResetsInFlightReservation() {
        // Reserve most of the texture budget, then clear. After clear a fresh reservation must succeed.
        let nearFull = Int(Double(manager.textureBudget) * 0.90)
        _ = manager.reserveTexture(sizeBytes: nearFull)
        manager.clear() // resets everything including inFlightTextureReservation

        // With a fresh state, a 50% reservation should succeed.
        let halfBudget = Int(Double(manager.textureBudget) * 0.50)
        XCTAssertTrue(manager.reserveTexture(sizeBytes: halfBudget),
                      "clear() must reset inFlightTextureReservation to zero")
        manager.releaseTextureReservation(sizeBytes: halfBudget) // cleanup
    }

    // MARK: - Allocations several entities hold

    private func allocation(_ object: AnyObject, _ bytes: Int) -> GPUAllocation {
        GPUAllocation(object: object, bytes: bytes)
    }

    func testABufferSeveralEntitiesHoldIsCountedOnce() {
        // 500 placements of one model: one set of buffers, one texture.
        let vertices = NSObject(), indices = NSObject(), texture = NSObject()
        for entity in 1 ... 500 {
            manager.registerMesh(
                entityId: EntityID(entity),
                meshAllocations: [allocation(vertices, 3000), allocation(indices, 1000)],
                textureAllocations: [allocation(texture, 8000)]
            )
        }

        let stats = manager.getStats()
        XCTAssertEqual(stats.meshMemoryUsed, 4000)
        XCTAssertEqual(stats.textureMemoryUsed, 8000)
        XCTAssertEqual(stats.trackedEntityCount, 500)
    }

    func testAnEntitysOwnBuffersAddToTheOnesItShares() {
        let shared = NSObject(), ownA = NSObject(), ownB = NSObject()
        manager.registerMesh(entityId: 1, meshAllocations: [allocation(shared, 1000), allocation(ownA, 200)], textureAllocations: [])
        manager.registerMesh(entityId: 2, meshAllocations: [allocation(shared, 1000), allocation(ownB, 50)], textureAllocations: [])

        XCTAssertEqual(manager.getStats().meshMemoryUsed, 1250)
    }

    func testABufferAnEntityUsesTwiceIsCountedOnce() {
        // The submeshes of a mesh can draw from one index buffer.
        let indices = NSObject()
        manager.registerMesh(entityId: 1, meshAllocations: [allocation(indices, 600), allocation(indices, 600)], textureAllocations: [])

        XCTAssertEqual(manager.getStats().meshMemoryUsed, 600)
    }

    func testASharedBufferStaysInTheTotalUntilItsLastHolderLeaves() {
        let buffer = NSObject(), texture = NSObject()
        for entity in 1 ... 3 {
            manager.registerMesh(entityId: EntityID(entity), meshAllocations: [allocation(buffer, 1000)], textureAllocations: [allocation(texture, 500)])
        }

        manager.unregisterMesh(entityId: 1)
        manager.unregisterMesh(entityId: 2)
        XCTAssertEqual(manager.getStats().meshMemoryUsed, 1000)
        XCTAssertEqual(manager.getStats().textureMemoryUsed, 500)

        manager.unregisterMesh(entityId: 3)
        XCTAssertEqual(manager.getStats().meshMemoryUsed, 0)
        XCTAssertEqual(manager.getStats().textureMemoryUsed, 0)
    }

    func testRegisteringAnEntityAgainReplacesWhatItHeld() {
        let first = NSObject(), second = NSObject()
        manager.registerMesh(entityId: 1, meshAllocations: [allocation(first, 1000)], textureAllocations: [])
        manager.registerMesh(entityId: 2, meshAllocations: [allocation(first, 1000)], textureAllocations: [])

        manager.registerMesh(entityId: 1, meshAllocations: [allocation(second, 300)], textureAllocations: [])
        XCTAssertEqual(manager.getStats().meshMemoryUsed, 1300, "entity 2 still holds the first buffer")

        manager.registerMesh(entityId: 2, meshAllocations: [allocation(second, 300)], textureAllocations: [])
        XCTAssertEqual(manager.getStats().meshMemoryUsed, 300)
    }

    func testASizeRegisteredAsANumberReplacesTheAllocations() {
        // The streaming paths register an entity's render component and then its size.
        let buffer = NSObject()
        manager.registerMesh(entityId: 1, meshAllocations: [allocation(buffer, 1000)], textureAllocations: [])
        manager.registerMesh(entityId: 2, meshAllocations: [allocation(buffer, 1000)], textureAllocations: [])

        manager.registerMesh(entityId: 2, meshSizeBytes: 700)

        XCTAssertEqual(manager.getStats().meshMemoryUsed, 1700, "a number is the entity's own")
        manager.unregisterMesh(entityId: 1)
        XCTAssertEqual(manager.getStats().meshMemoryUsed, 700)
    }

    func testEvictingAnEntityFreesOnlyWhatNoOtherEntityHolds() {
        let shared = NSObject(), own = NSObject()
        manager.registerMesh(entityId: 1, meshAllocations: [allocation(shared, 1000), allocation(own, 200)], textureAllocations: [])
        manager.registerMesh(entityId: 2, meshAllocations: [allocation(shared, 1000)], textureAllocations: [])

        XCTAssertEqual(manager.getMemorySize(for: 1), 200)
        XCTAssertEqual(manager.getMemorySize(for: 2), 0)

        manager.unregisterMesh(entityId: 1)
        XCTAssertEqual(manager.getMemorySize(for: 2), 1000, "the last holder frees the buffer")
        XCTAssertEqual(manager.getEvictionCandidatesWithSizes(count: 1).first?.sizeBytes, 1000)
    }

    func testEvictionToATargetCountsASharedBufferWithItsLastHolder() {
        manager.meshBudget = 100 * 1024
        manager.lowWaterMark = 0.50
        let budget = manager.geometryBudget + manager.textureBudget
        let shared = NSObject()
        let sharedBytes = budget * 6 / 10

        // Three old placements of one model, then an entity of its own, the most recent.
        for entity in 1 ... 3 {
            manager.beginFrame()
            manager.registerMesh(entityId: EntityID(entity), meshAllocations: [allocation(shared, sharedBytes)], textureAllocations: [])
        }
        manager.beginFrame()
        manager.registerMesh(entityId: 4, meshSizeBytes: budget * 3 / 10)

        // 90 % of the budget is in use and 40 % has to go. The first two placements free
        // nothing; the model goes with the third.
        XCTAssertEqual(manager.getEvictionCandidatesToTarget(), [1, 2, 3])
    }

    func testATextureSizeUpdateLetsGoOfTheTexturesTheEntityShared() {
        let texture = NSObject()
        manager.registerMesh(entityId: 1, meshAllocations: [], textureAllocations: [allocation(texture, 8000)])
        manager.registerMesh(entityId: 2, meshAllocations: [], textureAllocations: [allocation(texture, 8000)])

        // Texture streaming gave entity 2 textures of its own.
        manager.updateTextureSizeBytes(entityId: 2, newSizeBytes: 2000)
        XCTAssertEqual(manager.getStats().textureMemoryUsed, 10000)

        manager.unregisterMesh(entityId: 1)
        XCTAssertEqual(manager.getStats().textureMemoryUsed, 2000)
        manager.updateTextureSizeBytes(entityId: 2, newSizeBytes: 500)
        XCTAssertEqual(manager.getStats().textureMemoryUsed, 500)
    }

    func testAnAllocationThatDiedIsNotMistakenForTheOneAtItsAddress() throws {
        // Entity 1 stays registered with a buffer that is then released, as when its
        // meshes are replaced behind the ledger's back. Whatever is allocated at that
        // address next is another buffer.
        var first: NSObject? = NSObject()
        let address = try ObjectIdentifier(XCTUnwrap(first))
        try manager.registerMesh(entityId: 1, meshAllocations: [allocation(XCTUnwrap(first), 1000)], textureAllocations: [])
        first = nil

        var kept: [NSObject] = []
        var second: NSObject?
        for _ in 0 ..< 10000 {
            let candidate = NSObject()
            if ObjectIdentifier(candidate) == address {
                second = candidate
                break
            }
            kept.append(candidate)
        }
        guard let reused = second else {
            throw XCTSkip("the allocator did not hand the address out again in 10,000 tries")
        }
        _ = kept

        manager.registerMesh(entityId: 2, meshAllocations: [allocation(reused, 300)], textureAllocations: [])
        XCTAssertEqual(manager.getStats().meshMemoryUsed, 1300)

        manager.unregisterMesh(entityId: 1)
        XCTAssertEqual(manager.getStats().meshMemoryUsed, 300, "entity 1 lets go of its own record, not of entity 2's buffer")
        manager.unregisterMesh(entityId: 2)
        XCTAssertEqual(manager.getStats().meshMemoryUsed, 0)
    }

    func testClearForgetsTheAllocations() {
        let buffer = NSObject()
        manager.registerMesh(entityId: 1, meshAllocations: [allocation(buffer, 1000)], textureAllocations: [])

        manager.clear()
        manager.registerMesh(entityId: 2, meshAllocations: [allocation(buffer, 1000)], textureAllocations: [])

        XCTAssertEqual(manager.getStats().meshMemoryUsed, 1000)
        XCTAssertEqual(manager.getMemorySize(for: 2), 1000)
    }
}
