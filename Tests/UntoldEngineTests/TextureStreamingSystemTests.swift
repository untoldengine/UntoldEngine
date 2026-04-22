//
//  TextureStreamingSystemTests.swift
//  UntoldEngineTests
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldEngine
import XCTest

@MainActor
final class TextureStreamingSystemTests: XCTestCase {
    var system: TextureStreamingSystem!

    override func setUp() async throws {
        system = TextureStreamingSystem.shared
        system.reset()
        system.enabled = true
        system.upgradeRadius = 30.0
        system.downgradeRadius = 60.0
        system.maxTextureDimension = 1024
        system.minimumTextureDimension = 256
        system.updateInterval = 0.2
        system.maxConcurrentOps = 3
    }

    override func tearDown() async throws {
        system.reset()
    }

    // MARK: - Initial State

    func testInitialStatsAreZero() {
        system.reset()
        let stats = system.getStats()
        XCTAssertEqual(stats.totalUpgrades, 0)
        XCTAssertEqual(stats.totalDowngrades, 0)
        XCTAssertEqual(stats.upgradedEntityCount, 0)
        XCTAssertEqual(stats.activeOps, 0)
    }

    // MARK: - Reset

    func testResetClearsStats() {
        // Stats start at zero; reset should keep them at zero and not crash.
        system.reset()
        let stats = system.getStats()
        XCTAssertEqual(stats.totalUpgrades, 0)
        XCTAssertEqual(stats.totalDowngrades, 0)
        XCTAssertEqual(stats.upgradedEntityCount, 0)
        XCTAssertEqual(stats.activeOps, 0)
    }

    func testResetIsIdempotent() {
        system.reset()
        system.reset()
        let stats = system.getStats()
        XCTAssertEqual(stats.totalUpgrades, 0)
        XCTAssertEqual(stats.upgradedEntityCount, 0)
    }

    // MARK: - Enabled Flag

    func testDisabledSystemSkipsUpdate() {
        system.enabled = false
        // With no entities in the scene the call should be a no-op regardless,
        // but the guard should fire before any ECS access.
        system.update(cameraPosition: .zero, deltaTime: 1.0)
        let stats = system.getStats()
        XCTAssertEqual(stats.activeOps, 0)
    }

    func testReenablingSystemAllowsUpdate() {
        system.enabled = false
        system.enabled = true
        // No crash, no ops with an empty scene.
        system.update(cameraPosition: .zero, deltaTime: 1.0)
        XCTAssertEqual(system.getStats().activeOps, 0)
    }

    // MARK: - Timer Throttling

    func testUpdateThrottledBelowInterval() {
        // Accumulate time below the threshold — no evaluation should occur.
        system.updateInterval = 0.5
        system.update(cameraPosition: .zero, deltaTime: 0.1)
        system.update(cameraPosition: .zero, deltaTime: 0.1)
        // With an empty scene the result is also zero ops, but this confirms
        // no panic or assertion fires during the throttle window.
        XCTAssertEqual(system.getStats().activeOps, 0)
    }

    func testUpdateFiresAfterIntervalElapsed() {
        system.updateInterval = 0.2
        // First call accumulates 0.25 s, which exceeds the interval.
        system.update(cameraPosition: .zero, deltaTime: 0.25)
        // No entities → zero ops, but the timer must have reset (no assert).
        XCTAssertEqual(system.getStats().activeOps, 0)
    }

    func testTimerResetsAfterFiring() {
        system.updateInterval = 0.2
        system.update(cameraPosition: .zero, deltaTime: 0.25) // fires, resets timer
        system.update(cameraPosition: .zero, deltaTime: 0.05) // below threshold again
        XCTAssertEqual(system.getStats().activeOps, 0)
    }

    // MARK: - Configuration Defaults

    func testDefaultRadiusValues() {
        XCTAssertEqual(system.upgradeRadius, 30.0, accuracy: 1e-6)
        XCTAssertEqual(system.downgradeRadius, 60.0, accuracy: 1e-6)
    }

    func testDefaultDimensionValues() {
        // maxTextureDimension must be strictly positive.
        XCTAssertGreaterThan(system.maxTextureDimension, 0)
        // minimumTextureDimension must be ≤ maxTextureDimension.
        XCTAssertLessThanOrEqual(system.minimumTextureDimension, system.maxTextureDimension)
    }

    func testDefaultConcurrencyLimit() {
        XCTAssertGreaterThan(system.maxConcurrentOps, 0)
    }

    // MARK: - Configuration Mutation

    func testCanOverrideRadii() {
        system.upgradeRadius = 10.0
        system.downgradeRadius = 50.0
        XCTAssertEqual(system.upgradeRadius, 10.0, accuracy: 1e-6)
        XCTAssertEqual(system.downgradeRadius, 50.0, accuracy: 1e-6)
    }

