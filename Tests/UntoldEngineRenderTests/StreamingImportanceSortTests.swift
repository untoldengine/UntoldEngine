//
//  StreamingImportanceSortTests.swift
//  UntoldEngine
//
//  Tests for screen-space importance scoring added to GeometryStreamingSystem:
//    1. importanceScore(entityId:distance:) — verifies the helper returns the correct
//       bounding-radius / distance value and handles edge cases.
//    2. Sort order integration — verifies that with enableImportanceSort = true a
//       large-AABB tile is dispatched before a small-AABB tile that is slightly closer,
//       and that disabling the flag reverts to pure distance ordering.
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldEngine
import XCTest

// MARK: - importanceScore helper unit tests

/// Tests the `importanceScore(entityId:distance:)` helper that approximates
/// angular screen size as (max AABB half-extent) / distance.
@MainActor
final class ImportanceScoreTests: BaseRenderSetup {
    override func setUp() async throws {
        try await super.setUp()
        GeometryStreamingSystem.shared.reset()
    }

    override func tearDown() async throws {
        GeometryStreamingSystem.shared.reset()
        try await super.tearDown()
    }

    // MARK: Helpers

    /// Create an entity whose LocalTransformComponent has the given half-extents.
    /// The AABB is centred at the origin, so the half-extents match the inputs exactly.
    private func makeEntity(halfX: Float, halfY: Float, halfZ: Float) -> EntityID {
        let entityId = createEntity()
        if let local = scene.assign(to: entityId, component: LocalTransformComponent.self) {
            local.boundingBox = (
                min: simd_float3(-halfX, -halfY, -halfZ),
                max: simd_float3(halfX, halfY, halfZ)
            )
        }
        return entityId
    }

    // MARK: Tests

    func testImportanceScore_returnsMaxHalfExtentOverDistance() {
        // AABB half-extents (1, 2, 3) → max = 3 → score = 3/30
        let entityId = makeEntity(halfX: 1, halfY: 2, halfZ: 3)
        let score = GeometryStreamingSystem.shared.importanceScore(entityId: entityId, distance: 30.0)
        XCTAssertEqual(score, 3.0 / 30.0, accuracy: 1e-5)
    }

    func testImportanceScore_usesLargestAxis() {
        // Only the Z half-extent is large; the formula picks max(1,1,10) = 10.
        let entityId = makeEntity(halfX: 1, halfY: 1, halfZ: 10)
        let score = GeometryStreamingSystem.shared.importanceScore(entityId: entityId, distance: 20.0)
        XCTAssertEqual(score, 10.0 / 20.0, accuracy: 1e-5)
    }

    func testImportanceScore_uniformAABB() {
        let entityId = makeEntity(halfX: 10, halfY: 10, halfZ: 10)
        let score = GeometryStreamingSystem.shared.importanceScore(entityId: entityId, distance: 50.0)
        XCTAssertEqual(score, 10.0 / 50.0, accuracy: 1e-5)
    }

    func testImportanceScore_zeroDistanceClampedToOne() {
        // distance = 0 must not divide by zero — clamped to max(0, 1) = 1.
        let entityId = makeEntity(halfX: 5, halfY: 5, halfZ: 5)
        let score = GeometryStreamingSystem.shared.importanceScore(entityId: entityId, distance: 0.0)
        XCTAssertEqual(score, 5.0 / 1.0, accuracy: 1e-5)
    }

    func testImportanceScore_fallback_noLocalTransform() {
        // Entity without LocalTransformComponent falls back to radius = 1.0.
        let entityId = createEntity()
        let score = GeometryStreamingSystem.shared.importanceScore(entityId: entityId, distance: 10.0)
        XCTAssertEqual(score, 1.0 / 10.0, accuracy: 1e-5)
    }

    func testImportanceScore_largerObjectScoresHigherAtSameDistance() {
        let large = makeEntity(halfX: 20, halfY: 20, halfZ: 20)
        let small = makeEntity(halfX: 1, halfY: 1, halfZ: 1)
        let dist: Float = 40.0
        XCTAssertGreaterThan(
            GeometryStreamingSystem.shared.importanceScore(entityId: large, distance: dist),
            GeometryStreamingSystem.shared.importanceScore(entityId: small, distance: dist),
            "Larger AABB should score higher at equal distance"
        )
    }

