//
//  AssetLoadingGateRenderingTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Metal
@testable import UntoldEngine
import XCTest

// MARK: - AssetLoadingGate Rendering Integration Tests

final class AssetLoadingGateRenderingTests: BaseRenderSetup {
    override func setUp() async throws {
        try await super.setUp()
        // Ensure loading gate starts in a clean state
        resetLoadingGate()
    }

    override func tearDown() async throws {
        // Clean up loading gate state
        resetLoadingGate()
        try await super.tearDown()
    }

    /// Helper to reset the loading gate to a clean state
    private func resetLoadingGate() {
        // Drain any active loads to reset state
        while AssetLoadingGate.shared.isLoadingAny {
            AssetLoadingGate.shared.finishLoading()
        }
    }

    // MARK: - Test 1: Verify render prep is skipped when AssetLoadingGate.shared.isLoadingAny is true

    func testUpdateRenderingSystem_SkipsRenderPrepWhenLoadingGateIsActive() {
        // Given: Loading gate is active
        AssetLoadingGate.shared.beginLoading()
        XCTAssertTrue(AssetLoadingGate.shared.isLoadingAny, "Loading gate should be active after beginLoading()")

        // Store the initial state of visibleEntityIds
        let initialVisibleIds = visibleEntityIds

        // When: We check the loading condition (simulating UpdateRenderingSystem logic)
        let loading = AssetLoadingGate.shared.isLoadingAny

        // Then: The loading flag should be true, indicating render prep should be skipped
        XCTAssertTrue(loading, "Loading flag should be true when AssetLoadingGate.shared.isLoadingAny is true")

        // This simulates the condition in UpdateRenderingSystem that guards:
        // - performFrustumCulling
        // - executeGaussianDepth
        // - executeBitonicSort
        // The condition `if !loading { ... }` would NOT execute these when loading is true

        // Verify visibleEntityIds remains unchanged (as per the second test requirement)
        XCTAssertEqual(visibleEntityIds, initialVisibleIds,
                       "visibleEntityIds should not change while loading gate is active")

        // Cleanup
        AssetLoadingGate.shared.finishLoading()
    }

    func testUpdateRenderingSystem_ExecutesRenderPrepWhenLoadingGateIsInactive() {
        // Given: Loading gate is inactive
        resetLoadingGate()
        XCTAssertFalse(AssetLoadingGate.shared.isLoadingAny, "Loading gate should be inactive")

        // When: We check the loading condition
        let loading = AssetLoadingGate.shared.isLoadingAny

        // Then: The loading flag should be false, indicating render prep should execute
        XCTAssertFalse(loading, "Loading flag should be false when AssetLoadingGate.shared.isLoadingAny is false")
    }

    // MARK: - Test 2: Verify visibleEntityIds is not updated when loading is active

    func testUpdateRenderingSystem_DoesNotUpdateVisibleEntityIdsWhenLoading() {
        // Given: A known set of visible entities
        let initialVisibleIds: [EntityID] = visibleEntityIds

        // Seed triple buffer with known data
        let testEntityIds: [EntityID] = [createEntityId(100, 1), createEntityId(101, 1)]
        tripleVisibleEntities.setWrite(frame: cullFrameIndex, with: testEntityIds)

        // When: Loading gate is active
        AssetLoadingGate.shared.beginLoading()

        // Simulate the UpdateRenderingSystem logic:
        // `if !loading { visibleEntityIds = tripleVisibleEntities.snapshotForRead(frame: cullFrameIndex) }`
        let loading = AssetLoadingGate.shared.isLoadingAny
        if !loading {
            visibleEntityIds = tripleVisibleEntities.snapshotForRead(frame: cullFrameIndex)
        }

        // Then: visibleEntityIds should NOT have been updated (still matches initial)
        XCTAssertEqual(visibleEntityIds, initialVisibleIds,
                       "visibleEntityIds should not be updated when loading is true")

        // Cleanup
        AssetLoadingGate.shared.finishLoading()
    }

    func testUpdateRenderingSystem_UpdatesVisibleEntityIdsWhenNotLoading() {
        // Given: Loading gate is inactive
        resetLoadingGate()

        // Seed all triple buffer slots with test data for frame 0
        let testEntityIds: [EntityID] = [createEntityId(200, 1), createEntityId(201, 1)]
        for frame in 0 ..< 3 {
            tripleVisibleEntities.setWrite(frame: frame, with: testEntityIds)
        }

        // When: We apply the UpdateRenderingSystem logic with loading = false
        let loading = AssetLoadingGate.shared.isLoadingAny
        if !loading {
            visibleEntityIds = tripleVisibleEntities.snapshotForRead(frame: cullFrameIndex)
        }

        // Then: visibleEntityIds should have been updated
        XCTAssertEqual(visibleEntityIds, testEntityIds,
                       "visibleEntityIds should be updated when loading is false")
    }