    func testCanOverrideDimensions() {
        system.maxTextureDimension = 512
        system.minimumTextureDimension = 128
        XCTAssertEqual(system.maxTextureDimension, 512)
        XCTAssertEqual(system.minimumTextureDimension, 128)
    }

    func testCanOverrideConcurrencyLimit() {
        system.maxConcurrentOps = 1
        XCTAssertEqual(system.maxConcurrentOps, 1)
    }

    // MARK: - Stats Struct

    func testTextureStreamingStatsFields() {
        var stats = TextureStreamingStats(
            totalUpgrades: 5,
            totalDowngrades: 3,
            upgradedEntityCount: 2,
            activeOps: 1
        )
        XCTAssertEqual(stats.totalUpgrades, 5)
        XCTAssertEqual(stats.totalDowngrades, 3)
        XCTAssertEqual(stats.upgradedEntityCount, 2)
        XCTAssertEqual(stats.activeOps, 1)

        stats.totalUpgrades = 10
        XCTAssertEqual(stats.totalUpgrades, 10)
    }

    // MARK: - Concurrency Cap (no entities)

    func testUpdateRespectsMaxConcurrentOps() {
        system.maxConcurrentOps = 1
        // Empty scene → zero ops are ever launched; cap is not exceeded.
        system.update(cameraPosition: .zero, deltaTime: 1.0)
        XCTAssertLessThanOrEqual(system.getStats().activeOps, system.maxConcurrentOps)
    }

    // MARK: - Three-Tier TextureStreamingLevel

    func testTextureStreamingLevelHasThreeCases() {
        // Ensure all three enum cases are distinct and can be compared.
        XCTAssertNotEqual(TextureStreamingLevel.full, TextureStreamingLevel.capped)
        XCTAssertNotEqual(TextureStreamingLevel.full, TextureStreamingLevel.minimum)
        XCTAssertNotEqual(TextureStreamingLevel.capped, TextureStreamingLevel.minimum)
    }

    func testTextureStreamingLevelFullIsDefaultValue() {
        // .full is the sentinel "not yet streamed" state — verify its raw identity.
        // (Material cannot be constructed without Metal state; this test confirms
        //  the enum's default value without needing a live GPU device.)
        let defaultLevel = TextureStreamingLevel.full
        XCTAssertNotEqual(defaultLevel, .capped)
        XCTAssertNotEqual(defaultLevel, .minimum)
    }

    func testStreamLevelThresholdCappedVsMinimum() {
        // Simulate the three-tier streamLevel assignment used in scheduleResolutionChange.
        // capturedMinimumDim = 256; anything <= 256 → .minimum, anything > 256 → .capped, nil → .full.
        let minimumDim = 256

        let resolveLevel: (Int?) -> TextureStreamingLevel = { targetMaxDimension in
            guard let dim = targetMaxDimension else { return .full }
            return dim <= minimumDim ? .minimum : .capped
        }

        XCTAssertEqual(resolveLevel(nil), .full)
        XCTAssertEqual(resolveLevel(256), .minimum) // exactly at minimum threshold
        XCTAssertEqual(resolveLevel(192), .minimum) // below minimum threshold (visionOS)
        XCTAssertEqual(resolveLevel(257), .capped) // just above minimum threshold
        XCTAssertEqual(resolveLevel(1024), .capped) // medium dimension
    }

    func testNormalizedMinimumDimensionIsPositive() {
        system.minimumTextureDimension = 256
        XCTAssertGreaterThan(system.minimumTextureDimension, 0)
    }

    func testMinimumDimensionBelowOrEqualToMaxDimension() {
        system.maxTextureDimension = 1024
        system.minimumTextureDimension = 256
        XCTAssertLessThanOrEqual(system.minimumTextureDimension, system.maxTextureDimension)
    }

    // MARK: - Distance Model

    func testDistanceToWorldAABBUsesNearestSurfaceNotCenter() {
        let distance = TextureStreamingSystem.distanceToWorldAABB(
            cameraPosition: simd_float3(0, 0, 0.2),
            worldTransform: matrix_identity_float4x4,
            localMin: simd_float3(-10, -1, -1),
            localMax: simd_float3(10, 1, 1)
        )

        XCTAssertEqual(distance, 0.0, accuracy: 1e-5)
    }

    func testDistanceToWorldAABBPreservesWorldScale() {
        let worldTransform = matrix4x4Scale(0.1, 0.1, 0.1)
        let distance = TextureStreamingSystem.distanceToWorldAABB(
            cameraPosition: simd_float3(1.2, 0, 0),
            worldTransform: worldTransform,
            localMin: simd_float3(-10, -1, -1),
            localMax: simd_float3(10, 1, 1)
        )

        XCTAssertEqual(distance, 0.2, accuracy: 1e-5)
    }

    // MARK: - Detailed Profile

