//
//  ProgressiveAssetLoaderTests.swift
//  UntoldEngineTests
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import MetalKit
import ModelIO
@testable import UntoldEngine
import XCTest

// MARK: - ProgressiveLoadJob State Machine Tests

/// Tests for ProgressiveLoadJob's pure state machine logic.
/// No Metal device or ECS required — these verify that job fields
/// behave correctly in isolation.
@MainActor
final class ProgressiveLoadJobTests: XCTestCase {

    // MARK: Helpers

    private func makeJob(totalCount: Int, pendingItems: [PendingObjectItem] = []) -> ProgressiveLoadJob {
        ProgressiveLoadJob(
            rootEntityId: 0,
            filename: "test",
            withExtension: "usdz",
            url: URL(fileURLWithPath: "/tmp/test.usdz"),
            pending: pendingItems,
            totalCount: totalCount,
            assetRef: nil,
            completion: nil
        )
    }

    // MARK: - isFullyLoaded

    func testIsFullyLoaded_falseWhenNoWorkDone() {
        let job = makeJob(totalCount: 5)
        XCTAssertFalse(job.isFullyLoaded)
    }

    func testIsFullyLoaded_falseWhenPartiallyComplete() {
        let job = makeJob(totalCount: 5)
        job.completedCount = 3
        XCTAssertFalse(job.isFullyLoaded)
    }

    func testIsFullyLoaded_trueWhenCompletedEqualsTotal() {
        let job = makeJob(totalCount: 5)
        job.completedCount = 5
        XCTAssertTrue(job.isFullyLoaded)
    }

    func testIsFullyLoaded_trueWhenCompletedExceedsTotal() {
        // Should not happen in practice, but the predicate is >=
        let job = makeJob(totalCount: 3)
        job.completedCount = 4
        XCTAssertTrue(job.isFullyLoaded)
    }

    func testIsFullyLoaded_trueForZeroTotalCount() {
        // An asset with 0 top-level objects is immediately "done"
        let job = makeJob(totalCount: 0)
        XCTAssertTrue(job.isFullyLoaded)
    }

    // MARK: - hasPendingWork (index cursor)

    func testHasPendingWork_falseWithEmptyPending() {
        let job = makeJob(totalCount: 3, pendingItems: [])
        XCTAssertFalse(job.hasPendingWork)
    }

    func testHasPendingWork_falseWhenCursorAtEnd() {
        // Simulate all items consumed by advancing cursor manually
        let job = makeJob(totalCount: 1, pendingItems: [])
        // pending is empty so cursor == count == 0 → no pending work
        job.nextPendingIndex = 0
        XCTAssertFalse(job.hasPendingWork)
    }

    // MARK: - isCancelled

    func testIsCancelled_defaultsFalse() {
        let job = makeJob(totalCount: 4)
        XCTAssertFalse(job.isCancelled)
    }

    func testIsCancelled_canBeSetTrue() {
        let job = makeJob(totalCount: 4)
        job.isCancelled = true
        XCTAssertTrue(job.isCancelled)
    }

    // MARK: - failedCount

    func testFailedCount_defaultsZero() {
        let job = makeJob(totalCount: 4)
        XCTAssertEqual(job.failedCount, 0)
    }

    func testFailedCount_canBeIncremented() {
        let job = makeJob(totalCount: 4)
        job.failedCount += 1
        job.failedCount += 1
        XCTAssertEqual(job.failedCount, 2)
    }

    // MARK: - state

    func testState_initiallyProgressiveLoading() {
        let job = makeJob(totalCount: 10)
        if case .progressiveLoading(let completed, let total) = job.state {
            XCTAssertEqual(completed, 0)
            XCTAssertEqual(total, 10)
        } else {
            XCTFail("Expected .progressiveLoading initial state, got \(job.state)")
        }
    }

    func testState_canBeUpdatedToFullyLoaded() {
        let job = makeJob(totalCount: 2)
        job.state = .fullyLoaded
        if case .fullyLoaded = job.state { } else {
            XCTFail("Expected .fullyLoaded state")
        }
    }

    func testState_progressiveLoadingCarriesCorrectCounts() {
        let job = makeJob(totalCount: 8)
        job.state = .progressiveLoading(completed: 4, total: 8)
        if case .progressiveLoading(let completed, let total) = job.state {
            XCTAssertEqual(completed, 4)
            XCTAssertEqual(total, 8)
        } else {
            XCTFail("Expected .progressiveLoading state")
        }
    }

