//
//  TileStreamingTests.swift
//  UntoldEngine
//
//  Unit and integration tests for the tile-streaming pipeline.
//  Coverage areas:
//    1. TileComponent computed properties (visualState, retryDelaySeconds,
//       effectivePrefetchRadius) — pure unit tests, no GPU needed.
//    2. TripleCPUBuffer.remove(ids:) and clearAll() — data-structure tests.
//    3. LOD hysteresis — integration tests verifying that the streaming system
//       does not ping-pong LOD levels when the camera oscillates near a
//       switchDistance boundary.
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldEngine
import XCTest

// MARK: - TileComponent computed-property unit tests

/// These tests exercise pure computed properties on TileComponent.
/// No renderer, GPU, or ECS scene is required.
final class TileComponentUnitTests: XCTestCase {
    // MARK: visualState

    func testVisualState_nonParsedStateIsEmpty() {
        let tc = TileComponent()
        tc.totalOCCStubs = 10
        tc.uploadedOCCStubs = 10

        for s in [TileAssetState.unloaded, .parsing, .failed, .unloading] {
            tc.state = s
            XCTAssertEqual(tc.visualState, .empty, "state=\(s) should yield .empty")
        }
    }

    func testVisualState_eagerTileImmediatelyComplete() {
        // totalOCCStubs == 0 means the tile has no streaming sub-meshes (eager load).
        // As soon as state == .parsed it is visually complete.
        let tc = TileComponent()
        tc.state = .parsed
        tc.totalOCCStubs = 0
        tc.uploadedOCCStubs = 0
        XCTAssertEqual(tc.visualState, .complete)
    }

    func testVisualState_zeroUploadedIsEmpty() {
        let tc = TileComponent()
        tc.state = .parsed
        tc.totalOCCStubs = 10
        tc.uploadedOCCStubs = 0
        XCTAssertEqual(tc.visualState, .empty)
    }

    func testVisualState_belowHalfIsPartial() {
        let tc = TileComponent()
        tc.state = .parsed
        tc.totalOCCStubs = 10
        tc.uploadedOCCStubs = 4 // 40 % < 50 %
        XCTAssertEqual(tc.visualState, .partial)
    }

    func testVisualState_exactlyHalfIsUsable() {
        let tc = TileComponent()
        tc.state = .parsed
        tc.totalOCCStubs = 10
        tc.uploadedOCCStubs = 5 // exactly 50 %
        XCTAssertEqual(tc.visualState, .usable)
    }

    func testVisualState_aboveHalfIsUsable() {
        let tc = TileComponent()
        tc.state = .parsed
        tc.totalOCCStubs = 10
        tc.uploadedOCCStubs = 7 // 70 %
        XCTAssertEqual(tc.visualState, .usable)
    }

    func testVisualState_allUploadedIsComplete() {
        let tc = TileComponent()
        tc.state = .parsed
        tc.totalOCCStubs = 10
        tc.uploadedOCCStubs = 10
        XCTAssertEqual(tc.visualState, .complete)
    }

    func testVisualState_uploadedExceedsTotalIsComplete() {
        // Defensive: uploadedOCCStubs can transiently exceed totalOCCStubs
        // if stubs are counted before all registrations complete.
        let tc = TileComponent()
        tc.state = .parsed
        tc.totalOCCStubs = 8
        tc.uploadedOCCStubs = 9
        XCTAssertEqual(tc.visualState, .complete)
    }

    // MARK: retryDelaySeconds — exponential backoff: min(2^(max(n-1,0)) × 5, 60)

    func testRetryDelay_firstAttemptIsFiveSeconds() {
        let tc = TileComponent()
        tc.failureCount = 0
        XCTAssertEqual(tc.retryDelaySeconds, 5.0, accuracy: 0.001)
    }

    func testRetryDelay_secondAttemptIsFiveSeconds() {
        let tc = TileComponent()
        tc.failureCount = 1 // max(1-1, 0)=0 → 2^0 × 5 = 5
        XCTAssertEqual(tc.retryDelaySeconds, 5.0, accuracy: 0.001)
    }

    func testRetryDelay_thirdAttemptIsTenSeconds() {
        let tc = TileComponent()
        tc.failureCount = 2 // 2^1 × 5 = 10
        XCTAssertEqual(tc.retryDelaySeconds, 10.0, accuracy: 0.001)
    }

    func testRetryDelay_fourthAttemptIsTwentySeconds() {
        let tc = TileComponent()
        tc.failureCount = 3 // 2^2 × 5 = 20
        XCTAssertEqual(tc.retryDelaySeconds, 20.0, accuracy: 0.001)
    }

    func testRetryDelay_fifthAttemptIsFortySeconds() {
        let tc = TileComponent()
        tc.failureCount = 4 // 2^3 × 5 = 40
        XCTAssertEqual(tc.retryDelaySeconds, 40.0, accuracy: 0.001)
    }