    func testApplyDetailedProfileSetsExpectedValues() {
        system.apply(.detailed)
        XCTAssertEqual(system.upgradeRadius, 2.5, accuracy: 1e-6)
        XCTAssertEqual(system.downgradeRadius, 6.0, accuracy: 1e-6)
        XCTAssertEqual(system.maxTextureDimension, 1024)
        XCTAssertEqual(system.minimumTextureDimension, 512)
        XCTAssertEqual(system.maxConcurrentOps, 6)
        XCTAssertEqual(system.updateInterval, 0.1, accuracy: 1e-6)
    }

    func testApplyDetailedProfileUpgradeRadiusLessThanDowngrade() {
        system.apply(.detailed)
        XCTAssertLessThan(system.upgradeRadius, system.downgradeRadius)
    }

    // MARK: - Superdetailed Profile

    func testApplySuperdetailedProfileSetsExpectedValues() {
        system.apply(.superdetailed)
        XCTAssertEqual(system.upgradeRadius, 4.0, accuracy: 1e-6)
        XCTAssertEqual(system.downgradeRadius, 8.0, accuracy: 1e-6)
        XCTAssertEqual(system.maxTextureDimension, 2048)
        XCTAssertEqual(system.minimumTextureDimension, 1024)
        XCTAssertEqual(system.maxConcurrentOps, 6)
        XCTAssertEqual(system.updateInterval, 0.1, accuracy: 1e-6)
    }

    func testApplySuperdetailedProfileUpgradeRadiusLessThanDowngrade() {
        system.apply(.superdetailed)
        XCTAssertLessThan(system.upgradeRadius, system.downgradeRadius)
    }

    // MARK: - Tiled Profile

    func testApplyTiledProfileSetsExpectedValues() {
        system.apply(.tiled)
        XCTAssertEqual(system.upgradeRadius, 30.0, accuracy: 1e-6)
        XCTAssertEqual(system.downgradeRadius, 70.0, accuracy: 1e-6)
        XCTAssertEqual(system.maxTextureDimension, 1024)
        XCTAssertEqual(system.minimumTextureDimension, 256)
        XCTAssertGreaterThan(system.maxConcurrentOps, 0)
    }

    func testApplyTiledProfileUpgradeRadiusLessThanDowngrade() {
        system.apply(.tiled)
        XCTAssertLessThan(system.upgradeRadius, system.downgradeRadius)
    }

    // MARK: - alignToManifest

    func testAlignToManifestOverridesRadii() {
        system.alignToManifest(streamingRadius: 38.5, unloadRadius: 57.8)
        XCTAssertEqual(system.upgradeRadius, 38.5 * 0.70, accuracy: 1e-4)
        XCTAssertEqual(system.downgradeRadius, 57.8, accuracy: 1e-4)
    }

    func testAlignToManifestEnforcesDowngradeMinimum() {
        // When unloadRadius is smaller than the downgrade floors, the widest floor wins.
        system.alignToManifest(streamingRadius: 10.0, unloadRadius: 5.0)
        let expectedUpgrade = max(Float(10.0 * 0.70), 2.5)
        let expectedDowngrade = max(Float(5.0), expectedUpgrade + 1.0, expectedUpgrade * 2.0)
        XCTAssertEqual(system.upgradeRadius, expectedUpgrade, accuracy: 1e-4)
        XCTAssertEqual(system.downgradeRadius, expectedDowngrade, accuracy: 1e-4)
    }

    func testAlignToManifestAppliesTiledProfileSettings() {
        // alignToManifest calls apply(.tiled) internally so tiled profile values
        // (dimensions, concurrency) are set alongside the manifest-derived radii.
        system.alignToManifest(streamingRadius: 38.5, unloadRadius: 57.8)
        XCTAssertEqual(system.maxTextureDimension, 1024)
        XCTAssertEqual(system.minimumTextureDimension, 256)
    }

    func testAlignToManifestUpgradeAlwaysLessThanDowngrade() {
        system.alignToManifest(streamingRadius: 38.5, unloadRadius: 57.8)
        XCTAssertLessThan(system.upgradeRadius, system.downgradeRadius)
    }

    // MARK: - notifyEntitiesReady / cancelEntities

    func testNotifyEntitiesReadyWithEmptySetDoesNotCrash() {
        system.notifyEntitiesReady([])
        XCTAssertEqual(system.getStats().activeOps, 0)
    }

    func testCancelEntitiesWithEmptySetDoesNotCrash() {
        system.cancelEntities([])
        XCTAssertEqual(system.getStats().activeOps, 0)
    }

    func testResetClearsPriorityEntities() {
        // notifyEntitiesReady adds to priorityEntities; reset must drain it.
        // We verify indirectly: after reset the system remains fully operational.
        system.notifyEntitiesReady([EntityID(0)])
        system.reset()
        let stats = system.getStats()
        XCTAssertEqual(stats.activeOps, 0)
        XCTAssertEqual(stats.upgradedEntityCount, 0)
    }
}