    // MARK: - assetRef lifecycle

    func testAssetRef_canBeNilledToReleaseMemory() {
        let job = makeJob(totalCount: 1)
        XCTAssertNil(job.assetRef)
        // Verify nilling is a no-op (no crash)
        job.assetRef = nil
        XCTAssertNil(job.assetRef)
    }
}

// MARK: - ProgressiveAssetLoader Scheduler Tests

/// Tests for ProgressiveAssetLoader's scheduling, queue management,
/// cancellation, and per-tick budget logic.
///
/// `tick()` is called with dummy `PendingObjectItem`s that wrap a plain
/// `MDLObject()` (no mesh data). `makeMeshesFromCPUBuffers` returns an
/// empty array for these objects, so `failedCount` increments and
/// `registerProgressiveChildEntity` is never reached — keeping tests
/// independent of the ECS and render pipeline.
@MainActor
final class ProgressiveAssetLoaderSchedulerTests: XCTestCase {

    var loader: ProgressiveAssetLoader!
    var device: MTLDevice!
    var textureLoader: TextureLoader!

    /// Entity IDs enqueued during a test — cancelled in tearDown to leave
    /// the shared singleton clean for the next test.
    private var enqueuedEntityIds: [EntityID] = []

    // MARK: Setup / Teardown

    override func setUp() async throws {
        loader = ProgressiveAssetLoader.shared

        guard let mtlDevice = MTLCreateSystemDefaultDevice() else {
            XCTFail("No Metal device available")
            return
        }
        device = mtlDevice
        renderInfo.device = mtlDevice
        textureLoader = TextureLoader(device: mtlDevice)

        // Restore defaults before each test
        loader.maxMeshesPerTick = 4
        loader.maxTickMilliseconds = 2.0
        loader.fileSizeThresholdBytes = 50 * 1024 * 1024  // 50 MB default
        loader.enabled = true
    }

    override func tearDown() async throws {
        for id in enqueuedEntityIds {
            loader.cancel(entityId: id)
        }
        enqueuedEntityIds.removeAll()
        device = nil
        textureLoader = nil
    }

    // MARK: Helpers

    /// Unique entity IDs per test run to avoid cross-test interference on the singleton.
    private var nextEntityId: EntityID = 600

    private func makeEntityId() -> EntityID {
        let id = nextEntityId
        nextEntityId += 1
        return id
    }

    /// Creates a `PendingObjectItem` with a plain `MDLObject` (no mesh data).
    /// `makeMeshesFromCPUBuffers` returns [] for these, so no ECS writes occur.
    private func makeDummyItem(index: Int, entityId: EntityID) -> PendingObjectItem {
        PendingObjectItem(
            index: index,
            object: MDLObject(),
            rootEntityId: entityId,
            url: URL(fileURLWithPath: "/tmp/test.usdz"),
            filename: "test",
            withExtension: "usdz",
            vertexDescriptor: MDLVertexDescriptor(),
            textureLoader: textureLoader,
            device: device
        )
    }

    private func makeJob(entityId: EntityID, itemCount: Int) -> ProgressiveLoadJob {
        let items = (0 ..< itemCount).map { makeDummyItem(index: $0, entityId: entityId) }
        return ProgressiveLoadJob(
            rootEntityId: entityId,
            filename: "test_\(entityId)",
            withExtension: "usdz",
            url: URL(fileURLWithPath: "/tmp/test.usdz"),
            pending: items,
            totalCount: itemCount,
            assetRef: nil,
            completion: nil
        )
    }

    private func enqueue(itemCount: Int) -> (EntityID, ProgressiveLoadJob) {
        let id = makeEntityId()
        let job = makeJob(entityId: id, itemCount: itemCount)
        loader.enqueue(job)
        enqueuedEntityIds.append(id)
        return (id, job)
    }

    // MARK: - Configuration defaults

    func testDefaultConfiguration() {
        XCTAssertEqual(loader.maxMeshesPerTick, 4)
        XCTAssertEqual(loader.maxTickMilliseconds, 2.0, accuracy: 0.001)
        XCTAssertTrue(loader.enabled)
    }

    // MARK: - Enqueue