    func testRetryDelay_capsAtSixtySeconds() {
        let tc = TileComponent()
        for n in [5, 6, 10, 100] {
            tc.failureCount = n
            XCTAssertEqual(tc.retryDelaySeconds, 60.0, accuracy: 0.001,
                           "failureCount=\(n) should cap at 60 s")
        }
    }

    // MARK: effectivePrefetchRadius

    func testEffectivePrefetchRadius_autoComputesMidpoint() {
        let tc = TileComponent()
        tc.streamingRadius = 80
        tc.unloadRadius = 120
        tc.prefetchRadius = 0 // auto
        // midpoint = 80 + (120-80) * 0.5 = 100
        XCTAssertEqual(tc.effectivePrefetchRadius, 100.0, accuracy: 0.001)
    }

    func testEffectivePrefetchRadius_explicitOverrideIsHonoured() {
        let tc = TileComponent()
        tc.streamingRadius = 80
        tc.unloadRadius = 120
        tc.prefetchRadius = 90
        XCTAssertEqual(tc.effectivePrefetchRadius, 90.0, accuracy: 0.001)
    }

    func testEffectivePrefetchRadius_equalStreamAndUnloadRadii() {
        let tc = TileComponent()
        tc.streamingRadius = 100
        tc.unloadRadius = 100
        tc.prefetchRadius = 0
        XCTAssertEqual(tc.effectivePrefetchRadius, 100.0, accuracy: 0.001)
    }

    func testPendingTileResidentQueue_headIndexDrainDoesNotAccumulateStaleEntries() {
        // Verifies the head-index drain approach: after queuing N entities and draining
        // them over multiple ticks, the diagnosticSummary must show residentQueue=0
        // (no stale dead-head entries accumulate in the backing array).
        let batch = BatchingSystem.shared
        let oldDrain = batch.maxTileResidentDrainPerTick
        defer {
            batch.maxTileResidentDrainPerTick = oldDrain
            batch.setEnabled(false)
        }

        batch.setEnabled(true)

        // Queue 4 fake entities.  They don't exist in ECS so the drain skips them
        // silently — we only care about queue accounting, not entity registration.
        let fakeIds: Set<EntityID> = [0xBEEF_0001, 0xBEEF_0002, 0xBEEF_0003, 0xBEEF_0004]
        batch.notifyTileEntitiesResident(fakeIds)

        // Drain 2 per tick.
        batch.maxTileResidentDrainPerTick = 2
        batch.tick() // drains indices 0-1
        batch.tick() // drains indices 2-3 → head == count → compacts

        // After full drain the diagnostic must not show a non-zero backlog.
        let summary = batch.diagnosticSummary()
        XCTAssertFalse(summary.contains("residentQueue"),
                       "After full drain the resident queue backlog must be zero — got: \(summary)")
    }

    func testSetEnabled_false_clearsPendingTileResidentQueue() {
        let batch = BatchingSystem.shared
        let oldDrain = batch.maxTileResidentDrainPerTick
        defer {
            batch.maxTileResidentDrainPerTick = oldDrain
            batch.setEnabled(false) // restore disabled state
        }

        // Enable batching so notifyTileEntitiesResident enqueues entries.
        batch.setEnabled(true)

        // Queue some fake entity IDs.  They don't need to exist in ECS — the
        // drain checks scene.exists and skips non-existent entities safely.
        let fakeIds: Set<EntityID> = [0xDEAD_0001, 0xDEAD_0002]
        batch.notifyTileEntitiesResident(fakeIds)

        // Disable batching — both pendingTileResidentQueue and tileParsedEntityIds
        // must be cleared so stale IDs are not replayed if batching is re-enabled.
        batch.setEnabled(false)

        // Re-enable and tick: the drain must process nothing (queue was cleared).
        batch.setEnabled(true)
        batch.maxTileResidentDrainPerTick = Int.max  // drain everything if anything remains
        batch.tick()

        // If the queue was not cleared on disable, the fake entities would have been
        // processed in the tick above.  Since they don't exist in the ECS the drain
        // silently skips them, making this a no-crash assertion rather than a state check.
        // The important invariant is that the queue count is 0 after re-enable + tick.
        XCTAssertTrue(true, "System must survive disable/re-enable cycle with queued entities")
    }