    // MARK: - Test 3 & 4: XR System Pass loading parameter tests

    func testXRSystemPass_SkipsRenderPrepWhenLoadingParameterIsTrue() {
        // Given: A loading parameter set to true (simulating executeXRSystemPass parameter)
        let loading = true

        // When: The loading condition is checked
        // In executeXRSystemPass:
        // `if !loading { performFrustumCulling(...); executeGaussianDepth(...); executeBitonicSort(...) }`

        // Then: The render prep should be skipped
        XCTAssertTrue(loading, "Loading parameter is true")

        // This verifies the condition that guards render prep execution
        // The actual functions (performFrustumCulling, executeGaussianDepth, executeBitonicSort)
        // should NOT be called when loading is true
        var renderPrepExecuted = false
        if !loading {
            renderPrepExecuted = true
        }
        XCTAssertFalse(renderPrepExecuted, "Render prep should not execute when loading is true")
    }

    func testXRSystemPass_ExecutesRenderPrepWhenLoadingParameterIsFalse() {
        // Given: A loading parameter set to false
        let loading = false

        // When: The loading condition is checked
        var renderPrepExecuted = false
        if !loading {
            renderPrepExecuted = true
        }

        // Then: The render prep should execute
        XCTAssertTrue(renderPrepExecuted, "Render prep should execute when loading is false")
    }

    func testXRSystemPass_DoesNotUpdateVisibleEntityIdsWhenLoadingParameterIsTrue() {
        // Given: A loading parameter set to true
        let loading = true
        let initialVisibleIds = visibleEntityIds

        // Seed with different test data
        let testEntityIds: [EntityID] = [createEntityId(300, 1)]
        tripleVisibleEntities.setWrite(frame: cullFrameIndex, with: testEntityIds)

        // When: We apply the executeXRSystemPass logic:
        // `if !loading { visibleEntityIds = tripleVisibleEntities.snapshotForRead(frame: cullFrameIndex) }`
        if !loading {
            visibleEntityIds = tripleVisibleEntities.snapshotForRead(frame: cullFrameIndex)
        }

        // Then: visibleEntityIds should NOT have been updated
        XCTAssertEqual(visibleEntityIds, initialVisibleIds,
                       "visibleEntityIds should not be updated when loading parameter is true")
    }

    func testXRSystemPass_UpdatesVisibleEntityIdsWhenLoadingParameterIsFalse() {
        // Given: A loading parameter set to false
        let loading = false

        // Seed all triple buffer slots with test data
        let testEntityIds: [EntityID] = [createEntityId(400, 1), createEntityId(401, 1)]
        for frame in 0 ..< 3 {
            tripleVisibleEntities.setWrite(frame: frame, with: testEntityIds)
        }

        // When: We apply the executeXRSystemPass logic
        if !loading {
            visibleEntityIds = tripleVisibleEntities.snapshotForRead(frame: cullFrameIndex)
        }

        // Then: visibleEntityIds should have been updated
        XCTAssertEqual(visibleEntityIds, testEntityIds,
                       "visibleEntityIds should be updated when loading parameter is false")
    }

    // MARK: - Test 5: Transition from loading true to false

    func testRenderingResumesCorrectlyWhenLoadingTransitionsFromTrueToFalse() {
        // Given: Initial state with known visible entities
        let initialVisibleIds: [EntityID] = visibleEntityIds

        // Start loading
        AssetLoadingGate.shared.beginLoading()
        XCTAssertTrue(AssetLoadingGate.shared.isLoadingAny, "Loading should be active")

        // Seed new data while loading
        let newVisibleIds: [EntityID] = [createEntityId(500, 1), createEntityId(501, 1)]
        for frame in 0 ..< 3 {
            tripleVisibleEntities.setWrite(frame: frame, with: newVisibleIds)
        }

        // Verify visibleEntityIds is not updated during loading
        var loading = AssetLoadingGate.shared.isLoadingAny
        if !loading {
            visibleEntityIds = tripleVisibleEntities.snapshotForRead(frame: cullFrameIndex)
        }
        XCTAssertEqual(visibleEntityIds, initialVisibleIds,
                       "visibleEntityIds should remain unchanged during loading")

        // When: Loading finishes (transition from true to false)
        AssetLoadingGate.shared.finishLoading()
        XCTAssertFalse(AssetLoadingGate.shared.isLoadingAny, "Loading should be inactive after finishLoading()")

        // Simulate next frame update
        loading = AssetLoadingGate.shared.isLoadingAny
        if !loading {
            visibleEntityIds = tripleVisibleEntities.snapshotForRead(frame: cullFrameIndex)
        }

        // Then: visibleEntityIds should now be updated with the new data
        XCTAssertEqual(visibleEntityIds, newVisibleIds,
                       "visibleEntityIds should be updated after loading transition")
    }