    func testEnqueue_makesLoaderActive() {
        let (_, _) = enqueue(itemCount: 3)
        XCTAssertTrue(loader.hasActiveJobs)
    }

    func testEnqueue_loadStateIsProgressiveLoading() {
        let (id, _) = enqueue(itemCount: 5)
        guard let state = loader.loadState(for: id) else {
            XCTFail("Expected a load state for entity \(id)")
            return
        }
        if case .progressiveLoading(let completed, let total) = state {
            XCTAssertEqual(completed, 0)
            XCTAssertEqual(total, 5)
        } else {
            XCTFail("Expected .progressiveLoading, got \(state)")
        }
    }

    func testEnqueue_diagnosticsReflectsQueuedItems() {
        let (_, _) = enqueue(itemCount: 6)
        let (queued, completed) = (loader.diagnostics().totalQueued, loader.diagnostics().totalCompleted)
        XCTAssertGreaterThanOrEqual(queued, 6)
        XCTAssertEqual(completed, 0)
    }

    // MARK: - Cancel

    func testCancel_removesJobFromLoader() {
        let (id, _) = enqueue(itemCount: 4)
        XCTAssertTrue(loader.hasActiveJobs)
        loader.cancel(entityId: id)
        enqueuedEntityIds.removeAll { $0 == id }
        XCTAssertNil(loader.loadState(for: id))
    }

    func testCancel_setsIsCancelledOnJob() {
        let (id, job) = enqueue(itemCount: 4)
        loader.cancel(entityId: id)
        enqueuedEntityIds.removeAll { $0 == id }
        XCTAssertTrue(job.isCancelled)
    }

    func testCancel_unknownEntityId_doesNotCrash() {
        // Should silently no-op for an ID that was never enqueued
        loader.cancel(entityId: 99_999)
    }

    func testCancel_loadStateNilAfterCancel() {
        let (id, _) = enqueue(itemCount: 3)
        loader.cancel(entityId: id)
        enqueuedEntityIds.removeAll { $0 == id }
        XCTAssertNil(loader.loadState(for: id))
    }

    // MARK: - Tick: count budget

    func testTick_advancesCompletedCount() {
        loader.maxMeshesPerTick = 2
        let (_, job) = enqueue(itemCount: 6)

        loader.tick()

        XCTAssertEqual(job.completedCount, 2)
    }

    func testTick_respectsMaxMeshesPerTick() {
        loader.maxMeshesPerTick = 3
        let (_, job) = enqueue(itemCount: 10)

        loader.tick()

        XCTAssertLessThanOrEqual(job.completedCount, 3)
    }

    func testTick_doesNotExceedCountBudgetAcrossMultipleJobs() {
        loader.maxMeshesPerTick = 4
        let (_, jobA) = enqueue(itemCount: 10)
        let (_, jobB) = enqueue(itemCount: 10)

        loader.tick()

        let totalProcessed = jobA.completedCount + jobB.completedCount
        XCTAssertLessThanOrEqual(totalProcessed, loader.maxMeshesPerTick)
    }

    // MARK: - Tick: time budget

    func testTick_timeBudget_stopsProcessingWhenExceeded() {
        // Set a negative budget so the time check fires before any item is processed.
        loader.maxTickMilliseconds = -1.0
        loader.maxMeshesPerTick = 100
        let (_, job) = enqueue(itemCount: 10)

        loader.tick()

        XCTAssertEqual(job.completedCount, 0)
        // Clean up — job never completed so still in the loader
    }

    // MARK: - Tick: failed mesh tracking

    func testTick_failedCountIncrementsWhenMeshCreationReturnsEmpty() {
        // MDLObject() has no mesh data → makeMeshesFromCPUBuffers returns []
        // → failedCount increments, completedCount still advances
        loader.maxMeshesPerTick = 4
        let (_, job) = enqueue(itemCount: 4)

        loader.tick()

        XCTAssertEqual(job.completedCount, 4)
        XCTAssertEqual(job.failedCount, 4)
    }

    func testTick_completedCountAndFailedCountAreIndependent() {
        loader.maxMeshesPerTick = 2
        let (_, job) = enqueue(itemCount: 6)

        loader.tick()

        // completedCount tracks items dequeued; failedCount tracks empty results
        XCTAssertEqual(job.completedCount, job.failedCount)
    }

    // MARK: - Tick: job lifecycle