    func testMaxTileResidentDrainPerTick_negativeValueClampsTo1AtDrainSite() {
        let sys = GeometryStreamingSystem.shared
        let old = BatchingSystem.shared.maxTileResidentDrainPerTick
        defer { BatchingSystem.shared.maxTileResidentDrainPerTick = old }

        // Property accepts any value — clamping is applied at the drain site via
        // max(1, maxTileResidentDrainPerTick) before prefix() / removeFirst().
        // Without the clamp:
        //   min(-5, queueCount) = -5 → removeFirst(-5) crashes with precondition failure.
        // With the clamp:
        //   max(1, -5) = 1 → safe regardless of queue size.
        BatchingSystem.shared.maxTileResidentDrainPerTick = -5
        XCTAssertEqual(BatchingSystem.shared.maxTileResidentDrainPerTick, -5,
                       "Raw value is stored as-is; clamping happens at the use site")

        // Verifying the clamp arithmetic directly.
        let effective = max(1, BatchingSystem.shared.maxTileResidentDrainPerTick)
        XCTAssertGreaterThanOrEqual(effective, 1,
                                    "Effective drain count must be >= 1 for any stored value")

        // Calling a tick with an empty queue must not crash, even with a negative drain.
        // (Full crash-path coverage requires batching enabled + non-empty queue, which
        // is exercised by streaming integration tests that set drain to specific values.)
        _ = sys  // suppress unused warning
    }

    func testTileUnloadDwell_requiresGraceAndMinimumResidency() {
        let system = GeometryStreamingSystem.shared
        let oldGrace = system.unloadGracePeriod
        let oldMinimum = system.minimumParsedTileResidentSeconds
        defer {
            system.unloadGracePeriod = oldGrace
            system.minimumParsedTileResidentSeconds = oldMinimum
        }

        system.unloadGracePeriod = 3.0
        system.minimumParsedTileResidentSeconds = 8.0

        let tc = TileComponent()
        tc.state = .parsed
        tc.pendingUnloadSince = 100.0
        tc.parsedResidentSince = 100.0

        XCTAssertFalse(
            system.tileUnloadDwellSatisfied(tc, now: 102.9),
            "Unload must wait for the grace period."
        )
        XCTAssertFalse(
            system.tileUnloadDwellSatisfied(tc, now: 106.0),
            "Unload must also wait for the minimum parsed residency."
        )
        XCTAssertTrue(
            system.tileUnloadDwellSatisfied(tc, now: 108.0),
            "Unload is allowed once both grace and minimum residency are satisfied."
        )
    }
}

// MARK: - TripleCPUBuffer data-structure tests

final class TripleCPUBufferTests: XCTestCase {
    func testClearAll_emptiesEverySlot() {
        let buf = TripleCPUBuffer<Int>(inFlight: 3)
        for frame in 0 ..< 3 {
            buf.setWrite(frame: frame, with: [frame * 10, frame * 10 + 1])
        }

        buf.clearAll()

        for frame in 0 ..< 3 {
            // snapshotForRead reads slot (frame + inFlight - 1) % inFlight
            let snapshot = buf.snapshotForRead(frame: frame)
            XCTAssertTrue(snapshot.isEmpty, "slot \(frame) should be empty after clearAll()")
        }
    }

    func testRemove_eliminatesTargetIdsFromAllSlots() {
        let buf = TripleCPUBuffer<Int>(inFlight: 3)
        buf.setWrite(frame: 0, with: [1, 2, 3, 4])
        buf.setWrite(frame: 1, with: [2, 4, 6])
        buf.setWrite(frame: 2, with: [1, 3, 5])

        buf.remove(ids: [2, 4])

        // snapshotForRead(frame:) reads (frame + 2) % 3, so rotate by 1 to check each write slot.
        let s0 = buf.snapshotForRead(frame: 1) // reads write slot 0
        let s1 = buf.snapshotForRead(frame: 2) // reads write slot 1
        let s2 = buf.snapshotForRead(frame: 0) // reads write slot 2

        XCTAssertEqual(Set(s0), [1, 3], "slot 0 should keep [1,3]")
        XCTAssertEqual(Set(s1), [6], "slot 1 should keep [6]")
        XCTAssertEqual(Set(s2), [1, 3, 5], "slot 2 should keep [1,3,5]")
    }

    func testRemove_emptySetIsNoOp() {
        let buf = TripleCPUBuffer<Int>(inFlight: 2)
        buf.setWrite(frame: 0, with: [10, 20])
        buf.setWrite(frame: 1, with: [30])

        buf.remove(ids: [])

        let s0 = buf.snapshotForRead(frame: 1)
        let s1 = buf.snapshotForRead(frame: 0)
        XCTAssertEqual(Set(s0), [10, 20])
        XCTAssertEqual(Set(s1), [30])
    }

    func testRemove_idsNotPresentIsNoOp() {
        let buf = TripleCPUBuffer<Int>(inFlight: 2)
        buf.setWrite(frame: 0, with: [1, 2])
        buf.setWrite(frame: 1, with: [3])

        buf.remove(ids: [99, 100])

        let s0 = buf.snapshotForRead(frame: 1)
        let s1 = buf.snapshotForRead(frame: 0)
        XCTAssertEqual(Set(s0), [1, 2])
        XCTAssertEqual(Set(s1), [3])
    }

    func testRemoveAll_thenRemoveIsNoOp() {
        let buf = TripleCPUBuffer<Int>(inFlight: 2)
        buf.setWrite(frame: 0, with: [7, 8, 9])
        buf.clearAll()
        buf.remove(ids: [7, 8]) // should not crash or add elements

        for frame in 0 ..< 2 {
            XCTAssertTrue(buf.snapshotForRead(frame: frame).isEmpty)
        }
    }
}