    func testImportanceScore_closerObjectScoresHigherWithSameSize() {
        let entityId = makeEntity(halfX: 5, halfY: 5, halfZ: 5)
        let near = GeometryStreamingSystem.shared.importanceScore(entityId: entityId, distance: 10.0)
        let far = GeometryStreamingSystem.shared.importanceScore(entityId: entityId, distance: 50.0)
        XCTAssertGreaterThan(near, far, "Closer object should score higher with the same AABB")
    }
}

// MARK: - Sort order integration tests

/// Verifies that GeometryStreamingSystem dispatches tile loads in importance order
/// (larger screen footprint first) when enableImportanceSort = true, and falls back to
/// pure distance ordering when the flag is false.
///
/// Scenario:
///   Tile A — AABB half-extent 20 m at distance 45 → importance ≈ 0.444
///   Tile B — AABB half-extent  1 m at distance 40 → importance ≈ 0.025
///
/// maxConcurrentTileLoads = 1 so only one tile is dispatched per update() tick.
/// `loadTile` sets `tileComp.state = .parsing` synchronously before returning, so
/// the assertion can be made immediately after `update()` without any async waiting.
@MainActor
final class StreamingImportanceSortIntegrationTests: BaseRenderSetup {
    override func setUp() async throws {
        try await super.setUp()

        GeometryStreamingSystem.shared.reset()
        GeometryStreamingSystem.shared.enabled = true
        GeometryStreamingSystem.shared.updateInterval = 0.0
        GeometryStreamingSystem.shared.maxConcurrentTileLoads = 1 // one dispatch per tick
        GeometryStreamingSystem.shared.enableFrustumGate = false // skip view-frustum test
        GeometryStreamingSystem.shared.enableImportanceSort = true // default under test

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
        GeometryStreamingSystem.shared.enableImportanceSort = true
        OctreeSystem.shared.clear()
        MemoryBudgetManager.shared.clear()
        try await super.tearDown()
    }

    // MARK: Helpers

    /// Create a tile stub with the near face of its AABB at `distance` along the X axis.
    /// `calculateDistance` uses closest-point-on-AABB, so the returned distance equals
    /// the `distance` argument when the camera is at the origin.
    /// `halfExtent` drives all three AABB axes, so importanceScore = halfExtent / distance.
    @discardableResult
    private func makeTileStub(
        distance: Float,
        halfExtent: Float,
        id: String,
        priority: Int = 0
    ) -> (EntityID, TileComponent) {
        let entityId = createEntity()

        if let local = scene.assign(to: entityId, component: LocalTransformComponent.self) {
            local.boundingBox = (
                min: simd_float3(distance, -halfExtent, -halfExtent),
                max: simd_float3(distance + halfExtent * 2.0, halfExtent, halfExtent)
            )
        }
        if let world = scene.assign(to: entityId, component: WorldTransformComponent.self) {
            world.space = simd_float4x4(1.0)
        }

        guard let tileComp = scene.assign(to: entityId, component: TileComponent.self) else {
            XCTFail("Failed to assign TileComponent to entity \(entityId)")
            return (entityId, TileComponent())
        }

        tileComp.state = .unloaded
        tileComp.tileId = id
        tileComp.tileURL = URL(fileURLWithPath: "/dev/null")
        tileComp.streamingRadius = 60.0
        tileComp.unloadRadius = 200.0
        tileComp.hlodSwitchDistance = 0
        tileComp.hlodState = .unloaded
        tileComp.lodLevels = [] // no LOD levels — avoids the LOD-distance gate
        tileComp.fileSizeBytes = 0 // zero budget cost
        tileComp.priority = priority

        OctreeSystem.shared.registerEntity(entityId)
        return (entityId, tileComp)
    }

    // MARK: Tests