    func testTick_removesJobWhenFullyLoaded() {
        loader.maxMeshesPerTick = 10
        let (id, _) = enqueue(itemCount: 3)

        loader.tick()

        // Job should have self-removed — loadState returns nil
        XCTAssertNil(loader.loadState(for: id))
        enqueuedEntityIds.removeAll { $0 == id }
    }

    func testTick_jobStateIsFullyLoadedAfterCompletion() {
        loader.maxMeshesPerTick = 10
        let (id, job) = enqueue(itemCount: 2)

        loader.tick()

        if case .fullyLoaded = job.state { } else {
            XCTFail("Expected .fullyLoaded state after all items processed")
        }
        enqueuedEntityIds.removeAll { $0 == id }
    }

    func testTick_assetRefNilledAfterCompletion() {
        loader.maxMeshesPerTick = 10
        let (id, job) = enqueue(itemCount: 1)

        loader.tick()

        XCTAssertNil(job.assetRef)
        enqueuedEntityIds.removeAll { $0 == id }
    }

    func testTick_multipleTicksRequiredForLargeAsset() {
        loader.maxMeshesPerTick = 2
        let (_, job) = enqueue(itemCount: 6)

        loader.tick() // processes 2
        XCTAssertEqual(job.completedCount, 2)
        XCTAssertFalse(job.isFullyLoaded)

        loader.tick() // processes 2 more
        XCTAssertEqual(job.completedCount, 4)
        XCTAssertFalse(job.isFullyLoaded)

        loader.tick() // processes final 2
        XCTAssertEqual(job.completedCount, 6)
        XCTAssertTrue(job.isFullyLoaded)
    }

    // MARK: - Tick: cancellation during load

    func testTick_cancelledJobIsSkippedDuringTick() {
        loader.maxMeshesPerTick = 10
        let (id, job) = enqueue(itemCount: 5)

        // Cancel before tick — isCancelled is set, job removed from loader
        loader.cancel(entityId: id)
        enqueuedEntityIds.removeAll { $0 == id }

        loader.tick()

        // Cancelled job should not have been processed
        XCTAssertEqual(job.completedCount, 0)
    }

    // MARK: - Tick: round-robin fairness

    func testTick_roundRobin_bothJobsReceiveWorkOverMultipleTicks() {
        // With maxMeshesPerTick=1 and 2 jobs, round-robin means each job
        // gets one item per 2 ticks. After 4 ticks, both should have
        // completedCount >= 1, proving neither was starved.
        loader.maxMeshesPerTick = 1
        let (_, jobA) = enqueue(itemCount: 4)
        let (_, jobB) = enqueue(itemCount: 4)

        for _ in 0 ..< 4 {
            loader.tick()
        }

        XCTAssertGreaterThanOrEqual(jobA.completedCount, 1, "Job A was starved — round-robin not working")
        XCTAssertGreaterThanOrEqual(jobB.completedCount, 1, "Job B was starved — round-robin not working")
        XCTAssertEqual(jobA.completedCount + jobB.completedCount, 4)
    }

    func testTick_roundRobin_totalProcessedMatchesBudget() {
        loader.maxMeshesPerTick = 2
        let (_, jobA) = enqueue(itemCount: 6)
        let (_, jobB) = enqueue(itemCount: 6)

        loader.tick()

        let total = jobA.completedCount + jobB.completedCount
        XCTAssertEqual(total, loader.maxMeshesPerTick)
    }

    // MARK: - Diagnostics

    func testDiagnostics_activeJobCount() {
        let (_, _) = enqueue(itemCount: 3)
        let (_, _) = enqueue(itemCount: 3)
        let diag = loader.diagnostics()
        XCTAssertGreaterThanOrEqual(diag.activeJobs, 2)
    }

    func testDiagnostics_queuedDecrementsAfterTick() {
        loader.maxMeshesPerTick = 2
        let (_, _) = enqueue(itemCount: 6)
        let beforeQueued = loader.diagnostics().totalQueued

        loader.tick()

        let afterQueued = loader.diagnostics().totalQueued
        XCTAssertEqual(afterQueued, beforeQueued - 2)
    }

    func testDiagnostics_completedIncrementsAfterTick() {
        loader.maxMeshesPerTick = 3
        let (_, _) = enqueue(itemCount: 6)

        loader.tick()

        XCTAssertEqual(loader.diagnostics().totalCompleted, 3)
    }
}