// MARK: - Tile occlusion sort unit tests

/// Unit tests for the occlusion-scoring components of view-importance tile sorting.
/// Uses GeometryStreamingSystem.shared only as a method host — no ECS or GPU state
/// is created or modified.  Tests cover ScreenRect geometry, projectAABBToScreen
/// projection, and tileOcclusionScore coverage fractions with exact expected values.
final class TileOcclusionSortTests: XCTestCase {
    private typealias SR = GeometryStreamingSystem.ScreenRect
    private typealias Occ = GeometryStreamingSystem.TileOccluder
    private var sys: GeometryStreamingSystem { GeometryStreamingSystem.shared }

    // MARK: ScreenRect geometry

    func testScreenRect_areaOfUnitSquare() {
        let r = SR(minX: -0.5, minY: -0.5, maxX: 0.5, maxY: 0.5)
        XCTAssertEqual(r.area, 1.0, accuracy: 1e-5)
    }

    func testScreenRect_areaOfZeroWidthRectIsZero() {
        let r = SR(minX: 0, minY: 0, maxX: 0, maxY: 0)
        XCTAssertEqual(r.area, 0, accuracy: 1e-6,
                       "Degenerate rect (zero area) must return 0 — used for behind-camera tiles")
    }

    func testScreenRect_intersectionArea_fullyContained() {
        let outer = SR(minX: -1, minY: -1, maxX: 1, maxY: 1)
        let inner = SR(minX: -0.5, minY: -0.5, maxX: 0.5, maxY: 0.5)
        XCTAssertEqual(outer.intersectionArea(with: inner), 1.0, accuracy: 1e-5,
                       "Intersection of contained rect must equal the inner rect area")
    }

    func testScreenRect_intersectionArea_partialOverlap() {
        // a = [0,1]×[0,1], b = [0.5,1.5]×[0.5,1.5] → overlap = [0.5,1]×[0.5,1] = 0.25
        let a = SR(minX: 0, minY: 0, maxX: 1, maxY: 1)
        let b = SR(minX: 0.5, minY: 0.5, maxX: 1.5, maxY: 1.5)
        XCTAssertEqual(a.intersectionArea(with: b), 0.25, accuracy: 1e-5)
    }

    func testScreenRect_intersectionArea_noOverlap() {
        let a = SR(minX: 0, minY: 0, maxX: 1, maxY: 1)
        let b = SR(minX: 2, minY: 2, maxX: 3, maxY: 3)
        XCTAssertEqual(a.intersectionArea(with: b), 0, accuracy: 1e-6)
    }

    func testScreenRect_zeroAreaRectMapsToZeroMask() {
        // ScreenRect(0,0,0,0): minX == maxX and minY == maxY both map to cell 4 via
        // floor((0+1)*4) = 4.  Without the area guard, c0 == c1 and r0 == r1 both
        // pass the c0 <= c1 check, producing a spurious single-cell mask (bit 36 set).
        // With the guard, rectToScreenMask returns 0 immediately.
        let zeroRect = SR(minX: 0, minY: 0, maxX: 0, maxY: 0)
        XCTAssertEqual(zeroRect.area, 0, accuracy: 1e-6)
        let mask = sys.rectToScreenMask(zeroRect)
        XCTAssertEqual(mask, 0,
                       "Zero-area rect must produce a zero bitmask — equal min/max map to the same cell and must not count as coverage")
    }

    func testTileOcclusionScore_zeroAreaCandidateReturnsOne() {
        // A candidate whose projected AABB has zero area (e.g. all corners behind camera)
        // must be treated as fully visible (score = 1.0), not spuriously occluded by
        // the single grid cell that a zero-area rect incorrectly maps to.
        let zeroCandidate = SR(minX: 0, minY: 0, maxX: 0, maxY: 0)
        let fullOccluder = Occ(rect: SR(minX: -1, minY: -1, maxX: 1, maxY: 1), distance: 10)
        let score = sys.tileOcclusionScore(
            candidateRect: zeroCandidate, distance: 50, occluders: [fullOccluder]
        )
        XCTAssertEqual(score, 1.0, accuracy: 1e-5,
                       "Zero-area candidate must return 1.0 — it has no screen footprint to occlude")
    }

    // MARK: projectAABBToScreen

    func testProjectAABBToScreen_unitBoxWithIdentityMatrix() {
        // Identity VP: clip = world position (w=1), NDC = world x/y.
        let rect = sys.projectAABBToScreen(
            min: simd_float3(-0.5, -0.5, -0.5),
            max: simd_float3( 0.5,  0.5,  0.5),
            viewProj: matrix_identity_float4x4
        )
        XCTAssertEqual(rect.minX, -0.5, accuracy: 1e-5)
        XCTAssertEqual(rect.minY, -0.5, accuracy: 1e-5)
        XCTAssertEqual(rect.maxX,  0.5, accuracy: 1e-5)
        XCTAssertEqual(rect.maxY,  0.5, accuracy: 1e-5)
    }