    /// With importance sort on, the tile with the larger AABB (higher importance score)
    /// is dispatched first even though it is farther from the camera.
    func testImportanceSort_enabled_largeObjectDispatchedFirst() {
        // A: halfExtent=20, distance=45 → importance = 20/45 ≈ 0.444
        // B: halfExtent=1,  distance=40 → importance =  1/40 ≈ 0.025
        let (_, tileA) = makeTileStub(distance: 45, halfExtent: 20, id: "tile_A")
        let (_, tileB) = makeTileStub(distance: 40, halfExtent: 1, id: "tile_B")

        GeometryStreamingSystem.shared.enableImportanceSort = true

        GeometryStreamingSystem.shared.update(
            cameraPosition: simd_float3(0, 0, 0),
            deltaTime: 0.016
        )

        XCTAssertEqual(tileA.state, .parsing,
                       "Tile A (large AABB, higher importance) should be dispatched first")
        XCTAssertEqual(tileB.state, .unloaded,
                       "Tile B (small AABB, lower importance) should wait")
    }

    /// With importance sort off, the closer tile is dispatched first regardless of size.
    func testImportanceSort_disabled_closerObjectDispatchedFirst() {
        let (_, tileA) = makeTileStub(distance: 45, halfExtent: 20, id: "tile_A")
        let (_, tileB) = makeTileStub(distance: 40, halfExtent: 1, id: "tile_B")

        GeometryStreamingSystem.shared.enableImportanceSort = false

        GeometryStreamingSystem.shared.update(
            cameraPosition: simd_float3(0, 0, 0),
            deltaTime: 0.016
        )

        XCTAssertEqual(tileB.state, .parsing,
                       "Tile B (closer) should be dispatched first when importance sort is off")
        XCTAssertEqual(tileA.state, .unloaded,
                       "Tile A (farther) should wait when importance sort is off")
    }

    /// Priority is always the primary sort key — a high-priority tile beats a
    /// low-priority tile with a larger importance score.
    func testImportanceSort_priorityAlwaysWins() {
        // High priority, small AABB, farther — importance ≈ 0.022
        let (_, tileHighPrio) = makeTileStub(distance: 45, halfExtent: 1, id: "high_prio", priority: 10)
        // Low priority, large AABB, closer — importance ≈ 0.444
        let (_, tileLowPrio) = makeTileStub(distance: 40, halfExtent: 20, id: "low_prio", priority: 0)

        GeometryStreamingSystem.shared.enableImportanceSort = true

        GeometryStreamingSystem.shared.update(
            cameraPosition: simd_float3(0, 0, 0),
            deltaTime: 0.016
        )

        XCTAssertEqual(tileHighPrio.state, .parsing,
                       "High-priority tile should be dispatched first regardless of importance score")
        XCTAssertEqual(tileLowPrio.state, .unloaded,
                       "Low-priority tile should wait even if it has a higher importance score")
    }

    /// Enabling then disabling importance sort within the same test confirms the
    /// `enableImportanceSort` flag is read each tick, not cached.
    func testImportanceSort_flagRespectedEachTick() {
        // First tick: importance sort ON — tile A (larger, farther) goes first.
        let (entityA, tileA) = makeTileStub(distance: 45, halfExtent: 20, id: "tile_A")
        let (_, tileB) = makeTileStub(distance: 40, halfExtent: 1, id: "tile_B")

        GeometryStreamingSystem.shared.enableImportanceSort = true
        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 0.016)
        XCTAssertEqual(tileA.state, .parsing, "First tick: A should be dispatched")

        // Simulate A finishing (or cancel it) so the slot is free for the next tick.
        tileA.state = .parsed
        GeometryStreamingSystem.shared.withStateLock {
            _ = GeometryStreamingSystem.shared.activeTileLoads.removeValue(forKey: entityA)
        }

        // Second tick: importance sort OFF — tile B (closer) should now go first.
        GeometryStreamingSystem.shared.enableImportanceSort = false
        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 0.016)
        XCTAssertEqual(tileB.state, .parsing, "Second tick: B (closer) should be dispatched when sort is off")
    }
}