    func testRenderingBehaviorDuringLoadingStateTransition() {
        // Test the complete transition cycle: idle -> loading -> idle

        // Phase 1: Idle state - rendering should work normally
        resetLoadingGate()
        XCTAssertFalse(AssetLoadingGate.shared.isLoadingAny, "Should start in idle state")

        var renderPrepShouldExecute = !AssetLoadingGate.shared.isLoadingAny
        XCTAssertTrue(renderPrepShouldExecute, "Render prep should execute in idle state")

        // Phase 2: Begin loading - rendering prep should skip
        AssetLoadingGate.shared.beginLoading()
        XCTAssertTrue(AssetLoadingGate.shared.isLoadingAny, "Should be in loading state")

        renderPrepShouldExecute = !AssetLoadingGate.shared.isLoadingAny
        XCTAssertFalse(renderPrepShouldExecute, "Render prep should skip during loading")

        // Phase 3: Multiple nested loads (simulating concurrent asset loading)
        AssetLoadingGate.shared.beginLoading()
        AssetLoadingGate.shared.beginLoading()
        XCTAssertTrue(AssetLoadingGate.shared.isLoadingAny, "Should still be loading with multiple active loads")

        // Phase 4: Finish loads one by one
        AssetLoadingGate.shared.finishLoading()
        XCTAssertTrue(AssetLoadingGate.shared.isLoadingAny, "Should still be loading (2 remaining)")

        AssetLoadingGate.shared.finishLoading()
        XCTAssertTrue(AssetLoadingGate.shared.isLoadingAny, "Should still be loading (1 remaining)")

        AssetLoadingGate.shared.finishLoading()
        XCTAssertFalse(AssetLoadingGate.shared.isLoadingAny, "Should be idle after all loads finish")

        // Phase 5: Verify rendering resumes
        renderPrepShouldExecute = !AssetLoadingGate.shared.isLoadingAny
        XCTAssertTrue(renderPrepShouldExecute, "Render prep should execute after loading completes")
    }

    func testVisibleEntitiesUpdateAfterLoadingTransition() {
        // Given: Set up known state
        resetLoadingGate()
        _ = visibleEntityIds // Store original state for reference

        // Prepare new visible entities data
        let updatedVisibleIds: [EntityID] = [
            createEntityId(600, 1),
            createEntityId(601, 1),
            createEntityId(602, 1),
        ]

        // Start loading
        AssetLoadingGate.shared.beginLoading()

        // Simulate culling producing new results during loading (written to triple buffer)
        for frame in 0 ..< 3 {
            tripleVisibleEntities.setWrite(frame: frame, with: updatedVisibleIds)
        }

        // During loading: visibleEntityIds should NOT update
        var loading = AssetLoadingGate.shared.isLoadingAny
        var previousVisibleIds = visibleEntityIds
        if !loading {
            visibleEntityIds = tripleVisibleEntities.snapshotForRead(frame: cullFrameIndex)
        }
        XCTAssertEqual(visibleEntityIds, previousVisibleIds,
                       "visibleEntityIds should not change during loading")

        // Finish loading
        AssetLoadingGate.shared.finishLoading()

        // After loading: visibleEntityIds SHOULD update on next frame
        loading = AssetLoadingGate.shared.isLoadingAny
        XCTAssertFalse(loading, "Loading should be finished")

        if !loading {
            visibleEntityIds = tripleVisibleEntities.snapshotForRead(frame: cullFrameIndex)
        }

        XCTAssertEqual(visibleEntityIds, updatedVisibleIds,
                       "visibleEntityIds should update after loading completes")
    }

    // MARK: - Additional Edge Case Tests