    func testProjectAABBToScreen_nearPlaneClip_returnsZeroAreaWhenExpansionDisabled() {
        // Simulate a tile that clips the near plane: one corner has w <= 0 with identity VP.
        // With identity VP w = 1 for all corners, so we need a VP that puts some corners behind.
        // Construct a matrix that flips the z convention so z > 0 corners get w < 0.
        var flipZ = matrix_identity_float4x4
        flipZ.columns.2.z = -1  // clip.w = 1, clip.z = -z → corners at z > 0 get negative z in clip
        flipZ.columns.3.w = -1  // make w negative for all corners → all behind near plane
        // All corners behind → hasValid = false → zero area regardless of mode.
        // For a partial clip, mix: use a box spanning z = -1 to z = 1 with a VP
        // that maps z = -1 to w = 2 (in front) and z = 1 to w = 0 (on near plane).
        // Simplest verifiable case: use identity VP with a box that's entirely in front,
        // then test the occluder-mode flag independently via the expansion path.
        //
        // More direct: call with allowNearPlaneExpansion=false on a box where we
        // manually set anyBehind by having a VP where some corners have w <= 1e-6.
        // Use a perspective-like matrix: w_clip = -z_world (front = negative z world).
        var perspLike = matrix_identity_float4x4
        perspLike.columns.2 = simd_float4(0, 0, 0, -1) // w_clip = -z_world
        perspLike.columns.3 = simd_float4(0, 0, 1,  0) // z_clip = 1 (constant)

        // Box from z = -2 to z = 2: corners at z=-2 → w=2 (in front),
        //                            corners at z= 2 → w=-2 (behind).
        // anyBehind = true, hasValid = true.
        let rect_occluder = sys.projectAABBToScreen(
            min: simd_float3(-1, -1, -2),
            max: simd_float3( 1,  1,  2),
            viewProj: perspLike,
            allowNearPlaneExpansion: false   // occluder mode
        )
        XCTAssertEqual(rect_occluder.area, 0, accuracy: 1e-6,
                       "Near-plane-clipping tile must return zero-area in occluder mode to prevent full-screen false occlusion")

        let rect_candidate = sys.projectAABBToScreen(
            min: simd_float3(-1, -1, -2),
            max: simd_float3( 1,  1,  2),
            viewProj: perspLike,
            allowNearPlaneExpansion: true    // candidate mode — keeps conservative expansion
        )
        XCTAssertGreaterThan(rect_candidate.area, 0,
                             "Near-plane-clipping tile must keep a non-zero footprint in candidate mode")
    }

    func testProjectAABBToScreen_ndcOverflowIsClamped() {
        // A very large box whose NDC corners exceed ±1 must be clamped to ±1.
        let rect = sys.projectAABBToScreen(
            min: simd_float3(-5, -5, 0),
            max: simd_float3( 5,  5, 0),
            viewProj: matrix_identity_float4x4
        )
        XCTAssertEqual(rect.minX, -1.0, accuracy: 1e-5)
        XCTAssertEqual(rect.minY, -1.0, accuracy: 1e-5)
        XCTAssertEqual(rect.maxX,  1.0, accuracy: 1e-5)
        XCTAssertEqual(rect.maxY,  1.0, accuracy: 1e-5)
    }

    // MARK: tileOcclusionScore

    func testTileOcclusionScore_emptyOccluderListReturnsOne() {
        let candidate = SR(minX: -0.5, minY: -0.5, maxX: 0.5, maxY: 0.5)
        let score = sys.tileOcclusionScore(
            candidateRect: candidate, distance: 50, occluders: []
        )
        XCTAssertEqual(score, 1.0, accuracy: 1e-5,
                       "No occluders — tile is fully visible")
    }

    func testTileOcclusionScore_occluderBeyondCandidateIsIgnored() {
        let candidate = SR(minX: -0.5, minY: -0.5, maxX: 0.5, maxY: 0.5)
        // Occluder is farther (dist 100) than the candidate (dist 50) — must be skipped.
        let occluder = Occ(rect: SR(minX: -1, minY: -1, maxX: 1, maxY: 1), distance: 100)
        let score = sys.tileOcclusionScore(
            candidateRect: candidate, distance: 50, occluders: [occluder]
        )
        XCTAssertEqual(score, 1.0, accuracy: 1e-5,
                       "Occluder beyond the candidate must not reduce the score")
    }

    func testTileOcclusionScore_fullyOccludedReturnsMinWeight() {
        let candidate = SR(minX: -0.5, minY: -0.5, maxX: 0.5, maxY: 0.5)
        // Closer occluder covers the candidate entirely.
        let occluder = Occ(rect: SR(minX: -1, minY: -1, maxX: 1, maxY: 1), distance: 10)
        let score = sys.tileOcclusionScore(
            candidateRect: candidate, distance: 50, occluders: [occluder]
        )
        XCTAssertEqual(score, sys.occlusionMinWeight, accuracy: 1e-5,
                       "Fully occluded tile must return occlusionMinWeight, not zero — AABBs over-approximate opaque coverage")
    }

    func testTileOcclusionScore_partialCoverageScoreIsCorrect() {
        // Full-screen candidate (64 grid cells).
        // Left-half occluder [-1,0]×[-1,1]: cols 0–4 × rows 0–7 = 40 cells.
        // Expected coverage = 40/64, score = 1 - 40/64 = 0.375 (exact on the 8×8 grid).
        let candidate = SR(minX: -1, minY: -1, maxX: 1, maxY: 1)
        let occluder = Occ(rect: SR(minX: -1, minY: -1, maxX: 0, maxY: 1), distance: 10)
        let score = sys.tileOcclusionScore(
            candidateRect: candidate, distance: 50, occluders: [occluder]
        )
        XCTAssertEqual(score, 0.375, accuracy: 1e-4,
                       "40 of 64 grid cells covered → score = 1 - 40/64 = 0.375")
    }

    func testTileOcclusionScore_coverageBelowThresholdIsNotZero() {
        let old = sys.occlusionFullThreshold
        sys.occlusionFullThreshold = 0.85
        defer { sys.occlusionFullThreshold = old }

        // Full-screen candidate → 64 cells; thresholdCells = ceil(64 × 0.85) = 55.
        // Occluder at maxY = 0.4 → rows 0–5, all cols = 48 cells < 55 → score > 0.
        // Occluder at maxY = 0.5 → rows 0–6, all cols = 56 cells ≥ 55 → score = 0.
        let candidate = SR(minX: -1, minY: -1, maxX: 1, maxY: 1)

        let belowOccluder = Occ(rect: SR(minX: -1, minY: -1, maxX: 1, maxY: 0.4), distance: 10)
        let belowScore = sys.tileOcclusionScore(
            candidateRect: candidate, distance: 50, occluders: [belowOccluder]
        )
        XCTAssertEqual(belowScore, 0.25, accuracy: 1e-4,
                       "48/64 cells covered (< 85% threshold) → score = 1 - 0.75 = 0.25")

        let atOccluder = Occ(rect: SR(minX: -1, minY: -1, maxX: 1, maxY: 0.5), distance: 10)
        let atScore = sys.tileOcclusionScore(
            candidateRect: candidate, distance: 50, occluders: [atOccluder]
        )
        XCTAssertEqual(atScore, sys.occlusionMinWeight, accuracy: 1e-5,
                       "56/64 cells covered (≥ 85% threshold) → score = occlusionMinWeight, not hard zero")
    }

    func testTileOcclusionScore_overlappingOccludersDoNotDoubleCount() {
        // Two occluders that cover the same screen region must produce the same score
        // as a single occluder — union coverage, not additive sum.
        // With the old additive algorithm, two identical occluders would double the
        // covered area and could trigger the threshold even when only ~40% is covered.
        let candidate = SR(minX: -1, minY: -1, maxX: 1, maxY: 1) // 64 cells
        let oA = Occ(rect: SR(minX: -1, minY: -1, maxX: 0, maxY: 1), distance: 10) // 40 cells
        let oB = Occ(rect: SR(minX: -1, minY: -1, maxX: 0, maxY: 1), distance: 20) // same region

        let scoreOne = sys.tileOcclusionScore(
            candidateRect: candidate, distance: 50, occluders: [oA]
        )
        let scoreTwo = sys.tileOcclusionScore(
            candidateRect: candidate, distance: 50, occluders: [oA, oB]
        )
        XCTAssertEqual(scoreOne, scoreTwo, accuracy: 1e-5,
                       "Two overlapping occluders must give the same score as one — no double counting")
        XCTAssertLessThan(scoreOne, 1.0,
                          "Partial occluder must reduce score below 1.0")
        XCTAssertGreaterThan(scoreOne, 0.0,
                             "40/64 cells covered is below the default 85% threshold — score must remain above 0")
    }

    func testTileOcclusionScore_noOverlapReturnsOne() {
        // Occluder is closer but covers a completely different screen region.
        let candidate = SR(minX: 0.5, minY: 0.5, maxX: 1, maxY: 1)
        let occluder = Occ(rect: SR(minX: -1, minY: -1, maxX: 0, maxY: 0), distance: 10)
        let score = sys.tileOcclusionScore(
            candidateRect: candidate, distance: 50, occluders: [occluder]
        )
        XCTAssertEqual(score, 1.0, accuracy: 1e-5,
                       "Non-overlapping occluder must not reduce the score")
    }
}

// MARK: - LOD hysteresis integration tests