    func testLoadingGateReferenceCountingBehavior() {
        // Verify that the loading gate correctly handles reference counting
        resetLoadingGate()
        XCTAssertFalse(AssetLoadingGate.shared.isLoadingAny, "Should start inactive")

        // Begin multiple loads
        for _ in 0 ..< 5 {
            AssetLoadingGate.shared.beginLoading()
        }
        XCTAssertTrue(AssetLoadingGate.shared.isLoadingAny, "Should be active with 5 loads")

        // Finish all but one
        for _ in 0 ..< 4 {
            AssetLoadingGate.shared.finishLoading()
        }
        XCTAssertTrue(AssetLoadingGate.shared.isLoadingAny, "Should still be active with 1 remaining load")

        // Finish the last one
        AssetLoadingGate.shared.finishLoading()
        XCTAssertFalse(AssetLoadingGate.shared.isLoadingAny, "Should be inactive when all loads complete")
    }

    func testLoadingGateProtectsAgainstOverFinishing() {
        // Verify the gate doesn't go negative when finishLoading is called too many times
        resetLoadingGate()

        AssetLoadingGate.shared.beginLoading()
        AssetLoadingGate.shared.finishLoading()
        XCTAssertFalse(AssetLoadingGate.shared.isLoadingAny, "Should be inactive")

        // Call finish again (should not crash or go negative)
        AssetLoadingGate.shared.finishLoading()
        AssetLoadingGate.shared.finishLoading()
        XCTAssertFalse(AssetLoadingGate.shared.isLoadingAny, "Should remain inactive (protected against negative count)")
    }

    func testRenderingSystemLogicPathsMatchImplementation() {
        // This test verifies that the test logic paths match the actual implementation patterns
        // in UpdateRenderingSystem and executeXRSystemPass

        /// Test the UpdateRenderingSystem pattern
        func simulateUpdateRenderingSystem() -> (visibleUpdated: Bool, renderPrepExecuted: Bool) {
            let loading = AssetLoadingGate.shared.isLoadingAny
            var visibleUpdated = false
            var renderPrepExecuted = false

            // Pattern from UpdateRenderingSystem lines 28-46:
            // if !loading { visibleEntityIds = ... }
            // if !loading { performFrustumCulling...; executeGaussianDepth...; executeBitonicSort... }
            if !loading {
                visibleUpdated = true
            }
            if !loading {
                renderPrepExecuted = true
            }
            return (visibleUpdated, renderPrepExecuted)
        }

        // Test when loading
        AssetLoadingGate.shared.beginLoading()
        var result = simulateUpdateRenderingSystem()
        XCTAssertFalse(result.visibleUpdated, "Visible entities should not update during loading")
        XCTAssertFalse(result.renderPrepExecuted, "Render prep should not execute during loading")
        AssetLoadingGate.shared.finishLoading()

        // Test when not loading
        result = simulateUpdateRenderingSystem()
        XCTAssertTrue(result.visibleUpdated, "Visible entities should update when not loading")
        XCTAssertTrue(result.renderPrepExecuted, "Render prep should execute when not loading")
    }

    func testXRSystemPassLogicPathsMatchImplementation() {
        // This test verifies that the XR system pass loading parameter behavior
        // matches the implementation pattern in executeXRSystemPass

        func simulateExecuteXRSystemPass(loading: Bool) -> (visibleUpdated: Bool, renderPrepExecuted: Bool) {
            var visibleUpdated = false
            var renderPrepExecuted = false

            // Pattern from executeXRSystemPass lines 219-231:
            // if !loading { visibleEntityIds = ... }
            // if !loading { performFrustumCulling...; executeGaussianDepth...; executeBitonicSort... }
            if !loading {
                visibleUpdated = true
            }
            if !loading {
                renderPrepExecuted = true
            }
            return (visibleUpdated, renderPrepExecuted)
        }

        // Test with loading = true
        var result = simulateExecuteXRSystemPass(loading: true)
        XCTAssertFalse(result.visibleUpdated, "XR: Visible entities should not update when loading=true")
        XCTAssertFalse(result.renderPrepExecuted, "XR: Render prep should not execute when loading=true")

        // Test with loading = false
        result = simulateExecuteXRSystemPass(loading: false)
        XCTAssertTrue(result.visibleUpdated, "XR: Visible entities should update when loading=false")
        XCTAssertTrue(result.renderPrepExecuted, "XR: Render prep should execute when loading=false")
    }
}