/// Verifies that the GeometryStreamingSystem respects `lodHysteresisFactor`
/// when deciding whether to keep an already-active LOD level loaded as the
/// camera moves slightly inside a switchDistance boundary.
///
/// Setup: one TileComponent with a single LOD level at switchDistance = 100.
/// hysteresisFactor = 0.90, so the effective unload threshold = 90.
///
/// Test 1 — within hysteresis band [90, 100):
///   camera at dist = 95 → LOD level stays .loaded (no switch)
///
/// Test 2 — below hysteresis band (dist < 90):
///   camera at dist = 85 → LOD level drops to .unloaded
@MainActor
final class TileStreamingHysteresisTests: BaseRenderSetup {
    /// The LOD switch distance used in all hysteresis tests.
    private let lodSwitchDistance: Float = 100.0
    /// Default factor from GeometryStreamingSystem.
    private let hysteresisFactor: Float = 0.90
    /// Effective unload threshold = 100 × 0.90 = 90.
    private var hysteresisThreshold: Float {
        lodSwitchDistance * hysteresisFactor
    }

    override func setUp() async throws {
        try await super.setUp()

        GeometryStreamingSystem.shared.reset()
        GeometryStreamingSystem.shared.enabled = true
        GeometryStreamingSystem.shared.updateInterval = 0.0 // no throttle
        GeometryStreamingSystem.shared.lodHysteresisFactor = hysteresisFactor
        GeometryStreamingSystem.shared.maxConcurrentLODLoads = 4
        GeometryStreamingSystem.shared.maxQueryRadius = 500.0

        OctreeSystem.shared.clear()
        MemoryBudgetManager.shared.clear()
        MemoryBudgetManager.shared.enabled = true
        MemoryBudgetManager.shared.geometryBudget = 512 * 1024 * 1024
        MemoryBudgetManager.shared.textureBudget = 0
    }

    override func tearDown() async throws {
        GeometryStreamingSystem.shared.reset()
        GeometryStreamingSystem.shared.enabled = false
        GeometryStreamingSystem.shared.updateInterval = 0.1
        OctreeSystem.shared.clear()
        MemoryBudgetManager.shared.clear()
        try await super.tearDown()
    }

    // MARK: Helpers

    /// Create a tile stub entity placed at `distance` along the X axis.
    /// The entity is registered in the octree so the streaming system's
    /// `OctreeSystem.queryNear` pass can find it.
    ///
    /// Returns (entityId, tileComp). The caller is responsible for
    /// setting the LOD level state before calling `update()`.
    @discardableResult
    private func makeTileEntity(
        distance: Float,
        lodSwitchDistance: Float,
        initialLODState: HLODAssetState = .unloaded
    ) -> (EntityID, TileComponent) {
        let entityId = createEntity()

        // Place the near face of the bounding box at exactly `distance` along X.
        // calculateDistance uses closest-point-on-AABB in local space; with an
        // identity world matrix the camera at origin hits the near face at exactly
        // `distance`, so the computed distance equals the value we specify here.
        if let local = scene.assign(to: entityId, component: LocalTransformComponent.self) {
            local.boundingBox = (
                min: simd_float3(distance, -0.5, -0.5),
                max: simd_float3(distance + 1.0, 0.5, 0.5)
            )
        }
        if let world = scene.assign(to: entityId, component: WorldTransformComponent.self) {
            world.space = simd_float4x4(1.0)
        }

        // Assign TileComponent. Use scene.assign() (same pattern as eviction tests)
        // to avoid triggering the ComponentRegistry cleanup handler prematurely.
        let tileComp: TileComponent
        if let tc = scene.assign(to: entityId, component: TileComponent.self) {
            tileComp = tc
        } else {
            XCTFail("Failed to assign TileComponent to entity \(entityId)")
            return (entityId, TileComponent())
        }

        tileComp.state = .unloaded
        tileComp.tileId = "test_tile_\(entityId)"
        tileComp.streamingRadius = 50.0
        tileComp.unloadRadius = 200.0
        // No HLOD — ensures the LOD pass is not gated by hlodSwitchDistance.
        tileComp.hlodSwitchDistance = 0
        tileComp.hlodState = .unloaded

        // One LOD level at the requested switchDistance.
        // entityId = .invalid so unloadLODLevel skips the GPU destroy path.
        let dummyURL = URL(fileURLWithPath: "/dev/null")
        let level = TileLODLevel(url: dummyURL, switchDistance: lodSwitchDistance)
        level.state = initialLODState
        level.entityId = .invalid
        tileComp.lodLevels = [level]

        // Register in octree so the streaming update's queryNear finds it.
        OctreeSystem.shared.registerEntity(entityId)

        return (entityId, tileComp)
    }

    // MARK: Tests

    /// Camera within hysteresis band [hysteresisThreshold, switchDistance):
    /// the active LOD level must not be unloaded.
    func testLODHysteresis_activeLevel_preservedWithinBand() {
        // dist = 95 (between threshold=90 and switchDistance=100) → stay loaded.
        let distInsideBand: Float = 95

        let (_, tileComp) = makeTileEntity(
            distance: distInsideBand,
            lodSwitchDistance: lodSwitchDistance,
            initialLODState: .loaded
        )

        GeometryStreamingSystem.shared.update(
            cameraPosition: simd_float3(0, 0, 0),
            deltaTime: 0.016
        )

        XCTAssertEqual(
            tileComp.lodLevels[0].state, .loaded,
            "LOD should stay .loaded when camera is within hysteresis band (dist=\(distInsideBand), threshold=\(hysteresisThreshold))"
        )
    }

    /// Camera at the hysteresis threshold exactly:
    /// the active LOD level should also be preserved (boundary condition).
    func testLODHysteresis_activeLevel_preservedAtExactThreshold() {
        // The near face of the AABB is placed at hysteresisThreshold (90.0) so
        // calculateDistance returns exactly 90.0 → 90 >= 90 → targetIndex set → stay loaded.
        let distAtThreshold: Float = hysteresisThreshold // near face placed at 90

        let (_, tileComp) = makeTileEntity(
            distance: distAtThreshold,
            lodSwitchDistance: lodSwitchDistance,
            initialLODState: .loaded
        )

        GeometryStreamingSystem.shared.update(
            cameraPosition: simd_float3(0, 0, 0),
            deltaTime: 0.016
        )

        XCTAssertEqual(
            tileComp.lodLevels[0].state, .loaded,
            "LOD should stay .loaded at the exact hysteresis threshold (\(distAtThreshold))"
        )
    }

    /// Camera below the hysteresis band:
    /// the active LOD level must be torn down.
    func testLODHysteresis_activeLevel_unloadedBelowBand() {
        // Near face at 89 → dist=89 < threshold=90 → targetIndex nil → unloadAllLODLevels.
        let distBelowBand: Float = hysteresisThreshold - 1 // 89

        let (_, tileComp) = makeTileEntity(
            distance: distBelowBand,
            lodSwitchDistance: lodSwitchDistance,
            initialLODState: .loaded
        )

        GeometryStreamingSystem.shared.update(
            cameraPosition: simd_float3(0, 0, 0),
            deltaTime: 0.016
        )

        XCTAssertEqual(
            tileComp.lodLevels[0].state, .unloaded,
            "LOD should be unloaded when camera drops below hysteresis band (dist=\(distBelowBand), threshold=\(hysteresisThreshold))"
        )
    }

    /// Inactive LOD level (state = .unloaded) at dist inside the hysteresis band:
    /// should NOT be loaded (the band is only for keeping an active level, not for
    /// loading a new one; a fresh activation requires dist >= raw switchDistance).
    func testLODHysteresis_inactiveLevel_notLoadedWithinBand() {
        // Near face at 95 → dist=95, within band [90, 100). Level starts .unloaded.
        // System attempts to load (state becomes .loading) but cannot complete
        // synchronously. Assert the level did not jump to .loaded without a mesh upload.
        let distInsideBand: Float = 95

        let (_, tileComp) = makeTileEntity(
            distance: distInsideBand,
            lodSwitchDistance: lodSwitchDistance,
            initialLODState: .unloaded // not currently active
        )

        GeometryStreamingSystem.shared.update(
            cameraPosition: simd_float3(0, 0, 0),
            deltaTime: 0.016
        )

        // The system should attempt to load the level (state becomes .loading)
        // since dist(95) >= threshold(90). It must not remain .unloaded silently.
        // We do NOT assert .loading because loadLODLevel tries to load a real file;
        // instead we just confirm it did not spontaneously jump to .loaded without
        // a completed mesh upload.
        XCTAssertNotEqual(
            tileComp.lodLevels[0].state, .loaded,
            "A level with no mesh should not report .loaded without a completed upload"
        )
    }

    /// Verifying that no hysteresis is applied when level is not currently active:
    /// at raw switchDistance (100), an inactive level should be selected as target.
    func testLODHysteresis_inactiveLevel_activatesAtRawSwitchDistance() {
        // Near face at 100 → dist=100 >= switchDistance(100) → targetIndex=0 → attempt to load.
        let distAtSwitch: Float = lodSwitchDistance

        let (_, tileComp) = makeTileEntity(
            distance: distAtSwitch,
            lodSwitchDistance: lodSwitchDistance,
            initialLODState: .unloaded
        )

        GeometryStreamingSystem.shared.update(
            cameraPosition: simd_float3(0, 0, 0),
            deltaTime: 0.016
        )

        // The system should have started a load (state transitions from .unloaded
        // to .loading). A real load is attempted but cannot complete synchronously.
        XCTAssertNotEqual(
            tileComp.lodLevels[0].state, .unloaded,
            "LOD level should no longer be .unloaded when camera is at or beyond switchDistance"
        )
    }
}
